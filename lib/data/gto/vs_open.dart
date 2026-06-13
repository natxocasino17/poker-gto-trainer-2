import '../../core/utils/preflop_charts.dart';
import '../models/player_model.dart';
import 'hand_classes.dart';
import 'spot_record.dart';

/// FACING OPEN RAISE database — every legal matchup in 6-max 100BB cash.
///
/// 15 spots: {HJ,CO,BTN,SB,BB} vs UTG · {CO,BTN,SB,BB} vs HJ ·
/// {BTN,SB,BB} vs CO · {SB,BB} vs BTN · BB vs SB.
///
/// For each of the 169 hands per spot: fold/call/3bet with equilibrium
/// frequency, EV and a coach-grade explanation. Strategy logic:
///   * Studied base ranges from [PreflopCharts.defense] (hero-position layer).
///   * Villain-position tightening: defend tighter vs UTG opens (strong range)
///     and wider vs BTN/SB opens (wide range) — exactly like a professional
///     adjusting his defense chart to the opener's seat.
class VsOpenDB {
  /// All legal (hero, villain) matchups.
  static const List<List<TablePosition>> matchups = [
    [TablePosition.mp, TablePosition.utg],
    [TablePosition.co, TablePosition.utg],
    [TablePosition.btn, TablePosition.utg],
    [TablePosition.sb, TablePosition.utg],
    [TablePosition.bb, TablePosition.utg],
    [TablePosition.co, TablePosition.mp],
    [TablePosition.btn, TablePosition.mp],
    [TablePosition.sb, TablePosition.mp],
    [TablePosition.bb, TablePosition.mp],
    [TablePosition.btn, TablePosition.co],
    [TablePosition.sb, TablePosition.co],
    [TablePosition.bb, TablePosition.co],
    [TablePosition.sb, TablePosition.btn],
    [TablePosition.bb, TablePosition.btn],
    [TablePosition.bb, TablePosition.sb],
  ];

  /// How much tighter (positive) or looser (negative) to defend, by opener.
  /// A UTG open represents a ~16% range; a BTN open ~45%; SB open ~40%.
  static double villainOffset(TablePosition villain) {
    switch (villain) {
      case TablePosition.utg: return 0.055;
      case TablePosition.mp: return 0.035;
      case TablePosition.co: return 0.0;
      case TablePosition.btn: return -0.045;
      case TablePosition.sb: return -0.055;
      case TablePosition.bb: return 0.0;
    }
  }

  /// 3-bet bluff frequency multiplier by opener (bluff more vs wide openers).
  static double bluff3BetFreq(TablePosition villain) {
    switch (villain) {
      case TablePosition.utg: return 0.35;
      case TablePosition.mp: return 0.45;
      case TablePosition.co: return 0.60;
      case TablePosition.btn: return 0.80;
      case TablePosition.sb: return 0.90;
      case TablePosition.bb: return 0.5;
    }
  }

  static String _lbl(TablePosition p) {
    switch (p) {
      case TablePosition.utg: return 'UTG';
      case TablePosition.mp: return 'HJ';
      case TablePosition.co: return 'CO';
      case TablePosition.btn: return 'BTN';
      case TablePosition.sb: return 'SB';
      case TablePosition.bb: return 'BB';
    }
  }

