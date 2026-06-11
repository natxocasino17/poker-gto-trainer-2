import 'dart:math';
import '../data/models/card_model.dart';
import '../data/models/hand_log_model.dart';
import '../data/models/session_stats_model.dart';
import '../data/repositories/game_repository.dart';
import '../core/utils/hand_evaluator.dart';
import '../core/utils/equity_calculator.dart';
import 'poker_engine.dart';

class HandReviewerEngine {
  final GameRepository _repo;

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

    String handDesc = 'Folded';
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

      final explanation = _buildExplanation(
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

  DecisionQuality _evaluateDecision({
    required HandAction action,
    required double equity,
    required double potOdds,
    required String street,
  }) {
    switch (action.type) {
      case ActionType.fold:
        if (equity > 0.45) return DecisionQuality.blunder;
        if (equity > 0.35) return DecisionQuality.marginal;
        if (equity > 0.25) return DecisionQuality.correct;
        return DecisionQuality.optimal;

      case ActionType.call:
        final ev = equity - potOdds;
        if (ev > 0.15) return DecisionQuality.marginal; // under-raised
        if (ev > 0.05) return DecisionQuality.correct;
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

  String _buildExplanation({
    required HandAction action,
    required double equity,
    required double potOdds,
    required DecisionQuality quality,
    required String street,
  }) {
    final eqPct = (equity * 100).toStringAsFixed(1);
    final oddsPct = (potOdds * 100).toStringAsFixed(1);

    switch (quality) {
      case DecisionQuality.optimal:
        return _optimalExplanation(action, eqPct, oddsPct, street);
      case DecisionQuality.correct:
        return _correctExplanation(action, eqPct, oddsPct, street);
      case DecisionQuality.marginal:
        return _marginalExplanation(action, eqPct, oddsPct, street);
      case DecisionQuality.blunder:
        return _blunderExplanation(action, eqPct, oddsPct, street);
    }
  }

  String _optimalExplanation(HandAction a, String eq, String odds, String street) {
    switch (a.type) {
      case ActionType.fold:
        return 'Correct fold on $street. Your equity of $eq% was insufficient to continue.';
      case ActionType.check:
        return 'Well-timed check on $street with $eq% equity. Controls pot and traps aggression.';
      case ActionType.bet:
      case ActionType.raise:
        return 'Excellent value bet on $street. Your $eq% equity justifies aggressive extraction.';
      case ActionType.call:
        return 'Profitable call on $street. Equity $eq% clearly exceeds pot odds $odds%.';
      case ActionType.allIn:
        return 'Premium all-in spot on $street with $eq% equity. Maximized EV perfectly.';
    }
  }

  String _correctExplanation(HandAction a, String eq, String odds, String street) {
    switch (a.type) {
      case ActionType.fold:
        return 'Reasonable fold on $street. Equity $eq% was low, though a call had marginal positive EV.';
      case ActionType.call:
        return 'Correct call on $street. Your $eq% equity covers the $odds% pot odds required.';
      case ActionType.check:
        return 'Acceptable check on $street with $eq% equity. Bet-sizing alternatives existed.';
      default:
        return 'Sound decision on $street with $eq% equity. In line with GTO principles.';
    }
  }

  String _marginalExplanation(HandAction a, String eq, String odds, String street) {
    switch (a.type) {
      case ActionType.fold:
        return 'Marginal fold on $street. Equity of $eq% vs pot odds $odds% — a call had slight positive EV. Consider wider continuing range.';
      case ActionType.call:
        return 'Marginal call on $street. Equity $eq% barely justifies the $odds% pot odds. Borderline spot — fold or raise are often better.';
      case ActionType.check:
        return 'Thin check on $street with $eq% equity. A value bet would have been marginally superior here.';
      default:
        return 'Marginal decision on $street. Equity $eq% is borderline for this action. Review sizing.';
    }
  }

  String _blunderExplanation(HandAction a, String eq, String odds, String street) {
    switch (a.type) {
      case ActionType.fold:
        return 'Blunder: Folding with $eq% equity on $street was a serious mistake. Your hand had strong equity vs the opponent range and pot odds were ${odds}% — this fold cost significant expected value.';
      case ActionType.call:
        return 'Blunder: Calling on $street with only $eq% equity vs $odds% pot odds required was unprofitable. Expected value was significantly negative. Fold was the correct play.';
      case ActionType.bet:
      case ActionType.raise:
        return 'Blunder: Aggressive action on $street with only $eq% equity. Your range lacks the strength to profitably bet/raise here. Check-fold was the GTO play.';
      case ActionType.allIn:
        return 'Blunder: All-in on $street with $eq% equity. You were far behind the opponent range. This commit was a major EV loss.';
      default:
        return 'Blunder: Your action on $street with $eq% equity was a significant mistake. Review the hand closely.';
    }
  }
}

class AICoach {
  static String generateReport(SessionStats stats, List<HandLog> hands) {
    if (stats.handsPlayed < 3) {
      return 'Play at least 5 hands to unlock your personalized AI Coach report.';
    }

    final buffer = StringBuffer();
    buffer.writeln('═══ AI COACH REPORT ═══\n');
    buffer.writeln('Session: ${stats.handsPlayed} hands | Net: ${stats.netProfit >= 0 ? "+" : ""}\$${stats.netProfit.toStringAsFixed(2)} | BB/100: ${stats.bbPer100.toStringAsFixed(1)}\n');

    // VPIP Analysis
    buffer.writeln('📊 PREFLOP PROFILE');
    if (stats.vpip > 35) {
      buffer.writeln('⚠️ VPIP ${stats.vpip.toStringAsFixed(1)}% is too high for 6-Max. You\'re playing too many speculative hands, bleeding chips in unfavorable spots. Target: 22–28%.');
    } else if (stats.vpip < 16) {
      buffer.writeln('⚠️ VPIP ${stats.vpip.toStringAsFixed(1)}% is excessively tight. You\'re leaving money on the table and becoming predictable. Widen your range from CO and BTN. Target: 22–28%.');
    } else {
      buffer.writeln('✅ VPIP ${stats.vpip.toStringAsFixed(1)}% is within the optimal 6-Max range (22–28%). Solid preflop discipline.');
    }

    if (stats.pfr < stats.vpip * 0.65) {
      buffer.writeln('⚠️ PFR ${stats.pfr.toStringAsFixed(1)}% is too low relative to VPIP (${stats.vpip.toStringAsFixed(1)}%). You\'re calling too much preflop instead of 3-betting or isolating. Aggression gap: ${(stats.vpip - stats.pfr).toStringAsFixed(1)}%.');
    } else {
      buffer.writeln('✅ PFR/VPIP ratio is healthy. Good aggression balance preflop.');
    }

    buffer.writeln('');
    buffer.writeln('🃏 3-BET FREQUENCY');
    if (stats.threeBetPct < 5) {
      buffer.writeln('⚠️ 3-Bet% of ${stats.threeBetPct.toStringAsFixed(1)}% is too passive. You\'re allowing opponents to steal blinds profitably. Add bluff 3-bets with hands like A5s, KQs from BB/SB. Target: 8–12%.');
    } else if (stats.threeBetPct > 15) {
      buffer.writeln('⚠️ 3-Bet% of ${stats.threeBetPct.toStringAsFixed(1)}% is over-aggressive. You\'re ballooning pots with marginal hands. Tighten 3-bet bluff range. Target: 8–12%.');
    } else {
      buffer.writeln('✅ 3-Bet% ${stats.threeBetPct.toStringAsFixed(1)}% is in the healthy range. Good balance of value and bluff 3-bets.');
    }

    buffer.writeln('');
    buffer.writeln('💰 POSTFLOP TENDENCIES');
    if (stats.cBetPct > 80) {
      buffer.writeln('⚠️ C-Bet% ${stats.cBetPct.toStringAsFixed(1)}% is dangerously high. You\'re over-barrelling on unfavorable textures. Exploit this by check-folding more on wet boards. Target: 55–70%.');
    } else if (stats.cBetPct < 40) {
      buffer.writeln('⚠️ C-Bet% ${stats.cBetPct.toStringAsFixed(1)}% is too low. You\'re giving free cards and losing pot initiative. Increase c-bets on dry boards and when you have blockers. Target: 55–70%.');
    } else {
      buffer.writeln('✅ C-Bet frequency of ${stats.cBetPct.toStringAsFixed(1)}% is well-calibrated.');
    }

    if (stats.riverFoldPct > 55) {
      buffer.writeln('⚠️ River Fold% of ${stats.riverFoldPct.toStringAsFixed(1)}% is too high. You\'re over-folding on the river and being exploited by aggressive bots like Tom Dwan and Phil Ivey who will increase bluff frequency against you. Defend river with at least 40% of your bluff-catching range.');
    }

    buffer.writeln('');
    buffer.writeln('🎯 DECISION QUALITY');
    if (stats.blunders > 0) {
      final blunderRate = stats.handsPlayed > 0 ? stats.blunders / stats.handsPlayed * 100 : 0;
      buffer.writeln('⚠️ ${stats.blunders} blunder${stats.blunders > 1 ? "s" : ""} recorded (${blunderRate.toStringAsFixed(1)}% blunder rate). Each blunder represents a significant EV loss. Review these hands in the Analyze section.');
    } else {
      buffer.writeln('✅ Zero blunders this session. Strong decision-making fundamentals.');
    }
    buffer.writeln('Decision Score: ${stats.decisionScore.toStringAsFixed(0)}/100');

    buffer.writeln('');
    buffer.writeln('📋 ACTION PLAN FOR NEXT SESSION');
    final tasks = _generateTasks(stats);
    for (int i = 0; i < tasks.length; i++) {
      buffer.writeln('${i + 1}. ${tasks[i]}');
    }

    return buffer.toString();
  }

  static List<String> _generateTasks(SessionStats stats) {
    final tasks = <String>[];

    if (stats.vpip > 32) {
      tasks.add('Tighten preflop: Cut top 10% weakest hands from UTG/MP opening ranges.');
    }
    if (stats.vpip < 18) {
      tasks.add('Widen preflop: Add BTN/CO opens with suited connectors (T9s, 87s) and Axs hands.');
    }
    if (stats.threeBetPct < 6) {
      tasks.add('Add light 3-bets: Defend BB vs BTN opens with A5s, KQs as polar 3-bets.');
    }
    if (stats.riverFoldPct > 55) {
      tasks.add('Improve river defense: Call at least one bluff-catcher per session vs over-aggressive bots.');
    }
    if (stats.cBetPct > 78) {
      tasks.add('Reduce c-bet frequency on wet, connected boards (e.g., 9♠8♥7♠). Check-call instead.');
    }
    if (stats.blunders > 2) {
      tasks.add('Review all blunder hands in Analyze — identify the street where you deviated from GTO.');
    }
    if (stats.wtsd > 38) {
      tasks.add('Be more selective going to showdown — fold marginal made hands facing river aggression.');
    }
    if (tasks.isEmpty) {
      tasks.add('Maintain current discipline and focus on bet sizing optimization.');
      tasks.add('Work on mixed strategies — add randomization to your betting patterns to avoid exploitation.');
    }

    return tasks.take(5).toList();
  }
}
