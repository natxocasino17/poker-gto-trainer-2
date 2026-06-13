import '../models/player_model.dart';
import 'blind_vs_blind.dart';
import 'hand_classes.dart';
import 'multiway_spots.dart';
import 'open_raise.dart';
import 'spot_record.dart';
import 'squeeze_spots.dart';
import 'vs_3bet.dart';
import 'vs_4bet.dart';
import 'vs_open.dart';

/// Unified GTO preflop database facade.
///
/// Priority lookup order (mirrors the solver decision hierarchy):
///   1. RFI (no prior action)          → OpenRaiseDB
///   2. Facing an open (1 raiser)      → VsOpenDB
///   3. Facing a 3-bet (was the opener) → Vs3BetDB
///   4. Facing a 4-bet (was the 3-bettor) → Vs4BetDB
///   5. Blind vs Blind                 → BvBDB
///   6. Squeeze spot (open + caller)   → SqueezeDB
///   7. Multiway (2+ callers)          → MultiwayDB
///
/// Usage:
///   final s = GTODatabase.preflop(
///     hero: TablePosition.btn,
///     hand: 'AKs',
///     context: PreflopContext(action: PreflopAction.facingOpen,
///                            opener: TablePosition.co),
///   );
///   print(s.primary.action); // 'call' / '3bet' / 'fold' / ...
enum PreflopAction {
  /// No prior action — hero is first to act or all folded to hero.
  rfi,

  /// An open raise is facing hero; no caller yet.
  facingOpen,

  /// Hero opened, villain 3-bet, hero now acts.
  facing3bet,

  /// Hero 3-bet, villain 4-bet, hero now acts.
  facing4bet,

  /// Blind vs blind: SB open or BB defense.
  blindVsBlind,

  /// Open + at least one caller before hero.
  squeeze,

  /// Two or more players already in the pot.
  multiway,
}

/// Contextual parameters for a preflop decision.
class PreflopContext {
  final PreflopAction action;

  /// The original opener's seat (required for facingOpen, facing3bet, squeeze, multiway).
  final TablePosition? opener;

  /// Primary villain seat (3-bettor for facing3bet, 4-bettor for facing4bet,
  /// first caller for squeeze/multiway).
  final TablePosition? villain;

  /// Additional callers for squeeze / multiway.
  final List<TablePosition> extraCallers;

  const PreflopContext({
    required this.action,
    this.opener,
    this.villain,
    this.extraCallers = const [],
  });
}

class GTODatabase {
  GTODatabase._();

  // ─── Primary lookup ────────────────────────────────────────────────────────

  /// Returns the GTO [HandStrategy] for [hero] holding [hand] in the given context.
  static HandStrategy preflop(
      TablePosition hero, String hand, PreflopContext ctx) {
    switch (ctx.action) {
      case PreflopAction.rfi:
        return OpenRaiseDB.strategy(hero, hand);

      case PreflopAction.facingOpen:
        assert(ctx.opener != null, 'opener required for facingOpen');
        return VsOpenDB.strategy(hero, ctx.opener!, hand);

      case PreflopAction.facing3bet:
        assert(ctx.opener != null && ctx.villain != null,
            'opener+villain required for facing3bet');
        return Vs3BetDB.strategy(hero, ctx.villain!, hand);

      case PreflopAction.facing4bet:
        return Vs4BetDB.strategy(hero, hand);

      case PreflopAction.blindVsBlind:
        if (hero == TablePosition.sb) return BvBDB.sbStrategy(hand);
        return BvBDB.bbVsSbStrategy(hand);

      case PreflopAction.squeeze:
        assert(ctx.opener != null && ctx.villain != null,
            'opener+caller required for squeeze');
        return SqueezeDB.strategy(hero, ctx.opener!, ctx.villain!, hand);

      case PreflopAction.multiway:
        assert(ctx.opener != null,
            'opener required for multiway');
        final callers = ctx.villain != null
            ? [ctx.villain!, ...ctx.extraCallers]
            : ctx.extraCallers;
        return MultiwayDB.strategy(hero, ctx.opener!, callers, hand);
    }
  }

  // ─── Convenience lookup: best single action ────────────────────────────────

  /// Returns the primary recommended action label ('open', 'call', '3bet', 'fold', …).
  static String recommendedAction(
      TablePosition hero, String hand, PreflopContext ctx) {
    return preflop(hero, hand, ctx).primary.action;
  }

  /// Returns the EV of the primary action (in BB).
  static double recommendedEv(
      TablePosition hero, String hand, PreflopContext ctx) {
    return preflop(hero, hand, ctx).primary.ev;
  }

  // ─── Full-range queries ────────────────────────────────────────────────────

  /// Full 169-hand range for RFI.
  static List<HandStrategy> rfiRange(TablePosition hero) =>
      OpenRaiseDB.fullRange(hero);

  /// Full 169-hand range for facing an open.
  static List<HandStrategy> vsOpenRange(
          TablePosition hero, TablePosition opener) =>
      VsOpenDB.fullRange(hero, opener);

  /// Full 169-hand range for facing a 3-bet.
  static List<HandStrategy> vs3BetRange(
          TablePosition opener, TablePosition threeBettor) =>
      Vs3BetDB.fullRange(opener, threeBettor);

  /// Full 169-hand range for facing a 4-bet.
  static List<HandStrategy> vs4BetRange(TablePosition hero) =>
      Vs4BetDB.fullRange(hero);

