import 'dart:math';
import '../data/models/card_model.dart';
import '../data/models/hand_log_model.dart';
import '../data/models/session_stats_model.dart';
import '../data/repositories/game_repository.dart';
import '../core/utils/hand_evaluator.dart';
import '../core/utils/equity_calculator.dart';
import 'poker_engine.dart';

/// Background hand logger + street-by-street reviewer.
/// All player-facing texts speak with the voice of ZerosPoker:
/// a brutally honest coach who roasts you while teaching you.
class HandReviewerEngine {
  final GameRepository _repo;
  static final Random _rng = Random();

  HandReviewerEngine(this._repo);

  Future<void> recordHand({
    required GameState completedState,
    required double humanProfit,
    required int handNumber,
  }) async {
    final humanPlayer = completedState.humanPlayer;
    if (humanPlayer.holeCards.isEmpty) return;

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
    );

    await _repo.saveHandLog(log);
  }

  List<StreetAnalysis> _analyzeStreets({
    required List<HandAction> humanActions,
    required List<CardModel> humanHole,
    required List<CardModel> community,
    required List<HandAction> allActions,
    required int activePlayers,
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
        equity = EquityCalculator.calculate(
          heroCards: humanHole,
          communityCards: communityAtStreet,
          numOpponents: max(1, activePlayers - 1),
          simulations: 200,
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

      final quality = _evaluateDecision(
        action: humanAction,
        equity: equity,
        potOdds: potOdds,
        street: street,
      );

      final explanation = _zerosExplanation(
        action: humanAction,
        equity: equity,
        potOdds: potOdds,
        quality: quality,
        street: street,
      );

      analyses.add(StreetAnalysis(
        street: street,
        heroEquity: equity,
        potOdds: potOdds,
        heroAction: humanAction.label,
        heroAmount: humanAction.amount,
        quality: quality,
        explanation: explanation,
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

  /// A disciplined fold with low equity is OPTIMAL — never a mistake.
  DecisionQuality _evaluateDecision({
    required HandAction action,
    required double equity,
    required double potOdds,
    required String street,
  }) {
    switch (action.type) {
      case ActionType.fold:
        if (equity > 0.50) return DecisionQuality.blunder;
        if (equity > 0.38) return DecisionQuality.marginal;
        if (equity > 0.28) return DecisionQuality.correct;
        return DecisionQuality.optimal; // good fold = good play, period

      case ActionType.call:
        final ev = equity - potOdds;
        if (ev > 0.15) return DecisionQuality.marginal; // should have raised
        if (ev >= -0.05) return DecisionQuality.correct;
        if (ev >= -0.12) return DecisionQuality.marginal;
        return DecisionQuality.blunder;

      case ActionType.check:
        if (equity > 0.70 && street != 'preflop') return DecisionQuality.marginal;
        if (equity > 0.50) return DecisionQuality.correct;
        return DecisionQuality.optimal;

      case ActionType.bet:
      case ActionType.raise:
        if (equity >= 0.60) return DecisionQuality.optimal;
        if (equity >= 0.45) return DecisionQuality.correct;
        if (equity >= 0.30) return DecisionQuality.marginal;
        return DecisionQuality.blunder;

      case ActionType.allIn:
        if (equity >= 0.55) return DecisionQuality.optimal;
        if (equity >= 0.45) return DecisionQuality.correct;
        if (equity >= 0.35) return DecisionQuality.marginal;
        return DecisionQuality.blunder;
    }
  }

  // ── ZerosPoker speaks ──────────────────────────────────────────────

  static String _pick(List<String> options) =>
      options[_rng.nextInt(options.length)];

  String _zerosExplanation({
    required HandAction action,
    required double equity,
    required double potOdds,
    required DecisionQuality quality,
    required String street,
  }) {
    final eq = (equity * 100).toStringAsFixed(1);
    final odds = (potOdds * 100).toStringAsFixed(1);

    switch (quality) {
      case DecisionQuality.optimal:
        switch (action.type) {
          case ActionType.fold:
            return _pick([
              'Fold correcto en el $street. Con $eq% de equity ahí no se te ha perdido nada. Mira, hasta tú sabes soltar cartas. Me sorprendes.',
              'Buen fold en el $street, máquina. Tu equity era $eq% — pagar eso sería de pescado. Esto NO cuenta como mano perdida, cuenta como dinero ahorrado.',
              'Fold en el $street con $eq% de equity. Decisión de libro. No te emociones, que una golondrina no hace verano.',
            ]);
          case ActionType.check:
            return _pick([
              'Check decente en el $street con $eq% de equity. Control del bote, trampa tendida... ¿quién eres y qué has hecho con el manco de siempre?',
              'Check en el $street. Con $eq% está bien pasar y dejar que el rival se cuelgue solo. Bien visto.',
            ]);
          case ActionType.bet:
          case ActionType.raise:
            return _pick([
              'Apuesta de valor en el $street con $eq% de equity. Extracción máxima, como manda la teoría. Si jugaras así siempre no tendría trabajo.',
              'Bet en el $street con $eq%. Eso es presionar con ventaja, no como otras veces que apuestas por aburrimiento.',
            ]);
          case ActionType.call:
            return _pick([
              'Call rentable en el $street: $eq% de equity contra $odds% de pot odds. Las mates te dan la razón. Disfrútalo, no pasa a menudo.',
            ]);
          case ActionType.allIn:
            return _pick([
              'All-in en el $street con $eq% de equity. Spot premium, EV maximizado. Hasta un reloj parado da bien la hora dos veces al día.',
            ]);
        }

      case DecisionQuality.correct:
        switch (action.type) {
          case ActionType.fold:
            return 'Fold razonable en el $street. Equity de $eq%, justita. Un call tenía un pelín de EV pero no te voy a crucificar por ser prudente. Esta vez.';
          case ActionType.call:
            return 'Call correcto en el $street: $eq% de equity cubre las pot odds de $odds%. Aprobado raspado, no te flipes.';
          case ActionType.check:
            return 'Check aceptable en el $street con $eq%. Había opciones de apostar pero bueno, no todo el mundo nace valiente.';
          default:
            return 'Decisión sólida en el $street con $eq% de equity. En línea con GTO. Sigue así y a lo mejor llegas a regular de NL2.';
        }

      case DecisionQuality.marginal:
        switch (action.type) {
          case ActionType.fold:
            return 'Fold dudoso en el $street, campeón. Con $eq% de equity contra $odds% de pot odds, el call tenía EV positivo. Te están robando la merienda y tú dándoles las gracias.';
          case ActionType.call:
            return 'Call marginal en el $street. $eq% de equity contra $odds% de pot odds... eso es jugártela a la moneda. O subes o foldeas, pero deja de pagar por ver como si esto fuera Netflix.';
          case ActionType.check:
            return 'Check con $eq% de equity en el $street... ¿en serio? Tenías una apuesta de valor clarísima y la has dejado en el cajón. Dinero que no extraes es dinero que regalas, genio.';
          default:
            return 'Decisión marginal en el $street. Con $eq% de equity ese sizing chirría. Revisa los tamaños, que apostar a ojo es de cuñao en partida casera.';
        }

      case DecisionQuality.blunder:
        switch (action.type) {
          case ActionType.fold:
            return '🚨 ERROR GRAVE: ¿Foldeaste con $eq% de equity en el $street? ¡Tenías la mano ganadora media vida y la tiraste a la basura! Con pot odds de $odds% ese fold es prenderle fuego al EV. De verdad, a veces pienso que juegas con los pies.';
          case ActionType.call:
            return '🚨 ERROR GRAVE: Pagar en el $street con solo $eq% de equity necesitando $odds% es de manual... de manual de lo que NO se hace. Ese call fue quemar dinero. El fold era gratis, campeón, GRATIS.';
          case ActionType.bet:
          case ActionType.raise:
            return '🚨 ERROR GRAVE: ¿Agresión en el $street con $eq% de equity? ¿Farol con qué bloqueadores, con qué fold equity, con qué CABEZA? Check-fold era la jugada. Apuntado queda para tu informe.';
          case ActionType.allIn:
            return '🚨 ERROR GRAVE: All-in en el $street con $eq% de equity. Ibas detrás del rango rival como un cohete. Eso no es poker, eso es donar con estilo. Blunder de los gordos.';
          default:
            return '🚨 ERROR GRAVE en el $street con $eq% de equity. No sé ni cómo describirlo. Revisa la mano y reza.';
        }
    }
  }
}

/// ZerosPoker: the global session coach. Roasts your leaks, then hands
/// you the homework to fix them.
class AICoach {
  static String generateReport(SessionStats stats, List<HandLog> hands) {
    if (stats.handsPlayed < 3) {
      return 'Juega al menos 5 manos y vuelve. No puedo destrozar tu juego sin pruebas, aunque me muera de ganas. — ZerosPoker';
    }

    final b = StringBuffer();
    b.writeln('═══ INFORME DE ZEROSPOKER ═══');
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
    b.writeln('— ZerosPoker, que te aprecia más de lo que parece 🃏');

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
