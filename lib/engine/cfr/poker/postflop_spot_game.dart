import 'dart:math';
import '../cfr_game.dart';
import 'bet_sizing_config.dart';
import 'hand_abstraction.dart';
import 'hu_state.dart';

/// Single-street postflop CFR subgame.
///
/// [HuCashGame] (in `hu_cashgame.dart`) models the full 4-street hand, but
/// solving it end-to-end is computationally prohibitive on mobile: vanilla
/// CFR re-enumerates the *entire* chance tree on every iteration, and a full
/// run-out branches combinatorially at each of the three street transitions.
/// That's why [HuCashGame] is only ever run with `fullTree: false`, which
/// truncates at the preflop/flop boundary — postflop nodes are never trained.
///
/// [PostflopSpotGame] solves a single street as an isolated subgame instead —
/// the same "continual re-solving" idea used by modern poker solvers (e.g.
/// DeepStack/Libratus subgame solving): hero's exact postflop bucket is known
/// (their real hand), villain's bucket is hidden and drawn from
/// [HandAbstraction.postflopTransition] (this is what forces a genuine
/// equilibrium MIX instead of a deterministic best-response — hero's strategy
/// must hedge against the whole range, not the one hand), and the street is
/// solved to "showdown" using the abstracted postflop equity table directly —
/// i.e. as if hands compared right when this street's action closes. That's
/// the same simplification [HuCashGame] already relies on, just applied one
/// street later. The resulting tree is tiny (a handful of chance branches × a
/// short betting tree), so it trains in milliseconds, synchronously, with no
/// isolate required.
class PostflopSpotGame extends CfrGame<HuState> {
  final BetSizingConfig cfg;

  /// Hero's real postflop bucket (0=air .. 4=monster) — known exactly, since
  /// it comes from hero's actual hole cards + board.
  final int heroPostBucket;

  /// Assumed villain preflop bucket, used only as the anchor for villain's
  /// postflop bucket distribution (their hand is hidden from hero). Bucket 3
  /// ("playable") mirrors the same neutral assumption [SpotSolver.query]
  /// already makes elsewhere for the unknown opponent.
  final int villainAnchorPreBkt;

  final int boardBucket;
  final HuStreet street;

  final int heroSeat; // 0 = IP/BTN, 1 = OOP/BB
  final double heroStack;
  final double villainStack;
  final double pot;

  /// Amount villain has already put in THIS street (0 = no bet facing yet).
  final double facingBet;

  /// HERO's real equity (with run-out) vs each villain postflop bucket (0..4),
  /// from [HandAbstraction.heroEquityByVillainBucket]. When provided, the
  /// terminal showdown uses this hand-specific equity instead of the coarse
  /// static table, so the solve reflects the actual hand + draws. Entries of
  /// -1 (or a null list) fall back to [HandAbstraction.postflopShowdownEquity].
  final List<double>? heroEqByVillBucket;

  const PostflopSpotGame({
    this.cfg = BetSizingConfig.fast,
    required this.heroPostBucket,
    required this.boardBucket,
    required this.street,
    required this.heroSeat,
    required this.heroStack,
    required this.villainStack,
    required this.pot,
    this.facingBet = 0,
    this.villainAnchorPreBkt = 3,
    this.heroEqByVillBucket,
  });

  /// Hero's equity vs a given villain bucket — real (hand-specific) when
  /// available, else the abstract table.
  double _heroEqVs(int villainBucket) {
    final v = heroEqByVillBucket;
    if (v != null && villainBucket >= 0 && villainBucket < v.length && v[villainBucket] >= 0) {
      return v[villainBucket];
    }
    return HandAbstraction.postflopShowdownEquity(heroPostBucket, villainBucket);
  }

  // ─── CfrGame interface ────────────────────────────────────────────────────

