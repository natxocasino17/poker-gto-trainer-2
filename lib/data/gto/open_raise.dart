import '../../core/utils/preflop_charts.dart';
import '../models/player_model.dart';
import 'hand_classes.dart';
import 'spot_record.dart';

/// OPEN RAISE FIRST-IN database — 6-max cash 100BB.
///
/// Covers all 169 hand classes for UTG, HJ(MP), CO, BTN and SB with
/// open/fold frequencies, EV and coach-grade explanations.
///
/// Built on top of the studied ranges in [PreflopCharts] (the "rangos
/// estudiados" layer), adding mixed-frequency borders, an EV model and a
/// per-hand strategic explanation.
class OpenRaiseDB {
  /// Position open-score thresholds used by the EV model (looser → lower).
  static const Map<TablePosition, double> _threshold = {
    TablePosition.utg: 0.565,
    TablePosition.mp: 0.535,
    TablePosition.co: 0.485,
    TablePosition.btn: 0.415,
    TablePosition.sb: 0.445,
  };

  /// Border hands opened at mixed frequency (≈50%) per position — the hands a
  /// solver mixes to stay unexploitable rather than playing pure.
  static const Map<TablePosition, Set<String>> _mixed = {
    TablePosition.utg: {'66', '55', 'A9s', 'KTs', 'QTs', 'T9s', '98s', 'ATo', 'KJo'},
    TablePosition.mp: {'44', '33', 'A7s', 'A6s', 'K9s', 'Q9s', 'J9s', '87s', '76s', 'ATo', 'KJo', 'QJo'},
    TablePosition.co: {'A5o', 'K8s', 'Q8s', 'J8s', 'T8s', '97s', '86s', '75s', '65s', '54s', 'K9o', 'Q9o', 'J9o', 'T9o'},
    TablePosition.btn: {'K2s', 'Q6s', 'Q5s', 'J7s', 'T7s', '96s', '85s', '74s', '64s', '53s', '43s', 'A2o', 'K8o', 'Q8o', 'J8o', 'T8o', '98o', '97o', '87o', '76o'},
    TablePosition.sb: {'K6s', 'K5s', 'Q8s', 'J8s', 'T8s', '97s', '86s', '75s', '64s', '54s', 'A7o', 'A6o', 'A5o', 'K9o', 'Q9o', 'J9o', 'T8o', '98o', '87o'},
  };

  static String positionLabel(TablePosition p) {
    switch (p) {
      case TablePosition.utg: return 'UTG';
      case TablePosition.mp: return 'HJ';
      case TablePosition.co: return 'CO';
      case TablePosition.btn: return 'BTN';
      case TablePosition.sb: return 'SB';
      case TablePosition.bb: return 'BB';
    }
  }

  /// Open-raise frequency for [hand] from [pos] (0, 0.5 or 1.0).
  static double openFrequency(TablePosition pos, String hand) {
    if (pos == TablePosition.bb) return 0; // BB never opens (checks or faces SB)
    final chart = PreflopCharts.rfi(pos, hand);
    if (chart != ChartAction.fold) return 1.0;
    if (_mixed[pos]?.contains(hand) ?? false) return 0.5;
    return 0.0;
  }

  /// EV of opening [hand] from [pos], in BB. Negative for hands that should fold.
  static double openEv(TablePosition pos, String hand) {
    final score = HandClasses.score(hand);
    final th = _threshold[pos] ?? 0.5;
    final raw = (score - th) * 6.0;
    // Premium hands cap around +4.5 BB; clear folds bottom out at -0.6.
    return raw.clamp(-0.6, 4.5);
  }

  /// Strategic category for the hand in an RFI context.
  static String category(TablePosition pos, String hand) {
    final chart = PreflopCharts.rfi(pos, hand);
    switch (chart) {
      case ChartAction.fourBetCall:
        return SpotCategory.premium;
      case ChartAction.fourBetFold:
        return SpotCategory.bluffBlockers;
      case ChartAction.orCall3B:
        return SpotCategory.value;
      case ChartAction.orFold:
        final s = HandClasses.score(hand);
        if (HandClasses.isPair(hand) && HandClasses.hiRank(hand) <= 7) {
          return SpotCategory.setMining;
        }
        return s > 0.5 ? SpotCategory.value : SpotCategory.speculative;
      case ChartAction.fold:
        return (_mixed[pos]?.contains(hand) ?? false)
            ? SpotCategory.marginalMix
            : SpotCategory.trashFold;
    }
  }

