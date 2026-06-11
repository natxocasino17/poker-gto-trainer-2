import 'dart:math';
import '../data/models/card_model.dart';
import '../data/models/player_model.dart';
import '../data/models/hand_log_model.dart';
import '../core/utils/equity_calculator.dart';
import '../core/utils/poker_concepts.dart';

class BotDecision {
  final ActionType type;
  final double amount;
  final int thinkMs;

  const BotDecision({required this.type, required this.amount, required this.thinkMs});
}

class LegendProfile {
  final String name;
  final String style;
  final String emoji;

  // Preflop opening thresholds (hand strength 0-1; higher = tighter)
  final double utgOpen;
  final double mpOpen;
  final double coOpen;
  final double btnOpen;
  final double sbOpen;
  final double bbDefend;

  // 3-bet / 4-bet value thresholds
  final double threeBetThreshold;
  final double fourBetThreshold;

  // Postflop frequencies
  final double cBetFreq;
  final double doubleBarrelFreq;
  final double tripleBarrelFreq;
  final double checkRaiseFreq;
  final double bluffFreq;
  final double slowplayFreq;

  // Bet sizing (fraction of pot)
  final List<double> preferredSizings;
  final double riverOverbetThreshold;

  // Advanced concept dials
  final double openSizeBB;          // preflop open size in big blinds
  final double threeBetBluffFreq;   // light 3-bets with blockers (A5s style)
  final double squeezeFreq;         // 3-bet vs open + callers
  final double floatFreq;           // float/stab when checked to without initiative
  final double blockerBetFreq;      // small river blocker bets with medium hands
  final double impliedOddsWeight;   // multiplier on draw equity for calls
  final double bluffRaiseFreq;      // raising as a pure bluff (0 = raises are pure value)

  // Personality traits
  final bool exploitsHighFolders;
  final bool polarizedBetting;
  final bool highVarianceDraws;
  final bool potControl;
  final bool stackPressure;

  const LegendProfile({
    required this.name,
    required this.style,
    required this.emoji,
    required this.utgOpen,
    required this.mpOpen,
    required this.coOpen,
    required this.btnOpen,
    required this.sbOpen,
    required this.bbDefend,
    required this.threeBetThreshold,
    required this.fourBetThreshold,
    required this.cBetFreq,
    required this.doubleBarrelFreq,
    required this.tripleBarrelFreq,
    required this.checkRaiseFreq,
    required this.bluffFreq,
    required this.slowplayFreq,
    required this.preferredSizings,
    required this.riverOverbetThreshold,
    this.openSizeBB = 2.3,
    this.threeBetBluffFreq = 0.10,
    this.squeezeFreq = 0.12,
    this.floatFreq = 0.18,
    this.blockerBetFreq = 0.12,
    this.impliedOddsWeight = 1.0,
    this.bluffRaiseFreq = 0.12,
    this.exploitsHighFolders = false,
    this.polarizedBetting = false,
    this.highVarianceDraws = false,
    this.potControl = false,
    this.stackPressure = false,
  });
}

class LegendaryBotEngine {
  static final Random _rng = Random();

