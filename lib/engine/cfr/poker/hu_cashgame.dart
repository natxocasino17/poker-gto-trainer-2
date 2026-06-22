import 'dart:math';
import '../cfr_game.dart';
import 'bet_sizing_config.dart';
import 'hand_abstraction.dart';
import 'hu_state.dart';

/// Two-player zero-sum abstracted Texas Hold'em cash game (100BB heads-up).
///
/// Game-tree structure
/// ───────────────────
///   ROOT → Chance (deal preflop buckets)
///     └─ Preflop betting
///           └─ Chance (deal board + postflop buckets)
///                 └─ Flop betting
///                       └─ Chance (turn card refinement)
///                             └─ Turn betting
///                                   └─ Chance (river card refinement)
///                                         └─ River betting → Terminal
///
/// Folded hands resolve immediately; showdown equity is read from the
/// pre-computed [HandAbstraction] tables — no card enumeration at solve time.
///
/// Players:  0 = BTN/SB (IP postflop)   1 = BB (OOP postflop)
/// Streets:  preflop acts from P0; postflop acts from P1 (OOP first).
class HuCashGame extends CfrGame<HuState> {
  final BetSizingConfig cfg;

  /// When true the solver traverses all four streets (full tree).
  /// When false it terminates at the first street-transition chance node,
  /// producing a much faster "spot solve" suitable for real-time mobile use.
  final bool fullTree;

  const HuCashGame({
    this.cfg = BetSizingConfig.standard,
    this.fullTree = false,
  });

  // ─── CfrGame interface ────────────────────────────────────────────────────

  @override
  HuState root() => HuState.initial100BB();

  @override
  bool isTerminal(HuState s) {
    if (s.p0Folded || s.p1Folded) return true;
    if (!s.isDealt) return false;

    // All-in run-out or round complete on the river
    if (s.street == HuStreet.river && s.actorsLeft == 0) return true;

    // One player all-in mid-street (run-out of remaining streets)
    if (_allInRunout(s)) return true;

    // Spot-solve mode: terminate at first street transition
    if (!fullTree && s.actorsLeft == 0 && s.street == HuStreet.preflop && s.isDealt) {
      return true;
    }

    return false;
  }

  @override
  double utilityForP0(HuState s) {
    assert(isTerminal(s), 'utility called on non-terminal');
    if (s.p0Folded) {
      // P0 folded — loses their total contribution this hand
      return -(s.p0StreetBet);
    }
    if (s.p1Folded) {
      // P1 folded — P0 takes the whole pot uncontested
      return s.pot - s.p0StreetBet;
    }

    // Showdown: compute P0's equity from the abstraction table and return EV
    final eq = _showdownEquity(s);
    return eq * s.pot - s.p0StreetBet;
  }

  @override
  bool isChance(HuState s) {
    if (!s.isDealt) return true;             // initial deal
    if (s.actorsLeft == 0 && !isTerminal(s)) {
      // Street just closed: need to transition (deal board or next card)
      return true;
    }
    return false;
  }

  @override
  List<ChanceOutcome<HuState>> chanceOutcomes(HuState s) {
    if (!s.isDealt) return _dealPreflop(s);
    return _dealNextStreet(s);
  }

  @override
  int currentPlayer(HuState s) {
    // Preflop: P0 acts first; postflop: P1 (OOP) acts first.
    return s.toAct;
  }

  @override
  int numActions(HuState s) => _actions(s).length;

  @override
  List<String> actionLabels(HuState s) => _actions(s).map((a) => a.label).toList();

  @override
  String infoSetKey(HuState s) {
    final player = s.toAct;
    final handBkt = player == 0 ? s.p0PreflopBucket : s.p1PreflopBucket;
    final postBkt  = player == 0 ? s.p0PostBucket   : s.p1PostBucket;
    final board    = s.boardBucket;
    final st       = s.street.index;
    return '$player:$handBkt:$postBkt:$st:$board:${s.history}';
  }

  @override
  HuState applyAction(HuState s, int action) {
    final acts = _actions(s);
    assert(action < acts.length, 'action $action out of range ${acts.length}');
    return acts[action].apply(s);
  }

  // ─── Chance: deal preflop buckets ─────────────────────────────────────────

  List<ChanceOutcome<HuState>> _dealPreflop(HuState s) {
    final freq = HandAbstraction.preflopBucketFrequencies;
    final n = freq.length;
    final outcomes = <ChanceOutcome<HuState>>[];

    for (int b0 = 0; b0 < n; b0++) {
      for (int b1 = 0; b1 < n; b1++) {
        final prob = freq[b0] * freq[b1];
        if (prob == 0) continue;
        outcomes.add(ChanceOutcome(
          s.copyWith(p0PreflopBucket: b0, p1PreflopBucket: b1),
          prob,
        ));
      }
    }
    return outcomes;
  }

  // ─── Chance: transition to next street ────────────────────────────────────

