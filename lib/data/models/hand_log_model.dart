import 'dart:convert';
import 'card_model.dart';
import '../../core/i18n/i18n.dart';

enum ActionType { fold, check, call, bet, raise, allIn }

enum DecisionQuality { optimal, correct, marginal, blunder }

class HandAction {
  final String playerId;
  final String playerName;
  final ActionType type;
  final double amount;
  final String street;
  final int sequence;

  const HandAction({
    required this.playerId,
    required this.playerName,
    required this.type,
    required this.amount,
    required this.street,
    required this.sequence,
  });

  String get label {
    switch (type) {
      case ActionType.fold: return 'Fold';
      case ActionType.check: return 'Check';
      case ActionType.call: return 'Call \$${amount.toStringAsFixed(0)}';
      case ActionType.bet: return 'Bet \$${amount.toStringAsFixed(0)}';
      case ActionType.raise: return 'Raise \$${amount.toStringAsFixed(0)}';
      case ActionType.allIn: return 'All-In \$${amount.toStringAsFixed(0)}';
    }
  }

  Map<String, dynamic> toJson() => {
    'pid': playerId,
    'pn': playerName,
    'type': type.index,
    'amt': amount,
    'st': street,
    'seq': sequence,
  };

  factory HandAction.fromJson(Map<String, dynamic> j) => HandAction(
    playerId: j['pid'] as String,
    playerName: j['pn'] as String,
    type: ActionType.values[j['type'] as int],
    amount: (j['amt'] as num).toDouble(),
    street: j['st'] as String,
    sequence: j['seq'] as int,
  );
}

class StreetAnalysis {
  final String street;
  final double heroEquity;
  final double potOdds;
  final String heroAction;
  final double heroAmount;
  final DecisionQuality quality;
  /// Pre-rendered fallback text (used by old logs that predate i18n keys).
  final String explanation;
  /// i18n key of the coach phrase + the raw params needed to re-localize it
  /// in whatever language the user has selected RIGHT NOW. This is what fixes
  /// the "feedback always in Spanish" bug: nothing language-specific is
  /// frozen at record time.
  final String explanationKey;
  final Map<String, String> explanationParams;

  const StreetAnalysis({
    required this.street,
    required this.heroEquity,
    required this.potOdds,
    required this.heroAction,
    required this.heroAmount,
    required this.quality,
    required this.explanation,
    this.explanationKey = '',
    this.explanationParams = const {},
  });

  /// Rebuilds the coach explanation in the CURRENT locale from stored raw
  /// params. Falls back to the frozen text for legacy logs.
  String get localizedExplanation {
    if (explanationKey.isEmpty) return explanation;
    final p = explanationParams;
    final tex = (p['texKey'] ?? '').isEmpty ? '' : I18n.t(p['texKey']!);
    final mdf = (p['mdf'] ?? '').isEmpty ? '' : I18n.t('ctx_mdf', {'p': p['mdf']!});
    final spr = (p['spr'] ?? '').isEmpty ? '' : I18n.t('ctx_spr', {'v': p['spr']!});
    final draw = (p['outs'] ?? '').isEmpty
        ? ''
        : I18n.t('ctx_draw', {'outs': p['outs']!, 'p': p['drawp'] ?? '0'});
    final block = (p['block'] == '1') ? I18n.t('ctx_blockers') : '';
    return I18n.t(explanationKey, {
      'street': p['street'] ?? '',
      'pos': p['pos'] ?? '',
      'eq': p['eq'] ?? '',
      'odds': p['odds'] ?? '',
      'tex': tex,
      'mdf': mdf,
      'spr': spr,
      'draw': draw,
      'block': block,
    });
  }

  Map<String, dynamic> toJson() => {
    'street': street,
    'equity': heroEquity,
    'potOdds': potOdds,
    'action': heroAction,
    'amount': heroAmount,
    'quality': quality.index,
    'explanation': explanation,
    'ekey': explanationKey,
    'eparams': explanationParams,
  };

