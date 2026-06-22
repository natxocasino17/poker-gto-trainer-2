import 'dart:math';
import '../data/models/card_model.dart';
import '../data/models/hand_log_model.dart';
import '../data/models/session_stats_model.dart';
import '../data/repositories/game_repository.dart';
import '../core/utils/hand_evaluator.dart';
import '../core/utils/equity_calculator.dart';
import '../core/utils/poker_concepts.dart';
import '../core/utils/postflop_context.dart';
import '../core/utils/trainer_feedback.dart';
import '../data/models/player_model.dart';
import 'cfr/cfr_bridge.dart';
import 'poker_engine.dart';
import '../core/i18n/i18n.dart';

/// Background hand logger + street-by-street reviewer.
/// All player-facing texts speak with the voice of el Puxi:
/// a brutally honest coach who roasts you while teaching you.
class HandReviewerEngine {
  final GameRepository _repo;
  static final Random _rng = Random();

  HandReviewerEngine(this._repo);

  /// Records the completed hand and returns the persisted [HandLog] (or null
  /// when there's nothing to log), so callers can append it in memory instead
  /// of re-reading the whole history from disk.
  Future<HandLog?> recordHand({
    required GameState completedState,
    required double humanProfit,
    required int handNumber,
    Map<String, GTORecommendation>? liveAdvice,
  }) async {
    final humanPlayer = completedState.humanPlayer;
    if (humanPlayer.holeCards.isEmpty) return null;

    final humanActions = completedState.currentHandActions
        .where((a) => a.playerId == 'human')
        .toList();

    final allHoleCards = <String, List<CardModel>>{};
    for (final p in completedState.players) {
      if (p.holeCards.isNotEmpty) {
        allHoleCards[p.id] = p.holeCards;
      }
    }

    String handDesc = 'Fold';
    if (!humanPlayer.isFolded && completedState.communityCards.isNotEmpty) {
      try {
        final score = HandEvaluator.evaluateBest([
          ...humanPlayer.holeCards,
          ...completedState.communityCards,
        ]);
        handDesc = score.description;
      } catch (_) {}
    }

    final streetAnalyses = _analyzeStreets(
      humanActions: humanActions,
      humanHole: humanPlayer.holeCards,
      community: completedState.communityCards,
      allActions: completedState.currentHandActions,
      activePlayers: completedState.players.where((p) => !p.isFolded).length,
      position: humanPlayer.position,
      startStack: humanPlayer.stack - humanProfit,
      liveAdvice: liveAdvice,
    );

    final winner = completedState.players.firstWhere(
      (p) => p.isWinner,
      orElse: () => completedState.players.first,
    );

    final log = HandLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_$handNumber',
      timestamp: DateTime.now(),
      handNumber: handNumber,
      humanHoleCards: humanPlayer.holeCards,
      communityCards: completedState.communityCards,
      allHoleCards: allHoleCards,
      actions: completedState.currentHandActions,
      finalPot: completedState.pot,
      winnerId: winner.id,
      winnerName: winner.name,
      humanProfit: humanProfit,
      humanHandDescription: handDesc,
      streetAnalyses: streetAnalyses,
      botNames: completedState.players.where((p) => !p.isHuman).map((p) => p.name).toList(),
      humanStartStack: humanPlayer.stack - humanProfit,
      positions: {
        for (final p in completedState.players) p.id: _posLabel(p.position),
      },
    );