  List<ChanceOutcome<HuState>> _dealNextStreet(HuState s) {
    final nextStreet = HuStreet.values[s.street.index + 1];
    final boardProbs = HandAbstraction.boardTypeProbabilities;
    final outcomes = <ChanceOutcome<HuState>>[];

    final pot = s.pot;
    final p0Stack = s.p0Stack;
    final p1Stack = s.p1Stack;

    // OOP (P1) acts first postflop
    const firstToActPostflop = 1;

    for (int bt = 0; bt < HandAbstraction.boardBuckets; bt++) {
      final boardProb = boardProbs[bt];

      final p0Trans = HandAbstraction.postflopTransition(s.p0PreflopBucket, bt);
      final p1Trans = HandAbstraction.postflopTransition(s.p1PreflopBucket, bt);

      for (int pb0 = 0; pb0 < HandAbstraction.postflopBuckets; pb0++) {
        for (int pb1 = 0; pb1 < HandAbstraction.postflopBuckets; pb1++) {
          final prob = boardProb * p0Trans[pb0] * p1Trans[pb1];
          if (prob < 1e-8) continue;

          outcomes.add(ChanceOutcome(
            HuState(
              p0PreflopBucket:  s.p0PreflopBucket,
              p1PreflopBucket:  s.p1PreflopBucket,
              p0PostBucket:     pb0,
              p1PostBucket:     pb1,
              boardBucket:      bt,
              street:           nextStreet,
              pot:              pot,
              p0Stack:          p0Stack,
              p1Stack:          p1Stack,
              p0StreetBet:      0,
              p1StreetBet:      0,
              toAct:            firstToActPostflop,
              actorsLeft:       _activePlayers(p0Stack, p1Stack),
              raisesThisStreet: 0,
              p0Folded:         false,
              history:          '',
            ),
            prob,
          ));
        }
      }
    }
    return outcomes;
  }

  // ─── Action list ──────────────────────────────────────────────────────────

  List<_Action> _actions(HuState s) {
    final myStack  = s.myStack;
    final facing   = s.facingBet;
    final pot      = s.pot;
    final isPreflop = s.street == HuStreet.preflop;

    if (myStack <= 0) {
      // All-in already — shouldn't be a decision node, but guard here
      return [_CheckCallAction()];
    }

    final acts = <_Action>[];

    if (facing > 0) {
      // ── Facing a bet ──────────────────────────────────────────────────────
      acts.add(_FoldAction());
      acts.add(_CheckCallAction()); // call

      if (s.raisesThisStreet < cfg.maxRaisesPerStreet) {
        for (int i = 0; i < cfg.raiseSizeMultipliers.length; i++) {
          final mult = cfg.raiseSizeMultipliers[i];
          // Raise to: call + (pot after call × multiplier factor)
          // Simplified: new total = facing × mult (from acting player's side)
          final raiseTo = _snapBB(facing * mult);
          if (raiseTo >= facing * 2 && raiseTo < myStack) {
            acts.add(_RaiseAction(i, raiseTo, 'r$i'));
          }
        }
      }

      if (cfg.includeAllIn && myStack > facing) {
        acts.add(_AllInAction());
      }
    } else {
      // ── No bet facing ─────────────────────────────────────────────────────
      acts.add(_CheckCallAction()); // check

      final sizes = isPreflop ? _preflopOpenSizes(s) : _postflopBetAmounts(pot);
      for (int i = 0; i < sizes.length; i++) {
        final amount = sizes[i];
        if (amount > 0 && amount < myStack) {
          acts.add(_BetAction(i, amount, 'b$i'));
        }
      }

      if (cfg.includeAllIn) {
        acts.add(_AllInAction());
      }
    }

    return acts;
  }

  List<double> _preflopOpenSizes(HuState s) {
    final myStreetBet = s.myStreetBet;
    return cfg.preflopRaiseSizesBB
        .where((sz) => sz > myStreetBet) // only raises bigger than current bet
        .map((sz) => _snapBB(sz))
        .toList();
  }

  List<double> _postflopBetAmounts(double pot) {
    return cfg.postflopBetFractions
        .map((f) => _snapBB(f * pot))
        .where((a) => a > 0)
        .toList();
  }

  // ─── Terminal utility helpers ──────────────────────────────────────────────

  double _showdownEquity(HuState s) {
    if (s.p0PostBucket >= 0 && s.p1PostBucket >= 0) {
      return HandAbstraction.postflopShowdownEquity(s.p0PostBucket, s.p1PostBucket);
    }
    return HandAbstraction.preflopShowdownEquity(s.p0PreflopBucket, s.p1PreflopBucket);
  }

  bool _allInRunout(HuState s) {
    final bothIn = s.p0Stack <= 0 || s.p1Stack <= 0;
    return bothIn && s.street != HuStreet.river;
  }

  int _activePlayers(double s0, double s1) {
    int n = 0;
    if (s0 > 0) n++;
    if (s1 > 0) n++;
    return n;
  }

  static double _snapBB(double x) => (x * 2).roundToDouble() / 2;
}

// ─── Action helpers (internal) ────────────────────────────────────────────────

