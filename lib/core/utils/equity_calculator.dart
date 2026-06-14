import 'dart:math';
import '../../data/models/card_model.dart';
import '../../data/models/player_model.dart';
import 'hand_evaluator.dart';
import 'poker_concepts.dart';
import 'postflop_context.dart';

class GTORecommendation {
  final String action;
  final double amount;
  final double equity;
  final double potOdds;
  final String reasoning;
  final double ev;

  const GTORecommendation({
    required this.action,
    required this.amount,
    required this.equity,
    required this.potOdds,
    required this.reasoning,
    required this.ev,
  });
}

class EquityCalculator {
  static final Random _rng = Random();

  static double calculate({
    required List<CardModel> heroCards,
    required List<CardModel> communityCards,
    required int numOpponents,
    int simulations = 400,
    bool deterministic = false,
    // Fraction of hands to include for opponents (1.0 = all random,
    // 0.40 = realistic calling range, excludes garbage like 72o, 83o).
    // Lower = tighter range = more accurate equity vs real players postflop.
    double rangeWidth = 1.0,
  }) {
    if (heroCards.length != 2 || numOpponents <= 0) return 0.5;

    final known = <CardModel>{...heroCards, ...communityCards};
    final deck = CardModel.freshDeck().where((c) => !_has(known, c)).toList();

    // Deterministic mode (used by the GTO advisor and the hand analyst):
    // an identical situation must always yield the EXACT same equity/EV.
    // We seed the RNG from a hash of the situation so the Monte Carlo is
    // reproducible. Bots' live decisions pass deterministic:false.
    final rng = deterministic
        ? Random(_situationSeed(heroCards, communityCards, numOpponents))
        : _rng;

    int wins = 0;
    int ties = 0;
    final boardNeeded = 5 - communityCards.length;

    // Range-filtered hand pool: pre-generate all valid 2-card combos from the
    // remaining deck that clear the strength threshold. Rejection-sampled per
    // simulation to avoid dealing board-conflicting cards to opponents.
    // cut = 0 for rangeWidth≥1.0 (pure random / backward-compatible).
    final useRange = rangeWidth < 0.99;
    final strengthCut = useRange ? max(0.0, 0.75 - rangeWidth) : 0.0;
    // rangeWidth=0.40 → cut=0.35 (top ~40%: all pairs, AXo, broadway, suited connectors 65s+)
    // rangeWidth=0.60 → cut=0.15 (top ~60%: wide LAG range)

    List<List<CardModel>>? handPool;
    if (useRange) {
      handPool = [];
      for (int i = 0; i < deck.length - 1; i++) {
        for (int j = i + 1; j < deck.length; j++) {
          final h = [deck[i], deck[j]];
          if (CardModel.preflopStrength(h) >= strengthCut) handPool!.add(h);
        }
      }
      if (handPool!.isEmpty) handPool = null; // fallback to random
    }

    // ── EXACT RIVER EQUITY (board complete) vs a single opponent ──────────────
    // With no cards to come, equity is not a simulation — it is the exact
    // fraction of the villain's remaining combos that hero beats. Enumerate
    // every combo (within range) the way real solvers (GTO Wizard) do, so the
    // river number is precise and noise-free instead of Monte-Carlo jittered.
    if (boardNeeded == 0 && numOpponents == 1) {
      final heroScore =
          HandEvaluator.evaluateBest([...heroCards, ...communityCards]);
      int w = 0, t = 0, n = 0;
      void tally(CardModel a, CardModel b) {
        final opScore = HandEvaluator.evaluateBest([a, b, ...communityCards]);
        final cmp = heroScore.compareTo(opScore);
        if (cmp > 0) {
          w++;
        } else if (cmp == 0) {
          t++;
        }
        n++;
      }

      if (handPool != null) {
        for (final h in handPool) {
          tally(h[0], h[1]);
        }
      } else {
        for (int i = 0; i < deck.length - 1; i++) {
          for (int j = i + 1; j < deck.length; j++) {
            tally(deck[i], deck[j]);
          }
        }
      }
      if (n == 0) return 0.5;
      return (w + t * 0.5) / n;
    }

    for (int sim = 0; sim < simulations; sim++) {
      deck.shuffle(rng);
      int idx = 0;

      final board = List<CardModel>.from(communityCards);
      for (int i = 0; i < boardNeeded; i++) {
        board.add(deck[idx++]);
      }

      final heroScore = HandEvaluator.evaluateBest([...heroCards, ...board]);

      bool heroWins = true;
      bool isTie = false;
      final usedThisSim = <CardModel>{...heroCards, ...board};

      for (int op = 0; op < numOpponents; op++) {
        List<CardModel> opHole;

        if (handPool != null) {
          // Rejection sampling: pick a pool hand whose cards aren't already used.
          // Acceptance rate is typically >80% so 30 attempts is always enough.
          List<CardModel>? found;
          for (int attempt = 0; attempt < 30; attempt++) {
            final candidate = handPool![rng.nextInt(handPool!.length)];
            if (!_has(usedThisSim, candidate[0]) &&
                !_has(usedThisSim, candidate[1])) {
              found = candidate;
              break;
            }
          }
          if (found != null) {
            opHole = found;
            usedThisSim.add(opHole[0]);
            usedThisSim.add(opHole[1]);
          } else {
            // Rare fallback: no valid range hand — use next deck cards
            if (idx + 1 < deck.length) {
              opHole = [deck[idx++], deck[idx++]];
            } else {
              heroWins = false;
              break;
            }
          }
        } else {
          opHole = [deck[idx++], deck[idx++]];
        }

        final opScore = HandEvaluator.evaluateBest([...opHole, ...board]);
        final cmp = heroScore.compareTo(opScore);
        if (cmp < 0) {
          heroWins = false;
          isTie = false;
          break;
        } else if (cmp == 0) {
          isTie = true;
        }
      }

      if (heroWins && !isTie) wins++;
      else if (isTie) ties++;
    }

    return (wins + ties * 0.5) / simulations;
  }