    await _repo.saveHandLog(log);
    return log;
  }

  List<StreetAnalysis> _analyzeStreets({
    required List<HandAction> humanActions,
    required List<CardModel> humanHole,
    required List<CardModel> community,
    required List<HandAction> allActions,
    required int activePlayers,
    required TablePosition position,
    required double startStack,
    Map<String, GTORecommendation>? liveAdvice,
  }) {
    final analyses = <StreetAnalysis>[];
    final streets = ['preflop', 'flop', 'turn', 'river'];

    for (final street in streets) {
      final streetHumanActions = humanActions.where((a) => a.street == street).toList();
      if (streetHumanActions.isEmpty) continue;

      final communityAtStreet = _communityAtStreet(community, street);
      final boardCount = communityAtStreet.length;

      double equity;
      if (street == 'preflop' || boardCount == 0) {
        equity = CardModel.preflopStrength(humanHole);
      } else {
        // Range-filtered Monte Carlo: opponents are sampled from a realistic
        // calling range (~40% of hands), not purely random. This avoids the
        // inflated equity numbers caused by including garbage hands (72o, 83o…)
        // that real players would fold preflop.
        final rangeW = street == 'flop' ? 0.45 : 0.38;
        equity = EquityCalculator.calculate(
          heroCards: humanHole,
          communityCards: communityAtStreet,
          numOpponents: max(1, activePlayers - 1),
          simulations: 500,
          deterministic: true,
          rangeWidth: rangeW,
        );
      }

      final streetBets = allActions
          .where((a) => a.street == street && a.type != ActionType.fold && a.type != ActionType.check)
          .map((a) => a.amount)
          .fold(0.0, (sum, a) => sum + a);
      final potAtStreet = streetBets + (street == 'preflop' ? 3.0 : 0);
      final humanAction = streetHumanActions.last;
      final callAmt = humanAction.type == ActionType.call ? humanAction.amount : 0.0;
      final potOdds = EquityCalculator.potOddsRequired(callAmt, potAtStreet);

      // Deep context: texture, made hand/draws, blockers, SPR, MDF
      final texture = boardCount >= 3 ? BoardTexture.analyze(communityAtStreet) : null;
      final analysis = boardCount >= 3
          ? HandStrengthAnalysis.analyze(humanHole, communityAtStreet)
          : null;
      final blockers = boardCount >= 3
          ? Blockers.analyze(humanHole, communityAtStreet)
          : null;
      final spr = GtoMath.spr(max(startStack, 1), max(potAtStreet, 1));

      final quality = _evaluateDecision(
        action: humanAction,
        equity: equity,
        potOdds: potOdds,
        street: street,
        analysis: analysis,
        blockers: blockers,
        texture: texture,
      );

      final (expKey, expParams) = _zerosExplanation(
        action: humanAction,
        equity: equity,
        potOdds: potOdds,
        quality: quality,
        street: street,
        position: position,
        texture: texture,
        analysis: analysis,
        blockers: blockers,
        spr: spr,
        potAtStreet: potAtStreet,
        callAmt: callAmt,
      );

      // Postflop: use the same full 8-section reasoning engine as the live
      // GTO advisor so the hand review is as precise as the in-game overlay.
      // Preflop stays with the Puxi i18n coach phrase (no board to analyze).
      String fullExplanation = '';
      String finalKey = expKey;
      Map<String, String> finalParams = expParams;
      // Postflop these are overridden so the badge equity, the verdict and the
      // recommendation ALL come from the same source (no "optimal CALL graded
      // marginal", no two different equity numbers).
      var finalQuality = quality;
      var finalEquity = equity;
      var finalPotOdds = potOdds;

      if (boardCount >= 3) {
        // ── Postflop factors (same model the advisor + bots use) ──
        const streetIdx = {'preflop': 0, 'flop': 1, 'turn': 2, 'river': 3};
        final curIdx = streetIdx[street] ?? 1;
        final preflopRaises = allActions
            .where((a) => a.street == 'preflop' && a.isAggressive)
            .length;
        String? lastAggId;
        for (final a in allActions) {
          if ((streetIdx[a.street] ?? 0) > curIdx) break;
          if (a.isAggressive) {
            lastAggId = a.playerId;
          }
        }
        final hasInitiative = lastAggId == 'human';
        final inPosition = position == TablePosition.btn;
        final ctx = PostflopContext(
          position: position,
          inPosition: inPosition,
          hasInitiative: hasInitiative,
          numActive: activePlayers,
          potType: PostflopContext.potTypeFromRaiseCount(max(1, preflopRaises)),
          villainBet: callAmt,
          potSize: potAtStreet,
        );

        // Congruence: reuse the EXACT recommendation EL PUXI computed live at
        // the decision (same factors/snapshot) so the analyzer never contradicts
        // the in-game advisor. Only recompute if no live advice was captured.
        final rec = liveAdvice?[street] ??
            CfrBridge.instance.recommend(
              heroCards: humanHole,
              communityCards: communityAtStreet,
              callAmount: callAmt,
              potSize: potAtStreet,
              numOpponents: max(1, activePlayers - 1),
              heroStack: startStack,
              position: position,
              inPosition: inPosition,
              hasInitiative: hasInitiative,
              numActive: activePlayers,
              preflopRaises: max(1, preflopRaises),
            );
        // Grade the hero's actual action AGAINST this exact recommendation, and
        // show rec's equity/odds, so everything is internally consistent.
        finalQuality =
            TrainerGrader.grade(humanAction.type, humanAction.amount, rec).quality;
        finalEquity = rec.equity;
        finalPotOdds = rec.potOdds;
        // The concise advisor reasoning (head + hand + math + reco) is the
        // top; the hand-by-hand reviewer then APPENDS the deep, card-specific
        // sections (postflop factors, expanded SPR plan, blockers and bluff
        // spots that read the actual board/hand instead of boilerplate).
        final deep = _deepReview(
          street: street,
          hole: humanHole,
          board: communityAtStreet,
          pot: potAtStreet,
          spr: spr,
          heroStack: startStack,
          equity: finalEquity,
          texture: texture!,
          analysis: analysis!,
          blockers: blockers!,
          ctx: ctx,
          recAction: rec.action,
          recAmount: rec.amount,
          heroActionLabel: humanAction.label,
          quality: finalQuality,
        );
        fullExplanation = deep.isEmpty ? rec.reasoning : '${rec.reasoning}\n\n$deep';
        finalKey = '';
        finalParams = {};
      } else if (liveAdvice?[street] != null) {
        // PREFLOP congruence: reuse the exact live advice (DB-driven) so the
        // verdict + reasoning match EL PUXI (no "optimal fold" graded "marginal").
        final preRec = liveAdvice![street]!;
        finalQuality =
            TrainerGrader.grade(humanAction.type, humanAction.amount, preRec).quality;
        finalEquity = preRec.equity;
        finalPotOdds = preRec.potOdds;
        fullExplanation = preRec.reasoning;
        finalKey = '';
        finalParams = {};
      }

      analyses.add(StreetAnalysis(
        street: street,
        heroEquity: finalEquity,
        potOdds: finalPotOdds,
        heroAction: humanAction.label,
        heroAmount: humanAction.amount,
        quality: finalQuality,
        explanation: fullExplanation,
        explanationKey: finalKey,
        explanationParams: finalParams,
      ));
    }

    return analyses;
  }

  List<CardModel> _communityAtStreet(List<CardModel> community, String street) {
    switch (street) {
      case 'preflop': return [];
      case 'flop': return community.take(3).toList();
      case 'turn': return community.take(4).toList();
      case 'river': return community;
      default: return community;
    }
  }

  // ── Deep, card-specific review sections for the hand-by-hand analyzer ──────
  // Appended below the concise advisor reasoning. Every line reads the real
  // board / hole cards so the text varies hand to hand instead of repeating
  // generic boilerplate.

  String _deepReview({
    required String street,
    required List<CardModel> hole,
    required List<CardModel> board,
    required double pot,
    required double spr,
    required double heroStack,
    required double equity,
    required BoardTexture texture,
    required HandStrengthAnalysis analysis,
    required Blockers blockers,
    required PostflopContext ctx,
    required String recAction,
    required double recAmount,
    required String heroActionLabel,
    required DecisionQuality quality,
  }) {
    final isRiver = board.length == 5;
    final b = StringBuffer();

    b.writeln('━━━ ACCIÓN ÓPTIMA ━━━');
    b.writeln(_optimalSection(recAction, recAmount, pot, heroActionLabel,
        quality, analysis, equity, ctx));

    b.writeln();
    b.writeln('━━━ FACTORES POSTFLOP ━━━');
    b.writeln(_factorsRead(ctx, equity));

    b.writeln();
    b.writeln('━━━ PLAN SPR ${spr.toStringAsFixed(1)} ━━━');
    b.writeln(_sprPlan(spr, street, pot, heroStack, analysis, isRiver));

    b.writeln();
    b.writeln('━━━ BLOQUEADORES ━━━');
    b.writeln(_blockerRead(hole, board, blockers));

    if (!isRiver) {
      b.writeln();
      b.writeln('━━━ SPOTS DE BLUFF EN ESTE BOARD ━━━');
      b.writeln(_bluffRead(hole, board, texture));
    }
    return b.toString().trim();
  }

  /// "Acción óptima": the GTO play for this street, a concise why, and how the
  /// hero's actual action compares.
  String _optimalSection(
      String recAction,
      double recAmount,
      double pot,
      String heroActionLabel,
      DecisionQuality quality,
      HandStrengthAnalysis a,
      double equity,
      PostflopContext ctx) {
    final sizing = recAmount > 0
        ? ' \$${recAmount.toStringAsFixed(0)} (${(recAmount / max(pot, 1) * 100).toStringAsFixed(0)}% bote)'
        : '';
    final b = StringBuffer();
    b.writeln('GTO óptimo: ${recAction.toUpperCase()}$sizing');
    b.writeln('Por qué: ${_optimalWhy(a, equity, ctx, recAction)}');
    b.writeln('Tu jugada: $heroActionLabel → ${_verdictLabel(quality)}');
    return b.toString().trim();
  }

  // recAction is the action actually being recommended above — the narrative
  // must justify THAT action, not just describe the hand bucket in the
  // abstract. Otherwise a "GTO óptimo: CALL" header can be followed by a
  // "por qué" that argues for a semi-bluff/raise, reading as self-contradictory.
  String _optimalWhy(
      HandStrengthAnalysis a, double equity, PostflopContext ctx, String recAction) {
    final eq = (equity * 100).toStringAsFixed(0);
    final pos = ctx.inPosition ? 'en posición' : 'fuera de posición';
    final ini = ctx.hasInitiative ? 'con iniciativa' : 'sin iniciativa';
    final mw = ctx.isMultiway
        ? ' en bote multiway (sube el umbral de valor y baja el farol)'
        : '';
    final isAggro = recAction == 'Bet' || recAction == 'Raise';

    switch (a.bucket) {
      case HandBucket.nuts:
      case HandBucket.strongValue:
        if (isAggro) {
          return 'mano fuerte ($eq% equity)$mw: apuesta por valor y construye el bote ($pos, $ini).';
        }
        return 'mano fuerte ($eq% equity)$mw, pero aquí conviene controlar el bote (trampa/pot-control) en vez de apostar de nuevo ($pos, $ini).';
      case HandBucket.comboDraw:
      case HandBucket.strongDraw:
        if (isAggro) {
          return '${a.outs} outs (~${(a.drawEquity * 100).toStringAsFixed(0)}%) + fold equity: semi-bluff ($pos, $ini)$mw.';
        }
        return '${a.outs} outs (~${(a.drawEquity * 100).toStringAsFixed(0)}%) pero sin suficiente fold equity$mw: realiza tu equity con calma en vez de farolear ($pos, $ini).';
      case HandBucket.mediumValue:
      case HandBucket.weakShowdown:
        if (isAggro) {
          return 'valor medio ($eq%) que aguanta una apuesta fina de protección/valor$mw ($pos, $ini).';
        }
        return 'showdown / bluff-catcher ($eq%): controla el bote y paga según pot odds y MDF$mw ($pos).';
      case HandBucket.weakDraw:
      case HandBucket.air:
        if (isAggro) {
          return 'poca equity ($eq%) pero bloqueadores/textura permiten un farol +EV$mw ($pos, $ini).';
        }
        return 'poca equity ($eq%): check/fold salvo farol con bloqueadores$mw ($pos, $ini).';
    }
  }

  String _verdictLabel(DecisionQuality q) {
    switch (q) {
      case DecisionQuality.optimal:
        return 'ÓPTIMA ✅ (coincide con GTO)';
      case DecisionQuality.correct:
        return 'correcta 👍';
      case DecisionQuality.marginal:
        return 'marginal ⚠️ (había algo mejor)';
      case DecisionQuality.blunder:
        return 'error ❌ (te desviaste del GTO)';
    }
  }

  /// Per-factor postflop read: position/equity realization, multiway, initiative,
  /// pot type and (when known) the villain tendency, each with its effect.
  String _factorsRead(PostflopContext ctx, double equity) {
    final lines = <String>[];
    final realization = PostflopContext.equityRealization(
      inPosition: ctx.inPosition,
      hasInitiative: ctx.hasInitiative,
      numActive: ctx.numActive,
    );
    final realized = (equity * realization * 100).clamp(0, 100);

    lines.add(ctx.inPosition
        ? '· Posición: EN POSICIÓN → realizas más equity (~${realized.toStringAsFixed(0)}% de tu ${(equity * 100).toStringAsFixed(0)}%): ves cartas gratis, controlas el bote y puedes farolear/valorar más fino.'
        : '· Posición: FUERA DE POSICIÓN → realizas menos (~${realized.toStringAsFixed(0)}% de tu ${(equity * 100).toStringAsFixed(0)}%): te apuestan y te sacan de manos marginales; sé más selectivo y usa check-call/check-raise.');

    if (ctx.isMultiway) {
      lines.add('· Jugadores: MULTIWAY (${ctx.numActive}) → baja MUCHO la frecuencia de farol (alguien conecta casi siempre) y sube el umbral de valor: apuesta más fuerte y con manos más reales, casi nada de faroles puros.');
    } else {
      lines.add('· Jugadores: heads-up → guerra de rangos 1v1; faroles y value fino son rentables, aplica MDF y bloqueadores con normalidad.');
    }

    lines.add(ctx.hasInitiative
        ? '· Iniciativa: LA TIENES (fuiste el último agresor) → tu rango representa más fuerza; c-bet/barrel con buena frecuencia, sobre todo con ventaja de rango.'
        : '· Iniciativa: NO la tienes → no auto-apuestes; check-call, check-raise y floats (en posición) son mejores que farolear contra el agresor.');

    lines.add('· Tipo de bote: ${PostflopContext.potTypeLabel(ctx.potType)} → '
        '${ctx.potType == PotType.srp ? 'rangos amplios, SPR alto: juega varias calles, pot control con manos medias.' : ctx.potType == PotType.threeBet ? 'rangos más fuertes y SPR más bajo: te comprometes antes; overpairs y top pairs valen más.' : 'rangos muy fuertes y SPR bajo: casi todo es commit-or-fold; cuidado sin una mano premium.'}');

    if (!ctx.read.isNeutral) {
      lines.add(ctx.read.callingStation
          ? '· Rival: CALLING STATION → paga de más; valora MUCHO más fino y deja de farolear, no suelta una pareja.'
          : '· Rival: OVER-FOLDER → suelta de más; farolea sin descanso y no le pagues sus pocas apuestas grandes (rara vez farolea).');
    }

    return lines.join('\n');
  }

  /// Expanded SPR plan: explains what the ratio means here, how many bets to
  /// the all-in, recommended sizings, which hands to stack off, and the SPR
  /// the chosen line sets up for the next street.
  String _sprPlan(double spr, String street, double pot, double stack,
      HandStrengthAnalysis a, bool isRiver) {
    final b = StringBuffer();
    final streetsLeft = isRiver ? 0 : (street == 'flop' ? 2 : 1);
    final isStrong =
        a.bucket == HandBucket.nuts || a.bucket == HandBucket.strongValue;
    final isMed = a.bucket == HandBucket.mediumValue ||
        a.bucket == HandBucket.weakShowdown;
    final isDraw = a.bucket == HandBucket.comboDraw ||
        a.bucket == HandBucket.strongDraw;

    b.writeln('SPR = stack ÷ bote = ${stack.toStringAsFixed(0)} ÷ '
        '${pot.toStringAsFixed(0)} = ${spr.toStringAsFixed(1)}. Mide tu '
        'compromiso: cuanto más bajo, más casado estás con el bote.');

    if (spr <= 1.5) {
      b.writeln('MUY BAJO: estás prácticamente comprometido. Con top pair+ o un '
          'draw de muchos outs el dinero entra sí o sí; foldear aquí regala el '
          'bote. El precio que te dan ya justifica llegar al showdown.');
      b.writeln('Plan: una apuesta más = all-in. Apuesta por valor/protección, '
          'no para generar folds (apenas hay fold equity con stacks tan cortos).');
    } else if (spr <= 3.0) {
      b.writeln('BAJO: te comprometes con top pair buen kicker, overpairs, sets y '
          'draws de 12+ outs. Quedan $streetsLeft calle(s): una c-bet de 50-66% '
          'ya mete ~medio stack, así que el river es casi automático.');
      if (isStrong) {
        b.writeln('Tu mano entra de lleno en el rango de stack-off: construye el '
            'bote sin miedo, busca meter las fichas en 2 movimientos.');
      }
      if (isDraw) {
        b.writeln('Con tu draw, SPR bajo = semi-bluff/all-in ideal: equity + fold '
            'equity hacen el push +EV.');
      }
      if (isMed) {
        b.writeln('Con showdown medio, cuidado: a este SPR una guerra de apuestas '
            'te compromete; valora check para controlar el bote.');
      }
    } else if (spr <= 6.0) {
      b.writeln('MEDIO (estándar de cash): necesitas 2 apuestas para el all-in. '
          'Plan típico: flop 33-50% → turn 60-75% → river jam. Reserva el '
          'stack-off para two pair+, sets y draws que ligan.');
      b.writeln('Top pair de kicker flojo NO quiere un bote de 3 apuestas: si solo '
          'tienes showdown medio, controla el tamaño (check-call) en vez de inflar.');
      if (isDraw && !isRiver) {
        b.writeln('Con draw puedes barrelear 2 calles; si no ligas el river, decide '
            'el farol según tus bloqueadores.');
      }
    } else if (spr <= 12.0) {
      b.writeln('PROFUNDO: hacen falta las 3 calles para stackear. No te cases con '
          'manos mediocres. Usa sizings menores (33-50%) en flop para no inflar el '
          'bote con top pair.');
      b.writeln('Apunta a stack-off SOLO con manos que aguantan 3 barrels: '
          'overpairs altas, sets, two pair fuertes y nut draws. El resto → pot '
          'control para llegar barato al showdown.');
    } else {
      b.writeln('MUY PROFUNDO (${spr.toStringAsFixed(0)}x): juego de implícitas y '
          'posición. Solo metes todo con las nueces o casi. Sets y nut draws ganan '
          'mucho por implícitas (puedes stackear a un rival con top pair). Con '
          'showdown medio, bote pequeño.');
    }

    if (!isRiver) {
      final projSpr = ((spr - 0.66) / 2.33).clamp(0.0, spr);
      b.writeln('Si apuestas ~2/3 del bote y te pagan, el SPR de la próxima calle '
          'cae a ~${projSpr.toStringAsFixed(1)}: decide YA el tamaño del river '
          'antes de apostar, para no quedarte con un stack incómodo.');
    }
    return b.toString().trim();
  }

  /// Blocker read that NAMES the actual cards the hero holds and the combos
  /// they remove on THIS board — or, when there are none, teaches which
  /// blockers were missing here.
  String _blockerRead(
      List<CardModel> hole, List<CardModel> board, Blockers blk) {
    final lines = <String>[];

    final suitCount = <Suit, int>{};
    for (final c in board) {
      suitCount[c.suit] = (suitCount[c.suit] ?? 0) + 1;
    }
    Suit? flushSuit;
    int flushSuitN = 0;
    suitCount.forEach((s, n) {
      if (n >= 2 && n > flushSuitN) {
        flushSuit = s;
        flushSuitN = n;
      }
    });
    final flushSym = flushSuit == null
        ? ''
        : board.firstWhere((c) => c.suit == flushSuit).suitSymbol;

    if (blk.nutFlushBlocker) {
      final ace = hole.firstWhere(
          (c) => c.rank == 14 && c.suit == flushSuit,
          orElse: () => hole.first);
      lines.add('$ace → bloqueas el COLOR DE NUECES ($flushSym): el rival no '
          'puede tener el nut flush, así que sus colores fuertes para pagar caen '
          'en picado. Carta ideal para farolear representando ese color.');
    } else if (flushSuit != null && flushSuitN >= 3) {
      final mine = hole.where((c) => c.suit == flushSuit).toList();
      if (mine.isNotEmpty) {
        lines.add('${mine.first} → bloqueas ALGÚN color rival, pero no el de '
            'nueces. Vale para value medio, no como bloqueador de farol top.');
      } else {
        lines.add('No tienes cartas de $flushSym → NO bloqueas el color en un '
            'board de 3 del palo. Farolear aquí es caro: el rival paga con '
            'cualquier color hecho.');
      }
    }

    if (blk.straightBlocker) {
      final sc = _straightBlockerCard(hole, board);
      lines.add('${sc ?? 'una carta clave'} → bloqueas la ESCALERA principal: '
          'reduces los combos de valor que te pagarían, lo que mejora la '
          'rentabilidad de un farol.');
    }

    if (blk.topCardBlocker) {
      final top = board.map((c) => c.rank).reduce(max);
      final tc = hole.firstWhere((c) => c.rank == top, orElse: () => hole.first);
      lines.add('$tc → emparejas el tope del board: el rival tiene menos top pair '
          'fuerte. Bueno para value betting fino y reduce su rango de continuación.');
    }

    if (blk.hasAce && !blk.nutFlushBlocker) {
      final ace = hole.firstWhere((c) => c.rank == 14, orElse: () => hole.first);
      lines.add('$ace → bloqueas parte de los AX de valor del rival (AA y top '
          'pairs con As). Útil sobre todo en boards con As o para representar el '
          'As tú mismo.');
    }

    if (lines.isEmpty) {
      final b = StringBuffer();
      b.writeln('Tu mano NO aporta bloqueadores relevantes en este board, así que '
          'tus faroles son más caros: cuando apuestas/subes en farol, el rival '
          'tiene el rango entero para pagarte.');
      final ideal = <String>[];
      if (flushSuit != null && flushSuitN >= 2) {
        ideal.add('el A$flushSym (bloquea el color)');
      }
      final sb = _wouldBlockStraightRank(board);
      if (sb != null) ideal.add('un $sb (bloquea la escalera)');
      if (ideal.isNotEmpty) {
        b.writeln('Aquí los buenos bloqueadores serían ${ideal.join(' o ')}. Sin '
            'ellos, apuesta por valor o semi-bluffs con outs reales, no faroles '
            'puros.');
      }
      return b.toString().trim();
    }
    return lines.map((l) => '· $l').join('\n');
  }

  /// Bluff/representation read driven by the real board texture: names the
  /// hands you can credibly represent and the best scare cards to keep barreling.
  String _bluffRead(
      List<CardModel> hole, List<CardModel> board, BoardTexture t) {
    final b = StringBuffer();
    final ra = RangeModel.aggressorRangeAdvantage(t);

    if (t.wetness < 0.35) {
      b.writeln('Board SECO: tu rango de farol respira. El rival liga pocas veces, '
          'así que c-bets y barrels a alta frecuencia (≈55-65% en flop) rinden '
          'mucho${ra > 0.10 ? ', y como agresor tienes ventaja de rango para farolear amplio' : ''}.');
    } else if (t.wetness > 0.60) {
      b.writeln('Board HÚMEDO y coordinado: el rango del rival conecta a menudo. '
          'Farolea SELECTIVO y con respaldo (outs); los faroles puros se pagan, '
          'así que prioriza semi-bluffs y baja el tamaño de tus faroles.');
    } else {
      b.writeln('Textura MEDIA: faroles selectivos. Apóyate en posición, '
          'iniciativa y bloqueadores para elegir tus mejores combos.');
    }

    final suitCount = <Suit, int>{};
    for (final c in board) {
      suitCount[c.suit] = (suitCount[c.suit] ?? 0) + 1;
    }
    Suit? fsuit;
    int fn = 0;
    suitCount.forEach((s, n) {
      if (n >= 2 && n > fn) {
        fsuit = s;
        fn = n;
      }
    });
    final fsym =
        fsuit == null ? '' : board.firstWhere((c) => c.suit == fsuit).suitSymbol;

    final reps = <String>[];
    if (t.paired) {
      reps.add('TRIPS/FULL: el par de ${_pairedRankSym(board)} en la mesa hace '
          'creíble que tengas el trío. Polariza: apuestas grandes representan el '
          'full y el rival foldea pares sueltos.');
    }
    if (t.monotone) {
      final hasSuit = hole.any((c) => c.suit == fsuit);
      reps.add('COLOR: con 3 $fsym en el board, representar el color es potente'
          '${hasSuit ? ' y tú tienes una carta de $fsym que lo refuerza' : ', pero NO tienes carta de $fsym, así que el farol es más arriesgado'}.');
    } else if (t.twoTone) {
      reps.add('PROYECTO DE COLOR ($fsym): puedes barrelear los turns que '
          'completan el palo como si lo hubieras ligado — el rival te cree.');
    }
    if (t.aceHigh) {
      reps.add('AX: en board con As, como abridor preflop tienes muchos AX '
          'creíbles; representa el As y el rival suelta sus pares medios.');
    } else if (t.broadwayHeavy) {
      reps.add('BROADWAYS: board de figuras → representa AK/AQ/KQ; tus barrels en '
          'cartas altas son creíbles.');
    }
    if (t.connected && !t.monotone) {
      reps.add('ESCALERAS: board conectado → el check-raise como farol con tus '
          'draws (semi-bluff) ejerce máxima presión.');
    }
    if (t.low && ra < -0.10) {
      reps.add('OJO: board bajo favorece al defensor (BB). Su rango de calls '
          'conecta bien aquí; farolea menos y elige bien los runouts.');
    }

    for (final r in reps) {
      b.writeln('· $r');
    }

    if (board.length < 5) {
      final scare = <String>[];
      if (t.twoTone && fsym.isNotEmpty) scare.add('un 3.º $fsym (completa color)');
      final top = board.map((c) => c.rank).reduce(max);
      if (top < 14) {
        scare.add('un As (sobrecarta que representas mejor que el rival)');
      }
      if (!t.connected) {
        scare.add('cartas altas/conectoras que mejoran tu rango percibido');
      }
      if (scare.isNotEmpty) {
        b.writeln('Mejores cartas para seguir farolando en la próxima calle: '
            '${scare.join(', ')}.');
      }
    }
    return b.toString().trim();
  }

  /// Hero hole card that blocks the made straight on this board, or null.
  CardModel? _straightBlockerCard(List<CardModel> hole, List<CardModel> board) {
    final boardRanks = board.map((c) => c.rank).toSet();
    for (final h in hole) {
      if (boardRanks.contains(h.rank)) continue;
      for (int low = 1; low <= 10; low++) {
        final window = List.generate(5, (i) => low + i);
        final boardIn = window.where(boardRanks.contains).length;
        final hr = (h.rank == 14 && low == 1) ? 1 : h.rank;
        if (boardIn >= 3 && window.contains(hr)) return h;
      }
    }
    return null;
  }

  /// Symbol of a rank that would block the most-likely straight on this board.
  String? _wouldBlockStraightRank(List<CardModel> board) {
    final boardRanks = board.map((c) => c.rank).toSet();
    for (int low = 1; low <= 10; low++) {
      final window = List.generate(5, (i) => low + i);
      final boardIn = window.where(boardRanks.contains).length;
      if (boardIn >= 3) {
        final missing =
            window.where((r) => !boardRanks.contains(r) && r >= 2 && r <= 14).toList();
        if (missing.isNotEmpty) {
          final r = missing.reduce(max);
          return CardModel(rank: r, suit: Suit.spades).rankSymbol;
        }
      }
    }
    return null;
  }

  String _pairedRankSym(List<CardModel> board) {
    final counts = <int, int>{};
    for (final c in board) {
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    }
    int pr = board.first.rank;
    counts.forEach((r, n) {
      if (n >= 2) pr = r;
    });
    return CardModel(rank: pr, suit: Suit.spades).rankSymbol;
  }

  /// Quality evaluation with full context: a good fold is always a good
  /// play; bluffs are judged by blockers and texture, not raw equity;
  /// passive lines with monsters are flagged (raising was optimal).
  DecisionQuality _evaluateDecision({
    required HandAction action,
    required double equity,
    required double potOdds,
    required String street,
    HandStrengthAnalysis? analysis,
    Blockers? blockers,
    BoardTexture? texture,
  }) {
    final bucket = analysis?.bucket;
    final isAirOrWeak = bucket == HandBucket.air || bucket == HandBucket.weakDraw;

    switch (action.type) {
      case ActionType.fold:
        if (equity > 0.50) return DecisionQuality.blunder;
        if (equity > 0.38) return DecisionQuality.marginal;
        if (equity > 0.28) return DecisionQuality.correct;
        return DecisionQuality.optimal; // good fold = good play, period

      case ActionType.call:
        // Calling with a monster misses value: raising was optimal
        if (bucket == HandBucket.nuts || bucket == HandBucket.strongValue) {
          return DecisionQuality.marginal;
        }
        final ev = equity - potOdds;
        if (ev > 0.15) return DecisionQuality.marginal; // under-raised
        if (ev >= -0.05) return DecisionQuality.correct;
        if (ev >= -0.12) return DecisionQuality.marginal;
        return DecisionQuality.blunder;

      case ActionType.check:
        if ((bucket == HandBucket.nuts || bucket == HandBucket.strongValue) &&
            street != 'preflop') {
          // Trapping is fine on dry boards, costly on wet ones
          return (texture != null && texture.wetness < 0.35)
              ? DecisionQuality.correct
              : DecisionQuality.marginal;
        }
        if (equity > 0.70 && street != 'preflop') return DecisionQuality.marginal;
        if (equity > 0.50) return DecisionQuality.correct;
        return DecisionQuality.optimal;

      case ActionType.bet:
      case ActionType.raise:
        // Bluff line: judge by blockers + texture, not raw equity
        if (isAirOrWeak && street != 'preflop') {
          if (blockers != null && blockers.goodBluffBlockers &&
              texture != null && texture.wetness < 0.55) {
            return DecisionQuality.correct; // well-constructed bluff
          }
          if (texture != null && texture.wetness < 0.40) {
            return DecisionQuality.marginal; // stab on dry board, no blockers
          }
          return DecisionQuality.blunder; // spew into a wet board
        }
        if (bucket == HandBucket.comboDraw || bucket == HandBucket.strongDraw) {
          return DecisionQuality.optimal; // semi-bluff: equity + fold equity
        }
        if (equity >= 0.60) return DecisionQuality.optimal;
        if (equity >= 0.45) return DecisionQuality.correct;
        if (equity >= 0.30) return DecisionQuality.marginal;
        return DecisionQuality.blunder;

      case ActionType.allIn:
        if (bucket == HandBucket.comboDraw) return DecisionQuality.correct;
        if (equity >= 0.55) return DecisionQuality.optimal;
        if (equity >= 0.45) return DecisionQuality.correct;
        if (equity >= 0.35) return DecisionQuality.marginal;
        return DecisionQuality.blunder;
    }
  }

  // ── el Puxi speaks: localized in 6 languages, poker jargon stays English ──

  static String _pick(List<String> keys) =>
      I18n.t(keys[_rng.nextInt(keys.length)]);

  String _posLabel(TablePosition p) {
    switch (p) {
      case TablePosition.utg: return 'UTG';
      case TablePosition.mp: return 'MP';
      case TablePosition.co: return 'CO';
      case TablePosition.btn: return 'BTN';
      case TablePosition.sb: return 'SB';
      case TablePosition.bb: return 'BB';
    }
  }

  String _streetLabel(String s) {
    // Streets in lowercase English: stays as jargon across all locales.
    return s;
  }

  String _textureLabel(BoardTexture? t) {
    final k = _textureKey(t);
    return k.isEmpty ? '' : I18n.t(k);
  }

  /// Language-neutral texture key (resolved to text at display time).
  String _textureKey(BoardTexture? t) {
    if (t == null) return '';
    if (t.monotone) return 'tx_monotone';
    if (t.paired) return 'tx_paired';
    if (t.wetness > 0.55) return 'tx_wet';
    if (t.wetness < 0.35) return 'tx_dry';
    return 'tx_medium';
  }

  /// Builds the localized explanation, weaving in MDF / SPR / outs /
  /// blockers context only when relevant.
  /// Returns the i18n KEY of the coach phrase plus the raw, language-neutral
  /// params. Nothing is resolved to text here — that happens at display time
  /// in the user's CURRENT language, so switching language re-localizes the
  /// whole feedback (fixes the "always in Spanish" bug).
  (String, Map<String, String>) _zerosExplanation({
    required HandAction action,
    required double equity,
    required double potOdds,
    required DecisionQuality quality,
    required String street,
    required TablePosition position,
    BoardTexture? texture,
    HandStrengthAnalysis? analysis,
    Blockers? blockers,
    required double spr,
    required double potAtStreet,
    required double callAmt,
  }) {
    final bucket = analysis?.bucket;
    final preflop = street == 'preflop';

    final params = <String, String>{
      'street': _streetLabel(street),
      'pos': _posLabel(position),
      'eq': (equity * 100).toStringAsFixed(1),
      'odds': (potOdds * 100).toStringAsFixed(1),
      'texKey': _textureKey(texture),
      'mdf': callAmt > 0
          ? (GtoMath.mdf(potAtStreet - callAmt, callAmt) * 100).toStringAsFixed(0)
          : '',
      'spr': (!preflop && spr < 2.5) ? spr.toStringAsFixed(1) : '',
      'outs': (analysis != null && analysis.outs > 0) ? '${analysis.outs}' : '',
      'drawp': (analysis != null && analysis.outs > 0)
          ? (analysis.drawEquity * 100).toStringAsFixed(0)
          : '',
      'block': (blockers != null && blockers.goodBluffBlockers) ? '1' : '',
    };

    (String, Map<String, String>) fmt(String key) => (key, params);

    switch (quality) {
      case DecisionQuality.optimal:
        switch (action.type) {
          case ActionType.fold:
            return fmt(['opt_fold_a', 'opt_fold_b', 'opt_fold_c'][_rng.nextInt(3)]);
          case ActionType.check:
            return fmt(['opt_check_a', 'opt_check_b'][_rng.nextInt(2)]);
          case ActionType.bet:
          case ActionType.raise:
            if (bucket == HandBucket.comboDraw || bucket == HandBucket.strongDraw) {
              return fmt('opt_semibluff');
            }
            return fmt(['opt_value_a', 'opt_value_b'][_rng.nextInt(2)]);
          case ActionType.call:
            return fmt(['opt_call_a', 'opt_call_b'][_rng.nextInt(2)]);
          case ActionType.allIn:
            return fmt('opt_allin');
        }

      case DecisionQuality.correct:
        switch (action.type) {
          case ActionType.fold:
            return fmt('cor_fold');
          case ActionType.call:
            return fmt(['cor_call_a', 'cor_call_b'][_rng.nextInt(2)]);
          case ActionType.check:
            if (bucket == HandBucket.nuts || bucket == HandBucket.strongValue) {
              return fmt('cor_check_trap');
            }
            return fmt('cor_check');
          default:
            return fmt('cor_general');
        }

      case DecisionQuality.marginal:
        switch (action.type) {
          case ActionType.fold:
            // mar_fold_b references a board texture; preflop has none, so it
            // would render "...en ." — use the street-based line preflop.
            return fmt(preflop ? 'mar_fold_a' : ['mar_fold_a', 'mar_fold_b'][_rng.nextInt(2)]);
          case ActionType.call:
            if (bucket == HandBucket.nuts || bucket == HandBucket.strongValue) {
              return fmt('mar_call_monster');
            }
            return fmt(['mar_call_a', 'mar_call_b'][_rng.nextInt(2)]);
          case ActionType.check:
            return fmt('mar_check_value');
          case ActionType.bet:
          case ActionType.raise:
            if (bucket == HandBucket.air || bucket == HandBucket.weakDraw) {
              return fmt('mar_bluff_a');
            }
            return fmt('mar_aggro');
          default:
            return fmt('mar_general');
        }

      case DecisionQuality.blunder:
        switch (action.type) {
          case ActionType.fold:
            return fmt('bl_fold');
          case ActionType.call:
            return fmt('bl_call');
          case ActionType.bet:
          case ActionType.raise:
            return fmt('bl_aggro');
          case ActionType.allIn:
            return fmt('bl_allin');
          default:
            return fmt('bl_general');
        }
    }
  }
}

