import 'dart:math';
import '../data/models/card_model.dart';
import '../data/models/hand_log_model.dart';
import '../data/models/session_stats_model.dart';
import '../data/repositories/game_repository.dart';
import '../core/utils/hand_evaluator.dart';
import '../core/utils/equity_calculator.dart';
import '../core/utils/poker_concepts.dart';
import '../data/models/player_model.dart';
import 'poker_engine.dart';
import '../core/i18n/i18n.dart';

/// Background hand logger + street-by-street reviewer.
/// All player-facing texts speak with the voice of el Puxi:
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
      position: humanPlayer.position,
      startStack: humanPlayer.stack - humanProfit,
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
    required TablePosition position,
    required double startStack,
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

      final (explanationKey, explanationParams) = _zerosExplanation(
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

      analyses.add(StreetAnalysis(
        street: street,
        heroEquity: equity,
        potOdds: potOdds,
        heroAction: humanAction.label,
        heroAmount: humanAction.amount,
        quality: quality,
        explanation: '', // re-localized live from key+params
        explanationKey: explanationKey,
        explanationParams: explanationParams,
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
            return fmt(['mar_fold_a', 'mar_fold_b'][_rng.nextInt(2)]);
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
