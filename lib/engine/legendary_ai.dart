import 'dart:math';
import '../data/gto/open_raise.dart';
import '../data/models/card_model.dart';
import '../data/models/player_model.dart';
import '../data/models/hand_log_model.dart';
import '../core/utils/equity_calculator.dart';
import '../core/utils/poker_concepts.dart';
import '../core/utils/postflop_context.dart';
import '../core/utils/preflop_charts.dart';

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
  final bool stationCalling; // calling station: barely ever folds a piece
  final bool fitOrFold;      // gives up postflop without a made hand
  final bool isArchetype;    // style profile (Nit, LAG...) vs real legend
  // Phil Ivey: gates exploitation on observed confidence; traps vs aggressive humans
  final bool readsOpponent;
  // Papo MC "La Bestia": surprise factor, attacks tight players, sizing chaos,
  // ignores GTO to jam vs perceived weakness
  final bool freestyleAggressor;
  // Phil Hellmuth "White Magic": trusts reads over GTO — hero-calls vs aggression,
  // prioritises stack survival, folds marginal risky spots, patient max value
  final bool whiteMagicReader;
  // OOP probe bet frequency when IP checks back (demonstrates weakness on prior street)
  final double probeBetFreq;
  // OOP donk bet frequency when defender's range hits this board texture better
  final double donkBetFreq;
  // Optional illustrated avatar asset path (null → show emoji)
  final String? avatarAsset;

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
    this.stationCalling = false,
    this.fitOrFold = false,
    this.isArchetype = false,
    this.readsOpponent = false,
    this.freestyleAggressor = false,
    this.whiteMagicReader = false,
    this.probeBetFreq = 0.22,
    this.donkBetFreq = 0.08,
    this.avatarAsset,
  });
}

class LegendaryBotEngine {
  static final Random _rng = Random();

  /// Global difficulty knob set from user settings: 0.0 = easy (bots play
  /// passively and face-up, bluff less), 0.5 = medium (legend baseline),
  /// 1.0 = hard (bots hero-call thin and stay balanced — tougher to exploit).
  static double difficulty = 0.5;

  /// Post-processes a postflop decision according to [difficulty]. Easy bots
  /// give up low-equity aggression; hard bots occasionally bluff-catch thin.
  static BotDecision _applyDifficulty(
      BotDecision d, double equity, double callAmount) {
    if (difficulty < 0.5) {
      final ease = (0.5 - difficulty) * 2; // 0..1
      final aggressive = d.type == ActionType.bet ||
          d.type == ActionType.raise ||
          d.type == ActionType.allIn;
      if (aggressive && equity < 0.45 && _rng.nextDouble() < ease * 0.6) {
        return BotDecision(
          type: callAmount > 0 ? ActionType.fold : ActionType.check,
          amount: 0,
          thinkMs: d.thinkMs,
        );
      }
    } else if (difficulty > 0.5) {
      final tough = (difficulty - 0.5) * 2; // 0..1
      if (d.type == ActionType.fold &&
          callAmount > 0 &&
          equity > 0.30 &&
          _rng.nextDouble() < tough * 0.25) {
        return BotDecision(
            type: ActionType.call, amount: callAmount, thinkMs: d.thinkMs);
      }
    }
    return d;
  }