  static const List<LegendProfile> _allLegends = [
    // 1. Phil Ivey — Loose-Aggressive Exploiter: reads weakness instantly,
    // barrels turn/river up to 80% vs over-folders.
    LegendProfile(
      name: 'Phil Ivey',
      style: 'Loose-Aggressive Exploiter',
      emoji: '🦅',
      utgOpen: 0.64, mpOpen: 0.57, coOpen: 0.49, btnOpen: 0.40, sbOpen: 0.52, bbDefend: 0.38,
      threeBetThreshold: 0.72, fourBetThreshold: 0.88,
      cBetFreq: 0.72, doubleBarrelFreq: 0.58, tripleBarrelFreq: 0.42, checkRaiseFreq: 0.28,
      bluffFreq: 0.38, slowplayFreq: 0.20,
      preferredSizings: [0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.75,
      bluffRaiseFreq: 0.22, floatFreq: 0.30,
      exploitsHighFolders: true,
    ),
    // 2. Adrián Mateos — GTO Hyper-Aggressive: high 3-bet frequency,
    // polarized 150%+ river overbets with optimal blockers.
    LegendProfile(
      name: 'Adrián Mateos',
      style: 'GTO Hyper-Aggressive',
      emoji: '⚡',
      utgOpen: 0.68, mpOpen: 0.60, coOpen: 0.52, btnOpen: 0.42, sbOpen: 0.54, bbDefend: 0.40,
      threeBetThreshold: 0.66, fourBetThreshold: 0.84,
      cBetFreq: 0.78, doubleBarrelFreq: 0.62, tripleBarrelFreq: 0.46, checkRaiseFreq: 0.30,
      bluffFreq: 0.32, slowplayFreq: 0.10,
      preferredSizings: [0.5, 0.75, 1.0, 1.5],
      riverOverbetThreshold: 0.70,
      threeBetBluffFreq: 0.18, squeezeFreq: 0.16,
      polarizedBetting: true,
    ),
    // 3. Daniel Negreanu — Small Ball Trapper: 2x opens, high check-call
    // to induce bluffs, slowplays monsters.
    LegendProfile(
      name: 'Daniel Negreanu',
      style: 'Small Ball Trapper',
      emoji: '🎯',
      utgOpen: 0.60, mpOpen: 0.53, coOpen: 0.44, btnOpen: 0.34, sbOpen: 0.46, bbDefend: 0.32,
      threeBetThreshold: 0.76, fourBetThreshold: 0.90,
      cBetFreq: 0.55, doubleBarrelFreq: 0.40, tripleBarrelFreq: 0.28, checkRaiseFreq: 0.22,
      bluffFreq: 0.18, slowplayFreq: 0.45,
      preferredSizings: [0.25, 0.33, 0.5],
      riverOverbetThreshold: 0.90,
      openSizeBB: 2.0, floatFreq: 0.28, blockerBetFreq: 0.20,
    ),
    // 4. Phil Hellmuth — Tight-Passive White Magic: ultra-tight ranges,
    // his raises on later streets are PURE value (zero bluff raises).
    LegendProfile(
      name: 'Phil Hellmuth',
      style: 'Tight-Passive Premium',
      emoji: '👑',
      utgOpen: 0.74, mpOpen: 0.69, coOpen: 0.62, btnOpen: 0.53, sbOpen: 0.65, bbDefend: 0.50,
      threeBetThreshold: 0.82, fourBetThreshold: 0.92,
      cBetFreq: 0.60, doubleBarrelFreq: 0.42, tripleBarrelFreq: 0.25, checkRaiseFreq: 0.15,
      bluffFreq: 0.08, slowplayFreq: 0.12,
      preferredSizings: [0.5, 0.75],
      riverOverbetThreshold: 0.95,
      bluffRaiseFreq: 0.0, threeBetBluffFreq: 0.02, floatFreq: 0.06,
    ),
    // 5. Tom Dwan — Ultra-Loose Aggressive: triple barrels with total air,
    // unpredictable sizings designed to crack tight ranges.
    LegendProfile(
      name: 'Tom Dwan',
      style: 'Ultra-Loose Aggressive',
      emoji: '🌪️',
      utgOpen: 0.52, mpOpen: 0.44, coOpen: 0.34, btnOpen: 0.24, sbOpen: 0.36, bbDefend: 0.22,
      threeBetThreshold: 0.60, fourBetThreshold: 0.76,
      cBetFreq: 0.85, doubleBarrelFreq: 0.72, tripleBarrelFreq: 0.58, checkRaiseFreq: 0.40,
      bluffFreq: 0.55, slowplayFreq: 0.15,
      preferredSizings: [0.75, 1.0, 1.5, 2.5],
      riverOverbetThreshold: 0.60,
      openSizeBB: 2.8, threeBetBluffFreq: 0.22, bluffRaiseFreq: 0.28,
      polarizedBetting: true,
    ),
    // 6. Doyle Brunson — Old School Aggressive: heavy implied-odds weighting
    // on draws, ramps pressure when villain hesitates.
    LegendProfile(
      name: 'Doyle Brunson',
      style: 'Old School Aggressive',
      emoji: '🤠',
      utgOpen: 0.58, mpOpen: 0.50, coOpen: 0.41, btnOpen: 0.31, sbOpen: 0.43, bbDefend: 0.28,
      threeBetThreshold: 0.70, fourBetThreshold: 0.86,
      cBetFreq: 0.70, doubleBarrelFreq: 0.56, tripleBarrelFreq: 0.40, checkRaiseFreq: 0.25,
      bluffFreq: 0.30, slowplayFreq: 0.22,
      preferredSizings: [0.5, 0.75, 1.0, 1.25],
      riverOverbetThreshold: 0.80,
      openSizeBB: 2.5, impliedOddsWeight: 1.5,
    ),
    // 7. Fedor Holz — GTO Strict: perfectly balanced solver trees,
    // standardized sizings.
    LegendProfile(
      name: 'Fedor Holz',
      style: 'GTO Strict',
      emoji: '🤖',
      utgOpen: 0.66, mpOpen: 0.60, coOpen: 0.52, btnOpen: 0.43, sbOpen: 0.55, bbDefend: 0.40,
      threeBetThreshold: 0.70, fourBetThreshold: 0.86,
      cBetFreq: 0.68, doubleBarrelFreq: 0.55, tripleBarrelFreq: 0.40, checkRaiseFreq: 0.30,
      bluffFreq: 0.28, slowplayFreq: 0.18,
      preferredSizings: [0.33, 0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.80,
    ),
    // 8. Chris Moneymaker — Explosive Variance: wide preflop, jams
    // combo draws on the flop to force variance.
    LegendProfile(
      name: 'Chris Moneymaker',
      style: 'Explosive High Variance',
      emoji: '💣',
      utgOpen: 0.56, mpOpen: 0.48, coOpen: 0.38, btnOpen: 0.28, sbOpen: 0.40, bbDefend: 0.25,
      threeBetThreshold: 0.66, fourBetThreshold: 0.80,
      cBetFreq: 0.76, doubleBarrelFreq: 0.60, tripleBarrelFreq: 0.44, checkRaiseFreq: 0.22,
      bluffFreq: 0.40, slowplayFreq: 0.10,
      preferredSizings: [0.75, 1.0, 1.5],
      riverOverbetThreshold: 0.65,
      threeBetBluffFreq: 0.12,
      highVarianceDraws: true,
    ),
    // 9. Justin Bonomo — Computational Frequencies: strict equity-vs-range
    // balancing.
    LegendProfile(
      name: 'Justin Bonomo',
      style: 'Computational GTO',
      emoji: '📊',
      utgOpen: 0.67, mpOpen: 0.61, coOpen: 0.53, btnOpen: 0.44, sbOpen: 0.56, bbDefend: 0.41,
      threeBetThreshold: 0.69, fourBetThreshold: 0.85,
      cBetFreq: 0.70, doubleBarrelFreq: 0.57, tripleBarrelFreq: 0.42, checkRaiseFreq: 0.31,
      bluffFreq: 0.30, slowplayFreq: 0.16,
      preferredSizings: [0.33, 0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.78,
    ),
    // 10. Stephen Chidwick — Blind Defense Elite: wide blind defense and
    // relentless technical check-raises.
    LegendProfile(
      name: 'Stephen Chidwick',
      style: 'Blind Defense Elite',
      emoji: '🛡️',
      utgOpen: 0.65, mpOpen: 0.58, coOpen: 0.50, btnOpen: 0.40, sbOpen: 0.50, bbDefend: 0.30,
      threeBetThreshold: 0.68, fourBetThreshold: 0.84,
      cBetFreq: 0.66, doubleBarrelFreq: 0.53, tripleBarrelFreq: 0.38, checkRaiseFreq: 0.42,
      bluffFreq: 0.28, slowplayFreq: 0.14,
      preferredSizings: [0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.82,
      squeezeFreq: 0.18,
    ),
    // 11. Gus Hansen — Classic LAG: opens marginal hands from any seat,
    // grinds solid ranges down with extreme postflop aggression.
    LegendProfile(
      name: 'Gus Hansen',
      style: 'Classic Loose-Aggressive',
      emoji: '🔥',
      utgOpen: 0.49, mpOpen: 0.40, coOpen: 0.30, btnOpen: 0.20, sbOpen: 0.32, bbDefend: 0.18,
      threeBetThreshold: 0.62, fourBetThreshold: 0.78,
      cBetFreq: 0.82, doubleBarrelFreq: 0.68, tripleBarrelFreq: 0.52, checkRaiseFreq: 0.35,
      bluffFreq: 0.50, slowplayFreq: 0.12,
      preferredSizings: [0.75, 1.0, 1.25, 1.5],
      riverOverbetThreshold: 0.68,
      openSizeBB: 2.6, threeBetBluffFreq: 0.20, bluffRaiseFreq: 0.20,
      exploitsHighFolders: true,
    ),
    // 12. Antonio Esfandiari — Pot Control Specialist: keeps pots small with
    // medium hands, extracts surgical thin value on rivers.
    LegendProfile(
      name: 'Antonio Esfandiari',
      style: 'Pot Control Specialist',
      emoji: '🎪',
      utgOpen: 0.62, mpOpen: 0.55, coOpen: 0.46, btnOpen: 0.36, sbOpen: 0.48, bbDefend: 0.33,
      threeBetThreshold: 0.74, fourBetThreshold: 0.88,
      cBetFreq: 0.58, doubleBarrelFreq: 0.42, tripleBarrelFreq: 0.25, checkRaiseFreq: 0.20,
      bluffFreq: 0.22, slowplayFreq: 0.35,
      preferredSizings: [0.25, 0.33, 0.5],
      riverOverbetThreshold: 0.92,
      openSizeBB: 2.2, blockerBetFreq: 0.35,
      potControl: true,
    ),
    // 13. Michael Addamo — Overbet Terror: 2-3x pot bombs from the flop
    // forcing stack-commitment decisions.
    LegendProfile(
      name: 'Michael Addamo',
      style: 'Overbet Terror',
      emoji: '💥',
      utgOpen: 0.63, mpOpen: 0.56, coOpen: 0.47, btnOpen: 0.37, sbOpen: 0.49, bbDefend: 0.35,
      threeBetThreshold: 0.67, fourBetThreshold: 0.82,
      cBetFreq: 0.74, doubleBarrelFreq: 0.62, tripleBarrelFreq: 0.48, checkRaiseFreq: 0.36,
      bluffFreq: 0.36, slowplayFreq: 0.12,
      preferredSizings: [1.0, 1.5, 2.0, 3.0],
      riverOverbetThreshold: 0.60,
      openSizeBB: 3.0, bluffRaiseFreq: 0.18,
      polarizedBetting: true,
    ),
    // 14. Linus Loeliger — High Roller Cash GTO: mathematically perfect
    // preflop, immune to tilt, zero psychological exploitation.
    LegendProfile(
      name: 'Linus Loeliger',
      style: 'High Roller Cash GTO',
      emoji: '💎',
      utgOpen: 0.68, mpOpen: 0.62, coOpen: 0.54, btnOpen: 0.45, sbOpen: 0.57, bbDefend: 0.42,
      threeBetThreshold: 0.71, fourBetThreshold: 0.87,
      cBetFreq: 0.69, doubleBarrelFreq: 0.56, tripleBarrelFreq: 0.42, checkRaiseFreq: 0.30,
      bluffFreq: 0.27, slowplayFreq: 0.17,
      preferredSizings: [0.33, 0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.80,
      threeBetBluffFreq: 0.14,
    ),
    // 15. Bryn Kenney — Stack Pressure: sizes bets to punish survival
    // ranges, maximizing chip leverage.
    LegendProfile(
      name: 'Bryn Kenney',
      style: 'Stack Pressure Expert',
      emoji: '⚖️',
      utgOpen: 0.61, mpOpen: 0.54, coOpen: 0.45, btnOpen: 0.35, sbOpen: 0.47, bbDefend: 0.32,
      threeBetThreshold: 0.69, fourBetThreshold: 0.84,
      cBetFreq: 0.73, doubleBarrelFreq: 0.60, tripleBarrelFreq: 0.46, checkRaiseFreq: 0.26,
      bluffFreq: 0.32, slowplayFreq: 0.18,
      preferredSizings: [0.75, 1.0, 1.25],
      riverOverbetThreshold: 0.72,
      openSizeBB: 2.5,
      stackPressure: true,
    ),
    // 16. Raúl Mestre — Spanish GTO pioneer: theory-perfect balanced
    // frequencies, disciplined 3-bets, surgical postflop play.
    LegendProfile(
      name: 'Raúl Mestre',
      style: 'Teórico GTO Español',
      emoji: '🧠',
      utgOpen: 0.66, mpOpen: 0.59, coOpen: 0.51, btnOpen: 0.42, sbOpen: 0.53, bbDefend: 0.38,
      threeBetThreshold: 0.69, fourBetThreshold: 0.86,
      cBetFreq: 0.70, doubleBarrelFreq: 0.56, tripleBarrelFreq: 0.41, checkRaiseFreq: 0.32,
      bluffFreq: 0.29, slowplayFreq: 0.16,
      preferredSizings: [0.33, 0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.78,
      threeBetBluffFreq: 0.15, squeezeFreq: 0.15,
    ),
    // 17. Papo "Lococo" — Argentine freestyle: fearless creative aggression,
    // unpredictable lines and sizings, loves the big bluff.
    LegendProfile(
      name: 'Papo Lococo',
      style: 'Freestyle Agresivo',
      emoji: '🎤',
      utgOpen: 0.54, mpOpen: 0.46, coOpen: 0.36, btnOpen: 0.26, sbOpen: 0.38, bbDefend: 0.24,
      threeBetThreshold: 0.63, fourBetThreshold: 0.80,
      cBetFreq: 0.80, doubleBarrelFreq: 0.66, tripleBarrelFreq: 0.50, checkRaiseFreq: 0.34,
      bluffFreq: 0.48, slowplayFreq: 0.14,
      preferredSizings: [0.5, 1.0, 1.5, 2.2],
      riverOverbetThreshold: 0.64,
      openSizeBB: 2.7, threeBetBluffFreq: 0.19, bluffRaiseFreq: 0.24,
      polarizedBetting: true, highVarianceDraws: true,
    ),
  ];

  static List<LegendProfile> selectTable() {
    final pool = List<LegendProfile>.from(_allLegends)..shuffle(_rng);
    return pool.take(5).toList();
  }

  static LegendProfile profileByName(String name) =>
      _allLegends.firstWhere((p) => p.name == name, orElse: () => _allLegends[0]);

  /// When a bot busts it leaves the table; a fresh legend (not currently
  /// seated) takes the empty seat with a new stack.
  static LegendProfile replacementFor(List<String> seatedNames) {
    final available =
        _allLegends.where((p) => !seatedNames.contains(p.name)).toList();
    if (available.isEmpty) return _allLegends[_rng.nextInt(_allLegends.length)];
    return available[_rng.nextInt(available.length)];
  }

  // ──────────────────────────────────────────────────────────────────────
  // DECISION ENTRY POINT
  // ──────────────────────────────────────────────────────────────────────

  static Future<BotDecision> decide({
    required LegendProfile profile,
    required List<CardModel> holeCards,
    required List<CardModel> communityCards,
    required TablePosition position,
    required double callAmount,
    required double currentBet,
    required double myStreetBet,
    required double currentPot,
    required double botStack,
    required HumanReadModel humanModel,
    required bool isPreflop,
    required bool wasAggressor,
    required int activePlayers,
    required String street,
    required int raiseCount,
    required int callersThisStreet,
    required double bigBlind,
  }) async {
    // "Thinking time": 1-3s, harder spots take longer
    final difficulty = callAmount > currentPot * 0.6 ? 600 : 0;
    final thinkMs = 900 + _rng.nextInt(1400) + difficulty;

    BotDecision decision;
    if (isPreflop) {
      decision = _preflopDecision(
        profile: profile,
        hole: holeCards,
        position: position,
        callAmount: callAmount,
        currentBet: currentBet,
        myStreetBet: myStreetBet,
        pot: currentPot,
        stack: botStack,
        raiseCount: raiseCount,
        callers: callersThisStreet,
        bb: bigBlind,
      );
    } else {
      final equity = EquityCalculator.calculate(
        heroCards: holeCards,
        communityCards: communityCards,
        numOpponents: max(1, activePlayers - 1),
        simulations: 250,
      );
      decision = _postflopDecision(
        profile: profile,
        hole: holeCards,
        board: communityCards,
        equity: equity,
        callAmount: callAmount,
        currentBet: currentBet,
        myStreetBet: myStreetBet,
        pot: currentPot,
        stack: botStack,
        human: humanModel,
        wasAggressor: wasAggressor,
        street: street,
        bb: bigBlind,
      );
    }

    await Future.delayed(Duration(milliseconds: min(thinkMs, 2900)));
    return BotDecision(type: decision.type, amount: decision.amount, thinkMs: thinkMs);
  }

  // ──────────────────────────────────────────────────────────────────────
  // PREFLOP: RFI ranges, 3-bet/squeeze, blockers, set-mining implied odds
  // ──────────────────────────────────────────────────────────────────────

  static BotDecision _preflopDecision({
    required LegendProfile profile,
    required List<CardModel> hole,
    required TablePosition position,
    required double callAmount,
    required double currentBet,
    required double myStreetBet,
    required double pot,
    required double stack,
    required int raiseCount,
    required int callers,
    required double bb,
  }) {
    final strength = CardModel.preflopStrength(hole);
    final suited = hole[0].suit == hole[1].suit;
    final hasAce = hole.any((c) => c.rank == 14);
    final isPocketPair = hole[0].rank == hole[1].rank;
    final gap = (hole[0].rank - hole[1].rank).abs();
    final posThreshold = _openThreshold(profile, position);
    final rand = _rng.nextDouble();

    double clampTo(double v) => v.clamp(bb, stack).toDouble();

    // ---- Unopened pot (or limps only) ----
    if (raiseCount == 0) {
      if (callAmount <= 0) {
        // BB option: iso-raise strong hands at mixed frequency
        if (strength >= posThreshold + 0.18 && rand < 0.55) {
          final isoTo = clampTo(profile.openSizeBB * bb + callers * bb);
          return BotDecision(type: ActionType.raise, amount: isoTo, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
      }

      // RFI: open if inside the positional range (mixed at the boundary)
      final openBoundary = strength - posThreshold;
      if (openBoundary >= 0.04 || (openBoundary >= -0.02 && rand < 0.5)) {
        final openTo = clampTo(profile.openSizeBB * bb + callers * bb);
        return BotDecision(type: ActionType.raise, amount: openTo, thinkMs: 0);
      }
      // SB completes with playable hands sometimes
      if (position == TablePosition.sb &&
          strength >= posThreshold - 0.14 && rand < 0.45) {
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }
      return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
    }

    final potOdds = GtoMath.potOdds(callAmount, pot);
    final inPosition = position == TablePosition.btn || position == TablePosition.co;

    // ---- Facing a single open ----
    if (raiseCount == 1) {
      // Value 3-bet / squeeze
      final isSqueezeSpot = callers > 0;
      if (strength >= profile.threeBetThreshold) {
        final mult = (inPosition ? 3.0 : 3.8) + callers * 1.0;
        final to = clampTo(currentBet * mult);
        if (isSqueezeSpot && strength < profile.fourBetThreshold &&
            _rng.nextDouble() > profile.squeezeFreq + 0.55) {
          // Occasionally flat the squeeze spot to disguise
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
      }

      // Light 3-bet with blockers (A5s-type: ace blocker + suited playability)
      if (hasAce && suited && strength >= posThreshold - 0.05 &&
          rand < profile.threeBetBluffFreq) {
        final to = clampTo(currentBet * (inPosition ? 3.0 : 4.0));
        return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
      }

      // Set mining: small pocket pairs need ~12x implied odds
      if (isPocketPair && hole[0].rank <= 9) {
        final impliedRatio = stack / max(callAmount, bb);
        if (impliedRatio >= 12 / profile.impliedOddsWeight) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
      }

      // Suited connectors flat in position (implied odds hands)
      if (suited && gap <= 1 && min(hole[0].rank, hole[1].rank) >= 5 &&
          inPosition && callAmount <= stack * 0.06) {
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }

      // Standard flat: playable strength + price
      if (strength >= profile.threeBetThreshold - 0.14 && strength >= potOdds + 0.15) {
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }
      // BB closes cheap: defend wide per MDF
      if (position == TablePosition.bb && callAmount <= 2.5 * bb &&
          strength >= profile.bbDefend - 0.06) {
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }
      return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
    }

    // ---- Facing a 3-bet or bigger ----
    if (strength >= profile.fourBetThreshold) {
      final to = clampTo(currentBet * 2.3);
      // If the 4-bet commits us, just jam
      if (to >= stack * 0.40 || raiseCount >= 3) {
        return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
      }
      return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
    }
    // 4-bet bluff with ace blocker (only vs first 3-bet)
    if (raiseCount == 2 && hasAce && suited &&
        rand < profile.threeBetBluffFreq * 0.4) {
      final to = clampTo(currentBet * 2.3);
      return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
    }
    // Call the 3-bet with strong-but-not-premium
    if (strength >= profile.threeBetThreshold && callAmount <= stack * 0.25) {
      return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
    }
    // Priced in vs tiny raises
    if (strength >= potOdds + 0.25 && callAmount <= 3 * bb) {
      return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
    }
    return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
  }

  // ──────────────────────────────────────────────────────────────────────
  // POSTFLOP: texture, range advantage, SPR, MDF, alpha, blockers,
  // semi-bluffs, check-raises, overbets, blocker bets, exploits
  // ──────────────────────────────────────────────────────────────────────

  static BotDecision _postflopDecision({
    required LegendProfile profile,
    required List<CardModel> hole,
    required List<CardModel> board,
    required double equity,
    required double callAmount,
    required double currentBet,
    required double myStreetBet,
    required double pot,
    required double stack,
    required HumanReadModel human,
    required bool wasAggressor,
    required String street,
    required double bb,
  }) {
    final texture = BoardTexture.analyze(board);
    final analysis = HandStrengthAnalysis.analyze(hole, board);
    final blockers = Blockers.analyze(hole, board);
    final spr = GtoMath.spr(stack, pot);
    final rand = _rng.nextDouble();
    final isRiver = street == 'river';
    final isTurnOrRiver = street == 'turn' || isRiver;

    // Villain fold estimate (exploit input for all bluff math)
    double foldEst = isTurnOrRiver ? human.foldVsBarrelRate : human.foldVsBetRate;
    if (human.isCallingStation) foldEst *= 0.55;

    double clampBet(double v) => v.clamp(bb, stack).toDouble();

    // ════════════ NO BET TO FACE: bet or check ════════════
    if (callAmount <= 0) {
      // SPR commitment: short SPR + made value → get it in
      if (spr < 1.3 && analysis.isMadeValue) {
        return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
      }

      switch (analysis.bucket) {
        case HandBucket.nuts:
          // Trap on dry boards at slowplay frequency (Negreanu/Hellmuth high)
          if (texture.wetness < 0.35 && rand < profile.slowplayFreq) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          return BotDecision(
            type: ActionType.bet,
            amount: clampBet(_valueSize(profile, pot, texture, street, nut: true)),
            thinkMs: 0,
          );

        case HandBucket.strongValue:
          if (texture.wetness < 0.30 && rand < profile.slowplayFreq * 0.5) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          return BotDecision(
            type: ActionType.bet,
            amount: clampBet(_valueSize(profile, pot, texture, street, nut: false)),
            thinkMs: 0,
          );

        case HandBucket.mediumValue:
          // Pot control (Esfandiari): keep it small, milk rivers
          if (isRiver) {
            if (rand < profile.blockerBetFreq + 0.25) {
              return BotDecision(
                type: ActionType.bet,
                amount: clampBet(pot * (profile.potControl ? 0.30 : 0.40)),
                thinkMs: 0,
              );
            }
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          // Thin value / protection bet on dry boards
          if (texture.wetness < 0.5 && rand < 0.55) {
            return BotDecision(
              type: ActionType.bet,
              amount: clampBet(pot * 0.33),
              thinkMs: 0,
            );
          }
          return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);

        case HandBucket.comboDraw:
          // Moneymaker: jam combo draws and force variance
          if (profile.highVarianceDraws && spr < 5 && !isRiver && rand < 0.55) {
            return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
          }
          if (!isRiver && rand < 0.80) {
            return BotDecision(
              type: ActionType.bet,
              amount: clampBet(pot * 0.75),
              thinkMs: 0,
            );
          }
          return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);

        case HandBucket.strongDraw:
          if (!isRiver) {
            final semiFreq = wasAggressor
                ? _streetCBetFreq(profile, street)
                : 0.50;
            if (rand < semiFreq) {
              return BotDecision(
                type: ActionType.bet,
                amount: clampBet(pot * 0.66),
                thinkMs: 0,
              );
            }
          }
          return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);

        case HandBucket.weakDraw:
          if (!isRiver && wasAggressor && texture.wetness < 0.45 &&
              rand < _streetCBetFreq(profile, street) * 0.8) {
            return BotDecision(
              type: ActionType.bet,
              amount: clampBet(pot * 0.33),
              thinkMs: 0,
            );
          }
          // Delayed stab without initiative
          if (!isRiver && !wasAggressor && rand < profile.floatFreq * 0.7) {
            return BotDecision(
              type: ActionType.bet,
              amount: clampBet(pot * 0.5),
              thinkMs: 0,
            );
          }
          return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);

        case HandBucket.weakShowdown:
          // River blocker bet: set our own price with medium showdown value
          if (isRiver && rand < profile.blockerBetFreq) {
            return BotDecision(
              type: ActionType.bet,
              amount: clampBet(pot * 0.25),
              thinkMs: 0,
            );
          }
          return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);

        case HandBucket.air:
          return _airBetOrCheck(
            profile: profile,
            texture: texture,
            blockers: blockers,
            pot: pot,
            stack: stack,
            foldEst: foldEst,
            human: human,
            wasAggressor: wasAggressor,
            street: street,
            bb: bb,
          );
      }
    }

    // ════════════ FACING A BET ════════════
    final potOdds = GtoMath.potOdds(callAmount, pot);
    final betFraction = callAmount / max(pot - callAmount, 1.0);
    final isOverbet = betFraction > 1.0;
    final isSmallBet = betFraction <= 0.45;
    final facingAllInPrice = callAmount >= stack;

    double raiseTo() =>
        (currentBet * 2.8).clamp(currentBet + 2 * bb, stack).toDouble();

    switch (analysis.bucket) {
      case HandBucket.nuts:
        // Slowplay-call on dry boards to keep their bluffs in
        if (!isRiver && texture.wetness < 0.35 && rand < profile.slowplayFreq) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        final to = raiseTo();
        if (to >= stack * 0.85) {
          return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
        }
        return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);

      case HandBucket.strongValue:
        final raiseFreq = 0.40 + (wasAggressor ? 0.0 : profile.checkRaiseFreq * 0.6);
        if (rand < raiseFreq && !facingAllInPrice) {
          final to = raiseTo();
          if (to >= stack * 0.85) {
            return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
          }
          return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
        }
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);

      case HandBucket.mediumValue:
        // Bluff-catcher math: MDF defense vs small bets, tighten vs overbets
        double callThreshold = potOdds;
        if (isSmallBet) callThreshold -= 0.05;           // defend wide per MDF
        if (isOverbet) {
          callThreshold += blockers.topCardBlocker ? 0.02 : 0.06;
        }
        if (human.aggressionFactor > 2.0) callThreshold -= 0.03; // they bluff a lot
        if (equity >= callThreshold) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);

      case HandBucket.comboDraw:
        if (profile.highVarianceDraws && !isRiver && rand < 0.50) {
          return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
        }
        if (!isRiver && rand < profile.checkRaiseFreq + 0.25 && foldEst > 0.35) {
          final to = raiseTo();
          if (to >= stack * 0.85) {
            return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
          }
          return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
        }
        if (equity >= potOdds - 0.04) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);

      case HandBucket.strongDraw:
        if (isRiver) {
          return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
        }
        // Implied-odds weighted draw equity (Brunson: 1.5x)
        final effectiveEq = analysis.drawEquity * profile.impliedOddsWeight;
        // Semi-bluff check-raise with fold equity (Chidwick technical raises)
        if (rand < profile.checkRaiseFreq * 0.8 && foldEst > 0.40) {
          final to = raiseTo();
          return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
        }
        if (effectiveEq >= potOdds || equity >= potOdds) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);

      case HandBucket.weakDraw:
        if (isRiver) {
          return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
        }
        // Float small bets planning to take the pot away later
        if (street == 'flop' && isSmallBet && rand < profile.floatFreq) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        if (isSmallBet &&
            analysis.drawEquity * profile.impliedOddsWeight >= potOdds) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);

      case HandBucket.weakShowdown:
        if (isSmallBet && equity >= potOdds) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        if (human.aggressionFactor > 2.5 && equity >= potOdds - 0.02 && !isOverbet) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);