  /// Full mixed strategy (open/fold) for one hand at one position.
  static HandStrategy strategy(TablePosition pos, String hand) {
    final posLbl = positionLabel(pos);
    final spotId = 'rfi_${posLbl.toLowerCase()}';
    final f = openFrequency(pos, hand);
    final ev = openEv(pos, hand);
    final cat = category(pos, hand);
    final desc = HandClasses.describe(hand);

    final actions = <SpotRecord>[];
    if (f > 0) {
      actions.add(SpotRecord(
        spotId: spotId,
        heroPosition: posLbl,
        hand: hand,
        action: 'open',
        frequency: f,
        ev: ev > 0 ? ev : 0.05,
        category: cat,
        explanation: _openExplanation(posLbl, hand, desc, f, ev, cat),
      ));
    }
    if (f < 1) {
      actions.add(SpotRecord(
        spotId: spotId,
        heroPosition: posLbl,
        hand: hand,
        action: 'fold',
        frequency: 1 - f,
        ev: 0,
        category: f > 0 ? SpotCategory.marginalMix : SpotCategory.trashFold,
        explanation: _foldExplanation(posLbl, hand, desc, f),
      ));
    }
    return HandStrategy(spotId: spotId, hand: hand, actions: actions);
  }

  /// All 169 hands for one opening position.
  static List<HandStrategy> fullRange(TablePosition pos) {
    return HandClasses.all.map((h) => strategy(pos, h)).toList();
  }

  // ─── Explanations (coach voice, es) ─────────────────────────────────────────

  static String _openExplanation(
      String pos, String hand, String desc, double freq, double ev, String cat) {
    final evTxt = ev.toStringAsFixed(2);
    switch (cat) {
      case SpotCategory.premium:
        return '$hand es $desc: abre SIEMPRE desde $pos y planea meter todo el '
            'dinero contra un 3-bet. EV ≈ +$evTxt BB. Estas manos construyen el '
            'bote por valor puro: subir pequeño solo invita a que te realicen equity.';
      case SpotCategory.bluffBlockers:
        return '$hand abre desde $pos y funciona como 4-bet bluff si te 3-betean: '
            'el As bloquea AA/AK del rival, lo que reduce sus combos de continuar. '
            'Tiene jugabilidad postflop (nut flush, rueda) si pagan. EV ≈ +$evTxt BB.';
      case SpotCategory.value:
        return '$hand ($desc) es apertura estándar de $pos con EV ≈ +$evTxt BB. '
            'Domina al rango que te paga y juega bien postflop. Contra un 3-bet, '
            'paga en posición y reevalúa el flop; no conviertas la mano en farol.';
      case SpotCategory.setMining:
        return '$hand abre desde $pos buscando set-mining: pagas poco para '
            'intentar ligar un set (~12% por flop) que cobra stacks completos. '
            'Si te 3-betean grande, fold sin remordimiento: las implied odds desaparecen.';
      case SpotCategory.speculative:
        return '$hand ($desc) entra en el rango de $pos por su jugabilidad: '
            'conecta proyectos que pueden presionar como semibluff. Abre pero '
            'mantén disciplina postflop si el board no coopera. EV ≈ +$evTxt BB.';
      case SpotCategory.marginalMix:
        return '$hand está justo en el borde del rango de $pos: el equilibrio lo '
            'abre ~${(freq * 100).round()}% de las veces. Mézclalo — abrir siempre '
            'te hace explotable por 3-bets, foldear siempre regala el robo de ciegas.';
      default:
        return '$hand abre desde $pos con EV ≈ +$evTxt BB.';
    }
  }

  static String _foldExplanation(String pos, String hand, String desc, double openFreq) {
    if (openFreq > 0) {
      return '$hand se mezcla en $pos: el ${(100 - openFreq * 100).round()}% de las '
          'veces va al muck. Cuando la mesa tiene 3-bettors agresivos detrás, '
          'inclínate por el fold; contra mesas pasivas, ábrela más a menudo.';
    }
    return '$hand ($desc) no es rentable de abrir desde $pos: demasiados '
        'jugadores por actuar detrás y dominación frecuente cuando te pagan. '
        'Foldear aquí no pierde EV — abrir sí lo haría.';
  }

  /// Export the entire RFI database as JSON-serialisable records.
  static List<Map<String, dynamic>> exportJson() {
    final out = <Map<String, dynamic>>[];
    for (final pos in [
      TablePosition.utg, TablePosition.mp, TablePosition.co,
      TablePosition.btn, TablePosition.sb,
    ]) {
      for (final hs in fullRange(pos)) {
        out.addAll(hs.actions.map((a) => a.toJson()));
      }
    }
    return out;
  }
}
