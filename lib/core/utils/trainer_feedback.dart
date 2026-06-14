import '../../data/models/hand_log_model.dart';
import 'equity_calculator.dart';

/// Live grade of a single human decision vs the GTO recommendation, shown by
/// the Trainer mode banner right after the player acts.
class TrainerFeedback {
  final DecisionQuality quality;
  final String chosen; // e.g. "FOLD"
  final String recommended; // e.g. "RAISE $12"
  final double equity;
  final double ev;
  final String note;

  const TrainerFeedback({
    required this.quality,
    required this.chosen,
    required this.recommended,
    required this.equity,
    required this.ev,
    required this.note,
  });
}

class TrainerGrader {
  static String _famOf(ActionType t) {
    switch (t) {
      case ActionType.fold:
        return 'fold';
      case ActionType.check:
        return 'check';
      case ActionType.call:
        return 'call';
      case ActionType.bet:
      case ActionType.raise:
      case ActionType.allIn:
        return 'aggro';
    }
  }

  static String _label(ActionType t, double amount) {
    final base = t.name.toUpperCase();
    return amount > 0 ? '$base \$${amount.toStringAsFixed(0)}' : base;
  }

  /// Grades [chosen]/[amount] against the GTO [rec] captured at decision time.
  static TrainerFeedback grade(
      ActionType chosen, double amount, GTORecommendation rec) {
    var recFam = rec.action.toLowerCase();
    if (recFam == 'bet' || recFam == 'raise') recFam = 'aggro';
    final cf = _famOf(chosen);

    DecisionQuality q;
    String note;
    const passive = {'check', 'call'};

    if (cf == recFam) {
      q = DecisionQuality.optimal;
      note = 'Coincide con la línea GTO. 👏';
    } else if (passive.contains(cf) && passive.contains(recFam)) {
      q = DecisionQuality.correct;
      note = 'Línea pasiva razonable; GTO prefería ${rec.action.toLowerCase()}.';
    } else if (cf == 'fold' && (recFam == 'aggro' || recFam == 'call') && rec.ev > 0.02) {
      q = DecisionQuality.blunder;
      note = 'Foldeaste una situación +EV: GTO jugaba ${rec.action.toLowerCase()}.';
    } else if (cf == 'aggro' && (recFam == 'fold' || recFam == 'check')) {
      q = rec.equity < 0.35 ? DecisionQuality.blunder : DecisionQuality.marginal;
      note = 'Agresión de más; GTO iba a ${rec.action.toLowerCase()} con tu equity.';
    } else if (cf == 'check' && recFam == 'aggro') {
      q = DecisionQuality.marginal;
      note = 'Te dejaste valor/farol: GTO apostaba aquí.';
    } else if (cf == 'call' && recFam == 'fold') {
      q = rec.ev < -0.08 ? DecisionQuality.marginal : DecisionQuality.correct;
      note = 'Pago fino; GTO se inclinaba por foldear.';
    } else {
      q = DecisionQuality.marginal;
      note = 'GTO prefería ${rec.action.toLowerCase()}.';
    }

    return TrainerFeedback(
      quality: q,
      chosen: _label(chosen, amount),
      recommended: _label(_recAction(rec.action), rec.amount),
      equity: rec.equity,
      ev: rec.ev,
      note: note,
    );
  }

  static ActionType _recAction(String a) {
    switch (a.toLowerCase()) {
      case 'fold':
        return ActionType.fold;
      case 'check':
        return ActionType.check;
      case 'call':
        return ActionType.call;
      case 'raise':
        return ActionType.raise;
      case 'bet':
        return ActionType.bet;
      default:
        return ActionType.bet;
    }
  }
}
