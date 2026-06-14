import 'dart:math';
import '../../data/models/card_model.dart';
import 'hand_evaluator.dart';
import 'poker_concepts.dart';

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
    final eqPct = (equity * 100).toStringAsFixed(1);
    final oddsPct = (odds * 100).toStringAsFixed(1);

    final analysis = isPostflop ? HandStrengthAnalysis.analyze(heroCards, communityCards) : null;
    final blockers = isPostflop ? Blockers.analyze(heroCards, communityCards) : null;
    final texture = isPostflop ? BoardTexture.analyze(communityCards) : null;
    final spr = GtoMath.spr(heroStack, max(potSize, 1.0));
    final mdf = callAmount > 0 ? GtoMath.mdf(potSize - callAmount, callAmount) : 0.0;
    final alpha = callAmount > 0 ? GtoMath.alpha(potSize - callAmount, callAmount) : 0.0;

    // ── Determine primary action ─────────────────────────────────────────────
    String action;
    double amount;
    double evFinal;

    if (callAmount <= 0) {
      if (equity > 0.64 || analysis?.bucket == HandBucket.nuts || analysis?.bucket == HandBucket.strongValue) {
        final bet = _snapToBetSize(potSize * (texture != null && texture.wetness > 0.5 ? 0.75 : 0.66));
        action = 'Bet'; amount = bet; evFinal = equity - 0.5;
      } else if ((analysis?.bucket == HandBucket.comboDraw || analysis?.bucket == HandBucket.strongDraw) && !isRiver) {
        final bet = _snapToBetSize(potSize * 0.66);
        action = 'Bet'; amount = bet; evFinal = equity - 0.35;
      } else if (equity > 0.52) {
        final bet = _snapToBetSize(potSize * 0.40);
        action = 'Bet'; amount = bet; evFinal = equity - 0.45;
      } else if (equity > 0.28 && potSize > 15 && (blockers?.goodBluffBlockers ?? false) && !isRiver) {
        final bet = _snapToBetSize(potSize * 0.50);
        action = 'Bet'; amount = bet; evFinal = 0.08;
      } else {
        action = 'Check'; amount = 0; evFinal = 0;
      }
    } else {
      if (equity > 0.62 && ev > 0.12) {
        final raise = _snapToBetSize(callAmount * 2.8);
        action = 'Raise'; amount = raise; evFinal = ev;
      } else if (analysis != null &&
          (analysis.bucket == HandBucket.comboDraw || analysis.bucket == HandBucket.strongDraw) &&
          !isRiver) {
        final raise = _snapToBetSize(callAmount * 2.8);
        action = 'Raise'; amount = raise; evFinal = ev + 0.10;
      } else if (analysis != null && blockers != null && texture != null &&
          !isRiver && ev < -0.03 &&
          (analysis.bucket == HandBucket.air || analysis.bucket == HandBucket.weakShowdown) &&
          blockers.goodBluffBlockers && texture.wetness < 0.45) {
        final raise = _snapToBetSize(callAmount * 2.8);
        action = 'Raise'; amount = raise; evFinal = 0.05;
      } else if (ev >= -0.03) {
        action = 'Call'; amount = callAmount; evFinal = ev;
      } else {
        action = 'Fold'; amount = 0; evFinal = ev;
      }
    }

    final reasoning = _buildReasoning(
      heroCards: heroCards,
      communityCards: communityCards,
      equity: equity,
      callAmount: callAmount,
      potSize: potSize,
      heroStack: heroStack,
      spr: spr,
      mdf: mdf,
      alpha: alpha,
      analysis: analysis,
      blockers: blockers,
      texture: texture,
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
    required double callAmount,
    required double potSize,
    required double heroStack,
    required double spr,
    required double mdf,
    required double alpha,
    HandStrengthAnalysis? analysis,
    Blockers? blockers,
    BoardTexture? texture,
    required String primaryAction,
    required double primaryAmount,
    required bool isRiver,
  }) {
    final b = StringBuffer();
    final eqPct = (equity * 100).toStringAsFixed(1);
    final isPostflop = communityCards.isNotEmpty;
    final outs = analysis?.outs ?? 0;
    final drawPct = outs > 0 ? (analysis!.drawEquity * 100).toStringAsFixed(0) : '';
    final bucket = analysis?.bucket;

    // ── 1. MANO + TEXTURA ───────────────────────────────────────────────────
    if (isPostflop) {
      final handLabel = _bucketLabel(bucket);
      b.write('📊 Fuerza: $handLabel');
      if (outs > 0) b.write(' · $outs outs (~$drawPct% de ligar)');
      b.writeln();

      if (texture != null) {
        b.write('🃏 Board ${_textureDesc(texture)}');
        final ra = RangeModel.aggressorRangeAdvantage(texture);
        if (ra > 0.10) b.write(' → ventaja de rango: AGRESOR');
        else if (ra < -0.10) b.write(' → ventaja de rango: DEFENSOR/CALLER');
        b.writeln();
      }
      b.writeln();
    }

    // ── 2. MATEMÁTICAS GTO ──────────────────────────────────────────────────
    b.writeln('━━━ MATEMÁTICAS ━━━');
    if (callAmount > 0) {
      final odds = potOddsRequired(callAmount, potSize);
      final evVal = equity - odds;
      b.writeln('Equity: $eqPct% | Pot Odds: ${(odds*100).toStringAsFixed(1)}% | EV: ${evVal >= 0 ? "+" : ""}${(evVal*100).toStringAsFixed(1)}%');
      b.writeln('MDF (tu defensa mínima): ${(mdf*100).toStringAsFixed(0)}% del rango');
      b.writeln('Alpha (rival necesita ${(alpha*100).toStringAsFixed(0)}% folds para blufar)');
    } else {
      b.writeln('Equity: $eqPct% | SPR: ${spr.toStringAsFixed(1)} (${_sprLabel(spr)})');
    }
    b.writeln();

    // ── 3. RECOMENDACIÓN PRINCIPAL ──────────────────────────────────────────
    b.writeln('━━━ RECOMENDACIÓN ━━━');
    if (primaryAction == 'Bet' || primaryAction == 'Raise') {
      final sizing = primaryAmount > 0 ? '\$${primaryAmount.toStringAsFixed(0)} (${(primaryAmount / max(potSize, 1) * 100).toStringAsFixed(0)}% bote)' : '';
      if (bucket == HandBucket.nuts || bucket == HandBucket.strongValue) {
        b.writeln('BET VALOR $sizing — tu mano está adelante; construye el bote ahora.');
        if (texture != null && texture.wetness > 0.50) {
          b.writeln('Board húmedo: 66-75% del bote es el sizing óptimo para proteger + extraer.');
        } else {
          b.writeln('Board seco: puedes usar 50-66% del bote. También considera check para inducir bluffs del rival.');
        }
      } else if (bucket == HandBucket.comboDraw || bucket == HandBucket.strongDraw) {
        b.writeln('SEMI-BLUFF $sizing — $outs outs (~$drawPct%) + fold equity = dos formas de ganar.');
        b.writeln('Ganas cuando el rival foldea Y cuando ligas la mano. Presiona ahora.');
        b.writeln('Si el rival re-raise: evalúa el SPR. Con SPR ${spr.toStringAsFixed(1)} ${spr < 4 ? "considera el all-in — tienes equity" : "puedes llamar y realizer equity"}.');
      } else if (primaryAction == 'Raise' && callAmount > 0) {
        b.writeln('RAISE-FAROL $sizing — tus bloqueadores + board seco hacen viable el bluff.');
        b.writeln('El rival necesita ${(alpha*100).toStringAsFixed(0)}% de folds para que sea +EV. En este spot lo consigues.');
      } else {
        b.writeln('BET de valor fino / protección $sizing.');
        b.writeln('No dejes que el rival realice equity gratis con draws.');
      }
    } else if (primaryAction == 'Call') {
      b.writeln('CALL rentable — equity $eqPct% cubre las pot odds.');
      if (bucket == HandBucket.strongDraw || bucket == HandBucket.comboDraw) {
        b.writeln('⚡ Alternativa: RAISE SEMI-BLUFF a \$${_snapToBetSize(callAmount * 2.8).toStringAsFixed(0)} — suma fold equity a tus $outs outs reales. Suele ser superior al call pasivo.');
      }
      if (bucket == HandBucket.mediumValue || bucket == HandBucket.weakShowdown) {
        b.writeln('Tu mano es bluff-catcher válida. MDF requiere que defiendas ${(mdf*100).toStringAsFixed(0)}% del rango; pagando cumples.');
      }
    } else if (primaryAction == 'Fold') {
      b.writeln('FOLD — equity $eqPct% insuficiente vs pot odds. EV negativo continuar.');
      if ((blockers?.goodBluffBlockers ?? false) && texture != null && texture.wetness < 0.45 && !isRiver) {
        b.writeln('🔥 ALTERNATIVA: BLUFF RAISE. Tus bloqueadores + board seco = spot ideal para atacar. Alpha del ${(alpha*100).toStringAsFixed(0)}% es alcanzable. Considera atacar en vez de foldear.');
      }
    } else {
      b.writeln('CHECK — controla el bote y reevalúa.');
      if (bucket == HandBucket.nuts || bucket == HandBucket.strongValue) {
        b.writeln('Trampa: si el rival apuesta, puedes check-raise para construir el bote de golpe.');
      }
    }
    b.writeln();

    // ── 4. ANÁLISIS DE BLOQUEADORES ─────────────────────────────────────────
    if (isPostflop && blockers != null) {
      b.writeln('━━━ BLOQUEADORES ━━━');
      if (blockers.goodBluffBlockers) {
        b.writeln('✅ Tienes BUENAS cartas bloqueadoras:');
        if (blockers.nutFlushBlocker) b.writeln('  · Bloqueas el flush de nueces → el rival tiene menos nuts para llamar.');
        if (blockers.straightBlocker) b.writeln('  · Bloqueas las escaleras posibles → reduces el rango de valor del rival.');
        if (blockers.topCardBlocker) b.writeln('  · Bloqueas el tope del board → el rival tiene menos top pair strong kicker.');
        if (blockers.hasAce) b.writeln('  · Tienes un As → bloqueas combos AX de valor del rival.');
        b.writeln('→ Esto mejora la rentabilidad de cualquier apuesta/farol en este spot.');
      } else {
        b.writeln('⚠️ Sin bloqueadores fuertes — tus faroles son más arriesgados en este spot.');
        b.writeln('Prioriza semi-bluffs con outs o apuestas de valor puro.');
      }
      b.writeln();
    }

    // ── 5. MDF / DEFENSA ────────────────────────────────────────────────────
    if (callAmount > 0 && isPostflop) {
      b.writeln('━━━ DEFENSA MDF ━━━');
      b.writeln('Para no ser explotable: defiende ${(mdf*100).toStringAsFixed(0)}% de tu rango.');
      final odds = potOddsRequired(callAmount, potSize);
      if (equity >= odds - 0.05) {
        b.writeln('Tu mano ($eqPct%) entra en el rango de defensa → CALL o RAISE.');
        b.writeln('El rival necesita ${(alpha*100).toStringAsFixed(0)}% de folds para blufar a 0EV → si tu rango defiende correctamente, sus bluffs son -EV.');
      } else {
        b.writeln('Tu mano ($eqPct%) está por debajo del umbral puro.');
        if (blockers?.goodBluffBlockers ?? false) {
          b.writeln('Sin embargo, con tus bloqueadores puedes RAISE como defense con ventaja adicional.');
        } else {
          b.writeln('Fold es correcto. No defiendas por orgullo — el EV manda.');
        }
      }
      b.writeln();
    }

    // ── 6. PLANIFICACIÓN DE CALLES ──────────────────────────────────────────
    if (!isRiver && isPostflop && texture != null) {
      b.writeln('━━━ PLANIFICACIÓN MULTI-CALLE ━━━');
      final streetsLeft = communityCards.length == 3 ? 2 : 1;
      b.writeln('Calles restantes: $streetsLeft | SPR: ${spr.toStringAsFixed(1)}');
      b.writeln();

      if (texture.wetness > 0.50) {
        b.writeln('🃏 Board húmedo — cartas que CAMBIAN el spot:');
        b.writeln('  · Carta completando el flush/straight: FRENA. Check o bet pequeño. El rival pudo llegar.');
        b.writeln('  · Carta de par en el board: board empareado favorece al caller. Reevalúa.');
        b.writeln('  · Brick (carta sin conexión): BARREL. Tu historia de fuerza se mantiene.');
      } else {
        b.writeln('🃏 Board seco — cartas que CAMBIAN el spot:');
        b.writeln('  · Carta conectante (7, 8, 9 tipo): ojo con draws que se activan, reduce sizing.');
        b.writeln('  · Carta de flush (3 del mismo palo): reevalúa si tienes el bloqueador o no.');
        b.writeln('  · Brick: continúa la presión. Tienes ventaja de rango en este tipo de board.');
      }
      if (outs > 0) {
        b.writeln('  · Si LIGAS ($outs outs, ~$drawPct%): apuesta fuerte, extrae máximo valor.');
        b.writeln('  · Si NO ligas: decide si el barrel puro vale con tus bloqueadores.');
      }
      b.writeln();

      b.writeln('📐 Plan SPR ${spr.toStringAsFixed(1)}:');
      if (spr <= 2.5) {
        b.writeln('Stack corto → comprométete con valor ahora. Con mano fuerte: all-in es correcto.');
        b.writeln('Sizing recomendado: ≥75% del bote en cada calle para comprometerte eficientemente.');
      } else if (spr <= 5.0) {
        b.writeln('$streetsLeft calles para llegar al all-in. Plan: bet-bet o bet-check-river bomb.');
        b.writeln('Sizing recomendado: 50-60% del bote para tener bet de river con todo comprometido.');
      } else if (spr <= 10.0) {
        b.writeln('SPR profundo: necesitas 3 calles para stackear. No te comprometas sin mano fuerte.');
        b.writeln('Sizing recomendado: 33-50% del bote en calles tempranas; escala en river.');
      } else {
        b.writeln('SPR muy profundo (${spr.toStringAsFixed(0)}x): controla el bote. Solo stacks off con nueces.');
      }
      b.writeln();
    }

    // ── 7. SPOTS DE BLUFF EN ESTE BOARD ────────────────────────────────────
    if (isPostflop && texture != null && !isRiver) {
      b.writeln('━━━ SPOTS DE BLUFF / SEMI-BLUFF ━━━');
      if (texture.wetness < 0.35) {
        b.writeln('✅ Board seco: alta frecuencia de bluff (40-55%). El rival necesita mano real para continuar.');
        b.writeln('→ C-bets, barrels y check-raises son todos más rentables en este tipo de board.');
      } else if (texture.wetness > 0.60) {
        b.writeln('⚠️ Board húmedo: bluffs de riesgo alto. Rivales conectan más y pagan más.');
        b.writeln('→ Prioriza semi-bluffs (con outs) sobre bluffs puros. Reduce sizing en bluffs.');
      } else {
        b.writeln('☑️ Textura media: bluffs selectivos. Usa posición e iniciativa a tu favor.');
      }
      if (texture.connected && !texture.monotone) {
        b.writeln('⚡ Board conectado: el rival tiene muchos draws. Check-raise con tus draws semi-bluff es óptimo.');
      }
      if (texture.paired) {
        b.writeln('🎯 Board empareado: el rango se polariza. Bluffs representando trips funcionan bien.');
      }
      if (texture.aceHigh) {
        b.writeln('🎯 Board con As: el agresor preflop tiene muchos combos de AX. Bluffs representando AX creíbles.');
      }
    }

    return b.toString().trim();
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

  static String _textureDesc(BoardTexture t) {
    if (t.monotone) return 'MONOTONO (flush draw presente)';
    if (t.paired) return 'EMPAREJADO';
    if (t.connected && t.wetness > 0.55) return 'MUY HÚMEDO y CONECTADO';
    if (t.connected) return 'CONECTADO';
    if (t.wetness > 0.55) return 'HÚMEDO';
    if (t.aceHigh) return 'SECO con As';
    if (t.broadwayHeavy) return 'BROADWAY';
    if (t.low) return 'BAJO y SECO';
    return 'SECO';
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
