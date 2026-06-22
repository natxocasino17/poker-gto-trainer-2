import 'dart:math';

/// Street in a heads-up cash game.
enum HuStreet { preflop, flop, turn, river }

/// Immutable state for the abstracted heads-up cash-game CFR tree.
///
/// Conventions:
///   * P0 = BTN/SB (acts FIRST preflop, LAST postflop — IP postflop)
///   * P1 = BB     (acts LAST preflop, FIRST postflop — OOP postflop)
///   * [pot] = total chips committed by both players so far (this includes
///     all street bets; [p0StreetBet] and [p1StreetBet] are included in pot).
///   * Blinds already posted at construction: pot=1.5BB, P0StreetBet=0.5,
///     P1StreetBet=1.0.
///   * Buckets are -1 when the corresponding chance node has not yet fired.
class HuState {
  // ─── Card abstraction ────────────────────────────────────────────────────
  /// Preflop bucket 0-6 (or -1 = not yet dealt / chance pending).
  final int p0PreflopBucket;
  final int p1PreflopBucket;

  /// Postflop hand-strength bucket 0-4 (or -1 = preflop or not yet updated).
  final int p0PostBucket;
  final int p1PostBucket;

  /// Board type bucket 0-3 (or -1 = preflop).
  final int boardBucket;

  // ─── Street ──────────────────────────────────────────────────────────────
  final HuStreet street;

  // ─── Money (all in BB, always non-negative) ───────────────────────────────
  /// Total pot including all bets this street.
  final double pot;

  /// Remaining stacks.
  final double p0Stack;
  final double p1Stack;

  /// Each player's street contributions (subset of [pot]).
  final double p0StreetBet;
  final double p1StreetBet;

  // ─── Action tracking ─────────────────────────────────────────────────────
  /// Index of the player to act next (0 or 1).
  final int toAct;

  /// Number of players still needing to act before the round closes.
  /// 0 = round complete; move to terminal or next street.
  final int actorsLeft;

  /// Raise count this street (used to cap at [BetSizingConfig.maxRaisesPerStreet]).
  final int raisesThisStreet;

  // ─── Terminal flag ────────────────────────────────────────────────────────
  final bool p0Folded;
  final bool p1Folded;

  // ─── Identifiers for the info-set key ─────────────────────────────────────
  /// Compact action history this street (e.g. "xb1c", "fr0c").
  /// Used as part of the information-set key.
  final String history;

  const HuState({
    this.p0PreflopBucket = -1,
    this.p1PreflopBucket = -1,
    this.p0PostBucket = -1,
    this.p1PostBucket = -1,
    this.boardBucket = -1,
    this.street = HuStreet.preflop,
    required this.pot,
    required this.p0Stack,
    required this.p1Stack,
    required this.p0StreetBet,
    required this.p1StreetBet,
    this.toAct = 0,
    this.actorsLeft = 2,
    this.raisesThisStreet = 0,
    this.p0Folded = false,
    this.p1Folded = false,
    this.history = '',
  });

  /// Standard 100BB HU start: P0=BTN/SB, P1=BB. Waiting for initial card deal.
  factory HuState.initial100BB() {
    return const HuState(
      pot: 1.5,
      p0Stack: 99.5,  // 100 - 0.5 SB
      p1Stack: 99.0,  // 100 - 1.0 BB
      p0StreetBet: 0.5,
      p1StreetBet: 1.0,
      toAct: 0, // BTN acts first preflop
      actorsLeft: 2,
    );
  }

  /// Convenience factory for a postflop spot (cards already dealt).
  factory HuState.postflop({
    required int p0Pre,
    required int p1Pre,
    required int p0Post,
    required int p1Post,
    required int board,
    required HuStreet street,
    required double pot,
    required double p0Stack,
    required double p1Stack,
    int toAct = 1, // OOP (P1) acts first postflop
  }) {
    return HuState(
      p0PreflopBucket: p0Pre,
      p1PreflopBucket: p1Pre,
      p0PostBucket: p0Post,
      p1PostBucket: p1Post,
      boardBucket: board,
      street: street,
      pot: pot,
      p0Stack: p0Stack,
      p1Stack: p1Stack,
      p0StreetBet: 0,
      p1StreetBet: 0,
      toAct: toAct,
      actorsLeft: 2,
    );
  }

  // ─── Derived helpers ──────────────────────────────────────────────────────

  double get myStack   => toAct == 0 ? p0Stack : p1Stack;
  double get oppStack  => toAct == 0 ? p1Stack : p0Stack;

  double get myStreetBet  => toAct == 0 ? p0StreetBet : p1StreetBet;
  double get oppStreetBet => toAct == 0 ? p1StreetBet : p0StreetBet;

  /// Amount needed to call the facing bet (capped by remaining stack).
  double get facingBet => max(0, oppStreetBet - myStreetBet);

  /// Total pot including all current bets.
  double get totalPot => pot;

  bool get isDealt     => p0PreflopBucket >= 0;
  bool get hasBoard    => p0PostBucket >= 0;

  // ─── copyWith ─────────────────────────────────────────────────────────────
  HuState copyWith({
    int? p0PreflopBucket,
    int? p1PreflopBucket,
    int? p0PostBucket,
    int? p1PostBucket,
    int? boardBucket,
    HuStreet? street,
    double? pot,
    double? p0Stack,
    double? p1Stack,
    double? p0StreetBet,
    double? p1StreetBet,
    int? toAct,
    int? actorsLeft,
    int? raisesThisStreet,
    bool? p0Folded,
    bool? p1Folded,
    String? history,
  }) {
    return HuState(
      p0PreflopBucket:  p0PreflopBucket  ?? this.p0PreflopBucket,
      p1PreflopBucket:  p1PreflopBucket  ?? this.p1PreflopBucket,
      p0PostBucket:     p0PostBucket     ?? this.p0PostBucket,
      p1PostBucket:     p1PostBucket     ?? this.p1PostBucket,
      boardBucket:      boardBucket      ?? this.boardBucket,
      street:           street           ?? this.street,
      pot:              pot              ?? this.pot,
      p0Stack:          p0Stack          ?? this.p0Stack,
      p1Stack:          p1Stack          ?? this.p1Stack,
      p0StreetBet:      p0StreetBet      ?? this.p0StreetBet,
      p1StreetBet:      p1StreetBet      ?? this.p1StreetBet,
      toAct:            toAct            ?? this.toAct,
      actorsLeft:       actorsLeft       ?? this.actorsLeft,
      raisesThisStreet: raisesThisStreet ?? this.raisesThisStreet,
      p0Folded:         p0Folded         ?? this.p0Folded,
      p1Folded:         p1Folded         ?? this.p1Folded,
      history:          history          ?? this.history,
    );
  }
}