  /// Full 169-hand ranges for blind-vs-blind.
  static List<HandStrategy> bvbSbRange() => BvBDB.sbFullRange();
  static List<HandStrategy> bvbBbRange() => BvBDB.bbFullRange();

  /// Full 169-hand range for squeeze spots.
  static List<HandStrategy> squeezeRange(
          TablePosition hero, TablePosition opener, TablePosition caller) =>
      SqueezeDB.fullRange(hero, opener, caller);

  /// Full 169-hand range for multiway spots.
  static List<HandStrategy> multiwayRange(
          TablePosition hero, TablePosition opener, List<TablePosition> callers) =>
      MultiwayDB.fullRange(hero, opener, callers);

  // ─── Context-aware auto-detect ─────────────────────────────────────────────

  /// Infers the [PreflopContext] from game state primitives.
  ///
  /// [numRaisers] — how many players have raised before hero.
  /// [numCallers] — how many players have called before hero (no raise).
  /// [opener]     — seat of the original raiser (if any).
  /// [lastAggressor] — seat of the most recent raiser (may differ from opener).
  static PreflopContext inferContext({
    required TablePosition hero,
    required int numRaisers,
    required int numCallers,
    TablePosition? opener,
    TablePosition? lastAggressor,
  }) {
    if (numRaisers == 0 && numCallers == 0) {
      // Check BvB: only SB or BB remain
      if (hero == TablePosition.bb || hero == TablePosition.sb) {
        return const PreflopContext(action: PreflopAction.blindVsBlind);
      }
      return const PreflopContext(action: PreflopAction.rfi);
    }

    if (numRaisers == 1 && numCallers == 0) {
      // Simple facing-open
      return PreflopContext(action: PreflopAction.facingOpen, opener: opener);
    }

    if (numRaisers == 2 && numCallers == 0) {
      // Hero was the opener facing a 3-bet
      return PreflopContext(
        action: PreflopAction.facing3bet,
        opener: opener,
        villain: lastAggressor,
      );
    }

    if (numRaisers == 3 && numCallers == 0) {
      // Hero 3-bet, now facing a 4-bet
      return PreflopContext(action: PreflopAction.facing4bet);
    }

    if (numRaisers == 1 && numCallers >= 1) {
      // Open + caller(s) → squeeze or multiway
      if (numCallers == 1) {
        return PreflopContext(
          action: PreflopAction.squeeze,
          opener: opener,
          villain: lastAggressor, // first caller
        );
      }
      return PreflopContext(
        action: PreflopAction.multiway,
        opener: opener,
      );
    }

    // Fallback: treat as RFI if nothing clearer
    return const PreflopContext(action: PreflopAction.rfi);
  }

  // ─── Hand info helpers ─────────────────────────────────────────────────────

  static double handScore(String hand) => HandClasses.score(hand);
  static String handDescription(String hand) => HandClasses.describe(hand);
  static int handCombos(String hand) => HandClasses.combos(hand);
  static List<String> get allHands => HandClasses.all;

  // ─── Spot category helpers ─────────────────────────────────────────────────

  static bool isPremium(HandStrategy s) =>
      s.actions.any((a) => a.category == SpotCategory.premium && a.frequency > 0.5);

  static bool isBluff(HandStrategy s) =>
      s.actions.any((a) =>
          (a.category == SpotCategory.bluffBlockers ||
           a.category == SpotCategory.squeezeBluff) &&
          a.frequency > 0.2);

  static bool isMarginal(HandStrategy s) =>
      s.actions.any((a) => a.category == SpotCategory.marginalMix);

  // ─── JSON export ───────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> exportAll() {
    final out = <Map<String, dynamic>>[];

    // RFI
    for (final p in [
      TablePosition.utg, TablePosition.mp, TablePosition.co,
      TablePosition.btn, TablePosition.sb,
    ]) {
      for (final s in rfiRange(p)) {
        out.addAll(s.actions.map((a) => a.toJson()));
      }
    }

    // Vs open
    for (final m in VsOpenDB.matchups) {
      for (final s in vsOpenRange(m[0], m[1])) {
        out.addAll(s.actions.map((a) => a.toJson()));
      }
    }

    // Vs 3-bet
    for (final sc in Vs3BetDB.scenarios) {
      for (final s in vs3BetRange(sc[0], sc[1])) {
        out.addAll(s.actions.map((a) => a.toJson()));
      }
    }

    // Vs 4-bet
    for (final p in [
      TablePosition.utg, TablePosition.mp, TablePosition.co,
      TablePosition.btn, TablePosition.sb, TablePosition.bb,
    ]) {
      for (final s in vs4BetRange(p)) {
        out.addAll(s.actions.map((a) => a.toJson()));
      }
    }

    // BvB
    for (final s in bvbSbRange()) {
      out.addAll(s.actions.map((a) => a.toJson()));
    }
    for (final s in bvbBbRange()) {
      out.addAll(s.actions.map((a) => a.toJson()));
    }

    // Squeeze
    for (final line in SqueezeDB.lines) {
      for (final s in squeezeRange(line['hero']!, line['opener']!, line['caller']!)) {
        out.addAll(s.actions.map((a) => a.toJson()));
      }
    }

    // Multiway — a representative sample
    for (final s in multiwayRange(TablePosition.bb, TablePosition.utg,
        [TablePosition.mp, TablePosition.co])) {
      out.addAll(s.actions.map((a) => a.toJson()));
    }

    return out;
  }
}
