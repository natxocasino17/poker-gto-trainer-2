import '../../core/utils/preflop_charts.dart';
import '../models/player_model.dart';
import 'hand_classes.dart';
import 'spot_record.dart';

/// BLIND vs BLIND database: SB open/limp vs BB, and BB defense.
///
/// Two sub-scenarios:
///   A) SB action first-in (only BB left): open-raise vs limp.
///   B) BB vs SB open (closing action with a discount).
///
/// BvB theory:
///   * SB should open ~45-50% of hands (wider than CO, never wider than BTN);
///     limping is viable but polarises the range — here we model open-raise only.
///   * BB defends very wide (already in for 1BB, getting ~2:1): MDF ≈ 55-60%.
///   * BB 3-bet range is polarised (QQ+/AKs pure value + Ax bluffs).
///   * SB is OOP for all postflop streets → tighter calling range, more 3-bets.
class BvBDB {
  // ─── SB opening strategy ──────────────────────────────────────────────────

  /// Hands SB opens pure (1.0 frequency).
  static const Set<String> _sbOpenPure = {
    'AA', 'KK', 'QQ', 'JJ', 'TT', '99', '88', '77', '66', '55',
    'AKs', 'AQs', 'AJs', 'ATs', 'A9s', 'A8s', 'A7s', 'A6s', 'A5s', 'A4s', 'A3s', 'A2s',
    'KQs', 'KJs', 'KTs', 'K9s', 'K8s', 'K7s', 'K6s',
    'QJs', 'QTs', 'Q9s',
    'JTs', 'J9s', 'J8s',
    'T9s', 'T8s',
    '98s', '97s',
    '87s', '86s',
    '76s', '75s',
    '65s', '64s',
    '54s',
    'AKo', 'AQo', 'AJo', 'ATo', 'A9o', 'A8o', 'A7o', 'A6o', 'A5o',
    'KQo', 'KJo', 'KTo',
    'QJo', 'QTo',
    'JTo',
  };

  /// Mixed SB opens (~50%).
  static const Set<String> _sbOpenMix = {
    '44', '33', '22',
    'K5s', 'K4s', 'K3s', 'K2s',
    'Q8s', 'Q7s',
    'J7s',
    'T7s', 'T6s',
    '96s',
    '85s',
    '74s',
    '63s',
    '53s', '52s',
    '43s',
    'A4o', 'A3o', 'A2o',
    'K9o', 'K8o',
    'Q9o',
    'J9o',
    'T9o', 'T8o',
    '98o', '97o',
    '87o', '86o',
    '76o',
  };

  static double sbOpenFrequency(String hand) {
    if (_sbOpenPure.contains(hand)) return 1.0;
    if (_sbOpenMix.contains(hand)) return 0.5;
    return 0.0;
  }