abstract class _Action {
  String get label;
  HuState apply(HuState s);
}

class _FoldAction implements _Action {
  @override String get label => 'f';

  @override
  HuState apply(HuState s) {
    final p0Folds = s.toAct == 0;
    return s.copyWith(
      p0Folded: p0Folds,
      p1Folded: !p0Folds,
      actorsLeft: 0,
      history: s.history + 'f',
    );
  }
}

class _CheckCallAction implements _Action {
  @override String get label => 'c';

  @override
  HuState apply(HuState s) {
    final facing = s.facingBet;
    final isCheck = facing <= 0;
    final amount = min(facing, s.myStack);

    final newP0StreetBet = s.toAct == 0 ? s.p0StreetBet + amount : s.p0StreetBet;
    final newP1StreetBet = s.toAct == 1 ? s.p1StreetBet + amount : s.p1StreetBet;
    final newP0Stack = s.toAct == 0 ? s.p0Stack - amount : s.p0Stack;
    final newP1Stack = s.toAct == 1 ? s.p1Stack - amount : s.p1Stack;

    final newActorsLeft = isCheck ? max(0, s.actorsLeft - 1) : 0;
    final nextActor = (s.toAct + 1) % 2;
    final tag = isCheck ? 'x' : 'c';

    return s.copyWith(
      pot: s.pot + amount,
      p0StreetBet: newP0StreetBet,
      p1StreetBet: newP1StreetBet,
      p0Stack: newP0Stack,
      p1Stack: newP1Stack,
      toAct: nextActor,
      actorsLeft: newActorsLeft,
      history: s.history + tag,
    );
  }
}

class _BetAction implements _Action {
  final int idx;
  final double amount;
  @override final String label;

  _BetAction(this.idx, this.amount, this.label);

  @override
  HuState apply(HuState s) {
    final extra = amount - s.myStreetBet; // what's added above current street bet
    final newP0StreetBet = s.toAct == 0 ? amount : s.p0StreetBet;
    final newP1StreetBet = s.toAct == 1 ? amount : s.p1StreetBet;
    final newP0Stack = s.toAct == 0 ? s.p0Stack - extra : s.p0Stack;
    final newP1Stack = s.toAct == 1 ? s.p1Stack - extra : s.p1Stack;

    return s.copyWith(
      pot: s.pot + extra,
      p0StreetBet: newP0StreetBet,
      p1StreetBet: newP1StreetBet,
      p0Stack: newP0Stack,
      p1Stack: newP1Stack,
      toAct: (s.toAct + 1) % 2,
      actorsLeft: 1, // opponent must respond
      raisesThisStreet: s.raisesThisStreet + 1,
      history: s.history + label,
    );
  }
}

class _RaiseAction implements _Action {
  final int idx;
  final double raiseTo;
  @override final String label;

  _RaiseAction(this.idx, this.raiseTo, this.label);

  @override
  HuState apply(HuState s) {
    final extra = raiseTo - s.myStreetBet;
    final newP0StreetBet = s.toAct == 0 ? raiseTo : s.p0StreetBet;
    final newP1StreetBet = s.toAct == 1 ? raiseTo : s.p1StreetBet;
    final newP0Stack = s.toAct == 0 ? s.p0Stack - extra : s.p0Stack;
    final newP1Stack = s.toAct == 1 ? s.p1Stack - extra : s.p1Stack;

    return s.copyWith(
      pot: s.pot + extra,
      p0StreetBet: newP0StreetBet,
      p1StreetBet: newP1StreetBet,
      p0Stack: newP0Stack,
      p1Stack: newP1Stack,
      toAct: (s.toAct + 1) % 2,
      actorsLeft: 1,
      raisesThisStreet: s.raisesThisStreet + 1,
      history: s.history + label,
    );
  }
}

class _AllInAction implements _Action {
  @override String get label => 'a';

  @override
  HuState apply(HuState s) {
    final stack = s.myStack;
    final newP0StreetBet = s.toAct == 0 ? s.p0StreetBet + stack : s.p0StreetBet;
    final newP1StreetBet = s.toAct == 1 ? s.p1StreetBet + stack : s.p1StreetBet;
    final newP0Stack = s.toAct == 0 ? 0.0 : s.p0Stack;
    final newP1Stack = s.toAct == 1 ? 0.0 : s.p1Stack;

    // If this all-in is a raise (more than facing), opponent must respond
    final newFacing = max(newP0StreetBet, newP1StreetBet)
        - min(newP0StreetBet, newP1StreetBet);
    final actorsLeft = newFacing > 0 ? 1 : 0;

    return s.copyWith(
      pot: s.pot + stack,
      p0StreetBet: newP0StreetBet,
      p1StreetBet: newP1StreetBet,
      p0Stack: newP0Stack,
      p1Stack: newP1Stack,
      toAct: (s.toAct + 1) % 2,
      actorsLeft: actorsLeft,
      raisesThisStreet: s.raisesThisStreet + 1,
      history: s.history + 'a',
    );
  }
}