  static const List<LegendProfile> _allLegends = [
    // 1. Phil Ivey — High-Stakes Exploiter: reads patterns, barrels turn/river
    // vs over-folders, value-maximises vs stations, never tilts.
    LegendProfile(
      name: 'Phil',
      style: 'Loose-Aggressive Exploiter',
      emoji: '🦅',
      avatarAsset: 'assets/avatars/phil.png',
      // Disciplined preflop — oportunista desde BTN/CO
      utgOpen: 0.64, mpOpen: 0.57, coOpen: 0.49, btnOpen: 0.38, sbOpen: 0.52, bbDefend: 0.36,
      threeBetThreshold: 0.72, fourBetThreshold: 0.88,
      // Fuerte en turn/river — expert en calles tardías con profundidad de stacks
      cBetFreq: 0.70, doubleBarrelFreq: 0.65, tripleBarrelFreq: 0.50, checkRaiseFreq: 0.32,
      bluffFreq: 0.38, slowplayFreq: 0.22,
      // Sizing medio-grande como herramienta de presión
      preferredSizings: [0.66, 0.85, 1.0],
      riverOverbetThreshold: 0.72,
      openSizeBB: 2.3,
      bluffRaiseFreq: 0.22, floatFreq: 0.32,
      threeBetBluffFreq: 0.13, squeezeFreq: 0.14,
      probeBetFreq: 0.30, donkBetFreq: 0.12,
      exploitsHighFolders: true,
      readsOpponent: true,       // "El Observador": exploitation gated on confidence
    ),
    // 2. Adrián Mateos — GTO Aggressive Master: polarized overbets, relentless
    // multi-street pressure, pure GTO base with data-gated exploitation.
    LegendProfile(
      name: 'Adrián',
      style: 'GTO Aggressive Master',
      emoji: '⚡',
      avatarAsset: 'assets/avatars/adrian.png',
      // Aggressive preflop — opens wide, 3-bets often, squeezes relentlessly
      utgOpen: 0.66, mpOpen: 0.58, coOpen: 0.50, btnOpen: 0.40, sbOpen: 0.52, bbDefend: 0.38,
      threeBetThreshold: 0.64, fourBetThreshold: 0.82,
      // "Presión Continua": very high C-bet, fires Turn/River without mercy
      cBetFreq: 0.82, doubleBarrelFreq: 0.70, tripleBarrelFreq: 0.52, checkRaiseFreq: 0.34,
      // "Polarización": air or nuts — no medium bets. No slowplay.
      bluffFreq: 0.36, slowplayFreq: 0.06,
      // Large sizing only: 1.0-1.5x pot, river overbets at 1.5-2.0x
      preferredSizings: [0.75, 1.0, 1.5, 2.0],
      riverOverbetThreshold: 0.62,
      openSizeBB: 2.5,
      threeBetBluffFreq: 0.20, squeezeFreq: 0.18, bluffRaiseFreq: 0.20,
      probeBetFreq: 0.35, donkBetFreq: 0.10,
      // GTO-first: polarized overbets, no pot control
      polarizedBetting: true,
    ),
    // 3. Daniel Negreanu — "Kid Poker / The Hybrid": Small Ball strategist.
    // Keeps pots small pre-flop (2x opens) to reach post-flop, where his edge
    // lives. "The Talker": reads opponents through bet-sizing. "Adaptabilidad
    // Híbrida": GTO base adjusted to the villain — lets aggressive players
    // bluff and traps them. Pot control with medium hands; positional, friendly
    // but lethal.
    LegendProfile(
      name: 'Daniel',
      style: 'Small Ball Hybrid — Kid Poker',
      emoji: '🎯',
      avatarAsset: 'assets/avatars/daniel.png',
      // Small Ball: tight-ish, loosens in position (BTN), controlled pots OOP
      utgOpen: 0.60, mpOpen: 0.53, coOpen: 0.44, btnOpen: 0.34, sbOpen: 0.46, bbDefend: 0.32,
      threeBetThreshold: 0.76, fourBetThreshold: 0.90,
      cBetFreq: 0.55, doubleBarrelFreq: 0.40, tripleBarrelFreq: 0.28, checkRaiseFreq: 0.22,
      // Friendly but lethal: low bluff volume, heavy slowplay to trap
      bluffFreq: 0.18, slowplayFreq: 0.45,
      // Small Ball sizing: small controlled bets, big only with the nuts
      preferredSizings: [0.25, 0.33, 0.5],
      riverOverbetThreshold: 0.90,
      openSizeBB: 2.0, floatFreq: 0.28, blockerBetFreq: 0.20,
      probeBetFreq: 0.28, donkBetFreq: 0.14,
      // "Pot Control" + "Adaptabilidad Híbrida": controlled sizing, level-based
      // value/bluff adjustment to the villain (station/over-folder/aggressor).
      potControl: true,
      // "The Talker": bet-sizing reads → traps aggressive players, induces
      // bluffs with strong hands, ramps exploitation as confidence builds.
      readsOpponent: true,
    ),
    // 4. Phil Hellmuth — The Poker Brat / White Magic: legendary patience,
    // small-ball survival, hero-calls on reads over GTO, pure-value raises.
    LegendProfile(
      name: 'Philip',
      style: 'White Magic — The Poker Brat',
      emoji: '👑',
      avatarAsset: 'assets/avatars/philip.png',
      // "Paciencia Disciplinada": ultra-tight, no unnecessary pots
      utgOpen: 0.76, mpOpen: 0.71, coOpen: 0.64, btnOpen: 0.55, sbOpen: 0.66, bbDefend: 0.50,
      threeBetThreshold: 0.84, fourBetThreshold: 0.93,
      // Small-ball: low aggression frequencies, controlled barrels
      cBetFreq: 0.58, doubleBarrelFreq: 0.40, tripleBarrelFreq: 0.22, checkRaiseFreq: 0.14,
      // "White Magic" raises are PURE value (bluffRaiseFreq 0), minimal bluffing
      bluffFreq: 0.07, slowplayFreq: 0.18,
      // Small-ball sizings: lots of small pots, big only with the nuts
      preferredSizings: [0.33, 0.5, 0.66],
      riverOverbetThreshold: 0.96,
      openSizeBB: 2.2,
      bluffRaiseFreq: 0.0, threeBetBluffFreq: 0.02, floatFreq: 0.05,
      probeBetFreq: 0.12, donkBetFreq: 0.04,
      // "White Magic" + "Defensa del Stack": read-based hero calls, survival first
      whiteMagicReader: true,
    ),
    // 5. Tom Dwan — Ultra-Loose Aggressive: triple barrels with total air,
    // unpredictable sizings designed to crack tight ranges.
    LegendProfile(
      name: 'Tom',
      style: 'Ultra-Loose Aggressive',
      emoji: '🌪️',
      utgOpen: 0.52, mpOpen: 0.44, coOpen: 0.34, btnOpen: 0.24, sbOpen: 0.36, bbDefend: 0.22,
      threeBetThreshold: 0.60, fourBetThreshold: 0.76,
      cBetFreq: 0.85, doubleBarrelFreq: 0.72, tripleBarrelFreq: 0.58, checkRaiseFreq: 0.40,
      bluffFreq: 0.55, slowplayFreq: 0.15,
      preferredSizings: [0.75, 1.0, 1.5, 2.5],
      riverOverbetThreshold: 0.60,
      openSizeBB: 2.8, threeBetBluffFreq: 0.22, bluffRaiseFreq: 0.28,
      probeBetFreq: 0.42, donkBetFreq: 0.18,
      polarizedBetting: true,
    ),
    // 6. Doyle Brunson — "The Godfather of Poker": fearless old-school
    // aggression built on willpower & psychological dominance, not math.
    // "Jugar al jugador": attacks any sign of weakness. "Dominancia del bote":
    // keeps the initiative and bets constantly so villains never know value
    // from bluff. "Factor 10-2": intimidation plays with marginal hands; never
    // fears variance for a massive pot. Decades of experience → folds when a
    // villain shows undeniable strength.
    LegendProfile(
      name: 'Doyle',
      style: 'The Godfather — Old School Aggression',
      emoji: '🤠',
      avatarAsset: 'assets/avatars/doyle.png',
      utgOpen: 0.58, mpOpen: 0.50, coOpen: 0.41, btnOpen: 0.31, sbOpen: 0.43, bbDefend: 0.28,
      threeBetThreshold: 0.70, fourBetThreshold: 0.86,
      // "Dominancia del bote": relentless betting across streets
      cBetFreq: 0.78, doubleBarrelFreq: 0.62, tripleBarrelFreq: 0.44, checkRaiseFreq: 0.25,
      bluffFreq: 0.38, slowplayFreq: 0.18,
      // Old-school sizing: bets everything, no modern polarization
      preferredSizings: [0.5, 0.75, 1.0, 1.25],
      riverOverbetThreshold: 0.80,
      openSizeBB: 2.5, impliedOddsWeight: 1.5,
      probeBetFreq: 0.34, donkBetFreq: 0.12,
      // "Castiga pasivos / nunca cartas gratis": barrels vs over-folders
      exploitsHighFolders: true,
      // "Factor 10-2 / jugar al jugador": attacks weakness, conviction bluffs,
      // unpredictable sizing so villains can't read value vs bluff
      freestyleAggressor: true,
      // "La fortuna favorece a los audaces": fearless with draws/marginal hands
      highVarianceDraws: true,
      // "Dominancia del bote": sizes up to keep the pressure on
      stackPressure: true,
    ),
    // 7. Fedor Holz — "The High Roller Phenom": cutting-edge GTO base + total
    // mental control (zen, never tilts). Maximises EV over results.
    // "Adaptabilidad GTO": balanced & unexploitable vs strong pros, deviates to
    // punish weak players. "Precisión quirúrgica": every bet has a purpose, no
    // bluffs "porque sí". "Gestión de la información": reads sizing/frequencies
    // as data. Deep-stack specialist who minimises variance in unknown spots.
    LegendProfile(
      name: 'Fedor',
      style: 'GTO Phenom — Surgical Optimizer',
      emoji: '🤖',
      avatarAsset: 'assets/avatars/fedor.png',
      utgOpen: 0.66, mpOpen: 0.60, coOpen: 0.52, btnOpen: 0.43, sbOpen: 0.55, bbDefend: 0.40,
      threeBetThreshold: 0.70, fourBetThreshold: 0.86,
      cBetFreq: 0.68, doubleBarrelFreq: 0.55, tripleBarrelFreq: 0.40, checkRaiseFreq: 0.30,
      bluffFreq: 0.28, slowplayFreq: 0.18,
      preferredSizings: [0.33, 0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.80,
      probeBetFreq: 0.26, donkBetFreq: 0.08,
      // "Minimiza la varianza": disciplined draw calls, no speculative gambles
      impliedOddsWeight: 0.9,
      // "Adaptabilidad GTO" + "sizing as data": plays solid GTO vs strong reads,
      // ramps exploitation only as frequency reads on a weak villain build up.
      readsOpponent: true,
    ),
    // 8. Chris Moneymaker — "The Giant Killer": intuitive, fearless and
    // unpredictable. Pros underestimate him and he uses it. "Fearless Poker":
    // jams on a read without hesitation. "Factor Sorpresa": breaks solver logic
    // with moves that rattle GTO players. "Hero Calls": senses intimidation and
    // pays off bluffs with marginal hands. "Volatilidad positiva": double up or
    // bust — never survives blindly. Instinct over math.
    LegendProfile(
      name: 'Chris',
      style: 'The Giant Killer — Fearless Intuition',
      emoji: '💣',
      avatarAsset: 'assets/avatars/chris.png',
      utgOpen: 0.56, mpOpen: 0.48, coOpen: 0.38, btnOpen: 0.28, sbOpen: 0.40, bbDefend: 0.25,
      threeBetThreshold: 0.66, fourBetThreshold: 0.80,
      cBetFreq: 0.76, doubleBarrelFreq: 0.60, tripleBarrelFreq: 0.44, checkRaiseFreq: 0.22,
      bluffFreq: 0.40, slowplayFreq: 0.10,
      preferredSizings: [0.75, 1.0, 1.5],
      riverOverbetThreshold: 0.65,
      threeBetBluffFreq: 0.12,
      probeBetFreq: 0.34, donkBetFreq: 0.14,
      // "Fearless / volatilidad positiva": jams combo draws, doubles up, and
      // hero-calls aggression without ducking the variance (see call logic).
      highVarianceDraws: true,
      // "Factor Sorpresa": unpredictable sizing & moves that break solver reads,
      // attacks players who look weak or standard.
      freestyleAggressor: true,
    ),
    // 9. Justin Bonomo — "The GTO Master": a surgeon of numbers playing pure
    // mathematical frequencies, aiming for zero exploitable error.
    // "Equilibrio total": bet & check ranges balanced so he can't be exploited.
    // "La verdad en los datos": never deviates from theory even vs weak players
    // (no exploit flags by design) unless the edge were astronomical.
    // "EV-loss minimisation": prefers a solid small edge over a risky big pot.
    // Emotionless, predictable-by-design wall of ice; impeccable on the river.
    LegendProfile(
      name: 'Justin',
      style: 'The GTO Master — Wall of Ice',
      emoji: '📊',
      avatarAsset: 'assets/avatars/justin.png',
      utgOpen: 0.67, mpOpen: 0.61, coOpen: 0.53, btnOpen: 0.44, sbOpen: 0.56, bbDefend: 0.41,
      threeBetThreshold: 0.69, fourBetThreshold: 0.85,
      cBetFreq: 0.70, doubleBarrelFreq: 0.57, tripleBarrelFreq: 0.42, checkRaiseFreq: 0.31,
      bluffFreq: 0.30, slowplayFreq: 0.16,
      preferredSizings: [0.33, 0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.78,
      probeBetFreq: 0.26, donkBetFreq: 0.08,
      // "EV-loss minimisation": disciplined draw odds, no speculative gambles.
      // Intentionally carries NO exploit/read/variance flags — he never deviates.
      impliedOddsWeight: 0.9,
    ),
    // 10. Stephen Chidwick — "The Technician": modern gold standard. Sublime
    // GTO base + nearly invisible exploitative adaptation. Wins by taking the
    // mathematically superior decision, not theatre. "Disciplina inquebrantable":
    // linear, constant, no emotional swings. "Perfección en el margen": grinds
    // tiny edges in marginal pots. "Adaptabilidad silenciosa": detects frequency
    // shifts and adjusts subtly. River specialist who makes thin calls/bluffs
    // that look impossible but are perfectly founded. No unnecessary hero plays —
    // waits for the villain to err.
    LegendProfile(
      name: 'Stephen',
      style: 'The Technician — Silent Adapter',
      emoji: '🛡️',
      avatarAsset: 'assets/avatars/stephen.png',
      utgOpen: 0.65, mpOpen: 0.58, coOpen: 0.50, btnOpen: 0.40, sbOpen: 0.50, bbDefend: 0.30,
      threeBetThreshold: 0.68, fourBetThreshold: 0.84,
      // High check-raise + wide blind defense = relentless technical range play
      cBetFreq: 0.66, doubleBarrelFreq: 0.53, tripleBarrelFreq: 0.38, checkRaiseFreq: 0.42,
      bluffFreq: 0.28, slowplayFreq: 0.14,
      preferredSizings: [0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.82,
      squeezeFreq: 0.18,
      probeBetFreq: 0.32, donkBetFreq: 0.10,
      // "Adaptabilidad silenciosa": GTO baseline that quietly ramps exploitation
      // only as frequency reads build — never shows the villain he's adjusting.
      readsOpponent: true,
    ),
    // 11. Gus Hansen — "The Madman of High Stakes": hyper-aggressive,
    // unpredictable, risk-loving. Plays the opponent's pressure, not his cards,
    // forcing tough all-stack decisions every hand. "Rango infinito": plays junk
    // nobody can range him on. "Apuesta de creación": any connection (or none)
    // → he bets. "No te rindes": huge risk tolerance, rarely folds before
    // showdown. Attacks passive players until they break.
    LegendProfile(
      name: 'Gus',
      style: 'The Madman — Max-Variance LAG',
      emoji: '🔥',
      avatarAsset: 'assets/avatars/gus.png',
      utgOpen: 0.49, mpOpen: 0.40, coOpen: 0.30, btnOpen: 0.20, sbOpen: 0.32, bbDefend: 0.18,
      threeBetThreshold: 0.62, fourBetThreshold: 0.78,
      cBetFreq: 0.82, doubleBarrelFreq: 0.68, tripleBarrelFreq: 0.52, checkRaiseFreq: 0.35,
      bluffFreq: 0.50, slowplayFreq: 0.12,
      preferredSizings: [0.75, 1.0, 1.25, 1.5],
      riverOverbetThreshold: 0.68,
      openSizeBB: 2.6, threeBetBluffFreq: 0.20, bluffRaiseFreq: 0.20,
      probeBetFreq: 0.38, donkBetFreq: 0.16,
      // "Explora la debilidad": hammers over-folders/passive players
      exploitsHighFolders: true,
      // "Apuesta de creación" + enigmatic: chaotic sizing, conviction bluffs
      freestyleAggressor: true,
      // "Máxima varianza": jams draws, forces all-stack decisions
      highVarianceDraws: true,
      // "No te rindes": sticky, commits wide and rarely folds before showdown
      stationCalling: true,
    ),
    // 12. Antonio Esfandiari — "The Magician": a showman who plays misdirection.
    // Builds a table image and then plays the opposite to exploit expectations.
    // "Misdirection": weak-looking bets with strong hands to induce calls, and
    // theatrical big bets with air to generate fear. "Lectura de tilt": hunts
    // frustrated players. Charismatic and intuitive over an elite technical base
    // — the opposite of Bonomo's robotic wall.
    LegendProfile(
      name: 'Antonio',
      style: 'The Magician — Misdirection',
      emoji: '🎪',
      avatarAsset: 'assets/avatars/antonio.png',
      utgOpen: 0.62, mpOpen: 0.55, coOpen: 0.46, btnOpen: 0.36, sbOpen: 0.48, bbDefend: 0.33,
      threeBetThreshold: 0.74, fourBetThreshold: 0.88,
      cBetFreq: 0.58, doubleBarrelFreq: 0.42, tripleBarrelFreq: 0.25, checkRaiseFreq: 0.20,
      bluffFreq: 0.26, slowplayFreq: 0.35,
      preferredSizings: [0.25, 0.33, 0.5],
      // Lower overbet bar → willing to fire theatrical big river bets (fear/value)
      riverOverbetThreshold: 0.75,
      // High blocker-bet freq = weak-looking bets that induce the call
      openSizeBB: 2.2, blockerBetFreq: 0.35,
      probeBetFreq: 0.22, donkBetFreq: 0.08,
      // Controlled pots + image-adaptive value/bluff (plays against perception)
      potControl: true,
      // "Misdirection" + "lectura de tilt": traps with checked nuts, induces
      // bluffs with strong value, ramps exploitation on the frustrated villain.
      readsOpponent: true,
    ),
    // 13. Michael Addamo — "The High Roller Nightmare": hyper-aggressive
    // mathematical pressure that shatters opponents' range structure until the
    // fold looks like the only safe option (even when it's wrong).
    // "Presión del overbet": 1.5-3x pot bombs when range advantage is his,
    // forcing all-stack decisions with marginal hands. "Polarización brutal":
    // nuts or air, never medium. "Explotación de la incomodidad": punishes GTO
    // players in late streets, near-100% river aggression vs weakness. Risk
    // indifferent and almost impossible to read — never bluffs without a plan.
    LegendProfile(
      name: 'Michael',
      style: 'The Nightmare — Overbet Terror',
      emoji: '💥',
      avatarAsset: 'assets/avatars/michael.png',
      utgOpen: 0.63, mpOpen: 0.56, coOpen: 0.47, btnOpen: 0.37, sbOpen: 0.49, bbDefend: 0.35,
      threeBetThreshold: 0.67, fourBetThreshold: 0.82,
      // Relentless late-street pressure
      cBetFreq: 0.74, doubleBarrelFreq: 0.62, tripleBarrelFreq: 0.52, checkRaiseFreq: 0.36,
      bluffFreq: 0.36, slowplayFreq: 0.12,
      preferredSizings: [1.0, 1.5, 2.0, 3.0],
      riverOverbetThreshold: 0.60,
      openSizeBB: 3.0, bluffRaiseFreq: 0.18,
      probeBetFreq: 0.36, donkBetFreq: 0.14,
      // "Polarización brutal": air or nuts, no medium bets
      polarizedBetting: true,
      // "Explotación de la incomodidad": near-100% river barrels vs weakness,
      // never lets GTO players reach showdown for free
      exploitsHighFolders: true,
      // "Presión del overbet": sizes up to threaten the whole stack
      stackPressure: true,
    ),
    // 14. Linus Loeliger — "The Online Legend": the culmination of the solver
    // era. No theatre, no ego — relentless GTO execution that forces the villain
    // into lose-lose spots. "La Máquina de Explotación": balanced by default, but
    // detects any opponent error instantly and shifts frequency to punish it.
    // "Consistencia de acero": no bias, no tilt. Deep-stack master who builds the
    // perfect bet on every street, choking the villain on the river. Theoretically
    // perfect blind defense (never gives away pots) and constant positional
    // pressure from the button — a silent mathematical strangulation, not Papo's
    // loud aggression.
    LegendProfile(
      name: 'Linus',
      style: 'The Online Legend — GTO Strangler',
      emoji: '💎',
      avatarAsset: 'assets/avatars/linus.png',
      // "Agresividad en la posición" + "Defensa de ciegos perfecta": loose BTN,
      // very wide blind defense (low bbDefend = defends widest, never folds pots)
      utgOpen: 0.68, mpOpen: 0.62, coOpen: 0.48, btnOpen: 0.32, sbOpen: 0.54, bbDefend: 0.26,
      threeBetThreshold: 0.71, fourBetThreshold: 0.87,
      cBetFreq: 0.69, doubleBarrelFreq: 0.56, tripleBarrelFreq: 0.42, checkRaiseFreq: 0.30,
      bluffFreq: 0.27, slowplayFreq: 0.17,
      preferredSizings: [0.33, 0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.80,
      threeBetBluffFreq: 0.14,
      // "Presión técnica constante": stabs/floats relentlessly in position
      floatFreq: 0.30,
      probeBetFreq: 0.26, donkBetFreq: 0.08,
      // "La Máquina de Explotación": GTO baseline that ramps exploitation the
      // instant a read on the villain's mistake builds.
      readsOpponent: true,
      // "Nunca regalas botes": punishes over-folders in late streets
      exploitsHighFolders: true,
    ),
    // 15. Bryn Kenney — "High-Stakes Aggressor": incessant pressure over theory.
    // "Volumen sobre perfección": plays a far wider range than other pros to keep
    // villains in constant doubt. "Explotación psicológica": doesn't care if a
    // play is GTO-correct, only if it's profitable vs THIS player — destroys rigid
    // players with constant bets. "Presión post-flop": never lets off the gas,
    // multi-barrels mediocre hands into winners. "Lectura de debilidad": smells a
    // passive player waiting for cards and preys on their blinds/pots. Total
    // conviction on every all-in, fearless of variance.
    LegendProfile(
      name: 'Bryn',
      style: 'High-Stakes Aggressor — Relentless Pressure',
      emoji: '⚖️',
      avatarAsset: 'assets/avatars/bryn.png',
      // "Agresividad pre-flop": opens far wider than average, attacks blinds wide
      utgOpen: 0.52, mpOpen: 0.44, coOpen: 0.34, btnOpen: 0.24, sbOpen: 0.36, bbDefend: 0.24,
      threeBetThreshold: 0.69, fourBetThreshold: 0.84,
      // "Presión post-flop": relentless multi-barrels
      cBetFreq: 0.73, doubleBarrelFreq: 0.66, tripleBarrelFreq: 0.52, checkRaiseFreq: 0.26,
      bluffFreq: 0.40, slowplayFreq: 0.18,
      preferredSizings: [0.75, 1.0, 1.25],
      riverOverbetThreshold: 0.72,
      openSizeBB: 2.5,
      probeBetFreq: 0.30, donkBetFreq: 0.12,
      // "Presión incesante": sizes up to leverage the whole stack
      stackPressure: true,
      // "Lectura de debilidad / ataca pasivos": multi-barrels over-folders
      exploitsHighFolders: true,
      // "Explotación psicológica" + "convicción total": profitable-not-GTO
      // conviction, attacks weak players, all-ins regardless of his cards
      freestyleAggressor: true,
    ),
    // 16. Raúl Mestre — The Professor / Strategic Analyst: plays RANGES not cards.
    // Minimises errors, pots control with medium hands, max value with nuts.
    // Exploits by table level: solid vs passives, balanced vs strong players.
    LegendProfile(
      name: 'Raúl',
      style: 'The Professor — Strategic Analyst',
      emoji: '🧠',
      avatarAsset: 'assets/avatars/raul.png',
      // Disciplined preflop: tight-solid ranges, no fancy opens
      utgOpen: 0.68, mpOpen: 0.62, coOpen: 0.54, btnOpen: 0.44, sbOpen: 0.56, bbDefend: 0.42,
      threeBetThreshold: 0.72, fourBetThreshold: 0.88,
      // "Fundamentos ante Todo": standard C-bet, controlled barrels, measured check-raises
      cBetFreq: 0.68, doubleBarrelFreq: 0.54, tripleBarrelFreq: 0.38, checkRaiseFreq: 0.30,
      // Low bluff freq (only when EV-positive), medium slowplay for pot control
      bluffFreq: 0.22, slowplayFreq: 0.28,
      // Standard GTO sizings: no overbets, no tiny blocker bets without reason
      preferredSizings: [0.33, 0.5, 0.75, 1.0],
      riverOverbetThreshold: 0.85,
      openSizeBB: 2.3,
      threeBetBluffFreq: 0.12, squeezeFreq: 0.13,
      blockerBetFreq: 0.18,
      probeBetFreq: 0.25, donkBetFreq: 0.08,
      // "Gestión del Bote": never inflates with medium hands
      potControl: true,
    ),
    // 17. Papo MC "La Bestia" — Freestyle Poker: intimidation, psychological
    // pressure, pattern-breaking. Attacks tight players relentlessly, chaotic
    // sizings, jams on instinct vs perceived weakness. Ignores GTO dogma.
    LegendProfile(
      name: 'Papo',
      style: 'La Bestia — Freestyle Poker',
      emoji: '🎤',
      avatarAsset: 'assets/avatars/papo.png',
      // Wide, fearless preflop ranges from every seat
      utgOpen: 0.52, mpOpen: 0.44, coOpen: 0.34, btnOpen: 0.24, sbOpen: 0.36, bbDefend: 0.22,
      threeBetThreshold: 0.60, fourBetThreshold: 0.78,
      // "Confianza Total": relentless multi-street pressure
      cBetFreq: 0.84, doubleBarrelFreq: 0.70, tripleBarrelFreq: 0.54, checkRaiseFreq: 0.38,
      // "El Factor Sorpresa": very high bluff frequency, rarely slowplays
      bluffFreq: 0.52, slowplayFreq: 0.12,
      // Chaotic sizing menu: tiny stabs to massive overbets
      preferredSizings: [0.33, 0.75, 1.5, 2.5],
      riverOverbetThreshold: 0.58,
      openSizeBB: 2.7, threeBetBluffFreq: 0.22, bluffRaiseFreq: 0.28,
      probeBetFreq: 0.42, donkBetFreq: 0.20,
      polarizedBetting: true, highVarianceDraws: true,
      // "La Bestia": surprise factor + attacks tight players + instinct jams
      freestyleAggressor: true,
    ),
  ];

  /// Style archetypes from the "Tipos de Rivales" index: recreational
  /// passives/aggressives, regs and special profiles.
  static const List<LegendProfile> _archetypes = [
    LegendProfile(
      name: 'Nit', style: 'Roca Ultra-Tight', emoji: '🧊', isArchetype: true,
      utgOpen: 0.78, mpOpen: 0.74, coOpen: 0.68, btnOpen: 0.60, sbOpen: 0.70, bbDefend: 0.55,
      threeBetThreshold: 0.86, fourBetThreshold: 0.94,
      cBetFreq: 0.55, doubleBarrelFreq: 0.35, tripleBarrelFreq: 0.18, checkRaiseFreq: 0.10,
      bluffFreq: 0.04, slowplayFreq: 0.10,
      preferredSizings: [0.5, 0.75], riverOverbetThreshold: 0.97,
      bluffRaiseFreq: 0.0, threeBetBluffFreq: 0.0, floatFreq: 0.04,
      probeBetFreq: 0.06, donkBetFreq: 0.02,
    ),
    LegendProfile(
      name: 'TAG Clásico', style: 'Tight-Aggressive Sólido', emoji: '🎓', isArchetype: true,
      utgOpen: 0.68, mpOpen: 0.62, coOpen: 0.54, btnOpen: 0.45, sbOpen: 0.56, bbDefend: 0.42,
      threeBetThreshold: 0.72, fourBetThreshold: 0.88,
      cBetFreq: 0.68, doubleBarrelFreq: 0.52, tripleBarrelFreq: 0.36, checkRaiseFreq: 0.26,
      bluffFreq: 0.24, slowplayFreq: 0.16,
      preferredSizings: [0.5, 0.66, 0.75], riverOverbetThreshold: 0.85,
      probeBetFreq: 0.20, donkBetFreq: 0.06,
    ),
    LegendProfile(
      name: 'LAG Salvaje', style: 'Loose-Aggressive Total', emoji: '🐺', isArchetype: true,
      utgOpen: 0.50, mpOpen: 0.42, coOpen: 0.32, btnOpen: 0.22, sbOpen: 0.34, bbDefend: 0.20,
      threeBetThreshold: 0.60, fourBetThreshold: 0.78,
      cBetFreq: 0.84, doubleBarrelFreq: 0.70, tripleBarrelFreq: 0.54, checkRaiseFreq: 0.38,
      bluffFreq: 0.52, slowplayFreq: 0.10,
      preferredSizings: [0.66, 1.0, 1.5], riverOverbetThreshold: 0.64,
      openSizeBB: 2.6, threeBetBluffFreq: 0.22, bluffRaiseFreq: 0.24,
      probeBetFreq: 0.38, donkBetFreq: 0.16,
      exploitsHighFolders: true, polarizedBetting: true,
    ),
    LegendProfile(
      name: 'Calling Station', style: 'Recreacional Pasivo', emoji: '🐟', isArchetype: true,
      utgOpen: 0.45, mpOpen: 0.40, coOpen: 0.35, btnOpen: 0.28, sbOpen: 0.35, bbDefend: 0.15,
      threeBetThreshold: 0.88, fourBetThreshold: 0.95,
      cBetFreq: 0.35, doubleBarrelFreq: 0.22, tripleBarrelFreq: 0.12, checkRaiseFreq: 0.06,
      bluffFreq: 0.05, slowplayFreq: 0.30,
      preferredSizings: [0.33, 0.5], riverOverbetThreshold: 0.98,
      bluffRaiseFreq: 0.0, threeBetBluffFreq: 0.0, floatFreq: 0.30, impliedOddsWeight: 1.6,
      probeBetFreq: 0.06, donkBetFreq: 0.06,
      stationCalling: true,
    ),
    LegendProfile(
      name: 'Maniac', style: 'Recreacional Agresivo', emoji: '🤡', isArchetype: true,
      utgOpen: 0.40, mpOpen: 0.34, coOpen: 0.26, btnOpen: 0.16, sbOpen: 0.26, bbDefend: 0.12,
      threeBetThreshold: 0.52, fourBetThreshold: 0.68,
      cBetFreq: 0.92, doubleBarrelFreq: 0.80, tripleBarrelFreq: 0.66, checkRaiseFreq: 0.45,
      bluffFreq: 0.68, slowplayFreq: 0.05,
      preferredSizings: [1.0, 1.5, 2.0, 3.0], riverOverbetThreshold: 0.50,
      openSizeBB: 3.5, threeBetBluffFreq: 0.30, bluffRaiseFreq: 0.36,
      probeBetFreq: 0.55, donkBetFreq: 0.28,
      polarizedBetting: true, highVarianceDraws: true, stackPressure: true,
    ),
    LegendProfile(
      name: 'Fit or Fold', style: 'Recreacional Predecible', emoji: '🚪', isArchetype: true,
      utgOpen: 0.62, mpOpen: 0.56, coOpen: 0.50, btnOpen: 0.42, sbOpen: 0.52, bbDefend: 0.35,
      threeBetThreshold: 0.80, fourBetThreshold: 0.92,
      cBetFreq: 0.45, doubleBarrelFreq: 0.25, tripleBarrelFreq: 0.12, checkRaiseFreq: 0.08,
      bluffFreq: 0.05, slowplayFreq: 0.08,
      preferredSizings: [0.5, 0.75], riverOverbetThreshold: 0.95,
      bluffRaiseFreq: 0.0, threeBetBluffFreq: 0.02, floatFreq: 0.03,
      probeBetFreq: 0.05, donkBetFreq: 0.02,
      fitOrFold: true,
    ),
    LegendProfile(
      name: 'ABC Reg', style: 'Regular de Manual', emoji: '📘', isArchetype: true,
      utgOpen: 0.67, mpOpen: 0.61, coOpen: 0.53, btnOpen: 0.44, sbOpen: 0.55, bbDefend: 0.41,
      threeBetThreshold: 0.74, fourBetThreshold: 0.89,
      cBetFreq: 0.65, doubleBarrelFreq: 0.45, tripleBarrelFreq: 0.28, checkRaiseFreq: 0.18,
      bluffFreq: 0.18, slowplayFreq: 0.14,
      preferredSizings: [0.5, 0.66], riverOverbetThreshold: 0.90,
      threeBetBluffFreq: 0.06,
      probeBetFreq: 0.20, donkBetFreq: 0.06,
    ),
    LegendProfile(
      name: 'Solver Reg', style: 'GTO de Laboratorio', emoji: '🧮', isArchetype: true,
      utgOpen: 0.67, mpOpen: 0.61, coOpen: 0.53, btnOpen: 0.43, sbOpen: 0.55, bbDefend: 0.40,
      threeBetThreshold: 0.69, fourBetThreshold: 0.85,
      cBetFreq: 0.70, doubleBarrelFreq: 0.57, tripleBarrelFreq: 0.43, checkRaiseFreq: 0.33,
      bluffFreq: 0.30, slowplayFreq: 0.17,
      preferredSizings: [0.33, 0.5, 0.75, 1.25], riverOverbetThreshold: 0.76,
      threeBetBluffFreq: 0.16, squeezeFreq: 0.16, blockerBetFreq: 0.18,
      probeBetFreq: 0.28, donkBetFreq: 0.10,
    ),
    LegendProfile(
      name: 'Nit Agresivo', style: 'Rango Cerrado, Postflop Letal', emoji: '🦂', isArchetype: true,
      utgOpen: 0.75, mpOpen: 0.70, coOpen: 0.64, btnOpen: 0.56, sbOpen: 0.66, bbDefend: 0.50,
      threeBetThreshold: 0.80, fourBetThreshold: 0.90,
      cBetFreq: 0.80, doubleBarrelFreq: 0.66, tripleBarrelFreq: 0.50, checkRaiseFreq: 0.36,
      bluffFreq: 0.30, slowplayFreq: 0.12,
      preferredSizings: [0.75, 1.0, 1.5], riverOverbetThreshold: 0.72,
      bluffRaiseFreq: 0.14, threeBetBluffFreq: 0.05,
      probeBetFreq: 0.24, donkBetFreq: 0.08,
      polarizedBetting: true,
    ),
    LegendProfile(
      name: 'Gambler', style: 'Apostador Compulsivo', emoji: '🎰', isArchetype: true,
      utgOpen: 0.48, mpOpen: 0.42, coOpen: 0.34, btnOpen: 0.24, sbOpen: 0.36, bbDefend: 0.18,
      threeBetThreshold: 0.62, fourBetThreshold: 0.78,
      cBetFreq: 0.75, doubleBarrelFreq: 0.60, tripleBarrelFreq: 0.45, checkRaiseFreq: 0.25,
      bluffFreq: 0.40, slowplayFreq: 0.10,
      preferredSizings: [0.75, 1.0, 1.5], riverOverbetThreshold: 0.60,
      impliedOddsWeight: 1.8, threeBetBluffFreq: 0.15, bluffRaiseFreq: 0.18,
      probeBetFreq: 0.36, donkBetFreq: 0.14,
      highVarianceDraws: true,
    ),
  ];

  /// Every profile that can be seated via the table editor.
  static List<LegendProfile> get legends => List.unmodifiable(_allLegends);
  static List<LegendProfile> get archetypes => List.unmodifiable(_archetypes);
  static List<LegendProfile> get allSelectable =>
      [..._allLegends, ..._archetypes];

  static List<LegendProfile> selectTable() {
    final pool = List<LegendProfile>.from(_allLegends)..shuffle(_rng);
    return pool.take(5).toList();
  }

  static LegendProfile profileByName(String name) =>
      allSelectable.firstWhere((p) => p.name == name, orElse: () => _allLegends[0]);

  /// Coarse villain read derived from a legend's style, so the GTO advisor can
  /// exploit a known opponent the same way the bots exploit the human.
  static VillainRead villainReadFor(LegendProfile p) {
    if (p.stationCalling) {
      return const VillainRead(foldToBet: 0.18, callingStation: true);
    }
    if (p.fitOrFold) {
      return const VillainRead(foldToBet: 0.66, overFolds: true);
    }
    return VillainRead.neutral;
  }

  /// Synthesizes a read for a BOT opponent from its known style, so bot-vs-bot
  /// pots don't (wrongly) exploit the HUMAN's tendencies. Seeded — the style is
  /// known a priori, so the read is trusted with moderate confidence from hand
  /// one rather than waiting for observations that never come for bots.
  static HumanReadModel readModelFor(LegendProfile p) {
    final r = villainReadFor(p);
    // Aggression proxy from the profile's betting dials: bluff-happy / high
    // c-bet styles read as more aggressive bettors.
    final aggression =
        (0.6 + p.bluffFreq * 2.2 + (p.cBetFreq - 0.6)).clamp(0.3, 3.5);
    final model = HumanReadModel();
    model.seedFrom({
      'foldVsBet': r.foldToBet * 100,
      'riverFold': r.foldToBet * 100,
      'aggression': aggression,
    });
    return model;
  }

  /// When a bot busts it leaves the table; a fresh legend (not currently
  /// seated) takes the empty seat with a new stack.
  static LegendProfile replacementFor(List<String> seatedNames) {
    final available =
        allSelectable.where((p) => !seatedNames.contains(p.name)).toList();
    if (available.isEmpty) return _allLegends[_rng.nextInt(_allLegends.length)];
    return available[_rng.nextInt(available.length)];
  }

  /// Builds the lineup chosen in the table editor; null slots are filled
  /// with random profiles not already seated.
  static List<LegendProfile> buildLineup(List<String?> slots) {
    final lineup = <LegendProfile>[];
    final used = <String>[];
    for (final name in slots.take(5)) {
      if (name != null && allSelectable.any((p) => p.name == name) &&
          !used.contains(name)) {
        final prof = profileByName(name);
        lineup.add(prof);
        used.add(prof.name);
      }
    }
    final pool = allSelectable.where((p) => !used.contains(p.name)).toList()
      ..shuffle(_rng);
    int i = 0;
    while (lineup.length < 5 && i < pool.length) {
      lineup.add(pool[i++]);
    }
    return lineup;
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
    TablePosition? openerPosition,
    int preflopRaiseCount = 1,
    int villainBarrels = 0,
    bool inPosition = false,
    bool villainCheckedBack = false,
    List<CardModel> prevBoard = const [],
  }) async {
    // "Thinking time": 1-3s, harder spots take longer
    final difficulty = callAmount > currentPot * 0.6 ? 600 : 0;
    int thinkMs = 900 + _rng.nextInt(1400) + difficulty;

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
        openerPosition: openerPosition,
      );
    } else {
      // A bigger bet polarizes the villain's range — narrow the range used for
      // equity accordingly, so bluff-catchers don't overrate themselves vs an overbet.
      final betFrac =
          callAmount > 0 ? callAmount / max(currentPot - callAmount, 1.0) : 0.0;
      // Each prior barrel this hand condenses the villain's range further: a
      // 3rd-barrel river is far stronger than a one-and-done bet of the same size.
      final rangeWidth = ((betFrac > 0.85 ? 0.25 : (betFrac > 0.40 ? 0.33 : 0.40)) -
              villainBarrels * 0.04)
          .clamp(0.18, 0.40);
      final equity = EquityCalculator.calculate(
        heroCards: holeCards,
        communityCards: communityCards,
        numOpponents: max(1, activePlayers - 1),
        simulations: 500,
        rangeWidth: rangeWidth,
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
        inPosition: inPosition,
        activePlayers: activePlayers,
        preflopRaiseCount: preflopRaiseCount,
        street: street,
        bb: bigBlind,
        villainCheckedBack: villainCheckedBack,
        prevBoard: prevBoard,
      );
      decision = _applyDifficulty(decision, equity, callAmount);
      decision = _snapBotBet(decision);
      if (decision.type == ActionType.fold && equity < 0.12) {
        thinkMs = 250 + _rng.nextInt(400); // easy fold, no need to tank
      } else if (callAmount > 0 &&
          (equity - GtoMath.potOdds(callAmount, currentPot)).abs() < 0.05) {
        thinkMs += 600 + _rng.nextInt(800); // genuinely close spot, tank longer
      }
    }

    await Future.delayed(Duration(milliseconds: min(thinkMs, 2900)));
    return BotDecision(type: decision.type, amount: decision.amount, thinkMs: thinkMs);
  }

  /// Rounds bot bet/raise sizes to the nearest $2 — real players bet round
  /// numbers, not "$37.40". All-ins keep the exact stack amount.
  static BotDecision _snapBotBet(BotDecision d) {
    if (d.type != ActionType.bet && d.type != ActionType.raise) return d;
    final snapped = d.amount < 2 ? d.amount : (d.amount / 2).round() * 2.0;
    return BotDecision(type: d.type, amount: snapped, thinkMs: d.thinkMs);
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
    TablePosition? openerPosition,
  }) {
    final code = PreflopCharts.handCode(hole);
    final rfiPlan = PreflopCharts.rfi(position, code);
    final defensePlan = PreflopCharts.defense(position, code);
    final strength = CardModel.preflopStrength(hole);
    final rand = _rng.nextDouble();

    // Personality drift around the chart: loose profiles (Dwan, Maniac)
    // add hands the chart folds; tight ones (Hellmuth, Nit) trim the bottom.
    final looseness = (0.40 - profile.btnOpen).clamp(-0.25, 0.25).toDouble();
    final posThreshold = _openThreshold(profile, position);
    final stackBBs = stack / bb;

    // Safe clamp: when the stack is shorter than one BB the lower bound would
    // exceed the upper bound and Dart's clamp() throws — collapse to all-in.
    double clampTo(double v) => v.clamp(min(bb, stack), stack).toDouble();
    final potOdds = GtoMath.potOdds(callAmount, pot);
    final inPosition = position == TablePosition.btn || position == TablePosition.co;

    // ── Short-stack adjustment: simplify to push/fold at ≤25BB ──────────────
    if (stackBBs <= 25 && callAmount > 0) {
      // Push range tightens more for nits/TAGs, looser for maniacs/LAGs
      final pushThresh = posThreshold + (looseness < 0 ? 0.08 : -0.04);
      if (strength >= pushThresh) {
        return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
      }
      return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
    }

    // ── Deep-stack adjustment: implied odds matter more ──────────────────────
    // At >150BB, small pairs and suited connectors gain value for all profiles.
    final impliedOddsBoost = stackBBs > 150 ? 0.04 : 0.0;

    // ───── Unopened pot: RFI using GTO frequency + profile drift ─────
    if (raiseCount == 0) {
      if (callAmount <= 0) {
        // BB option: iso-raise the top of range at mixed frequency
        if (strength >= posThreshold + 0.18 && rand < 0.55) {
          return BotDecision(
            type: ActionType.raise,
            amount: clampTo(profile.openSizeBB * bb + callers * bb),
            thinkMs: 0,
          );
        }
        return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
      }

      // Use GTO mixed-frequency from OpenRaiseDB as the base probability.
      final gtoOpenFreq = position != TablePosition.bb
          ? OpenRaiseDB.openFrequency(position, code)
          : 0.0;
      bool opens;
      if (gtoOpenFreq >= 1.0) {
        opens = true;
        // Tight drift: drop weakest pure opens (Hellmuth/Nit)
        if (rfiPlan == ChartAction.orFold && looseness < -0.08 &&
            strength < posThreshold + 0.02 && rand < -looseness * 1.5) {
          opens = false;
        }
      } else if (gtoOpenFreq <= 0.0) {
        opens = false;
        // Loose drift: open some GTO-folds with playable hands
        if (looseness > 0 &&
            strength >= posThreshold - 0.06 - impliedOddsBoost &&
            rand < looseness * 2.2) {
          opens = true;
        }
      } else {
        // Mixed GTO hand — apply profile bias around the GTO frequency
        final profileFreq = (gtoOpenFreq + looseness * 0.5).clamp(0.0, 1.0);
        opens = rand < profileFreq;
      }

      if (opens) {
        // Deep-stack: open bigger to discourage drawing callers
        final sizeMod = stackBBs > 150 ? 0.3 : 0.0;
        return BotDecision(
          type: ActionType.raise,
          amount: clampTo((profile.openSizeBB + sizeMod) * bb + callers * bb),
          thinkMs: 0,
        );
      }
      // SB completes with some playable hands behind the discount
      if (position == TablePosition.sb &&
          strength >= posThreshold - 0.14 && rand < 0.40) {
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }
      return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
    }

    final iOpenedThisHand = myStreetBet > bb || (myStreetBet == bb && position != TablePosition.bb);

    // ───── Facing a 3-bet of our own open: follow the RFI plan ─────
    if (raiseCount >= 2 && iOpenedThisHand) {
      switch (rfiPlan) {
        case ChartAction.fourBetCall:
          final to = clampTo(currentBet * 2.3);
          if (to >= stack * 0.40 || raiseCount >= 3) {
            return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
          }
          return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
        case ChartAction.fourBetFold:
          if (raiseCount >= 3) {
            return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
          }
          return BotDecision(
            type: ActionType.raise, amount: clampTo(currentBet * 2.3), thinkMs: 0);
        case ChartAction.orCall3B:
          if (callAmount <= stack * 0.30) {
            return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
          }
          return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
        default:
          // Sticky stations peel anyway when priced in
          if (profile.stationCalling && strength >= potOdds + 0.10) {
            return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
          }
          return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
      }
    }

    // ───── Facing an open raise: defense chart ─────
    if (raiseCount == 1) {
      final isSqueezeSpot = callers > 0;
      // Opener-position awareness: tighten vs early opens, widen vs late/blind.
      final openerTight = _openerTightness(openerPosition);
      switch (defensePlan) {
        case DefenseAction.threeBetFiveBet:
          final mult = (inPosition ? 3.0 : 3.8) + callers * 1.0;
          return BotDecision(
            type: ActionType.raise, amount: clampTo(currentBet * mult), thinkMs: 0);
        case DefenseAction.threeBetCall4B:
          final mult = (inPosition ? 3.0 : 3.8) + callers * 1.0;
          if (isSqueezeSpot && rand > profile.squeezeFreq + 0.55) {
            return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
          }
          return BotDecision(
            type: ActionType.raise, amount: clampTo(currentBet * mult), thinkMs: 0);
        case DefenseAction.threeBetFold:
          // Polar bluff 3-bet at the profile's light 3-bet frequency, fired less
          // vs early openers (stronger continuing range), more vs late opens.
          // Squeeze awareness: every caller behind the open is another player who
          // must fold for the bluff to work — crush the bluff frequency multiway.
          final squeezeBluffMult =
              PostflopContext.multiwayBluffMultiplier(2 + callers);
          final bluffFreq =
              (profile.threeBetBluffFreq * 2.2 * (1 - openerTight * 3.0) *
                      squeezeBluffMult)
                  .clamp(0.0, 1.0);
          if (rand < bluffFreq && !profile.stationCalling) {
            final mult = (inPosition ? 3.0 : 4.0) + callers * 1.0;
            return BotDecision(
              type: ActionType.raise, amount: clampTo(currentBet * mult), thinkMs: 0);
          }
          // Otherwise these hands play fine as calls when cheap
          if (callAmount <= 3 * bb && strength >= potOdds + 0.12 + openerTight) {
            return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
          }
          return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
        case DefenseAction.call:
          // Set mining check: tiny pairs need implied odds behind
          final isPocketPair = hole[0].rank == hole[1].rank;
          if (isPocketPair && hole[0].rank <= 6 &&
              stack / max(callAmount, bb) < 12 / profile.impliedOddsWeight) {
            return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
          }
          // vs an early-position opener the weakest non-pair flats are folds
          // (their range dominates ours); vs late opens we keep flatting.
          if (openerTight >= 0.07 && !isPocketPair &&
              strength < potOdds + 0.10 + openerTight && rand < 0.6) {
            return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
          }
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        case DefenseAction.fold:
          // Loose drift: stations and LAGs peel wider — and everyone defends a
          // bit wider vs a late/blind opener (openerTight negative).
          if ((profile.stationCalling || looseness > 0.10 || openerTight < -0.04) &&
              callAmount <= 3 * bb && strength >= potOdds + 0.15 + openerTight &&
              rand < 0.5) {
            return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
          }
          return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
      }
    }

    // ───── Cold facing a 3-bet+ (we have not raised yet) ─────
    if (defensePlan == DefenseAction.threeBetFiveBet) {
      final to = clampTo(currentBet * 2.3);
      if (to >= stack * 0.40 || raiseCount >= 3) {
        return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
      }
      return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
    }
    if (defensePlan == DefenseAction.threeBetCall4B && callAmount <= stack * 0.25) {
      return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
    }
    if (profile.stationCalling && strength >= potOdds + 0.08 &&
        callAmount <= stack * 0.20) {
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
    int activePlayers = 2,
    int preflopRaiseCount = 1,
    bool inPosition = false,
    bool villainCheckedBack = false,
    List<CardModel> prevBoard = const [],
  }) {
    final texture = BoardTexture.analyze(board);
    final analysis = HandStrengthAnalysis.analyze(hole, board);
    final blockers = Blockers.analyze(hole, board);
    final spr = GtoMath.spr(stack, pot);
    final rand = _rng.nextDouble();
    final isRiver = street == 'river';
    final isTurnOrRiver = street == 'turn' || isRiver;
    final stackBBsPost = stack / bb;
    final drawCompleted = prevBoard.isNotEmpty && board.isNotEmpty
        ? BoardTexture.drawCompletedOn(prevBoard, board.last)
        : false;

    // Scare card: the board just PAIRED on this street (turn/river), so trips and
    // full houses now live in the villain's range. Devalue our non-nut made hands
    // — stack off less readily and tighten bluff-catchers (no effect on a board
    // that was already paired on the flop).
    final pairedOnStreet = isTurnOrRiver &&
        prevBoard.isNotEmpty &&
        texture.paired &&
        !BoardTexture.analyze(prevBoard).paired;
    final scareValueShift = pairedOnStreet ? 0.03 : 0.0;
    final scareCommitTighten = pairedOnStreet ? 0.5 : 0.0;

    // Pot type (SRP / 3-bet / 4-bet+): ranges get stronger, narrower and more
    // polarized as the preflop raising escalates. The 3-bettor's range is
    // condensed and nut-heavy, so the OOP caller's range advantage shrinks,
    // bluff-catchers must tighten, and value hands stack off wider (low SPR,
    // strong ranges on both sides).
    final potType = PostflopContext.potTypeFromRaiseCount(preflopRaiseCount);
    final potValueShift = potType == PotType.fourBetPlus ? 0.06
        : potType == PotType.threeBet ? 0.03 : 0.0;
    final potCommitBoost = potType == PotType.fourBetPlus ? 1.0
        : potType == PotType.threeBet ? 0.6 : 0.0;
    final potDefAdvMult = potType == PotType.fourBetPlus ? 0.4
        : potType == PotType.threeBet ? 0.65 : 1.0;
    final defAdv =
        RangeModel.defenderRangeAdvantage(texture) * potDefAdvMult;

    // Multiway dampens pure bluffs (every extra player is another fold you
    // need) and raises the bar to stack off/bluff-catch thin.
    final mwBluffMult = PostflopContext.multiwayBluffMultiplier(activePlayers);
    final mwValueShift = PostflopContext.multiwayValueShift(activePlayers);

    // ── Phil Ivey "El Observador": build a read before exploiting.
    // With low confidence (<30%), plays close to GTO baseline.
    // With enough reads, adapts aggressively to every detected weakness.
    // vs calling station → maximises value, never bluffs.
    // vs over-folder → barrels turn/river without hesitation.
    // vs aggressive human → slows down, check-raises more, traps.
    double iveyExploitMult = 1.0; // multiplies exploit frequency
    if (profile.readsOpponent) {
      final conf = human.confidence;
      iveyExploitMult = conf < 0.30
          ? 0.55  // not enough data: plays GTO-ish
          : (0.55 + conf * 1.45).clamp(0.6, 2.0); // ramps hard with reads
    }

    // ── Raúl Mestre "Explotación por Nivel": adapts play to table strength.
    // vs passive/weak (calling station or high folder): value-heavy, minimal bluffs.
    // vs strong/aggressive: stays balanced GTO, no leaks.
    // "Sin sesgos": ignores past results — every hand is a fresh EV calculation.
    // "Pensamiento en Rangos": commitment decisions are range-vs-range, not hand-vs-hand.
    double raulBluffMult = 1.0;
    double raulValueMult = 1.0;
    if (profile.potControl && human.confidence >= 0.30) {
      if (human.isCallingStation) {
        raulBluffMult = 0.25; // weak table: barely bluff, extract max value
        raulValueMult = 1.30; // bigger sizing for value vs station
      } else if (human.overFolds) {
        raulBluffMult = 1.40; // passive: fire more when they fold too much
        raulValueMult = 1.10;
      } else if (human.aggressionFactor > 1.8) {
        raulBluffMult = 0.80; // strong player: stay GTO, don't over-bluff
        raulValueMult = 0.95;
      }
    }

    // ── Papo MC "La Bestia": freestyle pressure & intimidation.
    // "Presión de Límites": vs tight/over-folding humans, attacks ruthlessly.
    // "El Factor Sorpresa": injects sizing chaos to break opponent reads.
    // "Irreverente": jams on instinct vs perceived weakness, ignoring strict math.
    double papoBluffMult = 1.0;
    double papoSizingChaos = 1.0; // random multiplier on bluff bet sizing
    if (profile.freestyleAggressor) {
      // Surprise factor: chaotic sizing on every bluff (0.7x - 1.6x)
      papoSizingChaos = 0.7 + _rng.nextDouble() * 0.9;
      // Attacks tight players: over-folders or low aggression get hammered
      if (human.overFolds || (human.confidence >= 0.30 && human.aggressionFactor < 0.9)) {
        papoBluffMult = 1.50;
      }
      // vs calling station he reins it in (instinct still respects a payer)
      if (human.isCallingStation) papoBluffMult = 0.45;
    }

    // Villain fold estimate (exploit input for all bluff math)
    double foldEst = isTurnOrRiver ? human.foldVsBarrelRate : human.foldVsBetRate;
    if (human.isCallingStation) foldEst *= 0.55;
    // Papo plays his bluffs with conviction — treats villain as foldier than real
    if (profile.freestyleAggressor && !human.isCallingStation) {
      foldEst = (foldEst + 0.12).clamp(0.0, 0.95);
    }

    // Profile-specific SPR commitment threshold: the SPR at or below which this
    // profile will stack-off with the given hand bucket.
    //   Calling Station: commits much earlier (SPR 4 with medium value)
    //   Nit / Hellmuth: needs SPR ≤1.8 for strongValue, never commits thin
    //   Maniac / LAG: commits wide at SPR ≤4 even with medium hands
    //   TAG / GTO: standard SPR 2.5 for strongValue, 1.5 for medium
    final commitSprStrong = profile.stationCalling ? 4.5
        : (profile.fitOrFold || profile.bluffFreq < 0.10) ? 1.8
        : profile.bluffFreq > 0.48 ? 4.0
        : 2.8;
    final commitSprMedium = profile.stationCalling ? 3.0
        : (profile.fitOrFold || profile.bluffFreq < 0.10) ? 1.0
        : profile.bluffFreq > 0.48 ? 2.5
        : 1.5;

    // Multiway: need a bigger edge to commit (more live hands could be ahead).
    // 3-bet/4-bet pots: ranges are stronger and SPR lower, so stack off WIDER.
    final mwCommitTighten = activePlayers >= 4 ? 1.0 : (activePlayers == 3 ? 0.5 : 0.0);
    final netCommitAdjust = potCommitBoost - mwCommitTighten - scareCommitTighten;
    final commitSprStrongMw = (commitSprStrong + netCommitAdjust)
        .clamp(1.0, commitSprStrong + potCommitBoost);
    final commitSprMediumMw = (commitSprMedium + netCommitAdjust)
        .clamp(0.6, commitSprMedium + potCommitBoost);

    // Safe clamp (see _preflopDecision): avoid low>high crash on short stacks.
    double clampBet(double v) => v.clamp(min(bb, stack), stack).toDouble();

    // ════════════ NO BET TO FACE: bet or check ════════════
    if (callAmount <= 0) {
      // ── OOP Probe bet: IP checked back last street → fire to exploit weakness ──
      if (!inPosition && villainCheckedBack && !wasAggressor) {
        switch (analysis.bucket) {
          case HandBucket.nuts:
          case HandBucket.strongValue:
            return BotDecision(
              type: ActionType.bet,
              amount: clampBet(_valueSize(profile, pot, texture, street, spr: spr, nut: analysis.bucket == HandBucket.nuts)),
              thinkMs: 0,
            );
          case HandBucket.mediumValue:
            if (rand < profile.probeBetFreq * 0.75) {
              return BotDecision(type: ActionType.bet, amount: clampBet(pot * 0.40), thinkMs: 0);
            }
            break;
          case HandBucket.comboDraw:
          case HandBucket.strongDraw:
            if (!isRiver && rand < profile.probeBetFreq) {
              return BotDecision(type: ActionType.bet, amount: clampBet(pot * 0.55), thinkMs: 0);
            }
            break;
          case HandBucket.weakDraw:
          case HandBucket.weakShowdown:
            if (!isRiver && rand < profile.probeBetFreq * 0.45) {
              return BotDecision(type: ActionType.bet, amount: clampBet(pot * 0.33), thinkMs: 0);
            }
            break;
          case HandBucket.air:
            if (!isRiver && blockers.goodBluffBlockers && rand < profile.probeBetFreq * 0.30) {
              return BotDecision(type: ActionType.bet, amount: clampBet(pot * 0.40), thinkMs: 0);
            }
            break;
        }
      }

      // ── OOP Donk bet: leading into the preflop aggressor. Real players donk
      //    RARELY and only on textures that genuinely favour the defender's
      //    range — low/connected/paired boards (e.g. 765, 543, 884) — never on
      //    ace-high or broadway-heavy boards where the raiser's range crushes.
      //    Gate is strict (high defender advantage AND favourable texture) and
      //    frequencies are low, so the lead is reserved for strong made hands
      //    that want to build a pot OOP and the occasional strong draw, instead
      //    of firing into the aggressor on any board with a slight edge.
      final donkFavorableTexture = (texture.low || texture.connected || texture.paired) &&
          !texture.aceHigh &&
          !texture.broadwayHeavy;
      if (!inPosition && !wasAggressor && !villainCheckedBack &&
          defAdv > 0.18 && donkFavorableTexture && !profile.fitOrFold) {
        switch (analysis.bucket) {
          case HandBucket.nuts:
          case HandBucket.strongValue:
            if (rand < profile.donkBetFreq) {
              return BotDecision(
                type: ActionType.bet,
                amount: clampBet(_valueSize(profile, pot, texture, street, spr: spr, nut: analysis.bucket == HandBucket.nuts)),
                thinkMs: 0,
              );
            }
            break;
          case HandBucket.mediumValue:
            if (rand < profile.donkBetFreq * 0.4) {
              return BotDecision(type: ActionType.bet, amount: clampBet(pot * 0.33), thinkMs: 0);
            }
            break;
          case HandBucket.comboDraw:
          case HandBucket.strongDraw:
            if (!isRiver && rand < profile.donkBetFreq * 0.7) {
              return BotDecision(type: ActionType.bet, amount: clampBet(pot * 0.50), thinkMs: 0);
            }
            break;
          default:
            break;
        }
      }

      // SPR commitment: short SPR + made value → get it in
      if (spr < 1.3 && analysis.isMadeValue) {
        return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
      }

      switch (analysis.bucket) {
        case HandBucket.nuts:
          // Phil vs calling station: never slow-play, maximise value now.
          // Phil vs aggressive human: trap more often (check-raise setup).
          final iveyTrapVsAgg = profile.readsOpponent &&
              human.aggressionFactor > 1.8 && human.confidence > 0.35;
          if (iveyTrapVsAgg && rand < 0.55) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          final skipSlowplay = profile.readsOpponent && human.isCallingStation;
          if (!skipSlowplay && texture.wetness < 0.35 && rand < profile.slowplayFreq) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          // Phil vs station: size up to extract maximum value
          final nutsSize = (profile.readsOpponent && human.isCallingStation)
              ? clampBet(pot * 0.90)
              : clampBet(_valueSize(profile, pot, texture, street, spr: spr, nut: true) * raulValueMult);
          return BotDecision(type: ActionType.bet, amount: nutsSize, thinkMs: 0);

        case HandBucket.strongValue:
          // Phil vs aggressive human: check to induce bluffs
          final iveyInduceVsAgg = profile.readsOpponent &&
              human.aggressionFactor > 2.0 && human.confidence > 0.40 && rand < 0.45;
          if (iveyInduceVsAgg) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          // IP balance: occasionally check back strong value on dry boards to protect range
          if (inPosition && texture.wetness < 0.30 && rand < profile.slowplayFreq * 0.5) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          if (!inPosition && texture.wetness < 0.30 && rand < profile.slowplayFreq * 0.5) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          final strongSize = (profile.readsOpponent && human.isCallingStation)
              ? clampBet(pot * 0.75)
              : clampBet(_valueSize(profile, pot, texture, street, spr: spr, nut: false) * raulValueMult);
          return BotDecision(type: ActionType.bet, amount: strongSize, thinkMs: 0);

        case HandBucket.mediumValue:
          // Adrián "Polarización": medium value is checked, not bet small.
          // He only bets big (nuts/bluff). Medium hands go to check-call/check-fold.
          if (profile.polarizedBetting && !profile.potControl) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          // River polarization: medium value rarely bets river — check or small blocker only
          if (isRiver) {
            final riverBetFreq = profile.potControl
                ? profile.blockerBetFreq * 2.0
                : profile.blockerBetFreq;
            if (rand < riverBetFreq) {
              return BotDecision(
                type: ActionType.bet,
                amount: clampBet(pot * (profile.potControl ? 0.30 : 0.38)),
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
          // Delayed stab without initiative — blocker bonus: holding blockers
          // to villain's nuts makes weak-draw stabs more viable
          if (!isRiver && !wasAggressor &&
              rand < profile.floatFreq * (blockers.goodBluffBlockers ? 1.2 : 0.7)) {
            return BotDecision(
              type: ActionType.bet,
              amount: clampBet(pot * 0.5),
              thinkMs: 0,
            );
          }
          return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);

        case HandBucket.weakShowdown:
          // IP blocker stab: use weak showdown value to set own price
          if (!isRiver && inPosition && blockers.goodBluffBlockers &&
              rand < profile.floatFreq * 0.9) {
            return BotDecision(type: ActionType.bet, amount: clampBet(pot * 0.33), thinkMs: 0);
          }
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
          // Fit-or-fold never fires without a piece
          if (profile.fitOrFold) {
            return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
          }
          return _airBetOrCheck(
            profile: profile,
            texture: texture,
            blockers: blockers,
            pot: pot,
            stack: stack,
            foldEst: foldEst,
            human: human,
            wasAggressor: wasAggressor,
            inPosition: inPosition,
            street: street,
            bb: bb,
            iveyExploitMult: iveyExploitMult,
            raulBluffMult: raulBluffMult,
            papoBluffMult: papoBluffMult,
            papoSizingChaos: papoSizingChaos,
            drawCompleted: drawCompleted,
            multiwayBluffMult: mwBluffMult,
          );
      }
    }

    // ════════════ FACING A BET ════════════
    final potOdds = GtoMath.potOdds(callAmount, pot);
    final betFraction = callAmount / max(pot - callAmount, 1.0);
    final isOverbet = betFraction > 1.0;
    final isSmallBet = betFraction <= 0.40;
    final isMediumBet = betFraction > 0.40 && betFraction <= 0.85;
    final facingAllInPrice = callAmount >= stack;
    // OOP check-raise multiplier: wet boards reward semi-bluff check-raises OOP
    final oopCRMult = (!inPosition && !wasAggressor && texture.wetness > 0.45) ? 1.40 : 1.0;
    // Position-adjusted equity realization: IP draws worth more, OOP draws worth less
    final eqReal = inPosition ? 1.15 : 0.85;

    // ── Archetype-specific bet-size reactions ────────────────────────────────
    // Calling station: pays anything with a piece, adjusts marginally vs overbets
    if (profile.stationCalling) {
      if (analysis.bucket == HandBucket.air) {
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
      }
      // Stations fold vs overbets if they only have a weak draw (rare but real)
      if (isOverbet && analysis.bucket == HandBucket.weakDraw &&
          equity < potOdds - 0.08) {
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
      }
      if (equity >= potOdds - 0.10 && callAmount < stack) {
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
      }
    }

    // Nit / tight profiles: fold marginals to overbets, never gamble
    if (profile.bluffFreq < 0.10 && isOverbet) {
      if (analysis.bucket == HandBucket.mediumValue ||
          analysis.bucket == HandBucket.weakShowdown) {
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
      }
    }

    // Short-stack facing a large bet: commit or fold logic
    if (stackBBsPost < 20 && callAmount >= stack * 0.35) {
      if (analysis.isMadeValue && equity >= 0.30) {
        return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
      }
      return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
    }

    // ── Facing an ALL-IN at a deep stack: NO loose hero-calls. A shove gives no
    // implied odds and its range is strong/polarised, so a mediocre hand (Tx,
    // third pair, ace-high) that only beats bluffs must FOLD unless it holds a
    // genuinely strong made hand, a priced-in draw, or a real blocker that turns
    // a decent made hand into a credible bluff-catcher. Calling stations exempt.
    if (facingAllInPrice && !profile.stationCalling) {
      final strongMade = analysis.bucket == HandBucket.nuts ||
          analysis.bucket == HandBucket.strongValue;
      final pricedDraw = !isRiver &&
          (analysis.bucket == HandBucket.comboDraw ||
              (analysis.hasStrongDraw &&
                  analysis.drawEquity * eqReal >= potOdds));
      // Bluff-catch a shove only with a real made hand AND a blocker to value.
      final blockerCatch = analysis.bucket == HandBucket.mediumValue &&
          blockers.goodBluffBlockers &&
          equity >= potOdds;
      if (!strongMade && !pricedDraw && !blockerCatch) {
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
      }
    }

    // Fit-or-fold: without at least medium value, the hand goes to the muck
    if (profile.fitOrFold &&
        !analysis.isMadeValue &&
        !(analysis.hasStrongDraw && GtoMath.potOdds(callAmount, pot) <= analysis.drawEquity)) {
      return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);
    }

    // SPR-based early commitment for value hands
    if (analysis.bucket == HandBucket.strongValue && spr <= commitSprStrongMw && !isRiver) {
      return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
    }
    if (analysis.bucket == HandBucket.mediumValue && spr <= commitSprMediumMw && !isRiver) {
      return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
    }

    // Safe raise sizing: if the stack can't cover a min-raise (currentBet+2bb),
    // the lower bound would exceed the stack and clamp() would throw — collapse
    // the lower bound to the stack so the "raise" becomes an all-in shove.
    double raiseTo() => (currentBet * 2.8)
        .clamp(min(currentBet + 2 * bb, stack), stack)
        .toDouble();

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
        final raiseFreq = (isRiver ? 0.20 : 0.40) +
            (wasAggressor ? 0.0 : profile.checkRaiseFreq * (isRiver ? 0.3 : 0.6) * oopCRMult);
        if (rand < raiseFreq && !facingAllInPrice) {
          final to = raiseTo();
          if (to >= stack * 0.85) {
            return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
          }
          return BotDecision(type: ActionType.raise, amount: to, thinkMs: 0);
        }
        return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);

      case HandBucket.mediumValue:
        // Bluff-catcher math: MDF defense vs small bets, tighten vs overbets.
        // Nits over-fold overbets; LAGs/stations call wider; GTO uses pure MDF.
        double callThreshold = potOdds;
        if (isSmallBet) {
          callThreshold -= profile.stationCalling ? 0.10 : 0.05; // wide vs small
        }
        if (isOverbet) {
          // Nit folds to overbets except with good blockers
          final nit = profile.bluffFreq < 0.12;
          callThreshold += nit ? 0.10 : (blockers.topCardBlocker ? 0.02 : 0.06);
        }
        if (human.aggressionFactor > 2.0) callThreshold -= 0.03; // they bluff a lot
        // Symmetric read: a passive villain rarely bluffs, so their bets are
        // value-weighted → fold more bluff-catchers against them.
        if (human.aggressionFactor < 0.8 || human.overFolds) callThreshold += 0.04;
        // Board texture: on monotone/paired boards tighten (risk of flush/full)
        if (texture.wetness > 0.65) callThreshold += 0.04;
        // POSITION: in position we realise more equity and control the pot, so we
        // defend our bluff-catchers wider (real MDF). Out of position we tighten.
        callThreshold += inPosition ? -0.05 : 0.025;
        callThreshold += mwValueShift; // more live hands behind → defend tighter
        callThreshold += potValueShift; // 3-bet+ pot → villain range stronger
        callThreshold += scareValueShift; // board just paired → trips/boats live
        // Anti-overfold floor: bluff-catchers must defend enough vs normal bets
        // to not be exploitable. Only true overbets get the disciplined fold.
        // On the river the bettor's range is polarised (value + bluffs), so the
        // generic equity (vs a 40% range) overstates a medium hand — no MDF
        // discount there: require real equity instead of hero-calling light.
        final floorDiscount = (isRiver && !isSmallBet)
            ? 0.0
            : (inPosition ? 0.07 : 0.03);
        if (!isOverbet && human.aggressionFactor >= 1.0 &&
            equity >= potOdds - floorDiscount) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        // Read-driven hero-calls: trusting the read over the math. Hellmuth
        // "White Magic" and Moneymaker's fearless intuition both pay off an
        // aggressive villain lighter when they sense a bluff.
        if (profile.whiteMagicReader || profile.highVarianceDraws) {
          if (human.aggressionFactor > 1.5 && human.confidence >= 0.30 && !isOverbet) {
            callThreshold -= 0.07; // reads the bluff, pays off
          }
        }
        // "Defensa del Stack": only Hellmuth ducks the variance, folding marginal
        // overbets for survival. Fearless gamblers (Moneymaker) never do.
        if (profile.whiteMagicReader && !profile.highVarianceDraws &&
            isOverbet && !blockers.topCardBlocker) {
          callThreshold += 0.08; // survival first: don't risk stack on a guess
        }
        if (equity >= callThreshold) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);