  static HandStrategy sbStrategy(String hand) {
    const spotId = 'bvb_sb_open';
    final f = sbOpenFrequency(hand);
    final score = HandClasses.score(hand);
    final desc = HandClasses.describe(hand);
    final ev = ((score - 0.38) * 5.5).clamp(-0.6, 4.0);
    final cat = f == 0
        ? SpotCategory.trashFold
        : f < 1
            ? SpotCategory.marginalMix
            : score > 0.7
                ? SpotCategory.premium
                : score > 0.55
                    ? SpotCategory.value
                    : SpotCategory.speculative;

    final actions = <SpotRecord>[];
    if (f > 0) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: 'SB', villainPosition: 'BB',
        hand: hand, action: 'open', frequency: f,
        ev: f == 1 ? ev.clamp(0.05, 4.0) : 0.05,
        category: cat,
        explanation: f >= 1.0
            ? '$hand abre SIEMPRE desde SB: en el duelo ciego, tu rango de apertura '
                'se expande a ~45-50% porque solo actúa una mano tras de ti. OOP para '
                'todo el postflop — apuesta rango claro y mantén el sizing bajo (2.5-3x).'
            : f > 0
                ? '$hand se mezcla en SB (${(f * 100).round()}%): está en el borde '
                    'del rango. Contra BBs que 3-betean mucho, inclínate al fold; contra '
                    'BBs que solo flatean, ábrela — robarás el pozo a menudo.'
                : '$hand foldea en SB: sin la fuerza ni la jugabilidad para atacar '
                    'OOP al BB. Cada BB que pierdes aquí es EV negativo directo.',
      ));
    }
    if (f < 1.0) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: 'SB', villainPosition: 'BB',
        hand: hand, action: 'fold', frequency: 1.0 - f,
        ev: 0,
        category: f > 0 ? SpotCategory.marginalMix : SpotCategory.trashFold,
        explanation: f > 0
            ? '$hand en SB al ${((1 - f) * 100).round()}%: con BBs 3-bettors agresivos '
                'o rakeback bajo, el fold se vuelve correcto incluso con manos medias OOP.'
            : '$hand foldea en SB: sus implied odds no compensan el spot OOP duelo-ciego.',
      ));
    }
    return HandStrategy(spotId: spotId, hand: hand, actions: actions);
  }

  // ─── BB defense vs SB open ─────────────────────────────────────────────────

  /// Hands BB 3-bets for value (pure or near-pure).
  static const Set<String> _bbThreeBetValue = {
    'AA', 'KK', 'QQ', 'JJ', 'AKs', 'AKo',
  };

  /// Hands BB 3-bets as polarised bluff (Ax blockers).
  static const Set<String> _bbThreeBetBluff = {
    'A5s', 'A4s', 'A3s', 'A2s', 'K4s', 'K3s', 'K2s',
  };

  /// Hands BB calls (flat, MDF defence).
  static const Set<String> _bbCallPure = {
    'TT', '99', '88', '77', '66', '55', '44', '33', '22',
    'AQs', 'AJs', 'ATs', 'A9s', 'A8s', 'A7s', 'A6s',
    'KQs', 'KJs', 'KTs', 'K9s', 'K8s', 'K7s', 'K6s', 'K5s',
    'QJs', 'QTs', 'Q9s', 'Q8s', 'Q7s',
    'JTs', 'J9s', 'J8s', 'J7s',
    'T9s', 'T8s', 'T7s',
    '98s', '97s', '96s',
    '87s', '86s', '85s',
    '76s', '75s', '74s',
    '65s', '64s', '63s',
    '54s', '53s', '52s',
    '43s',
    'AQo', 'AJo', 'ATo', 'A9o', 'A8o', 'A7o', 'A6o',
    'KQo', 'KJo', 'KTo', 'K9o', 'K8o',
    'QJo', 'QTo', 'Q9o',
    'JTo', 'J9o',
    'T9o', 'T8o',
    '98o', '97o',
    '87o', '86o',
    '76o',
  };

  static HandStrategy bbVsSbStrategy(String hand) {
    const spotId = 'bvb_bb_vs_sb';
    final score = HandClasses.score(hand);
    final desc = HandClasses.describe(hand);

    double f3bet = 0, fCall = 0;
    String cat3bet = SpotCategory.premium;
    String catCall = SpotCategory.potControl;

    if (_bbThreeBetValue.contains(hand)) {
      f3bet = 1.0;
      cat3bet = SpotCategory.premium;
    } else if (_bbThreeBetBluff.contains(hand)) {
      f3bet = 0.45;
      fCall = 0.30;
      cat3bet = SpotCategory.bluffBlockers;
      catCall = SpotCategory.speculative;
    } else if (_bbCallPure.contains(hand)) {
      fCall = score > 0.65 ? 1.0 : score > 0.5 ? 0.85 : 0.65;
      catCall = HandClasses.isPair(hand) && HandClasses.hiRank(hand) <= 7
          ? SpotCategory.setMining
          : SpotCategory.potControl;
    } else if (score > 0.36) {
      fCall = 0.5;
      catCall = SpotCategory.defenseMdf;
    }

    final total = f3bet + fCall;
    if (total > 1.0) { f3bet /= total; fCall /= total; }
    final fFold = (1.0 - f3bet - fCall).clamp(0.0, 1.0);

    final ev3bet = cat3bet == SpotCategory.premium
        ? (score - 0.6) * 12.0
        : 0.15;
    final evCall = ((score - 0.38) * 3.5).clamp(0.05, 2.5);

    final actions = <SpotRecord>[];
    if (f3bet > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: 'BB', villainPosition: 'SB',
        hand: hand, action: '3bet', frequency: _r(f3bet),
        ev: _r(ev3bet.clamp(0.1, 10.0)),
        category: cat3bet,
        explanation: cat3bet == SpotCategory.premium
            ? '$hand 3-betea SIEMPRE desde BB vs SB: el SB abre muy amplio (~45%) '
                'y tienes iniciativa + cierre de acción con descuento. Jam contra 4-bet — '
                'nunca foldeas con estas manos vs un rango de apertura tan ancho.'
            : '$hand 3-betea farol al ${(f3bet * 100).round()}% vs la apertura del SB: '
                'el As (o el K) bloquea sus premiums. El SB abre OOP — muchos folds al '
                '3-bet. Si pagan, tienes jugabilidad con $desc. Fold limpio al 4-bet.',
      ));
    }
    if (fCall > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: 'BB', villainPosition: 'SB',
        hand: hand, action: 'call', frequency: _r(fCall),
        ev: _r(evCall),
        category: catCall,
        explanation: catCall == SpotCategory.setMining
            ? '$hand paga en BB buscando set: con descuento y multiway equity, '
                'las implied odds cuadran. Sin set en flop seguro, suéltala rápido.'
            : catCall == SpotCategory.defenseMdf
                ? '$hand defiende al ${(fCall * 100).round()}% en BB (MDF): el SB '
                    'abre tan amplio que foldear demasiado le imprime EV gratis. '
                    'Tu descuento de ciega convierte muchas manos marginales en defensa rentable.'
                : '$hand paga al ${(fCall * 100).round()}% en BB vs SB: cerrando la '
                    'acción con descuento, $desc tiene suficiente equity realizable. '
                    'IP el SB, pero tu discount + posición de apuesta hacen el call correcto.',
      ));
    }
    if (fFold > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: 'BB', villainPosition: 'SB',
        hand: hand, action: 'fold', frequency: _r(fFold),
        ev: 0,
        category: fFold > 0.9 ? SpotCategory.trashFold : SpotCategory.marginalMix,
        explanation: '$hand foldea en BB vs SB el ${(fFold * 100).round()}%: aunque '
            'tienes descuento, la mano no realiza suficiente equity para compensar '
            'jugar sin iniciativa vs un rango aunque sea amplio.',
      ));
    }
    return HandStrategy(spotId: spotId, hand: hand, actions: actions);
  }

  // ─── Utilities ────────────────────────────────────────────────────────────

  static List<HandStrategy> sbFullRange() =>
      HandClasses.all.map(sbStrategy).toList();

  static List<HandStrategy> bbFullRange() =>
      HandClasses.all.map(bbVsSbStrategy).toList();

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}