class AICoach {
  static String generateReport(SessionStats stats, List<HandLog> hands) {
    if (stats.handsPlayed < 3) {
      return 'Juega al menos 5 manos y vuelve. No puedo destrozar tu juego sin pruebas, aunque me muera de ganas. — el Puxi';
    }

    final b = StringBuffer();
    b.writeln('═══ INFORME DE EL PUXI ═══');
    b.writeln('(tu coach favorito, aunque no me aguantes)\n');
    b.writeln('Sesión: ${stats.handsPlayed} manos | Neto: ${stats.netProfit >= 0 ? "+" : ""}\$${stats.netProfit.toStringAsFixed(2)} | BB/100: ${stats.bbPer100.toStringAsFixed(1)}');
    if (stats.netProfit < 0) {
      b.writeln('Vas perdiendo. Sorpresa nivel: cero.\n');
    } else {
      b.writeln('Vas ganando. Disfrútalo mientras dure.\n');
    }

    b.writeln('📊 PERFIL PREFLOP');
    if (stats.vpip > 35) {
      b.writeln('⚠️ VPIP ${stats.vpip.toStringAsFixed(1)}%: juegas más manos que un pulpo. En 6-Max eso es sangrar fichas con basura especulativa. Objetivo: 22–28%. Aprende a foldear, que es gratis.');
    } else if (stats.vpip < 16 && stats.handsPlayed >= 10) {
      b.writeln('⚠️ VPIP ${stats.vpip.toStringAsFixed(1)}%: juegas tan cerrado que las rocas te llaman aburrido. Te leen como un libro infantil. Abre más desde CO y BTN. Objetivo: 22–28%.');
    } else {
      b.writeln('✅ VPIP ${stats.vpip.toStringAsFixed(1)}%: rango razonable para 6-Max. Vale, esto lo haces bien. No te acostumbres a los cumplidos.');
    }

    if (stats.pfr < stats.vpip * 0.65 && stats.vpip > 5) {
      b.writeln('⚠️ PFR ${stats.pfr.toStringAsFixed(1)}% vs VPIP ${stats.vpip.toStringAsFixed(1)}%: pagas demasiado preflop en vez de subir. Eso tiene un nombre técnico: jugar de pescado. Sube o foldea.');
    } else {
      b.writeln('✅ Ratio PFR/VPIP sano. Agresión preflop decente, quién lo diría.');
    }

    b.writeln('');
    b.writeln('🃏 FRECUENCIA DE 3-BET');
    if (stats.threeBetPct < 5) {
      b.writeln('⚠️ 3-Bet ${stats.threeBetPct.toStringAsFixed(1)}%: más pasivo que un domingo por la tarde. Los bots te roban las ciegas y tú sonriendo. Mete 3-bets de farol con A5s, KQs desde las ciegas. Objetivo: 8–12%.');
    } else if (stats.threeBetPct > 15) {
      b.writeln('⚠️ 3-Bet ${stats.threeBetPct.toStringAsFixed(1)}%: te has venido arriba. Inflas botes con manos marginales como si el dinero fuera de mentira. Recorta el rango de farol. Objetivo: 8–12%.');
    } else {
      b.writeln('✅ 3-Bet ${stats.threeBetPct.toStringAsFixed(1)}%: equilibrado entre valor y farol. Correcto. Me cuesta decirlo, pero correcto.');
    }

    b.writeln('');
    b.writeln('💰 TENDENCIAS POSTFLOP');
    if (stats.cBetPct > 80) {
      b.writeln('⚠️ C-Bet ${stats.cBetPct.toStringAsFixed(1)}%: disparas la continuación en cualquier textura como si fuera obligatorio. En boards húmedos te van a hacer check-raise hasta en la sopa. Objetivo: 55–70%.');
    } else if (stats.cBetPct < 40 && stats.handsPlayed >= 8) {
      b.writeln('⚠️ C-Bet ${stats.cBetPct.toStringAsFixed(1)}%: regalas cartas gratis y pierdes la iniciativa. Subiste preflop, ¿no? Pues actúa como tal. Objetivo: 55–70%.');
    } else {
      b.writeln('✅ Frecuencia de C-Bet bien calibrada (${stats.cBetPct.toStringAsFixed(1)}%).');
    }

    if (stats.riverFoldPct > 55) {
      b.writeln('⚠️ Fold en river del ${stats.riverFoldPct.toStringAsFixed(1)}%: foldeas el river más que respiras. Ivey y Dwan ya se han dado cuenta y te están faroleando EN TU CARA. Defiende al menos el 40% de tus bluff-catchers, por dignidad.');
    }

    b.writeln('');
    b.writeln('🎯 CALIDAD DE DECISIONES');
    if (stats.blunders > 0) {
      final blunderRate = stats.handsPlayed > 0 ? stats.blunders / stats.handsPlayed * 100 : 0;
      b.writeln('⚠️ ${stats.blunders} error${stats.blunders > 1 ? "es" : ""} grave${stats.blunders > 1 ? "s" : ""} (${blunderRate.toStringAsFixed(1)}% de las manos). Cada blunder es EV tirado al váter. Revísalos en ANALIZAR, están todos apuntados con nombre y apellidos.');
    } else {
      b.writeln('✅ Cero errores graves esta sesión. Estoy... ¿orgulloso? Qué sensación tan rara.');
    }
    b.writeln('Nota de decisiones: ${stats.decisionScore.toStringAsFixed(0)}/100');

    b.writeln('');
    b.writeln('📋 DEBERES PARA LA PRÓXIMA SESIÓN');
    b.writeln('(sí, deberes; el talento no te va a salvar)');
    final tasks = _generateTasks(stats);
    for (int i = 0; i < tasks.length; i++) {
      b.writeln('${i + 1}. ${tasks[i]}');
    }
    b.writeln('');
    b.writeln('— el Puxi, que te aprecia más de lo que parece 🃏');

    return b.toString();
  }

