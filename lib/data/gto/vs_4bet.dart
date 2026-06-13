import '../models/player_model.dart';
import 'hand_classes.dart';
import 'spot_record.dart';

/// FACING 4-BET database: the 3-bettor's decision after being 4-bet.
/// Per position: fold / call / 5bet (small) / 5bet_jam, with frequency + EV.
///
/// 100BB context: a 4-bet is typically ~22BB, so a 5-bet is effectively a jam
/// (or commits ~half the stack). The strategic core:
///   * QQ+/AK: never fold — jam or call to induce.
///   * JJ/TT/AQs: defend by calling (playable postflop, hate facing a jam).
///   * A5s-A2s class bluff 3-bets: occasional 5-bet jam as the bluff branch
///     (the Ace blocks AA/AK, exactly when villain folds the most).
///   * Everything else folds — its 3-bet already did its job.
class Vs4BetDB {
  static const Set<String> _jamValue = {'AA', 'KK'};
  static const Set<String> _jamOrCall = {'QQ', 'AKs', 'AKo'};
  static const Set<String> _call = {'JJ', 'TT', 'AQs'};
  static const Set<String> _jamBluff = {'A5s', 'A4s'};

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

  /// Strategy for [hand] when [hero] (the 3-bettor) faces a 4-bet.
  static HandStrategy strategy(TablePosition hero, String hand) {
    final lbl = _lbl(hero);
    final spotId = 'vs_4bet_${lbl.toLowerCase()}';
    final score = HandClasses.score(hand);
    final inBlinds = hero == TablePosition.sb || hero == TablePosition.bb;

    double fJam = 0, fCall = 0, fFold = 0;

    if (_jamValue.contains(hand)) {
      fJam = 0.85; fCall = 0.15; // mostly jam, sometimes trap-call
    } else if (_jamOrCall.contains(hand)) {
      fJam = 0.55; fCall = 0.45;
    } else if (_call.contains(hand)) {
      fCall = inBlinds ? 0.55 : 0.75; // OOP defends tighter
      fFold = 1 - fCall;
    } else if (_jamBluff.contains(hand)) {
      fJam = 0.30; fFold = 0.70; // occasional bluff jam with blockers
    } else {
      fFold = 1.0;
    }

    final remainder = (1.0 - fJam - fCall - fFold).clamp(0.0, 1.0);
    fFold += remainder;

    final actions = <SpotRecord>[];
    if (fJam > 0.01) {
      final isValue = _jamValue.contains(hand) || _jamOrCall.contains(hand);
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: lbl, villainPosition: '4bettor',
        hand: hand, action: '5bet_jam', frequency: _r(fJam),
        ev: _r(isValue ? (score - 0.6) * 20.0 : 0.3),
        category: isValue ? SpotCategory.premium : SpotCategory.bluffBlockers,
        explanation: isValue
            ? '$hand mete los 100BB sin pestañear: contra el rango de 4-bet '
                'estás al frente o flipeando con AK. Dudar aquí solo deja que '
                'JJ/AQ realicen equity gratis. El 5-bet jam ES la jugada.'
            : '$hand 5-betea jam el ${(fJam * 100).round()}% como farol final: '
                'el As bloquea exactamente AA y AK — las únicas manos que pagan '
                'cómodas. Cuando funciona ganas ~25BB muertos; cuando pagan, '
                'aún tienes ~32% de equity. Riesgo calculado, no temeridad.',
      ));
    }
    if (fCall > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: lbl, villainPosition: '4bettor',
        hand: hand, action: 'call', frequency: _r(fCall),
        ev: _r(((score - 0.58) * 8.0).clamp(0.1, 6.0)),
        category: _jamValue.contains(hand) || _jamOrCall.contains(hand)
            ? SpotCategory.trapSlowplay
            : SpotCategory.potControl,
        explanation: _jamValue.contains(hand)
            ? '$hand a veces solo paga el 4-bet (trap): mantienes sus faroles '
                'vivos y disfrazas tu rango. SPR ~1.2 postflop — el dinero entra '
                'igual, pero dejas que el rival se cuelgue solo.'
            : '$hand paga el 4-bet: demasiado fuerte para foldear, demasiado '
                'débil para jam (dominada por su valor cuando te pagan el 5-bet). '
                'SPR ~1.2: busca flops con overpair/top pair y stack-off; sin '
                'conexión, check-fold sin drama.',
      ));
    }
    if (fFold > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: lbl, villainPosition: '4bettor',
        hand: hand, action: 'fold', frequency: _r(fFold),
        ev: 0,
        category: fFold > 0.95 ? SpotCategory.trashFold : SpotCategory.marginalMix,
        explanation: '$hand foldea al 4-bet: tu 3-bet ya hizo su trabajo '
            '(presión + información). Pagar 22BB con una mano dominada contra un '
            'rango de 4-bet es regalar stack. Perder esta escaramuza ≠ perder la guerra.',
      ));
    }
    return HandStrategy(spotId: spotId, hand: hand, actions: actions);
  }

  static List<HandStrategy> fullRange(TablePosition hero) {
    return HandClasses.all.map((h) => strategy(hero, h)).toList();
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}