  /// Exact equity vs a known villain hand (runs out remaining board cards).
  static double calculateVsVillain({
    required List<CardModel> heroCards,
    required List<CardModel> villainCards,
    required List<CardModel> communityCards,
    int simulations = 800,
  }) {
    if (heroCards.length != 2 || villainCards.length != 2) return 0.5;
    final known = <CardModel>{...heroCards, ...villainCards, ...communityCards};
    final deck = CardModel.freshDeck().where((c) => !_has(known, c)).toList();
    final boardNeeded = 5 - communityCards.length;
    int wins = 0, ties = 0;
    for (int sim = 0; sim < simulations; sim++) {
      deck.shuffle(_rng);
      final board = [...communityCards, ...deck.take(boardNeeded)];
      final heroScore = HandEvaluator.evaluateBest([...heroCards, ...board]);
      final villScore = HandEvaluator.evaluateBest([...villainCards, ...board]);
      final cmp = heroScore.compareTo(villScore);
      if (cmp > 0) wins++;
      else if (cmp == 0) ties++;
    }
    return (wins + ties * 0.5) / simulations;
  }

  /// Multiway equity for several KNOWN hands at showdown over [communityCards].
  /// Index 0 is the hero; the rest are villains. Split pots are shared, so the
  /// returned equities sum to 1.0. Exact enumeration of the remaining board when
  /// ≤2 cards are to come (river/turn/flop); Monte Carlo for preflop multiway.
  static List<double> equityMultiway({
    required List<List<CardModel>> hands,
    required List<CardModel> communityCards,
    int simulations = 3000,
  }) {
    final n = hands.length;
    if (n == 0) return const [];
    if (n == 1) return const [1.0];

    final wins = List<double>.filled(n, 0.0);
    final known = <CardModel>{
      for (final h in hands) ...h,
      ...communityCards,
    };
    final deck = CardModel.freshDeck().where((c) => !_has(known, c)).toList();
    final need = 5 - communityCards.length;

    void settle(List<CardModel> board) {
      var bestScore = HandEvaluator.evaluateBest([...hands[0], ...board]);
      var winners = <int>[0];
      for (int i = 1; i < n; i++) {
        final s = HandEvaluator.evaluateBest([...hands[i], ...board]);
        final cmp = s.compareTo(bestScore);
        if (cmp > 0) {
          bestScore = s;
          winners = [i];
        } else if (cmp == 0) {
          winners.add(i);
        }
      }
      final share = 1.0 / winners.length;
      for (final i in winners) {
        wins[i] += share;
      }
    }

    int total = 0;
    if (need <= 0) {
      settle(communityCards);
      total = 1;
    } else if (need == 1) {
      for (final c in deck) {
        settle([...communityCards, c]);
        total++;
      }
    } else if (need == 2) {
      for (int i = 0; i < deck.length - 1; i++) {
        for (int j = i + 1; j < deck.length; j++) {
          settle([...communityCards, deck[i], deck[j]]);
          total++;
        }
      }
    } else {
      // Preflop (5 cards to come): exact enumeration is too large — Monte Carlo.
      for (int s = 0; s < simulations; s++) {
        deck.shuffle(_rng);
        settle([...communityCards, ...deck.take(need)]);
        total++;
      }
    }

    if (total == 0) return List<double>.filled(n, 1.0 / n);
    return [for (final w in wins) w / total];
  }

