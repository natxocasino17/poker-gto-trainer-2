/// Configurable bet sizes for an abstracted Texas Hold'em CFR solve.
///
/// All preflop raise sizes are TOTAL street commitments in big blinds.
/// All postflop bet sizes are fractions of the current pot (0–1).
/// Raise multipliers apply to the FACING bet (e.g., 2.5× a 5BB bet = 12.5BB).
class BetSizingConfig {
  /// Preflop open/re-raise total commitments, in BB (e.g., 2.5 = open to 2.5BB).
  final List<double> preflopRaiseSizesBB;

  /// Postflop bet sizes as fractions of pot (e.g., 0.5 = half-pot).
  final List<double> postflopBetFractions;

  /// Re-raise multipliers applied to the facing bet (e.g., 2.5 = raise to 2.5×).
  final List<double> raiseSizeMultipliers;

  /// Whether to always include an all-in option at every decision node.
  final bool includeAllIn;

  /// Maximum number of raises per street (caps the tree depth).
  final int maxRaisesPerStreet;

  const BetSizingConfig({
    this.preflopRaiseSizesBB = const [2.5, 3.0],
    this.postflopBetFractions = const [0.33, 0.5, 0.75, 1.0],
    this.raiseSizeMultipliers = const [2.5, 3.0],
    this.includeAllIn = true,
    this.maxRaisesPerStreet = 3,
  });

  /// Standard GTO-oriented config for 100BB cash games.
  static const BetSizingConfig standard = BetSizingConfig();

  /// Simplified config for very fast mobile solves (fewer branches → smaller tree).
  static const BetSizingConfig fast = BetSizingConfig(
    preflopRaiseSizesBB: [2.5],
    postflopBetFractions: [0.5, 1.0],
    raiseSizeMultipliers: [2.5],
    maxRaisesPerStreet: 2,
  );

  /// Deeper config for high-accuracy solves (more branches, slower convergence).
  static const BetSizingConfig deep = BetSizingConfig(
    preflopRaiseSizesBB: [2.0, 2.5, 3.0, 4.0],
    postflopBetFractions: [0.25, 0.33, 0.5, 0.67, 0.75, 1.0, 1.5],
    raiseSizeMultipliers: [2.0, 2.5, 3.0, 4.0],
    maxRaisesPerStreet: 4,
  );
}