  static List<String> _generateTasks(SessionStats stats) {
    final tasks = <String>[];

    if (stats.vpip > 32) {
      tasks.add('Cierra el preflop: elimina el 10% más débil de tus aperturas en UTG/MP. Esas manos "bonitas" te están costando dinero.');
    }
    if (stats.vpip < 18 && stats.handsPlayed >= 10) {
      tasks.add('Abre más desde BTN/CO: añade conectores suited (T9s, 87s) y Axs. Deja de jugar como una roca con miedo.');
    }
    if (stats.threeBetPct < 6) {
      tasks.add('Añade 3-bets ligeros: defiende la BB vs aperturas de BTN con A5s y KQs como faroles polarizados.');
    }
    if (stats.riverFoldPct > 55) {
      tasks.add('Defiende el river: paga al menos un bluff-catcher por sesión contra los bots agresivos. Que no te vean el plumero.');
    }
    if (stats.cBetPct > 78) {
      tasks.add('Baja la frecuencia de c-bet en boards húmedos y conectados (tipo 9♠8♥7♠). Check-call y a vivir.');
    }
    if (stats.blunders > 2) {
      tasks.add('Repasa TODOS tus errores graves en ANALIZAR. Identifica la calle exacta donde te desviaste del GTO. Sin excusas.');
    }
    if (stats.wtsd > 38) {
      tasks.add('Sé más selectivo llegando al showdown: foldea manos marginales ante agresión en el river.');
    }
    if (tasks.isEmpty) {
      tasks.add('Mantén la disciplina actual y pule los tamaños de apuesta.');
      tasks.add('Trabaja las estrategias mixtas: aleatoriza tus patrones para que ni yo pueda leerte. Reto difícil, lo sé.');
    }

    return tasks.take(5).toList();
  }
}