      case HandBucket.air:
        // Pure bluff-raise: needs blockers + fold equity.
        // Hellmuth never does this (bluffRaiseFreq = 0); Ivey ramps to ~80%
        // on turn/river vs over-folders.
        double bluffRaiseFreq = profile.bluffRaiseFreq;
        if (profile.exploitsHighFolders && human.overFolds && isTurnOrRiver) {
          bluffRaiseFreq = max(bluffRaiseFreq, 0.55);
        }
        if (human.isCallingStation) bluffRaiseFreq *= 0.2;
        final alphaNeeded = GtoMath.alpha(pot, raiseTo() - callAmount);
        if (blockers.goodBluffBlockers && !facingAllInPrice &&
            rand < bluffRaiseFreq && foldEst >= alphaNeeded * 0.75) {
          return BotDecision(type: ActionType.raise, amount: raiseTo(), thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
    }
  }

  /// C-bet / barrel / probe with air: frequency driven by range advantage,
  /// texture, alpha break-even math and live exploit reads.
  static BotDecision _airBetOrCheck({
    required LegendProfile profile,
    required BoardTexture texture,
    required Blockers blockers,
    required double pot,
    required double stack,
    required double foldEst,
    required HumanReadModel human,
    required bool wasAggressor,
    required String street,
    required double bb,
  }) {
    final rand = _rng.nextDouble();
    final isRiver = street == 'river';
    final rangeAdv = wasAggressor ? RangeModel.aggressorRangeAdvantage(texture) : -0.05;

    double bluffFreq;
    if (wasAggressor) {
      bluffFreq = _streetCBetFreq(profile, street) * (1 + rangeAdv * 1.4);
      bluffFreq *= texture.wetness < 0.4 ? 1.15 : 0.75;
    } else {
      bluffFreq = profile.floatFreq * (texture.wetness < 0.4 ? 1.0 : 0.6);
    }

    // Ivey/Hansen exploit: vs over-folders barrel turn/river up to 80%
    if (profile.exploitsHighFolders && human.overFolds &&
        (street == 'turn' || isRiver)) {
      bluffFreq = max(bluffFreq, 0.80);
    }
    if (human.isCallingStation) bluffFreq *= 0.35;

    // Sizing: small on dry, big on wet; polarized profiles overbet rivers
    // with good blockers (Mateos blocker-optimal 150% pots)
    double sizeFrac = texture.wetness < 0.4 ? 0.40 : 0.66;
    if (isRiver && profile.polarizedBetting && blockers.goodBluffBlockers) {
      sizeFrac = 1.5;
    }
    if (profile.stackPressure) sizeFrac = (sizeFrac * 1.25).clamp(0.4, 2.0).toDouble();

    final betAmount = (pot * sizeFrac).clamp(bb, stack).toDouble();
    // Alpha gate: bluff must clear break-even fold frequency (with margin)
    final alphaNeeded = GtoMath.alpha(pot, betAmount);

    if (rand < bluffFreq && foldEst >= alphaNeeded * 0.80) {
      return BotDecision(type: ActionType.bet, amount: betAmount, thinkMs: 0);
    }
    return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
  }