      case HandBucket.comboDraw:
        if (profile.highVarianceDraws && !isRiver && rand < 0.50) {
          return BotDecision(type: ActionType.allIn, amount: stack, thinkMs: 0);
        }
        if (!isRiver && rand < (profile.checkRaiseFreq + 0.25) * oopCRMult && foldEst > 0.35) {
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
        // Implied-odds weighted draw equity (Brunson: 1.5x) with position adjustment
        final effectiveEq = analysis.drawEquity * profile.impliedOddsWeight * eqReal;
        // Semi-bluff check-raise with fold equity (Chidwick technical raises)
        if (rand < profile.checkRaiseFreq * 0.8 * oopCRMult && foldEst > 0.40) {
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
        // FLOAT: call now planning to take the pot away on a later street when the
        // opponent gives up. In position this is a core weapon — float wider on
        // flop AND turn; out of position float much less (we can't realise it).
        final floatFreqEff = inPosition ? profile.floatFreq * 1.8 : profile.floatFreq * 0.45;
        if ((isSmallBet || isMediumBet) && rand < floatFreqEff) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        // Direct implied-odds call when the draw is priced in (position-adjusted)
        if ((isSmallBet || isMediumBet) &&
            analysis.drawEquity * profile.impliedOddsWeight * eqReal >= potOdds) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);

      case HandBucket.weakShowdown:
        // Small bet: defend per MDF; medium bet: position-aware; overbet: fold
        if (isSmallBet && equity >= potOdds - (inPosition ? 0.04 : 0.0)) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        // In position we defend weak showdown vs medium bets too (MDF) — but
        // only preflop/flop/turn, where equity can still be realised. On the
        // river a weak pair (third pair, Tx, ace-high) only beats bluffs and the
        // betting range is polarised, so hero-calling a real medium bet is a
        // spew. Fold it there unless we hold a blocker to the villain's value.
        if (isMediumBet && !isRiver &&
            equity >= potOdds + (inPosition ? -0.01 : 0.03)) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        if (isMediumBet && isRiver && blockers.goodBluffBlockers &&
            equity >= potOdds + 0.02) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        // Hellmuth "White Magic": picks off aggressive bluffers with weak showdown,
        // but only when it doesn't endanger the stack (never vs overbets).
        final magicCallGate = (profile.whiteMagicReader && human.confidence >= 0.30)
            ? 1.7
            : 2.5;
        if (human.aggressionFactor > magicCallGate && equity >= potOdds - 0.02 && !isOverbet) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
        }
        return const BotDecision(type: ActionType.fold, amount: 0, thinkMs: 0);