  @override
  HuState root() {
    final villBet = facingBet > 0 ? facingBet : 0.0;
    return HuState(
      boardBucket: boardBucket,
      street: street,
      pot: pot,
      p0Stack: heroSeat == 0 ? heroStack : villainStack,
      p1Stack: heroSeat == 1 ? heroStack : villainStack,
      p0StreetBet: heroSeat == 1 ? villBet : 0,
      p1StreetBet: heroSeat == 0 ? villBet : 0,
      toAct: heroSeat,
      actorsLeft: facingBet > 0 ? 1 : 2,
      raisesThisStreet: facingBet > 0 ? 1 : 0,
      history: facingBet > 0 ? 'b' : '',
    );
  }

  /// [root] with both postflop buckets already assigned, for use with
  /// [CfrSolver.query]. [root] itself is a chance node (buckets unset) since
  /// villain's bucket is hidden until dealt, so it can't be used as a query
  /// key directly. Hero's own infoset key only ever reads *their own* bucket
  /// (see [infoSetKey]), so the villain placeholder value is immaterial.
  HuState dealtRoot() => root().copyWith(
        p0PostBucket: heroSeat == 0 ? heroPostBucket : 0,
        p1PostBucket: heroSeat == 1 ? heroPostBucket : 0,
      );

  bool _dealt(HuState s) => s.p0PostBucket >= 0 && s.p1PostBucket >= 0;

  @override
  bool isChance(HuState s) => !_dealt(s);

  /// Villain bucket distribution for the chance deal. When villain has already
  /// bet into hero (facingBet>0), their range is stronger and more POLARIZED
  /// (value + bluffs, fewer merged middle hands) — and more so for bigger bets —
  /// which is what makes bluff-catching realistic in the solve.
  List<double> _villainDist() {
    final dist = HandAbstraction.postflopTransition(villainAnchorPreBkt, boardBucket);
    if (facingBet <= 0) return dist;
    final frac = (facingBet / max(pot, 1.0)).clamp(0.0, 1.0);
    final pol = 0.10 + 0.25 * frac; // polarization strength grows with bet size
    final out = [
      dist[0] * (1 + pol),       // more pure bluffs
      dist[1] * (1 - pol * 0.5),
      dist[2] * (1 - pol),       // fewer merged medium hands
      dist[3] * (1 + pol * 0.3),
      dist[4] * (1 + pol * 1.2), // more value
    ];
    final sum = out.reduce((a, b) => a + b);
    return sum > 0 ? [for (final v in out) v / sum] : dist;
  }

  @override
  List<ChanceOutcome<HuState>> chanceOutcomes(HuState s) {
    final dist = _villainDist();
    final outcomes = <ChanceOutcome<HuState>>[];
    for (int vb = 0; vb < dist.length; vb++) {
      if (dist[vb] <= 0) continue;
      outcomes.add(ChanceOutcome(
        s.copyWith(
          p0PostBucket: heroSeat == 0 ? heroPostBucket : vb,
          p1PostBucket: heroSeat == 1 ? heroPostBucket : vb,
        ),
        dist[vb],
      ));
    }
    return outcomes;
  }

  @override
  bool isTerminal(HuState s) {
    if (s.p0Folded || s.p1Folded) return true;
    if (!_dealt(s)) return false;
    return s.actorsLeft == 0;
  }

  @override
  double utilityForP0(HuState s) {
    if (s.p0Folded) return -(s.p0StreetBet);
    if (s.p1Folded) return s.pot - s.p0StreetBet;
    // Hero-specific real equity. heroEqByVillBucket is indexed by the VILLAIN's
    // bucket (the player who isn't hero). From p0's perspective: if hero IS p0,
    // p0's equity = hero eq vs p1's bucket; if hero is p1, p0 is the villain so
    // p0's equity = 1 - hero's equity vs p0's bucket.
    final double p0Eq;
    if (heroSeat == 0) {
      p0Eq = _heroEqVs(s.p1PostBucket);
    } else {
      p0Eq = 1.0 - _heroEqVs(s.p0PostBucket);
    }
    return p0Eq * s.pot - s.p0StreetBet;
  }

