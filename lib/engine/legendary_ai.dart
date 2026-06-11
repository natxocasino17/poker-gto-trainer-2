import 'dart:math';
import '../data/models/card_model.dart';
import '../data/models/player_model.dart';
import '../data/models/hand_log_model.dart';
import '../core/utils/equity_calculator.dart';

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

  // 3-bet / 4-bet
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
  final double riverOverbetThreshold; // equity threshold to overbet river

  // Adaptive traits
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
    // 1. Phil Ivey — Loose-Aggressive Exploiter
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
      exploitsHighFolders: true,
    ),
    // 2. Adrián Mateos — GTO Hyper-Aggressive
    LegendProfile(
      name: 'Adrián Mateos',
      style: 'GTO Hyper-Aggressive',
      emoji: '⚡',
      utgOpen: 0.68, mpOpen: 0.60, coOpen: 0.52, btnOpen: 0.42, sbOpen: 0.54, bbDefend: 0.40,
      threeBetThreshold: 0.66, fourBetThreshold: 0.84,
      cBetFreq: 0.78, doubleBarrelFreq: 0.65, tripleBarrelFreq: 0.50, checkRaiseFreq: 0.32,
      bluffFreq: 0.35, slowplayFreq: 0.10,
      preferredSizings: [0.75, 1.0, 1.5, 2.0],
      riverOverbetThreshold: 0.70,
      polarizedBetting: true,
    ),
    // 3. Daniel Negreanu — Small Ball / Trapper
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
    ),
    // 4. Phil Hellmuth — Tight-Passive White Magic
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
    ),
    // 5. Tom Dwan — Ultra-Loose Aggressive
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
      polarizedBetting: true,
    ),
    // 6. Doyle Brunson — Old School Aggressive
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
    ),
    // 7. Fedor Holz — GTO Strict
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
    // 8. Chris Moneymaker — Explosive High Variance
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
      highVarianceDraws: true,
    ),
    // 9. Justin Bonomo — Computational Frequencies
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
    // 10. Stephen Chidwick — Blind Defense Expert
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
    ),
    // 11. Gus Hansen — Classic LAG
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
      exploitsHighFolders: true,
    ),
    // 12. Antonio Esfandiari — Pot Control Specialist
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
      potControl: true,
    ),
    // 13. Michael Addamo — Overbet Terror
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
      polarizedBetting: true,
    ),
    // 14. Linus Loeliger — High Roller Cash GTO
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
    ),
    // 15. Bryn Kenney — Stack Pressure Expert
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
      stackPressure: true,
    ),
  ];

  static List<LegendProfile> selectTable() {
    final pool = List<LegendProfile>.from(_allLegends)..shuffle(_rng);
    return pool.take(5).toList();
  }

  static LegendProfile profileByName(String name) =>
      _allLegends.firstWhere((p) => p.name == name, orElse: () => _allLegends[0]);

  static Future<BotDecision> decide({
    required LegendProfile profile,
    required List<CardModel> holeCards,
    required List<CardModel> communityCards,
    required TablePosition position,
    required double callAmount,
    required double currentPot,
    required double botStack,
    required double humanFoldRate,
    required bool isPreflop,
    required bool wasAggressor,
    required int activePlayers,
    required String street,
    required int raiseCount,
  }) async {
    final thinkMs = 800 + _rng.nextInt(1800);

    double equity;
    if (isPreflop) {
      equity = CardModel.preflopStrength(holeCards);
    } else {
      equity = EquityCalculator.calculate(
        heroCards: holeCards,
        communityCards: communityCards,
        numOpponents: max(1, activePlayers - 1),
        simulations: 200,
      );
    }

    final posThreshold = _openThreshold(profile, position);
    final decision = _resolveAction(
      profile: profile,
      equity: equity,
      posThreshold: posThreshold,
      callAmount: callAmount,
      currentPot: currentPot,
      botStack: botStack,
      humanFoldRate: humanFoldRate,
      isPreflop: isPreflop,
      wasAggressor: wasAggressor,
      street: street,
      raiseCount: raiseCount,
      activePlayers: activePlayers,
    );

    await Future.delayed(Duration(milliseconds: thinkMs));
    return decision;
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

  static BotDecision _resolveAction({
    required LegendProfile profile,
    required double equity,
    required double posThreshold,
    required double callAmount,
    required double currentPot,
    required double botStack,
    required double humanFoldRate,
    required bool isPreflop,
    required bool wasAggressor,
    required String street,
    required int raiseCount,
    required int activePlayers,
  }) {
    final rand = _rng.nextDouble();

    // Adapt bluff frequency based on human fold rate (for exploitative legends)
    double effectiveBluffFreq = profile.bluffFreq;
    if (profile.exploitsHighFolders && humanFoldRate > 0.55) {
      effectiveBluffFreq = (profile.bluffFreq * 1.5).clamp(0.0, 0.70);
    }

    // Preflop logic
    if (isPreflop) {
      if (callAmount <= 0) {
        // Opening opportunity
        if (equity >= posThreshold) {
          final sizing = _chooseSizing(profile, currentPot, street) * 2 + 2;
          return BotDecision(type: ActionType.raise, amount: sizing, thinkMs: 0);
        }
        return BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
      }

      final potOdds = EquityCalculator.potOddsRequired(callAmount, currentPot);

      // Facing a raise
      if (raiseCount >= 2 && equity >= profile.threeBetThreshold + 0.05) {
        // 4-bet range
        if (equity >= profile.fourBetThreshold) {
          final bet = (callAmount * 2.5).clamp(callAmount + 2, botStack);
          return BotDecision(type: ActionType.raise, amount: bet, thinkMs: 0);
        }
        if (rand < 0.25) {
          return BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
        }
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }

      if (equity >= profile.threeBetThreshold ||
          (equity >= profile.threeBetThreshold - 0.12 && rand < 0.35 && raiseCount < 2)) {
        // 3-bet or overcall
        if (equity >= profile.threeBetThreshold && raiseCount < 2) {
          final sizing = (callAmount * 3.0).clamp(callAmount + 2, botStack);
          return BotDecision(type: ActionType.raise, amount: sizing, thinkMs: 0);
        }
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }

      if (equity >= posThreshold - 0.08 && equity >= potOdds) {
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }

      return BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
    }

    // Postflop logic
    final potOdds = EquityCalculator.potOddsRequired(callAmount, currentPot);

    if (callAmount <= 0) {
      // No bet facing — check or bet
      bool shouldBet = false;
      double betSizing = 0.5;

      if (equity >= 0.65) {
        if (profile.slowplayFreq > rand) {
          return BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
        }
        shouldBet = true;
        betSizing = _chooseSizing(profile, currentPot, street);
      } else if (wasAggressor && rand < _streetCBetFreq(profile, street)) {
        shouldBet = true;
        betSizing = _chooseSizing(profile, currentPot, street);
      } else if (equity >= 0.30 && rand < effectiveBluffFreq * 0.7) {
        shouldBet = true;
        betSizing = profile.preferredSizings.first;
      }

      if (shouldBet) {
        if (profile.highVarianceDraws && equity > 0.35 && rand < 0.4) {
          return BotDecision(type: ActionType.allIn, amount: botStack, thinkMs: 0);
        }
        if (street == 'river' && equity >= profile.riverOverbetThreshold && profile.polarizedBetting) {
          final overbet = currentPot * 1.5;
          if (overbet <= botStack) {
            return BotDecision(type: ActionType.bet, amount: overbet, thinkMs: 0);
          }
        }
        if (profile.stackPressure && botStack > currentPot * 2 && equity >= 0.60) {
          betSizing = (betSizing * 1.3).clamp(0.5, 2.0);
        }
        if (profile.potControl && equity < 0.70) {
          betSizing = (betSizing * 0.6).clamp(0.25, 0.5);
        }
        final amount = (currentPot * betSizing).clamp(2.0, botStack);
        return BotDecision(type: ActionType.bet, amount: amount, thinkMs: 0);
      }
      return BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
    }

    // Facing a bet
    if (equity >= 0.72 && rand < 0.65) {
      // Raise for value or check-raise
      final sizing = (callAmount * 2.8).clamp(callAmount + 2, botStack);
      if (rand < profile.checkRaiseFreq + 0.20) {
        return BotDecision(type: ActionType.raise, amount: sizing, thinkMs: 0);
      }
    }

    if (equity > potOdds + 0.04) {
      return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
    }

    if (equity >= potOdds - 0.06 && rand < effectiveBluffFreq) {
      // Bluff raise
      final bluffAmt = (callAmount * 2.5).clamp(callAmount + 2, botStack);
      return BotDecision(type: ActionType.raise, amount: bluffAmt, thinkMs: 0);
    }

    if (equity > potOdds - 0.04) {
      return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
    }

    return BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
  }

  static double _chooseSizing(LegendProfile profile, double pot, String street) {
    final sizings = profile.preferredSizings;
    final idx = _rng.nextInt(sizings.length);
    double size = sizings[idx];

    if (street == 'river' && profile.polarizedBetting) {
      size = sizings.last;
    } else if (street == 'flop') {
      size = sizings[0];
    }
    return size;
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
