/// Canonical GTO spot record — matches the JSON schema:
/// {spot_id, hero_position, villain_position, stack_depth, hand, action,
///  frequency, ev, category, explanation}
class SpotRecord {
  final String spotId;
  final String heroPosition;
  final String villainPosition;
  final int stackDepth;
  final String hand;
  final String action;     // 'open' | 'fold' | 'call' | '3bet' | '4bet' | '5bet_jam' ...
  final double frequency;  // 0.0–1.0 equilibrium frequency
  final double ev;         // in BB from hero's perspective
  final String category;   // strategic category tag
  final String explanation;

  const SpotRecord({
    required this.spotId,
    required this.heroPosition,
    this.villainPosition = '',
    this.stackDepth = 100,
    required this.hand,
    required this.action,
    required this.frequency,
    required this.ev,
    required this.category,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
        'spot_id': spotId,
        'hero_position': heroPosition,
        'villain_position': villainPosition,
        'stack_depth': stackDepth,
        'hand': hand,
        'action': action,
        'frequency': frequency,
        'ev': ev,
        'category': category,
        'explanation': explanation,
      };
}

/// A full mixed strategy for one hand in one spot: the set of actions with
/// their equilibrium frequencies (summing to 1.0) and EVs.
class HandStrategy {
  final String spotId;
  final String hand;
  final List<SpotRecord> actions;

  const HandStrategy({
    required this.spotId,
    required this.hand,
    required this.actions,
  });

  /// The action played most often in equilibrium.
  SpotRecord get primary =>
      actions.reduce((a, b) => a.frequency >= b.frequency ? a : b);

  /// The highest-EV action (what a pure best response would pick).
  SpotRecord get bestEv => actions.reduce((a, b) => a.ev >= b.ev ? a : b);

  /// Frequency of a specific action label (0 if not present).
  double freqOf(String action) {
    for (final a in actions) {
      if (a.action == action) return a.frequency;
    }
    return 0.0;
  }

  /// EV of a specific action label (null if not present in the strategy).
  double? evOf(String action) {
    for (final a in actions) {
      if (a.action == action) return a.ev;
    }
    return null;
  }
}

/// Strategic categories used across the database.
class SpotCategory {
  static const premium = 'premium_value';
  static const value = 'value';
  static const thinValue = 'thin_value';
  static const semiBluff = 'semi_bluff';
  static const bluffBlockers = 'bluff_blockers';
  static const speculative = 'speculative';
  static const setMining = 'set_mining';
  static const marginalMix = 'marginal_mix';
  static const potControl = 'pot_control';
  static const trapSlowplay = 'trap_slowplay';
  static const defenseMdf = 'defense_mdf';
  static const trashFold = 'trash_fold';
  static const squeezeValue = 'squeeze_value';
  static const squeezeBluff = 'squeeze_bluff';
}