  @override
  int currentPlayer(HuState s) => s.toAct;

  @override
  int numActions(HuState s) => _actions(s).length;

  @override
  List<String> actionLabels(HuState s) => _actions(s).map((a) => a.label).toList();

  @override
  String infoSetKey(HuState s) {
    final player = s.toAct;
    final myBucket = player == 0 ? s.p0PostBucket : s.p1PostBucket;
    return '$player:$myBucket:${street.index}:$boardBucket:${s.history}';
  }

  @override
  HuState applyAction(HuState s, int action) => _actions(s)[action].apply(s);

  // ─── Action menu: fold/check-call/bet/raise/all-in for ONE street ────────

  List<_Action> _actions(HuState s) {
    final myStack = s.myStack;
    final facing = s.facingBet;
    final pot = s.pot;
    if (myStack <= 0) return [_CheckCall()];

    final acts = <_Action>[];
    if (facing > 0) {
      acts.add(_Fold());
      acts.add(_CheckCall());
      if (s.raisesThisStreet < cfg.maxRaisesPerStreet) {
        for (int i = 0; i < cfg.raiseSizeMultipliers.length; i++) {
          final raiseTo = _snapBB(facing * cfg.raiseSizeMultipliers[i]);
          if (raiseTo >= facing * 2 && raiseTo < myStack) {
            acts.add(_Raise(raiseTo, 'r$i'));
          }
        }
      }
      if (cfg.includeAllIn && myStack > facing) acts.add(_AllIn());
    } else {
      acts.add(_CheckCall());
      for (int i = 0; i < cfg.postflopBetFractions.length; i++) {
        final amount = _snapBB(cfg.postflopBetFractions[i] * pot);
        if (amount > 0 && amount < myStack) acts.add(_Bet(amount, 'b$i'));
      }
      if (cfg.includeAllIn) acts.add(_AllIn());
    }
    return acts;
  }

  static double _snapBB(double x) => (x * 2).roundToDouble() / 2;
}

// ─── Action primitives (file-private; mirror HuCashGame's action semantics
// but kept separate so this isolated subgame never depends on / risks the
// existing full-hand tree). ─────────────────────────────────────────────────

abstract class _Action {
  String get label;
  HuState apply(HuState s);
}

class _Fold implements _Action {
  @override
  String get label => 'f';

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

class _CheckCall implements _Action {
  @override
  String get label => 'c';

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

    return s.copyWith(
      pot: s.pot + amount,
      p0StreetBet: newP0StreetBet,
      p1StreetBet: newP1StreetBet,
      p0Stack: newP0Stack,
      p1Stack: newP1Stack,
      toAct: (s.toAct + 1) % 2,
      actorsLeft: newActorsLeft,
      history: s.history + (isCheck ? 'x' : 'c'),
    );
  }
}

class _Bet implements _Action {
  final double amount;
  @override
  final String label;
  _Bet(this.amount, this.label);

  @override
  HuState apply(HuState s) {
    final extra = amount - s.myStreetBet;
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
      actorsLeft: 1,
      raisesThisStreet: s.raisesThisStreet + 1,
      history: s.history + label,
    );
  }
}

class _Raise implements _Action {
  final double raiseTo;
  @override
  final String label;
  _Raise(this.raiseTo, this.label);

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

class _AllIn implements _Action {
  @override
  String get label => 'a';

  @override
  HuState apply(HuState s) {
    final stack = s.myStack;
    final newP0StreetBet = s.toAct == 0 ? s.p0StreetBet + stack : s.p0StreetBet;
    final newP1StreetBet = s.toAct == 1 ? s.p1StreetBet + stack : s.p1StreetBet;
    final newP0Stack = s.toAct == 0 ? 0.0 : s.p0Stack;
    final newP1Stack = s.toAct == 1 ? 0.0 : s.p1Stack;

    final newFacing = max(newP0StreetBet, newP1StreetBet) - min(newP0StreetBet, newP1StreetBet);
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
