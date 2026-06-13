import '../../core/utils/preflop_charts.dart';
import '../models/player_model.dart';
import 'hand_classes.dart';
import 'spot_record.dart';

/// FACING 3-BET database: opener's decision after being 3-bet.
///
/// 10 scenarios:
///   UTG open → {HJ,CO,BTN} 3bet · HJ open → BTN 3bet ·
///   CO open → {BTN,SB,BB} 3bet · BTN open → {SB,BB} 3bet · SB open → BB 3bet
///
/// Actions: fold / call / 4bet — with frequency, EV and explanation.
/// The chart layer ([PreflopCharts.rfi]) already encodes each opened hand's
/// plan vs a 3-bet (orFold / orCall3B / fourBetFold / fourBetCall); this
/// module turns that plan into mixed frequencies adjusted by:
///   * Position (in position vs the 3-bettor → defend wider).
///   * 3-bettor's seat (blind 3-bets are wider → defend wider).
class Vs3BetDB {
  static const List<List<TablePosition>> scenarios = [
    [TablePosition.utg, TablePosition.mp],
    [TablePosition.utg, TablePosition.co],
    [TablePosition.utg, TablePosition.btn],
    [TablePosition.mp, TablePosition.btn],
    [TablePosition.co, TablePosition.btn],
    [TablePosition.co, TablePosition.sb],
    [TablePosition.co, TablePosition.bb],
    [TablePosition.btn, TablePosition.sb],
    [TablePosition.btn, TablePosition.bb],
    [TablePosition.sb, TablePosition.bb],
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

  /// Is the opener in position vs the 3-bettor postflop?
  static bool _openerInPosition(TablePosition opener, TablePosition threeBettor) {
    // Blinds are always OOP postflop vs the opener.
    return threeBettor == TablePosition.sb || threeBettor == TablePosition.bb;
  }

  /// Blind 3-bets are wider, so the opener defends more.
  static double _widthBonus(TablePosition threeBettor) {
    switch (threeBettor) {
      case TablePosition.sb:
      case TablePosition.bb:
        return 0.06;
      case TablePosition.btn:
        return 0.03;
      default:
        return 0.0;
    }
  }

  /// Strategy for [hand] when [opener] faces a 3-bet from [threeBettor].
  static HandStrategy strategy(
      TablePosition opener, TablePosition threeBettor, String hand) {
    final oLbl = _lbl(opener);
    final tLbl = _lbl(threeBettor);
    final spotId = 'vs_3bet_${oLbl.toLowerCase()}_vs_${tLbl.toLowerCase()}';
    final plan = PreflopCharts.rfi(opener, hand);
    final score = HandClasses.score(hand);
    final ip = _openerInPosition(opener, threeBettor);
    final bonus = _widthBonus(threeBettor) + (ip ? 0.03 : 0.0);
    final desc = HandClasses.describe(hand);

    double f4bet = 0, fCall = 0;
    String cat4 = SpotCategory.premium, catCall = SpotCategory.potControl;

    switch (plan) {
      case ChartAction.fourBetCall:
        f4bet = 1.0;
        cat4 = SpotCategory.premium;
        break;
      case ChartAction.fourBetFold:
        // 4-bet bluff frequency rises vs wide (blind) 3-bettors.
        f4bet = (0.45 + bonus * 3).clamp(0.0, 0.8);
        cat4 = SpotCategory.bluffBlockers;
        if (ip) {
          fCall = (1 - f4bet) * 0.5; // suited aces can also flat IP
          catCall = SpotCategory.speculative;
        }
        break;
      case ChartAction.orCall3B:
        fCall = (0.75 + bonus * 2).clamp(0.0, 1.0);
        // Top of the call range mixes some value 4-bets vs wide 3-bettors
        if (score > 0.72 && bonus > 0.03) {
          f4bet = 0.25;
          fCall = (fCall - 0.25).clamp(0.0, 1.0);
          cat4 = SpotCategory.value;
        }
        catCall = SpotCategory.potControl;
        break;
      case ChartAction.orFold:
        // Mostly fold; defend the best of it vs wide 3-bettors when IP.
        if (score > 0.55 + (ip ? 0 : 0.04) - bonus) {
          fCall = 0.35;
          catCall = SpotCategory.marginalMix;
        }
        break;
      case ChartAction.fold:
        // Hand wasn't opened — shouldn't face a 3-bet; full fold.
        break;
    }

    final total = f4bet + fCall;
    if (total > 1.0) { f4bet /= total; fCall /= total; }
    final fFold = (1.0 - f4bet - fCall).clamp(0.0, 1.0);

    final ev4 = plan == ChartAction.fourBetCall
        ? (score - 0.6) * 14.0
        : 0.2; // bluff 4-bets ride on fold equity
    final evCall = ((score - 0.55) * 5.0 + (ip ? 0.4 : 0)).clamp(-0.5, 4.0);

    final actions = <SpotRecord>[];
    if (f4bet > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: oLbl, villainPosition: tLbl,
        hand: hand, action: '4bet', frequency: _r(f4bet),
        ev: _r(ev4.clamp(0.1, 12.0)), category: cat4,
        explanation: cat4 == SpotCategory.premium
            ? '$hand 4-betea por valor desde $oLbl contra el 3-bet de $tLbl y '
                'nunca foldea: estás por delante de todo su rango de stack-off. '
                'Sizing: ~2.3x el 3-bet IP, ~2.6x OOP.'
            : '$hand 4-betea como farol (${(f4bet * 100).round()}%) contra el '
                '3-bet de $tLbl: tus blockers ($desc) recortan sus AA/AK y su '
                'rango ancho de 3-bet no puede aguantar la presión. Fold al 5-bet.',
      ));
    }
    if (fCall > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: oLbl, villainPosition: tLbl,
        hand: hand, action: 'call', frequency: _r(fCall),
        ev: _r(evCall.clamp(0.02, 4.0)), category: catCall,
        explanation: ip
            ? '$hand paga el 3-bet de $tLbl en posición: con la ventaja '
                'posicional realizas tu equity de sobra y mantienes su rango '
                'ancho en el bote. SPR ~4: top pair ya juega por stacks con cautela.'
            : '$hand paga el 3-bet fuera de posición — defensa de borde. '
                'Sin iniciativa y OOP, juega fit-or-fold honesto: el bote 3-beteado '
                'castiga la indisciplina más que ningún otro.',
      ));
    }
    if (fFold > 0.01) {
      actions.add(SpotRecord(
        spotId: spotId, heroPosition: oLbl, villainPosition: tLbl,
        hand: hand, action: 'fold', frequency: _r(fFold),
        ev: 0,
        category: fFold > 0.95 ? SpotCategory.trashFold : SpotCategory.marginalMix,
        explanation: '$hand foldea al 3-bet de $tLbl el ${(fFold * 100).round()}%: '
            'pagar OOP con una mano dominada quema dinero a fuego lento. Abrir '
            'no te compromete — el fold disciplinado ES la jugada profesional.',
      ));
    }
    return HandStrategy(spotId: spotId, hand: hand, actions: actions);
  }

  static List<HandStrategy> fullRange(TablePosition opener, TablePosition threeBettor) {
    return HandClasses.all.map((h) => strategy(opener, threeBettor, h)).toList();
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}