  /// Value sizing: texture-aware, with nut-advantage overbets for
  /// polarized profiles (Addamo 2-3x pots, Mateos 1.5x rivers).
  static double _valueSize(
    LegendProfile profile,
    double pot,
    BoardTexture texture,
    String street, {
    required bool nut,
  }) {
    final isRiver = street == 'river';
    double frac;
    if (texture.wetness < 0.35) {
      frac = profile.preferredSizings.first.clamp(0.25, 0.6).toDouble();
    } else {
      frac = 0.70;
    }
    if (nut && profile.polarizedBetting) {
      // Nut advantage → leverage with overbets
      frac = profile.preferredSizings.last.clamp(1.0, 3.0).toDouble();
      if (street == 'flop') frac = min(frac, 2.0);
    } else if (nut && isRiver) {
      frac = max(frac, 0.85);
    }
    if (profile.potControl && !nut) frac = min(frac, 0.5);
    if (profile.stackPressure) frac = (frac * 1.2).clamp(0.3, 3.0).toDouble();
    return pot * frac;
  }

  static double _openThreshold(LegendProfile p, TablePosition pos) {
    switch (pos) {
      case TablePosition.utg: return p.utgOpen;
      case TablePosition.mp: return p.mpOpen;
      case TablePosition.co: return p.coOpen;
      case TablePosition.btn: return p.btnOpen;
      case TablePosition.sb: return p.sbOpen;
      case TablePosition.bb: return p.bbDefend;
    }
  }

  static double _streetCBetFreq(LegendProfile p, String street) {
    switch (street) {
      case 'flop': return p.cBetFreq;
      case 'turn': return p.doubleBarrelFreq;
      case 'river': return p.tripleBarrelFreq;
      default: return p.cBetFreq;
    }
  }
}
