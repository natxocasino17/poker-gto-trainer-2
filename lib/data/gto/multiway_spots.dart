import '../models/player_model.dart';
import 'hand_classes.dart';
import 'spot_record.dart';

/// MULTIWAY PREFLOP database — decisions when 3+ players are in the pot.
///
/// 4 canonical scenarios:
///   1) UTG open → HJ call → hero (CO/BTN/SB/BB) closes action
///   2) UTG open → CO call → hero (BTN/SB/BB) closes action
///   3) CO open → BTN call → hero (SB/BB) closes action
///   4) Two callers already in → hero (BB) completes cheaply
///
/// Multiway theory:
///   * Range tightens: you need real equity vs MULTIPLE ranges.
///   * Bluffs lose value fast (multiple players = someone has something).
///   * Implied odds rise: nut draws and sets pay more multiway.
///   * Suited connectors and small pairs UP in value vs two callers.
///   * Cold-call threshold rises: at least one player behind you might squeeze.
///   * 3-bet window narrows: you need stronger hands to 3-bet into multi-way action.
class MultiwayDB {
  static const List<Map<String, dynamic>> scenarios = [
    {
      'id': 'mw_utg_hj_in',
      'opener': TablePosition.utg,
      'callers': [TablePosition.mp],
      'heroes': [TablePosition.co, TablePosition.btn, TablePosition.sb, TablePosition.bb],
    },
    {
      'id': 'mw_utg_co_in',
      'opener': TablePosition.utg,
      'callers': [TablePosition.co],
      'heroes': [TablePosition.btn, TablePosition.sb, TablePosition.bb],
    },
    {
      'id': 'mw_co_btn_in',
      'opener': TablePosition.co,
      'callers': [TablePosition.btn],
      'heroes': [TablePosition.sb, TablePosition.bb],
    },
    {
      'id': 'mw_two_callers_bb',
      'opener': TablePosition.utg,
      'callers': [TablePosition.mp, TablePosition.co],
      'heroes': [TablePosition.bb],
    },
  ];

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

  /// Hands that retain strong value multiway (equity vs multiple ranges).
  static const Set<String> _mwValuePure = {
    'AA', 'KK', 'QQ', 'JJ',
    'AKs', 'AKo',
  };

  /// Hands that mix 3-bet / call multiway.
  static const Set<String> _mwValueMix = {
    'TT', '99',
    'AQs', 'AJs',
  };

  /// Hands that improve in value multiway (implied odds).
  static const Set<String> _mwImplied = {
    '88', '77', '66', '55', '44', '33', '22',
    'KQs', 'KJs', 'QJs',
    'JTs', 'T9s', '98s', '87s', '76s', '65s', '54s',
    'ATs', 'A9s', 'A8s',
  };

  /// Hands that flat multiway with reduced 3-bet equity.
  static const Set<String> _mwCallMarginal = {
    'AQo', 'AJo', 'KTs', 'QTs',
    'J9s', 'T8s', '97s', '86s', '75s', '64s',
  };

  /// Position bonus: IP heroes can play wider; OOP heroes tighten.
  static double _posBonus(TablePosition hero, TablePosition opener) {
    if (hero == TablePosition.bb) return -0.04; // discount but OOP
    if (hero == TablePosition.sb) return -0.08; // worst seat
    if (hero == TablePosition.btn) return 0.06;  // best seat
    if (hero == TablePosition.co && opener == TablePosition.utg) return 0.03;
    return 0.0;
  }

  static bool _isIP(TablePosition hero, TablePosition opener) {
    const order = [
      TablePosition.utg,
      TablePosition.mp,
      TablePosition.co,
      TablePosition.btn,
      TablePosition.sb,
      TablePosition.bb,
    ];
    return order.indexOf(hero) > order.indexOf(opener);
  }

