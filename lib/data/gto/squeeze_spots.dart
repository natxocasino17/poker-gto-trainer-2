import '../models/player_model.dart';
import 'hand_classes.dart';
import 'spot_record.dart';

/// SQUEEZE database: 3-betting vs an open + caller(s).
///
/// 5 canonical lines:
///   UTG open → BTN call → SB squeeze
///   UTG open → BTN call → BB squeeze
///   HJ open → BTN call → SB squeeze
///   CO open → BTN call → BB squeeze
///   BTN open → SB call → BB squeeze
///
/// Squeeze theory: the caller's range is capped (no premium — they would have
/// 3-bet), so a big squeeze attacks BOTH the opener's continuing range and a
/// capped caller. Sizing: 4x the open + 1x per caller. Value range tightens
/// (you face two players), bluff range leans on blockers (Axs).
class SqueezeDB {
  static const List<Map<String, TablePosition>> lines = [
    {'opener': TablePosition.utg, 'caller': TablePosition.btn, 'hero': TablePosition.sb},
    {'opener': TablePosition.utg, 'caller': TablePosition.btn, 'hero': TablePosition.bb},
    {'opener': TablePosition.mp, 'caller': TablePosition.btn, 'hero': TablePosition.sb},
    {'opener': TablePosition.co, 'caller': TablePosition.btn, 'hero': TablePosition.bb},
    {'opener': TablePosition.btn, 'caller': TablePosition.sb, 'hero': TablePosition.bb},
  ];

  static const Set<String> _squeezeValue = {'AA', 'KK', 'QQ', 'JJ', 'AKs', 'AKo', 'AQs'};
  static const Set<String> _squeezeMix = {'TT', '99', 'AQo', 'AJs', 'KQs'};
  static const Set<String> _squeezeBluff = {'A5s', 'A4s', 'A3s', 'A2s', 'KJs', '76s', '65s'};
  static const Set<String> _flatInstead = {
    '88', '77', '66', '55', '44', '33', '22',
    'ATs', 'KTs', 'QJs', 'JTs', 'T9s', '98s', '87s',
  };

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

  /// Tighter squeezes vs early-position opens (their range is stronger).
  static double _openerTightness(TablePosition opener) {
    switch (opener) {
      case TablePosition.utg: return 0.0;   // tightest — squeeze only premium+
      case TablePosition.mp: return 0.15;
      case TablePosition.co: return 0.3;
      case TablePosition.btn: return 0.5;   // widest — squeeze aggressively
      default: return 0.3;
    }
  }

  /// Strategy for [hand] when [hero] can squeeze vs [opener] open + [caller] call.
  static HandStrategy strategy(
      TablePosition hero, TablePosition opener, TablePosition caller, String hand) {
    final hLbl = _lbl(hero);
    final oLbl = _lbl(opener);
    final cLbl = _lbl(caller);
    final spotId =
        'squeeze_${hLbl.toLowerCase()}_vs_${oLbl.toLowerCase()}_${cLbl.toLowerCase()}';
    final loosen = _openerTightness(opener);
    final score = HandClasses.score(hand);

    double fSqueeze = 0, fCall = 0;
    String catSq = SpotCategory.squeezeValue;

    if (_squeezeValue.contains(hand)) {
      fSqueeze = 1.0;
    } else if (_squeezeMix.contains(hand)) {
      fSqueeze = 0.4 + loosen * 0.5;
      fCall = (1 - fSqueeze) * 0.8;
    } else if (_squeezeBluff.contains(hand)) {
      fSqueeze = 0.3 + loosen * 0.6;
      catSq = SpotCategory.squeezeBluff;
    } else if (_flatInstead.contains(hand)) {
      fCall = 0.8; // overcall: great multiway playability, terrible squeeze
    } else if (score > 0.5) {
      fCall = 0.35;
    }

    final total = fSqueeze + fCall;
    if (total > 1.0) { fSqueeze /= total; fCall /= total; }
    final fFold = (1.0 - fSqueeze - fCall).clamp(0.0, 1.0);

    final actions = <SpotRecord>[];
    if (fSqueeze > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: hLbl, villainPosition: '$oLbl+$cLbl',
        hand: hand, action: 'squeeze', frequency: _r(fSqueeze),
        ev: _r(catSq == SpotCategory.squeezeValue
            ? ((score - 0.55) * 9.0).clamp(0.3, 9.0)
            : 0.25),
        category: catSq,
        explanation: catSq == SpotCategory.squeezeValue
            ? '$hand squeeze por valor: hay dinero muerto (open + call) y el '
                'rango del caller está CAPADO — con premium habría 3-beteado. '
                'Sizing grande: ~4x el open +1x por caller (≈11-12BB). Cobras de '
                'dos rangos que continúan dominados.'
            : '$hand squeeze-farol al ${(fSqueeze * 100).round()}%: dos rivales '
                'que foldean mucho + blockers a sus premiums + dinero muerto. '
                'Alpha favorable: necesitas ~55% de folds combinados y los tienes. '
                'Si el OPENER te 4-betea, fold — su rango aguantó dos señales de fuerza.',
      ));
    }
    if (fCall > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: hLbl, villainPosition: '$oLbl+$cLbl',
        hand: hand, action: 'call', frequency: _r(fCall),
        ev: _r(((score - 0.42) * 3.0).clamp(0.05, 2.0)),
        category: SpotCategory.speculative,
        explanation: '$hand sobrepaga (overcall) en vez de squeeze: mano de '
            'IMPLIED ODDS que quiere ver flop barato multiway. Sets, colores y '
            'escaleras cobran botes gigantes con tres rangos involucrados. '
            'Squeezear esto convierte una mano de proyecto en un farol caro.',
      ));
    }
    if (fFold > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: hLbl, villainPosition: '$oLbl+$cLbl',
        hand: hand, action: 'fold', frequency: _r(fFold),
        ev: 0,
        category: fFold > 0.95 ? SpotCategory.trashFold : SpotCategory.marginalMix,
        explanation: '$hand foldea en el spot de squeeze: sin la fuerza para '
            'atacar dos rangos ni las implied odds para overcall multiway. '
            'Las ciegas OOP contra open+call es el peor asiento de la mesa — '
            'la disciplina aquí paga sola.',
      ));
    }
    return HandStrategy(spotId: spotId, hand: hand, actions: actions);
  }

  /// How the OPENER should respond to a squeeze (summary guidance per hand).
  static String vsSqueezeAdvice(String hand) {
    if (const {'AA', 'KK', 'QQ', 'AKs', 'AKo'}.contains(hand)) {
      return '$hand contra un squeeze: 4-betea por valor. El squeezer ataca '
          'dinero muerto con un rango ancho — castígalo.';
    }
    if (const {'JJ', 'TT', 'AQs', 'AJs', 'KQs'}.contains(hand)) {
      return '$hand contra un squeeze: call y reevalúa. Dominas parte de su '
          'rango de farol pero no aguantas un 5-bet. El flop decide.';
    }
    return '$hand contra un squeeze: fold. Tu open ya no es dueño del bote y '
        'pagar OOP contra un rango polarizado quema EV.';
  }

  static List<HandStrategy> fullRange(
      TablePosition hero, TablePosition opener, TablePosition caller) {
    return HandClasses.all
        .map((h) => strategy(hero, opener, caller, h))
        .toList();
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}