  static bool _has(Set<CardModel> set, CardModel c) =>
      set.any((x) => x.rank == c.rank && x.suit == c.suit);

  /// Stable seed derived purely from the situation (hero + board + #opps),
  /// order-independent for hole/board cards. Identical spots → identical seed.
  static int _situationSeed(
      List<CardModel> hero, List<CardModel> board, int opps) {
    int code(CardModel c) => c.rank * 4 + c.suit.index; // 0..55
    final h = (hero.map(code).toList()..sort());
    final b = (board.map(code).toList()..sort());
    int seed = 1469598103 ^ opps;
    for (final v in [...h, -1, ...b]) {
      seed = (seed * 31 + v + 7) & 0x7FFFFFFF;
    }
    return seed;
  }

  static double potOddsRequired(double callAmount, double potSize) {
    if (callAmount <= 0) return 0.0;
    return callAmount / (callAmount + potSize);
  }

  static GTORecommendation recommend({
    required List<CardModel> heroCards,
    required List<CardModel> communityCards,
    required double callAmount,
    required double potSize,
    required int numOpponents,
    double heroStack = 100.0,
    // ── Extra postflop factors (optional; default to a neutral HU SRP spot so
    //    existing callers keep working). They shift BOTH the decision and the
    //    explanation, mirroring how the legend bots read the spot. ──
    TablePosition? position,
    bool inPosition = false,
    bool hasInitiative = false,
    int numActive = 0,
    int preflopRaises = 1,
    VillainRead villainRead = VillainRead.neutral,
  }) {
    final isPostflop = communityCards.length >= 3;
    final isRiver = communityCards.length == 5;
    final equity = calculate(
      heroCards: heroCards,
      communityCards: communityCards,
      numOpponents: max(1, numOpponents),
      simulations: 500,
      deterministic: true,
      rangeWidth: isPostflop ? 0.40 : 1.0,
    );

    final odds = potOddsRequired(callAmount, potSize);
    final ev = equity - odds;

    final analysis = isPostflop ? HandStrengthAnalysis.analyze(heroCards, communityCards) : null;
    final blockers = isPostflop ? Blockers.analyze(heroCards, communityCards) : null;
    final texture = isPostflop ? BoardTexture.analyze(communityCards) : null;
    final spr = GtoMath.spr(heroStack, max(potSize, 1.0));
    final mdf = callAmount > 0 ? GtoMath.mdf(potSize - callAmount, callAmount) : 0.0;
    final alpha = callAmount > 0 ? GtoMath.alpha(potSize - callAmount, callAmount) : 0.0;

    // ── Postflop context: position, multiway, initiative, pot type, read ────
    final nActive = numActive > 0 ? numActive : max(2, numOpponents + 1);
    final ctx = PostflopContext(
      position: position,
      inPosition: inPosition,
      hasInitiative: hasInitiative,
      numActive: nActive,
      potType: PostflopContext.potTypeFromRaiseCount(preflopRaises),
      villainBet: callAmount,
      potSize: potSize,
      read: villainRead,
    );
    final realization = PostflopContext.equityRealization(
      inPosition: inPosition,
      hasInitiative: hasInitiative,
      numActive: nActive,
    );
    final realizedEq = (equity * realization).clamp(0.0, 1.0).toDouble();
    final vShift = PostflopContext.multiwayValueShift(nActive);
    final canBluff = ctx.canPureBluff;
    final callPenalty = ctx.callEvPenalty;
    final isMultiway = ctx.isMultiway;

    // ── Determine primary action (now factor-aware) ─────────────────────────
    String action;
    double amount;
    double evFinal;

    if (callAmount <= 0) {
      if (equity > 0.64 + vShift ||
          analysis?.bucket == HandBucket.nuts ||
          analysis?.bucket == HandBucket.strongValue) {
        // Multiway → bet bigger (more protection, fewer bluffs to balance).
        final wet = texture != null && texture.wetness > 0.5;
        final frac = isMultiway ? (wet ? 0.85 : 0.72) : (wet ? 0.75 : 0.66);
        final bet = _snapToBetSize(potSize * frac);
        action = 'Bet'; amount = bet; evFinal = equity - 0.5;
      } else if ((analysis?.bucket == HandBucket.comboDraw ||
              analysis?.bucket == HandBucket.strongDraw) &&
          !isRiver &&
          (canBluff || realizedEq > 0.45)) {
        final bet = _snapToBetSize(potSize * 0.66);
        action = 'Bet'; amount = bet; evFinal = equity - 0.35;
      } else if (realizedEq > 0.52 + vShift) {
        final bet = _snapToBetSize(potSize * 0.40);
        action = 'Bet'; amount = bet; evFinal = equity - 0.45;
      } else if (equity > 0.28 &&
          potSize > 15 &&
          (blockers?.goodBluffBlockers ?? false) &&
          !isRiver &&
          canBluff &&
          hasInitiative) {
        final bet = _snapToBetSize(potSize * 0.50);
        action = 'Bet'; amount = bet; evFinal = 0.08;
      } else {
        action = 'Check'; amount = 0; evFinal = 0;
      }
    } else {
      if (equity > 0.62 + vShift && ev > 0.12 + callPenalty) {
        final raise = _snapToBetSize(callAmount * 2.8);
        action = 'Raise'; amount = raise; evFinal = ev;
      } else if (analysis != null &&
          (analysis.bucket == HandBucket.comboDraw || analysis.bucket == HandBucket.strongDraw) &&
          !isRiver &&
          canBluff) {
        final raise = _snapToBetSize(callAmount * 2.8);
        action = 'Raise'; amount = raise; evFinal = ev + 0.10;
      } else if (analysis != null && blockers != null && texture != null &&
          !isRiver && ev < -0.03 &&
          (analysis.bucket == HandBucket.air || analysis.bucket == HandBucket.weakShowdown) &&
          blockers.goodBluffBlockers && texture.wetness < 0.45 &&
          canBluff && !isMultiway) {
        final raise = _snapToBetSize(callAmount * 2.8);
        action = 'Raise'; amount = raise; evFinal = 0.05;
      } else if (ev >= -0.03 + callPenalty) {
        action = 'Call'; amount = callAmount; evFinal = ev;
      } else {
        action = 'Fold'; amount = 0; evFinal = ev;
      }
    }

    final reasoning = _buildReasoning(
      heroCards: heroCards,
      communityCards: communityCards,
      equity: equity,
      realizedEq: realizedEq,
      callAmount: callAmount,
      potSize: potSize,
      heroStack: heroStack,
      spr: spr,
      mdf: mdf,
      alpha: alpha,
      analysis: analysis,
      blockers: blockers,
      texture: texture,
      ctx: ctx,
      primaryAction: action,
      primaryAmount: amount,
      isRiver: isRiver,
    );

    return GTORecommendation(
      action: action,
      amount: amount,
      equity: equity,
      potOdds: odds,
      ev: evFinal,
      reasoning: reasoning,
    );
  }