  factory StreetAnalysis.fromJson(Map<String, dynamic> j) => StreetAnalysis(
    street: j['street'] as String,
    heroEquity: (j['equity'] as num).toDouble(),
    potOdds: (j['potOdds'] as num).toDouble(),
    heroAction: j['action'] as String,
    heroAmount: (j['amount'] as num).toDouble(),
    quality: DecisionQuality.values[j['quality'] as int],
    explanation: j['explanation'] as String? ?? '',
    explanationKey: j['ekey'] as String? ?? '',
    explanationParams: (j['eparams'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const {},
  );

  String get qualityLabel {
    switch (quality) {
      case DecisionQuality.optimal: return I18n.t('q_optimal');
      case DecisionQuality.correct: return I18n.t('q_correct');
      case DecisionQuality.marginal: return I18n.t('q_marginal');
      case DecisionQuality.blunder: return I18n.t('q_blunder');
    }
  }
}

class HandLog {
  final String id;
  final DateTime timestamp;
  final int handNumber;
  final List<CardModel> humanHoleCards;
  final List<CardModel> communityCards;
  final Map<String, List<CardModel>> allHoleCards;
  final List<HandAction> actions;
  final double finalPot;
  final String winnerId;
  final String winnerName;
  final double humanProfit;
  final String humanHandDescription;
  final List<StreetAnalysis> streetAnalyses;
  final List<String> botNames;
  final double humanStartStack;

  const HandLog({
    required this.id,
    required this.timestamp,
    required this.handNumber,
    required this.humanHoleCards,
    required this.communityCards,
    required this.allHoleCards,
    required this.actions,
    required this.finalPot,
    required this.winnerId,
    required this.winnerName,
    required this.humanProfit,
    required this.humanHandDescription,
    required this.streetAnalyses,
    required this.botNames,
    required this.humanStartStack,
  });

  bool get humanWon => humanProfit > 0;

  bool get humanFolded =>
      actions.any((a) => a.playerId == 'human' && a.type == ActionType.fold);

  /// A disciplined fold without blunders is NOT a lost hand — it is
  /// money saved. These hands are displayed as neutral, not as losses.
  bool get isCleanFold =>
      humanFolded &&
      !streetAnalyses.any((sa) => sa.quality == DecisionQuality.blunder);

  String get resultLabel => humanProfit >= 0
      ? '+\$${humanProfit.toStringAsFixed(2)}'
      : '-\$${(-humanProfit).toStringAsFixed(2)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'ts': timestamp.millisecondsSinceEpoch,
    'hn': handNumber,
    'hh': humanHoleCards.map((c) => c.toJson()).toList(),
    'cc': communityCards.map((c) => c.toJson()).toList(),
    'ah': allHoleCards.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
    'actions': actions.map((a) => a.toJson()).toList(),
    'pot': finalPot,
    'wid': winnerId,
    'wn': winnerName,
    'hp': humanProfit,
    'hd': humanHandDescription,
    'sa': streetAnalyses.map((s) => s.toJson()).toList(),
    'bots': botNames,
    'hss': humanStartStack,
  };

  factory HandLog.fromJson(Map<String, dynamic> j) => HandLog(
    id: j['id'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
    handNumber: j['hn'] as int,
    humanHoleCards: (j['hh'] as List).map((c) => CardModel.fromJson(c as Map<String, dynamic>)).toList(),
    communityCards: (j['cc'] as List).map((c) => CardModel.fromJson(c as Map<String, dynamic>)).toList(),
    allHoleCards: (j['ah'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as List).map((c) => CardModel.fromJson(c as Map<String, dynamic>)).toList()),
    ),
    actions: (j['actions'] as List).map((a) => HandAction.fromJson(a as Map<String, dynamic>)).toList(),
    finalPot: (j['pot'] as num).toDouble(),
    winnerId: j['wid'] as String,
    winnerName: j['wn'] as String,
    humanProfit: (j['hp'] as num).toDouble(),
    humanHandDescription: j['hd'] as String,
    streetAnalyses: (j['sa'] as List).map((s) => StreetAnalysis.fromJson(s as Map<String, dynamic>)).toList(),
    botNames: List<String>.from(j['bots'] as List),
    humanStartStack: (j['hss'] as num).toDouble(),
  );

  static String encodeList(List<HandLog> logs) =>
      jsonEncode(logs.map((l) => l.toJson()).toList());

  static List<HandLog> decodeList(String json) {
    final list = jsonDecode(json) as List;
    return list.map((j) => HandLog.fromJson(j as Map<String, dynamic>)).toList();
  }
}