  /// Computes the full fold/call/3bet strategy for [hand] when [hero] faces an
  /// open raise from [villain].
  static HandStrategy strategy(TablePosition hero, TablePosition villain, String hand) {
    final heroLbl = _lbl(hero);
    final vilLbl = _lbl(villain);
    final spotId = 'vs_open_${heroLbl.toLowerCase()}_vs_${vilLbl.toLowerCase()}';
    final base = PreflopCharts.defense(hero, hand);
    final score = HandClasses.score(hand);
    final offset = villainOffset(villain);
    final desc = HandClasses.describe(hand);
    final isBB = hero == TablePosition.bb;

    double f3bet = 0, fCall = 0;
    String cat3bet = SpotCategory.value;
    String catCall = SpotCategory.potControl;

    switch (base) {
      case DefenseAction.threeBetFiveBet:
        f3bet = 1.0;
        cat3bet = SpotCategory.premium;
        break;
      case DefenseAction.threeBetCall4B:
        // vs tight openers these mix 3bet/call; vs wide openers pure 3bet.
        if (villain == TablePosition.utg) {
          f3bet = 0.5; fCall = 0.5;
        } else if (villain == TablePosition.mp) {
          f3bet = 0.7; fCall = 0.3;
        } else {
          f3bet = 1.0;
        }
        cat3bet = SpotCategory.value;
        catCall = SpotCategory.potControl;
        break;
      case DefenseAction.threeBetFold:
        f3bet = bluff3BetFreq(villain);
        cat3bet = SpotCategory.bluffBlockers;
        // Suited wheel aces flat sometimes in BB (closing action, discount)
        if (isBB && HandClasses.isSuited(hand) && HandClasses.hiRank(hand) == 14) {
          fCall = (1 - f3bet) * 0.7;
          catCall = SpotCategory.speculative;
        }
        break;
      case DefenseAction.call:
        // Tighten vs strong openers, defend in full vs wide ones.
        final margin = score - (0.46 + offset);
        if (margin > 0.06) {
          fCall = 1.0;
        } else if (margin > -0.02) {
          fCall = 0.6; // mixed border defend
        } else {
          fCall = isBB ? 0.5 : 0.25; // BB still defends with the discount
        }
        catCall = HandClasses.isPair(hand) && HandClasses.hiRank(hand) <= 8
            ? SpotCategory.setMining
            : SpotCategory.potControl;
        break;
      case DefenseAction.fold:
        // BB closes the action with a discount: marginal extra defends vs
        // wide opens (MDF pressure — fold too much and the BTN prints money).
        if (isBB && offset < 0 && score > 0.34) {
          fCall = 0.45;
          catCall = SpotCategory.defenseMdf;
        } else if (!isBB && offset < -0.04 && score > 0.52) {
          fCall = 0.35;
          catCall = SpotCategory.marginalMix;
        }
        break;
    }

    // Normalise: fold absorbs the remainder.
    final total = f3bet + fCall;
    if (total > 1.0) {
      f3bet /= total;
      fCall /= total;
    }
    final fFold = (1.0 - f3bet - fCall).clamp(0.0, 1.0);

    // ── EV model (BB) ──
    final ev3bet = base == DefenseAction.threeBetFiveBet
        ? (score - 0.55) * 9.0
        : base == DefenseAction.threeBetCall4B
            ? (score - 0.55) * 6.0
            : 0.15; // bluff 3-bets are near-zero-EV by design (balanced)
    final evCall = ((score - 0.45 - offset) * 4.0).clamp(-0.5, 3.0);

    final actions = <SpotRecord>[];
    if (f3bet > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: heroLbl, villainPosition: vilLbl,
        hand: hand, action: '3bet', frequency: _r(f3bet),
        ev: _r(ev3bet.clamp(0.05, 8.0)), category: cat3bet,
        explanation: _exp3Bet(heroLbl, vilLbl, hand, desc, cat3bet, f3bet),
      ));
    }
    if (fCall > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: heroLbl, villainPosition: vilLbl,
        hand: hand, action: 'call', frequency: _r(fCall),
        ev: _r(evCall.clamp(0.02, 3.0)), category: catCall,
        explanation: _expCall(heroLbl, vilLbl, hand, desc, catCall, fCall, isBB),
      ));
    }
    if (fFold > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: heroLbl, villainPosition: vilLbl,
        hand: hand, action: 'fold', frequency: _r(fFold),
        ev: 0, category: fFold > 0.95 ? SpotCategory.trashFold : SpotCategory.marginalMix,
        explanation: _expFold(heroLbl, vilLbl, hand, desc, fFold),
      ));
    }
    return HandStrategy(spotId: spotId, hand: hand, actions: actions);
  }

  /// Full 169-hand range for a matchup.
  static List<HandStrategy> fullRange(TablePosition hero, TablePosition villain) {
    return HandClasses.all.map((h) => strategy(hero, villain, h)).toList();
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;

  // ─── Explanations ──────────────────────────────────────────────────────────

  static String _exp3Bet(String hero, String vil, String hand, String desc,
      String cat, double freq) {
    final fq = '${(freq * 100).round()}%';
    if (cat == SpotCategory.premium) {
      return '$hand es la cima del rango: 3-betea SIEMPRE desde $hero contra la '
          'apertura de $vil y ve con todo contra un 4-bet. Flatear aquí deja que '
          'las ciegas entren baratas y caparía tu rango de 3-bet.';
    }
    if (cat == SpotCategory.bluffBlockers) {
      return '$hand 3-betea al $fq desde $hero vs $vil como farol con blockers: '
          'reduce los combos de manos premium del rival y, si pagan, tienes '
          'jugabilidad ($desc). Si te 4-betean, fold disciplinado — el farol ya cumplió.';
    }
    return '$hand 3-betea por valor ($fq) desde $hero contra $vil: domina su '
        'rango de continuar y aísla al agresor. Contra un 4-bet, paga y reevalúa: '
        'tu mano rinde bien en botes 4-beteados con SPR bajo.';
  }

  static String _expCall(String hero, String vil, String hand, String desc,
      String cat, double freq, bool isBB) {
    final fq = '${(freq * 100).round()}%';
    if (cat == SpotCategory.setMining) {
      return '$hand paga ($fq) la apertura de $vil buscando set: con ~12% de '
          'ligarlo al flop y stacks de 100BB tienes implied odds suficientes. '
          'Sin set ni overpair en boards seguros, suelta la mano sin dudar.';
    }
    if (cat == SpotCategory.defenseMdf) {
      return '$hand defiende el $fq desde la BB contra la apertura ancha de $vil: '
          'el descuento de la ciega + tus pot odds (~3.5:1) hacen el call rentable '
          'aunque la mano parezca débil. Foldear de más aquí es el leak nº1 — el '
          'MDF te obliga a defender o el rival imprime dinero robando.';
    }
    if (isBB) {
      return '$hand paga ($fq) desde la BB cerrando la acción con descuento. '
          '$desc con buena realización de equity. Postflop: no pagues tres calles '
          'sin mejorar — defender preflop no te compromete con el bote.';
    }
    return '$hand flatea ($fq) en posición contra $vil: jugabilidad excelente '
        'con la ventaja posicional. Cuidado con los squeezes de las ciegas — '
        'parte del EV del call depende de que no te aprieten detrás.';
  }

  static String _expFold(String hero, String vil, String hand, String desc, double freq) {
    if (freq >= 0.95) {
      return '$hand foldea contra la apertura de $vil: dominada por su rango y '
          'sin pot odds para especular. No pierdas EV pagando "para ver un flop" — '
          'ese flop te costará más fichas cuando conectes segundo par.';
    }
    return '$hand foldea el ${(freq * 100).round()}% en este spot: está en el '
        'borde exacto del rango. Contra openers que abren de más o se rinden '
        'postflop, defiéndela; contra regs sólidos de $vil, el fold es impecable.';
  }
}