  /// Strategy when [hero] faces an open from [opener] with [callers] already in.
  static HandStrategy strategy(
      TablePosition hero, TablePosition opener, List<TablePosition> callers, String hand) {
    final hLbl = _lbl(hero);
    final oLbl = _lbl(opener);
    final cLbls = callers.map(_lbl).join('+');
    final numCallers = callers.length;
    final spotId = 'mw_${hLbl.toLowerCase()}_vs_${oLbl.toLowerCase()}_${numCallers}caller';
    final score = HandClasses.score(hand);
    final desc = HandClasses.describe(hand);
    final bonus = _posBonus(hero, opener);
    final ip = _isIP(hero, opener);
    final isBB = hero == TablePosition.bb;

    double f3bet = 0, fCall = 0;
    String cat3bet = SpotCategory.premium;
    String catCall = SpotCategory.potControl;

    if (_mwValuePure.contains(hand)) {
      // Pure 3-bet value multiway — squeeze out callers and build pot.
      f3bet = 1.0;
      cat3bet = SpotCategory.premium;
    } else if (_mwValueMix.contains(hand)) {
      // Mix 3-bet/call: vs two callers, calling multiway is fine with implied odds.
      f3bet = numCallers >= 2 ? 0.35 : 0.55;
      fCall = 1.0 - f3bet;
      cat3bet = SpotCategory.value;
      catCall = SpotCategory.potControl;
    } else if (_mwImplied.contains(hand)) {
      // These hands WANT multiple callers in the pot.
      fCall = (0.8 + bonus).clamp(0.0, 1.0);
      // No 3-bet bluffs multiway — fold equity collapses.
      catCall = HandClasses.isPair(hand) && HandClasses.hiRank(hand) <= 9
          ? SpotCategory.setMining
          : SpotCategory.speculative;
    } else if (_mwCallMarginal.contains(hand)) {
      // Marginal callers: defend IP, fold OOP with squeeze risk.
      if (ip) {
        fCall = (0.55 + bonus).clamp(0.0, 0.85);
        catCall = SpotCategory.potControl;
      } else if (isBB) {
        fCall = 0.4; // cheap but OOP
        catCall = SpotCategory.defenseMdf;
      }
    } else if (score > 0.55) {
      // Mid-strength hands that can complete cheaply in BB or flat IP.
      if (isBB) {
        fCall = 0.45;
        catCall = SpotCategory.defenseMdf;
      } else if (ip && score > 0.6) {
        fCall = 0.3;
        catCall = SpotCategory.marginalMix;
      }
    }

    final total = f3bet + fCall;
    if (total > 1.0) { f3bet /= total; fCall /= total; }
    final fFold = (1.0 - f3bet - fCall).clamp(0.0, 1.0);

    final ev3bet = cat3bet == SpotCategory.premium
        ? (score - 0.62) * 11.0
        : 0.15;
    final evCall = ((score - 0.45 + bonus) * 3.5 + (numCallers * 0.3)).clamp(0.05, 3.0);

    final actions = <SpotRecord>[];
    if (f3bet > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: hLbl, villainPosition: '$oLbl+$cLbls',
        hand: hand, action: '3bet', frequency: _r(f3bet),
        ev: _r(ev3bet.clamp(0.1, 10.0)),
        category: cat3bet,
        explanation: cat3bet == SpotCategory.premium
            ? '$hand SQUEEZE por valor multiway desde $hLbl: con $numCallers '
                '${numCallers == 1 ? "caller" : "callers"} en el bote tienes dinero '
                'muerto + rangos capados. Sizing grande (4x open +1 por caller). '
                'Con AA/KK nunca te arrepientes de construir el bote ahora.'
            : '$hand 3-betea al ${(f3bet * 100).round()}% multiway: mano fuerte '
                'que quiere aislarse en bote más pequeño. Con menos rivales tu '
                'equity por calle vale más.',
      ));
    }
    if (fCall > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: hLbl, villainPosition: '$oLbl+$cLbls',
        hand: hand, action: 'call', frequency: _r(fCall),
        ev: _r(evCall),
        category: catCall,
        explanation: catCall == SpotCategory.setMining
            ? '$hand paga multiway buscando set: con $numCallers caller(s) en el '
                'bote, las implied odds son MÁXIMAS — ligas un set y cobras a todos. '
                '~12% de ratio, stacks profundos = call claro. Sin set, fold.'
            : catCall == SpotCategory.speculative
                ? '$hand flatea desde $hLbl en bote multiway: $desc conecta flops '
                    'de proyecto que cobran stacks completos con $numCallers rivales. '
                    'El EV real viene de flops donde nadie más conecta bien.'
                : catCall == SpotCategory.defenseMdf
                    ? '$hand completa en BB multiway al ${(fCall * 100).round()}%: '
                        'tu descuento de ciega + implied odds con $numCallers rivales '
                        'hace el call rentable. OOP — juega fit-or-fold honesto.'
                    : '$hand flatea (${ (fCall * 100).round()}%) en posición multiway: '
                        'con ${ip ? "ventaja posicional" : "descuento de ciega"} y '
                        '$numCallers rival(es), el bote vale la pena con $desc.',
      ));
    }
    if (fFold > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: hLbl, villainPosition: '$oLbl+$cLbls',
        hand: hand, action: 'fold', frequency: _r(fFold),
        ev: 0,
        category: fFold > 0.9 ? SpotCategory.trashFold : SpotCategory.marginalMix,
        explanation: '$hand foldea en el spot multiway: con $numCallers rival(es) '
            'ya en el bote, los faroles pierden valor y la mano necesita más equity '
            'para justificar la inversión. La disciplina preflop aquí es EV directo.',
      ));
    }
    return HandStrategy(spotId: spotId, hand: hand, actions: actions);
  }

  static List<HandStrategy> fullRange(
      TablePosition hero, TablePosition opener, List<TablePosition> callers) {
    return HandClasses.all
        .map((h) => strategy(hero, opener, callers, h))
        .toList();
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}