  static String _buildReasoning({
    required List<CardModel> heroCards,
    required List<CardModel> communityCards,
    required double equity,
    required double realizedEq,
    required double callAmount,
    required double potSize,
    required double heroStack,
    required double spr,
    required double mdf,
    required double alpha,
    HandStrengthAnalysis? analysis,
    Blockers? blockers,
    BoardTexture? texture,
    required PostflopContext ctx,
    required String primaryAction,
    required double primaryAmount,
    required bool isRiver,
  }) {
    final b = StringBuffer();
    final eqPct = (equity * 100).toStringAsFixed(1);
    final isPostflop = communityCards.length >= 3;
    final outs = analysis?.outs ?? 0;
    final drawPct = outs > 0 ? (analysis!.drawEquity * 100).toStringAsFixed(0) : '';
    final bucket = analysis?.bucket;

    // Preflop fallback (the engine normally routes preflop through the chart
    // database; this only fires if recommend() is called with no board).
    if (!isPostflop || texture == null || analysis == null) {
      b.writeln('Equity: $eqPct%');
      if (callAmount > 0) {
        final odds = potOddsRequired(callAmount, potSize);
        b.writeln('Pot odds ${(odds * 100).toStringAsFixed(1)}% · EV ${(equity - odds) >= 0 ? "+" : ""}${((equity - odds) * 100).toStringAsFixed(1)}%');
      }
      final amt = primaryAmount > 0 ? ' \$${primaryAmount.toStringAsFixed(0)}' : '';
      b.writeln('${primaryAction.toUpperCase()}$amt.');
      return b.toString().trim();
    }

    // ── 1. LECTURA DE LA CALLE — board real + qué cambió en ESTA carta ──────
    final streetName = communityCards.length == 3
        ? 'FLOP'
        : (communityCards.length == 4 ? 'TURN' : 'RIVER');
    final boardStr = communityCards.map((c) => c.toString()).join(' ');
    b.writeln('🎴 $streetName  $boardStr  ·  ${_wetBand(texture.wetness)}');

    if (communityCards.length == 3) {
      b.writeln(_flopRead(texture));
    } else {
      final prevBoard = communityCards.sublist(0, communityCards.length - 1);
      final newCard = communityCards.last;
      b.writeln('➕ $newCard — ${_newCardImpact(prevBoard, newCard)}');
    }
    b.writeln();

    // ── 2. TU MANO en este board ────────────────────────────────────────────
    b.writeln('✋ Tu mano: ${_handLine(analysis, outs, drawPct)}');
    b.writeln();

    // ── 3. MATEMÁTICAS — una sola línea ─────────────────────────────────────
    if (callAmount > 0) {
      final odds = potOddsRequired(callAmount, potSize);
      final evVal = equity - odds;
      b.writeln('📐 Equity $eqPct% · Pot odds ${(odds * 100).toStringAsFixed(1)}% · EV ${evVal >= 0 ? "+" : ""}${(evVal * 100).toStringAsFixed(1)}% · MDF ${(mdf * 100).toStringAsFixed(0)}%');
    } else {
      b.writeln('📐 Equity $eqPct% · SPR ${spr.toStringAsFixed(1)} (${_sprLabel(spr)})');
    }
    b.writeln(_factorLine(ctx, equity, realizedEq));
    b.writeln();

    // ── 4. RECOMENDACIÓN ────────────────────────────────────────────────────
    b.writeln('✅ ${_recoLine(
      action: primaryAction,
      amount: primaryAmount,
      potSize: potSize,
      eqPct: eqPct,
      bucket: bucket,
      texture: texture,
      spr: spr,
      alpha: alpha,
      outs: outs,
      drawPct: drawPct,
      callAmount: callAmount,
      isRiver: isRiver,
    )}');

