import 'dart:math';
import '../../data/models/player_model.dart';

/// Pot category from the number of preflop raises — defines range widths,
/// nut advantage and commitment thresholds postflop.
enum PotType { srp, threeBet, fourBetPlus }

/// Coarse read on the villain(s) driving value/bluff adjustments. Built from
/// live tendencies (HumanReadModel) or from a known opponent's playing style.
class VillainRead {
  /// 0..1 — how often the villain folds to a bet.
  final double foldToBet;
  final bool callingStation; // calls too much → value thin, bluff less
  final bool overFolds; // folds too much → bluff relentlessly

  const VillainRead({
    this.foldToBet = 0.5,
    this.callingStation = false,
    this.overFolds = false,
  });

  static const VillainRead neutral = VillainRead();

  bool get isNeutral =>
      !callingStation && !overFolds && (foldToBet - 0.5).abs() < 0.08;

  String get label {
    if (callingStation) return 'calling station (paga de más)';
    if (overFolds) return 'over-folder (suelta de más)';
    return 'equilibrado';
  }
}

/// All the postflop factors that matter beyond raw equity/texture/blockers.
/// Shared by the live advisor, the hand analyzer AND the legend bots so every
/// engine "reads" the spot the same way.
class PostflopContext {
  final TablePosition? position;

  /// Hero acts last vs the remaining villains on this street.
  final bool inPosition;

  /// Hero is the last aggressor (took the betting lead pre/postflop).
  final bool hasInitiative;

  /// Players still live in the hand (hero included).
  final int numActive;

  final PotType potType;

  /// Amount hero is facing this decision (0 if unopposed).
  final double villainBet;
  final double potSize;

  final VillainRead read;

  const PostflopContext({
    this.position,
    this.inPosition = false,
    this.hasInitiative = false,
    this.numActive = 2,
    this.potType = PotType.srp,
    this.villainBet = 0,
    this.potSize = 0,
    this.read = VillainRead.neutral,
  });

  bool get isMultiway => numActive >= 3;
  double get betFraction => potSize > 0 ? villainBet / potSize : 0;

  // ──────────────────────────────────────────────────────────────────────
  // Shared reading heuristics — the single source of truth for how much
  // each factor shifts a decision. Used by EquityCalculator.recommend (the
  // advisor + analyzer) and by the legend bots, so they never disagree.
  // ──────────────────────────────────────────────────────────────────────

  /// Equity realization multiplier: the fraction of raw equity you actually
  /// realize. Position and initiative raise it; being OOP and multiway lower
  /// it (you get bluffed/outdrawn off equity, can't see free cards).
  static double equityRealization({
    required bool inPosition,
    required bool hasInitiative,
    required int numActive,
  }) {
    double r = 1.0;
    r *= inPosition ? 1.12 : 0.88;
    if (hasInitiative) r *= 1.05;
    if (numActive >= 3) r *= 0.90;
    if (numActive >= 4) r *= 0.93;
    return r.clamp(0.70, 1.25).toDouble();
  }

  /// Multiway crushes bluffs: every extra player is another fold you need.
  static double multiwayBluffMultiplier(int numActive) {
    if (numActive <= 2) return 1.0;
    if (numActive == 3) return 0.55;
    return 0.30;
  }

  /// Value bets/stack-offs need a stronger hand multiway (someone connects).
  static double multiwayValueShift(int numActive) {
    if (numActive <= 2) return 0.0;
    if (numActive == 3) return 0.06;
    return 0.10;
  }

  static PotType potTypeFromRaiseCount(int raiseCount) {
    if (raiseCount >= 3) return PotType.fourBetPlus;
    if (raiseCount == 2) return PotType.threeBet;
    return PotType.srp;
  }

  static String potTypeLabel(PotType t) {
    switch (t) {
      case PotType.srp:
        return 'bote simple (SRP)';
      case PotType.threeBet:
        return 'bote 3-bet';
      case PotType.fourBetPlus:
        return 'bote 4-bet+';
    }
  }

  /// Combined bluff-frequency multiplier from multiway + villain read.
  double get bluffMultiplier {
    double m = multiwayBluffMultiplier(numActive);
    if (read.overFolds) m *= 1.4;
    if (read.callingStation) m *= 0.5;
    return m;
  }

  /// Pure (no-equity) bluffs are only sane when this gate is open.
  bool get canPureBluff => bluffMultiplier >= 0.5;

  /// Extra EV you should demand to call, given multiway + a non-neutral read
  /// (more players / value-heavy stations mean your bluff-catchers are worse).
  double get callEvPenalty {
    double p = numActive >= 3 ? 0.04 : 0.0;
    if (read.callingStation) p += 0.03; // they value bet → need more to call
    if (read.overFolds) p += 0.02; // they rarely bluff → fold more
    return p;
  }
}
