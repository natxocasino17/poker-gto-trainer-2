import 'hand_log_model.dart';

class SessionStats {
  final int handsPlayed;
  final double netProfit;
  final double vpip;
  final double pfr;
  final double threeBetPct;
  final double cBetPct;
  final double foldToCBetPct;
  final double wtsd;
  final double wsd;
  final double riverFoldPct;
  final double avgPotWon;
  final double bbPer100;
  final int blunders;
  final int optimalDecisions;
  final double decisionScore;
  final String sessionId;
  final DateTime startTime;

  const SessionStats({
    required this.handsPlayed,
    required this.netProfit,
    required this.vpip,
    required this.pfr,
    required this.threeBetPct,
    required this.cBetPct,
    required this.foldToCBetPct,
    required this.wtsd,
    required this.wsd,
    required this.riverFoldPct,
    required this.avgPotWon,
    required this.bbPer100,
    required this.blunders,
    required this.optimalDecisions,
    required this.decisionScore,
    required this.sessionId,
    required this.startTime,
  });

  static SessionStats fromHandLogs(List<HandLog> logs, String sessionId, DateTime start) {
    if (logs.isEmpty) {
      return SessionStats(
        handsPlayed: 0,
        netProfit: 0,
        vpip: 0,
        pfr: 0,
        threeBetPct: 0,
        cBetPct: 0,
        foldToCBetPct: 0,
        wtsd: 0,
        wsd: 0,
        riverFoldPct: 0,
        avgPotWon: 0,
        bbPer100: 0,
        blunders: 0,
        optimalDecisions: 0,
        decisionScore: 0,
        sessionId: sessionId,
        startTime: start,
      );
    }

    final total = logs.length;
    double totalProfit = 0;
    int vpipCount = 0;
    int pfrCount = 0;
    int threeBetCount = 0;
    int cBetOpps = 0;
    int cBetMade = 0;
    int foldToCBetOpps = 0;
    int foldToCBetDone = 0;
    int wentToShowdown = 0;
    int wonAtShowdown = 0;
    int riverFoldOpps = 0;
    int riverFolds = 0;
    double totalPotsWon = 0;
    int potsWonCount = 0;
    int blunderCount = 0;
    int optimalCount = 0;
    int totalDecisions = 0;

    const bb = 2.0;

    for (final log in logs) {
      totalProfit += log.humanProfit;
      final humanId = 'human';

      final preflopActions = log.actions.where((a) => a.street == 'preflop' && a.playerId == humanId).toList();
      bool didVpip = preflopActions.any((a) =>
          a.type == ActionType.call || a.type == ActionType.bet ||
          a.type == ActionType.raise || a.type == ActionType.allIn);
      bool didPfr = preflopActions.any((a) =>
          a.type == ActionType.bet || a.type == ActionType.raise || a.type == ActionType.allIn);

      if (didVpip) vpipCount++;
      if (didPfr) pfrCount++;

      final threeBetActions = log.actions.where((a) =>
          a.street == 'preflop' && a.playerId == humanId && a.type == ActionType.raise).toList();
      if (threeBetActions.length >= 2) threeBetCount++;

      bool wasAggressor = didPfr;
      if (wasAggressor && log.communityCards.isNotEmpty) {
        cBetOpps++;
        final flopActions = log.actions.where((a) => a.street == 'flop' && a.playerId == humanId).toList();
        if (flopActions.any((a) => a.type == ActionType.bet || a.type == ActionType.raise)) {
          cBetMade++;
        }
      }

      final riverActions = log.actions.where((a) => a.street == 'river' && a.playerId == humanId).toList();
      if (riverActions.isNotEmpty) {
        riverFoldOpps++;
        if (riverActions.any((a) => a.type == ActionType.fold)) {
          riverFolds++;
        }
      }

      final humanFolded = log.actions.any((a) => a.playerId == humanId && a.type == ActionType.fold);
      if (!humanFolded) {
        wentToShowdown++;
        if (log.winnerId == humanId) {
          wonAtShowdown++;
          totalPotsWon += log.finalPot;
          potsWonCount++;
        }
      }

      for (final sa in log.streetAnalyses) {
        totalDecisions++;
        if (sa.quality == DecisionQuality.blunder) blunderCount++;
        if (sa.quality == DecisionQuality.optimal) optimalCount++;
      }
    }

    final decScore = totalDecisions > 0
        ? ((optimalCount * 1.0 + (totalDecisions - blunderCount) * 0.5) / totalDecisions * 100).clamp(0, 100)
        : 50.0;

    return SessionStats(
      handsPlayed: total,
      netProfit: totalProfit,
      vpip: total > 0 ? vpipCount / total * 100 : 0,
      pfr: total > 0 ? pfrCount / total * 100 : 0,
      threeBetPct: pfrCount > 0 ? threeBetCount / pfrCount * 100 : 0,
      cBetPct: cBetOpps > 0 ? cBetMade / cBetOpps * 100 : 0,
      foldToCBetPct: foldToCBetOpps > 0 ? foldToCBetDone / foldToCBetOpps * 100 : 0,
      wtsd: total > 0 ? wentToShowdown / total * 100 : 0,
      wsd: wentToShowdown > 0 ? wonAtShowdown / wentToShowdown * 100 : 0,
      riverFoldPct: riverFoldOpps > 0 ? riverFolds / riverFoldOpps * 100 : 0,
      avgPotWon: potsWonCount > 0 ? totalPotsWon / potsWonCount : 0,
      bbPer100: total > 0 ? (totalProfit / bb) / total * 100 : 0,
      blunders: blunderCount,
      optimalDecisions: optimalCount,
      decisionScore: decScore.toDouble(),
      sessionId: sessionId,
      startTime: start,
    );
  }

  Map<String, dynamic> toJson() => {
    'hp': handsPlayed, 'np': netProfit, 'vpip': vpip, 'pfr': pfr,
    '3b': threeBetPct, 'cb': cBetPct, 'ftcb': foldToCBetPct,
    'wtsd': wtsd, 'wsd': wsd, 'rfp': riverFoldPct, 'apw': avgPotWon,
    'bb100': bbPer100, 'bl': blunders, 'od': optimalDecisions,
    'ds': decisionScore, 'sid': sessionId, 'st': startTime.millisecondsSinceEpoch,
  };

  factory SessionStats.fromJson(Map<String, dynamic> j) => SessionStats(
    handsPlayed: j['hp'] as int,
    netProfit: (j['np'] as num).toDouble(),
    vpip: (j['vpip'] as num).toDouble(),
    pfr: (j['pfr'] as num).toDouble(),
    threeBetPct: (j['3b'] as num).toDouble(),
    cBetPct: (j['cb'] as num).toDouble(),
    foldToCBetPct: (j['ftcb'] as num).toDouble(),
    wtsd: (j['wtsd'] as num).toDouble(),
    wsd: (j['wsd'] as num).toDouble(),
    riverFoldPct: (j['rfp'] as num).toDouble(),
    avgPotWon: (j['apw'] as num).toDouble(),
    bbPer100: (j['bb100'] as num).toDouble(),
    blunders: j['bl'] as int,
    optimalDecisions: j['od'] as int,
    decisionScore: (j['ds'] as num).toDouble(),
    sessionId: j['sid'] as String,
    startTime: DateTime.fromMillisecondsSinceEpoch(j['st'] as int),
  );
}