      case HandBucket.air:
        // Pure bluff-raise: needs blockers + fold equity.
        // Hellmuth never does this (bluffRaiseFreq = 0); Ivey ramps vs over-folders
        // scaled by how many hands of reads he has ("El Observador").
        double bluffRaiseFreq = profile.bluffRaiseFreq;
        if (profile.exploitsHighFolders && human.overFolds && isTurnOrRiver) {
          bluffRaiseFreq = max(bluffRaiseFreq, 0.55 * iveyExploitMult);
        }
        // Papo "Irreverente": jams on instinct vs perceived weakness. When the
        // human folds too much, he raises air far beyond what strict math allows.
        if (profile.freestyleAggressor && human.overFolds && isTurnOrRiver) {
          bluffRaiseFreq = max(bluffRaiseFreq, 0.50);
        }
        if (human.isCallingStation) bluffRaiseFreq *= 0.2;
        bluffRaiseFreq *= mwBluffMult; // fewer profitable pure bluffs with more live opponents
        final alphaNeeded = GtoMath.alpha(pot, raiseTo() - callAmount);
        // Papo respects blockers loosely — conviction over precision
        final papoLooseGate = profile.freestyleAggressor && human.overFolds
            ? 0.55
            : 0.75;
        final blockerGate = profile.freestyleAggressor
            ? (blockers.goodBluffBlockers || rand < 0.30)
            : blockers.goodBluffBlockers;
        // A pure-air bluff-raise must stay a RAISE, never a stack-off. If 2.8x
        // the bet would commit most of our stack, jamming air (e.g. 79o, KJo)
        // is never a credible line — give up the bluff instead of shoving.
        if (blockerGate && !facingAllInPrice &&
            raiseTo() < stack * 0.60 &&
            rand < bluffRaiseFreq && foldEst >= alphaNeeded * papoLooseGate) {
          return BotDecision(type: ActionType.raise, amount: raiseTo(), thinkMs: 0);
        }
        // FLOAT IP with air: in position vs a small flop/turn stab, call with good
        // blockers planning to take it away later. OOP air just folds.
        if (inPosition && !isRiver && isSmallBet && !facingAllInPrice &&
            blockers.goodBluffBlockers &&
            !profile.fitOrFold && profile.bluffFreq >= 0.15 &&
            rand < profile.floatFreq * 1.2) {
          return BotDecision(type: ActionType.call, amount: callAmount, thinkMs: 0);
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
    double iveyExploitMult = 1.0,
    double raulBluffMult = 1.0,
    double papoBluffMult = 1.0,
    double papoSizingChaos = 1.0,
    double multiwayBluffMult = 1.0,
    bool inPosition = false,
    bool drawCompleted = false,
  }) {
    final rand = _rng.nextDouble();
    final isRiver = street == 'river';
    final rangeAdv = wasAggressor ? RangeModel.aggressorRangeAdvantage(texture) : -0.05;

    double bluffFreq;
    if (wasAggressor) {
      // Has initiative → c-bet / barrel at street frequency
      bluffFreq = _streetCBetFreq(profile, street) * (1 + rangeAdv * 1.4);
      // Wet boards: reduce bluff freq for tight profiles; LAG maintains pressure
      bluffFreq *= texture.wetness < 0.4 ? 1.15 : (profile.bluffFreq > 0.40 ? 0.85 : 0.70);
      // In position with initiative: keep the foot on the gas
      if (inPosition) bluffFreq *= 1.12;
    } else {
      // No initiative but checked to → STAB. In position this is a big edge.
      // Blocker bonus: holding blockers to villain's strong hands makes OOP
      // stabs more viable (reduces risk of running into the nuts).
      final stabBase = profile.floatFreq * (texture.wetness < 0.4 ? 1.0 : 0.55);
      bluffFreq = inPosition
          ? max(stabBase, _streetCBetFreq(profile, street) * 0.75)
          : stabBase * (blockers.goodBluffBlockers ? 1.5 : 0.9);
    }

    // Nits stab/float rarely without initiative — but still more IP than OOP
    if (profile.bluffFreq < 0.10 && !wasAggressor) {
      bluffFreq *= inPosition ? 0.30 : 0.15;
    }

    // Ivey/Hansen exploit: vs over-folders barrel turn/river up to 80%
    if (profile.exploitsHighFolders && human.overFolds &&
        (street == 'turn' || isRiver)) {
      bluffFreq = max(bluffFreq, 0.80 * iveyExploitMult);
    }
    // Adrián "Adaptabilidad GTO": trust theory unless data is solid.
    // vs calling station with sufficient reads → clamp bluffs hard
    if (human.isCallingStation) {
      final dataGate = human.confidence >= 0.40 ? 0.20 : 0.50;
      bluffFreq *= dataGate;
    }
    // vs passive over-folder with reads → slight boost (but stays GTO-anchored)
    if (profile.polarizedBetting && human.overFolds && human.confidence >= 0.45) {
      bluffFreq = (bluffFreq * 1.25).clamp(0.0, 0.95);
    }
    // Generic in-hand adaptation: ANY thinking opponent fires a bit more when
    // the villain folds too much, scaled by how confident the read is — not
    // only the dedicated exploiters above. Modest and capped so ordinary
    // profiles get more lifelike (they punish over-folding) without turning
    // into maniacs.
    if (human.overFolds &&
        human.confidence >= 0.35 &&
        !profile.exploitsHighFolders &&
        !profile.polarizedBetting) {
      bluffFreq = (bluffFreq * (1.0 + 0.25 * human.confidence)).clamp(0.0, 0.85);
    }

    // Papo "Presión de Límites": hammer tight/over-folding opponents
    bluffFreq *= papoBluffMult;

    // Adrián sizing: always large — 1.0x on flop/turn, 1.5-2.0x overbet on river
    double sizeFrac = profile.polarizedBetting
        ? (isRiver ? 1.5 : 1.0)
        : (texture.wetness < 0.4 ? 0.40 : 0.66);
    if (isRiver && profile.polarizedBetting && blockers.goodBluffBlockers) {
      sizeFrac = 2.0; // river blocker overbet
    }
    if (profile.stackPressure) sizeFrac = (sizeFrac * 1.25).clamp(0.4, 2.0).toDouble();

    // Papo "El Factor Sorpresa / Improvisación": chaotic sizing to break reads.
    // On dry boards he flips expectations — small turns big, checks turn into bets.
    if (profile.freestyleAggressor) {
      sizeFrac *= papoSizingChaos;
      if (texture.wetness < 0.4 && rand < 0.35) {
        sizeFrac *= 1.6; // unexpected overbet on a dry board
      }
      sizeFrac = sizeFrac.clamp(0.25, 3.0).toDouble();
    }

    // Draw-completion: reduce barrel frequency when flush/straight completes OTT/OTR
    if (drawCompleted && wasAggressor) {
      bluffFreq *= texture.monotone ? 0.35 : 0.60;
    }

    // Raúl: apply level-based bluff multiplier
    bluffFreq = (bluffFreq * raulBluffMult * multiwayBluffMult).clamp(0.0, 0.95);

    final betAmount = (pot * sizeFrac).clamp(min(bb, stack), stack).toDouble();
    // Alpha gate: bluff must clear break-even fold frequency (with margin)
    final alphaNeeded = GtoMath.alpha(pot, betAmount);

    if (rand < bluffFreq && foldEst >= alphaNeeded * 0.80) {
      return BotDecision(type: ActionType.bet, amount: betAmount, thinkMs: 0);
    }
    return const BotDecision(type: ActionType.check, amount: 0, thinkMs: 0);
  }

  /// Value sizing: texture-aware, with nut-advantage overbets for
  /// polarized profiles (Addamo 2-3x pots, Mateos 1.5x rivers).
  /// SPR-aware multi-street planning: sizes down with deep SPR, up with shallow.
  static double _valueSize(
    LegendProfile profile,
    double pot,
    BoardTexture texture,
    String street, {
    required bool nut,
    double spr = 5.0,
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
    // River sizing: minimum 2/3 pot — no tiny river bets with value
    if (isRiver) {
      frac = texture.wetness < 0.35
          ? (profile.potControl ? 0.55 : 0.66)
          : (profile.potControl ? 0.66 : 0.75);
      if (nut && profile.polarizedBetting) {
        frac = profile.preferredSizings.last.clamp(1.0, 3.0).toDouble();
      } else if (nut) {
        frac = max(frac, 0.85);
      }
    }
    // SPR multi-street planning (non-river streets only)
    if (!isRiver) {
      if (spr <= 2.5) {
        frac = max(frac, 0.75); // short stack: commit quickly
      } else if (spr <= 4.5) {
        frac = max(frac, 0.50); // medium SPR: set up for 2 streets
      } else if (spr > 8.0 && !nut) {
        frac = min(frac, 0.45); // deep: keep pot small with non-nuts
      }
    }
    if (profile.potControl && !nut && !isRiver) frac = min(frac, 0.5);
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

  /// Range-strength offset for defending vs an opener in a given seat.
  /// Positive = the opener's range is stronger → defend tighter (need more
  /// strength, bluff-3bet less). Negative = wide opener → defend wider.
  /// This is what makes BB-vs-UTG play tight while BB-vs-BTN plays loose.
  static double _openerTightness(TablePosition? opener) {
    switch (opener) {
      case TablePosition.utg: return 0.10;
      case TablePosition.mp: return 0.07;
      case TablePosition.co: return 0.02;
      case TablePosition.btn: return -0.04;
      case TablePosition.sb: return -0.08;
      case TablePosition.bb:
      case null:
        return 0.0;
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