    // ── 5. UNA NOTA ADAPTADA — solo la más relevante a este spot ────────────
    final tip = _adaptiveTip(
      action: primaryAction,
      bucket: bucket,
      blockers: blockers,
      texture: texture,
      alpha: alpha,
      mdf: mdf,
      equity: equity,
      callAmount: callAmount,
      potSize: potSize,
      isRiver: isRiver,
    );
    if (tip.isNotEmpty) {
      b.writeln();
      b.writeln('💡 $tip');
    }

    return b.toString().trim();
  }

  /// Three-band wetness label used in the street header.
  static String _wetBand(double wetness) {
    if (wetness > 0.55) return 'HÚMEDO';
    if (wetness < 0.35) return 'SECO';
    return 'TEXTURA MEDIA';
  }

  /// One-line summary of the postflop factors that shaped the recommendation.
  static String _factorLine(
      PostflopContext ctx, double equity, double realizedEq) {
    final parts = <String>[
      ctx.inPosition ? 'IP (en posición)' : 'OOP (fuera de posición)',
      ctx.isMultiway ? 'MULTIWAY ${ctx.numActive} jug. (farol↓, valor↑)' : 'heads-up',
      ctx.hasInitiative ? 'con iniciativa' : 'sin iniciativa',
      PostflopContext.potTypeLabel(ctx.potType),
      if (!ctx.read.isNeutral) 'rival ${ctx.read.label}',
    ];
    final realDelta = (realizedEq - equity) * 100;
    final realNote = realDelta.abs() >= 3
        ? ' · equity realizada ≈${(realizedEq * 100).toStringAsFixed(0)}% '
            '(${realDelta >= 0 ? '+' : ''}${realDelta.toStringAsFixed(0)} pts por posición/multiway)'
        : '';
    return '🎯 ${parts.join(' · ')}$realNote';
  }

  /// Flop read: names the defining features from the actual cards and who the
  /// texture favours.
  static String _flopRead(BoardTexture t) {
    final feats = <String>[];
    if (t.monotone) {
      feats.add('monótono (color ya posible)');
    } else if (t.twoTone) {
      feats.add('two-tone (proyecto de color vivo)');
    }
    if (t.paired) feats.add('emparejado');
    if (t.connected) {
      feats.add('conectado (muchas escaleras)');
    } else if (t.wetness >= 0.35 && t.wetness <= 0.55) {
      feats.add('semi-conectado');
    }
    if (t.aceHigh) {
      feats.add('A-alto');
    } else if (t.broadwayHeavy) {
      feats.add('broadway');
    } else if (t.low) {
      feats.add('bajo');
    }
    final featStr = feats.isEmpty ? 'seco y disperso' : feats.join(', ');

    final ra = RangeModel.aggressorRangeAdvantage(t);
    final adv = ra > 0.10
        ? 'favorece al AGRESOR preflop → c-bet a buena frecuencia'
        : (ra < -0.10
            ? 'favorece al DEFENSOR/BB → modera tus c-bets, polariza'
            : 'rangos parejos → juega con cabeza, sin auto-pilot');
    return '   $featStr → $adv.';
  }

  /// Describes what the just-dealt turn/river card changed versus the prior
  /// board — the core "una lectura distinta por calle" behaviour.
  static String _newCardImpact(List<CardModel> prevBoard, CardModel newCard) {
    final prevRanks = prevBoard.map((c) => c.rank).toList();
    final maxPrev = prevRanks.isEmpty ? 0 : prevRanks.reduce(max);
    final suitOnBoard = prevBoard.where((c) => c.suit == newCard.suit).length;
    final pairsBoard = prevRanks.contains(newCard.rank);
    final flushNow = suitOnBoard >= 2; // third+ of its suit hits the board
    final straightNow =
        !flushNow && BoardTexture.drawCompletedOn(prevBoard, newCard);
    final overcard = newCard.rank > maxPrev;

    if (pairsBoard) {
      return 'empareja el board (${newCard.rankSymbol}${newCard.rankSymbol}) → posibles trips/full; el rango se polariza, ojo con barrels.';
    }
    if (flushNow) {
      return 'tercer ${newCard.suitSymbol} → COLOR posible. Frena los faroles puros: alguien pudo completar.';
    }
    if (straightNow) {
      return 'completa posibles ESCALERAS. Reevalúa: tu valor medio baja, el rival pudo ligar.';
    }
    if (overcard) {
      return 'sobrecarta (${newCard.rankSymbol}). Conecta con el rango del rival, pero también es buena carta para representar fuerza tú.';
    }
    return 'ladrillo — no cambia nada del board; tu historia de fuerza sigue intacta, puedes seguir presionando.';
  }

  /// Concrete description of the hero hand on this board: tier + made hand +
  /// named draws + outs.
  static String _handLine(HandStrengthAnalysis a, int outs, String drawPct) {
    final extras = <String>[];
    if (a.madeCategory != HandCategory.highCard) {
      extras.add(_madeLabel(a.madeCategory));
    }
    if (a.flushDraw) {
      extras.add(a.nutFlushDraw ? 'proyecto color de nueces' : 'proyecto de color');
    }
    if (a.openEnded) {
      extras.add('escalera abierta');
    } else if (a.gutshot) {
      extras.add('gutshot');
    }
    if (a.twoOvercards) extras.add('dos sobrecartas');

    final extraStr = extras.isEmpty ? '' : ' — ${extras.join(' + ')}';
    final outStr = outs > 0 ? ' · $outs outs (~$drawPct%)' : '';
    return '${_bucketLabel(a.bucket)}$extraStr$outStr';
  }

  static String _recoLine({
    required String action,
    required double amount,
    required double potSize,
    required String eqPct,
    required HandBucket? bucket,
    required BoardTexture texture,
    required double spr,
    required double alpha,
    required int outs,
    required String drawPct,
    required double callAmount,
    required bool isRiver,
  }) {
    final sizing = amount > 0
        ? '\$${amount.toStringAsFixed(0)} (${(amount / max(potSize, 1) * 100).toStringAsFixed(0)}% bote)'
        : '';
    final wet = texture.wetness >= 0.50;

    if (action == 'Bet' || action == 'Raise') {
      if (bucket == HandBucket.nuts || bucket == HandBucket.strongValue) {
        final size = wet ? '66-75% en board húmedo, protege + extrae' : '50-66% en board seco';
        return 'BET VALOR $sizing — vas adelante, construye el bote ($size).';
      }
      if (bucket == HandBucket.comboDraw || bucket == HandBucket.strongDraw) {
        final reraise = spr < 4
            ? 'si te suben, all-in: tienes la equity'
            : 'si te suben, puedes pagar y realizar equity';
        return 'SEMI-BLUFF $sizing — $outs outs (~$drawPct%) + fold equity, dos formas de ganar; $reraise.';
      }
      if (action == 'Raise') {
        return 'RAISE-FAROL $sizing — bloqueadores + textura te dejan representar; el rival necesita ${(alpha * 100).toStringAsFixed(0)}% de folds.';
      }
      return 'BET fina/protección $sizing — no des cartas gratis a los draws de este board.';
    }
    if (action == 'Call') {
      final alt = (!isRiver && (bucket == HandBucket.strongDraw || bucket == HandBucket.comboDraw))
          ? ' Alternativa superior: semi-bluff raise (sumas fold equity a tus $outs outs).'
          : '';
      return 'CALL — equity $eqPct% cubre las pot odds.$alt';
    }
    if (action == 'Fold') {
      return 'FOLD — equity $eqPct% insuficiente; continuar es -EV en este board.';
    }
    final trap = (bucket == HandBucket.nuts || bucket == HandBucket.strongValue)
        ? ' Si apuestan, check-raise para construir el bote de golpe.'
        : '';
    return 'CHECK — controla el bote y reevalúa según la próxima carta.$trap';
  }

  /// Picks the single most relevant coaching note for this spot instead of
  /// dumping every generic section.
  static String _adaptiveTip({
    required String action,
    required HandBucket? bucket,
    required Blockers? blockers,
    required BoardTexture texture,
    required double alpha,
    required double mdf,
    required double equity,
    required double callAmount,
    required double potSize,
    required bool isRiver,
  }) {
    final isAggro = action == 'Bet' || action == 'Raise';

    if (isAggro && (blockers?.goodBluffBlockers ?? false)) {
      final parts = <String>[];
      if (blockers!.nutFlushBlocker) parts.add('bloqueas el color de nueces');
      if (blockers.straightBlocker) parts.add('bloqueas la escalera');
      if (blockers.hasAce) parts.add('tienes un As (bloqueas AX)');
      if (parts.isNotEmpty) {
        return 'Bloqueadores: ${parts.join(', ')} → tu apuesta/farol gana valor extra aquí.';
      }
    }

    if (callAmount > 0 &&
        (bucket == HandBucket.mediumValue || bucket == HandBucket.weakShowdown)) {
      final odds = potOddsRequired(callAmount, potSize);
      if (equity >= odds - 0.05) {
        return 'Eres bluff-catcher: MDF pide defender ${(mdf * 100).toStringAsFixed(0)}% del rango — pagar cumple y desincentiva sus faroles.';
      }
      return 'Por debajo del umbral MDF; foldea salvo que tengas bloqueadores claros de farol.';
    }

    if (!isRiver &&
        (bucket == HandBucket.comboDraw ||
            bucket == HandBucket.strongDraw ||
            bucket == HandBucket.weakDraw)) {
      final scare = <String>[];
      if (texture.twoTone) scare.add('el 3.º del palo');
      if (texture.connected) scare.add('cartas conectoras');
      final s = scare.isEmpty ? 'una sobrecarta' : scare.join(' o ');
      return 'Plan: si ligas, apuesta fuerte por valor; vigila $s en la próxima calle y replanifica.';
    }

    if (action == 'Fold' &&
        (blockers?.goodBluffBlockers ?? false) &&
        texture.wetness < 0.35 &&
        !isRiver) {
      return 'Alternativa: RAISE-FAROL — board seco + tus bloqueadores hacen el farol +EV (alpha ${(alpha * 100).toStringAsFixed(0)}%).';
    }

    return '';
  }

  static String _madeLabel(HandCategory cat) {
    switch (cat) {
      case HandCategory.highCard: return 'carta alta';
      case HandCategory.onePair: return 'pareja';
      case HandCategory.twoPair: return 'doble pareja';
      case HandCategory.threeOfAKind: return 'trío/set';
      case HandCategory.straight: return 'escalera';
      case HandCategory.flush: return 'color';
      case HandCategory.fullHouse: return 'full';
      case HandCategory.fourOfAKind: return 'póker';
      case HandCategory.straightFlush: return 'escalera de color';
    }
  }

  static String _bucketLabel(HandBucket? bucket) {
    switch (bucket) {
      case HandBucket.nuts: return 'NUECES 🏆';
      case HandBucket.strongValue: return 'VALOR FUERTE 💪';
      case HandBucket.mediumValue: return 'VALOR MEDIO';
      case HandBucket.weakShowdown: return 'SHOWDOWN DÉBIL';
      case HandBucket.comboDraw: return 'COMBO DRAW 🔥';
      case HandBucket.strongDraw: return 'DRAW FUERTE';
      case HandBucket.weakDraw: return 'DRAW DÉBIL';
      case HandBucket.air: return 'AIRE (sin equity)';
      case null: return 'Sin board';
    }
  }

  static String _sprLabel(double spr) {
    if (spr <= 2.5) return 'stack corto: commítete';
    if (spr <= 5.0) return '2 calles de apuesta';
    if (spr <= 10.0) return 'profundo: 3 calles';
    return 'muy profundo: pot control';
  }

  static double _snapToBetSize(double amount) {
    if (amount < 2) return 2;
    return (amount / 2).round() * 2.0;
  }
}
