import '../../data/models/card_model.dart';
import '../../data/models/player_model.dart';

/// Preflop range charts (FormaPoker micro-limits style).
///
/// RFI chart semantics — each hand in range carries its full plan:
///  - orFold:      open raise, fold to a 3-bet
///  - orCall3B:    open raise, call a 3-bet
///  - fourBetFold: open raise, 4-bet as a bluff, fold to a 5-bet
///  - fourBetCall: open raise, 4-bet for value, call/jam a 5-bet
///
/// Defense chart semantics (facing an open):
///  - call:             flat call
///  - threeBetFold:     polar 3-bet bluff, fold to 4-bet
///  - threeBetCall4B:   3-bet, call a 4-bet
///  - threeBetFiveBet:  3-bet, 5-bet jam over a 4-bet
enum ChartAction { fold, orFold, orCall3B, fourBetFold, fourBetCall }

enum DefenseAction { fold, call, threeBetFold, threeBetCall4B, threeBetFiveBet }

class PreflopCharts {
  /// Canonical hand code: "AA", "AKs", "T9o"...
  static String handCode(List<CardModel> hole) {
    if (hole.length != 2) return '';
    const r = {2:'2',3:'3',4:'4',5:'5',6:'6',7:'7',8:'8',9:'9',10:'T',11:'J',12:'Q',13:'K',14:'A'};
    final hi = hole[0].rank >= hole[1].rank ? hole[0] : hole[1];
    final lo = hole[0].rank >= hole[1].rank ? hole[1] : hole[0];
    if (hi.rank == lo.rank) return '${r[hi.rank]}${r[lo.rank]}';
    final suited = hi.suit == lo.suit ? 's' : 'o';
    return '${r[hi.rank]}${r[lo.rank]}$suited';
  }

  // ───────────────────────── RFI CHARTS ─────────────────────────

  static const Set<String> _premium4BetCall = {'AA', 'KK', 'QQ', 'AKs', 'AKo'};

  static const Map<TablePosition, Set<String>> _fourBetBluff = {
    TablePosition.utg: {'A5s'},
    TablePosition.mp: {'A5s', 'A4s'},
    TablePosition.co: {'A5s', 'A4s', 'A3s'},
    TablePosition.btn: {'A5s', 'A4s', 'A3s', 'A2s', 'KJs'},
    TablePosition.sb: {'A5s', 'A4s', 'A3s', 'A2s'},
    TablePosition.bb: {'A5s', 'A4s'},
  };

  static const Map<TablePosition, Set<String>> _orCall3B = {
    TablePosition.utg: {'JJ', 'TT', 'AQs', 'AJs', 'KQs', 'AQo'},
    TablePosition.mp: {'JJ', 'TT', '99', 'AQs', 'AJs', 'ATs', 'KQs', 'KJs', 'AQo'},
    TablePosition.co: {'JJ', 'TT', '99', '88', 'AQs', 'AJs', 'ATs', 'KQs', 'KJs', 'QJs', 'JTs', 'AQo', 'AJo', 'KQo'},
    TablePosition.btn: {'JJ', 'TT', '99', '88', '77', 'AQs', 'AJs', 'ATs', 'A9s', 'KQs', 'KJs', 'KTs', 'QJs', 'QTs', 'JTs', 'T9s', 'AQo', 'AJo', 'KQo'},
    TablePosition.sb: {'JJ', 'TT', '99', '88', 'AQs', 'AJs', 'ATs', 'KQs', 'KJs', 'QJs', 'JTs', 'AQo', 'AJo', 'KQo'},
    TablePosition.bb: {'JJ', 'TT', 'AQs', 'AJs', 'KQs'},
  };

  static const Map<TablePosition, Set<String>> _orFold = {
    TablePosition.utg: {
      '99', '88', '77', '66', '55',
      'ATs', 'A9s', 'KJs', 'KTs', 'QJs', 'QTs', 'JTs', 'T9s', '98s', '87s', '76s',
      'AJo', 'KQo',
    },
    TablePosition.mp: {
      '88', '77', '66', '55', '44', '33', '22',
      'A9s', 'A8s', 'A7s', 'A6s', 'A3s', 'A2s',
      'KTs', 'K9s', 'QJs', 'QTs', 'Q9s', 'JTs', 'J9s', 'T9s', '98s', '87s', '76s', '65s',
      'AJo', 'ATo', 'KQo', 'KJo',
    },
    TablePosition.co: {
      '77', '66', '55', '44', '33', '22',
      'A9s', 'A8s', 'A7s', 'A6s', 'A2s',
      'KTs', 'K9s', 'K8s', 'QTs', 'Q9s', 'J9s', 'JTs', 'T9s', 'T8s', '98s', '97s', '87s', '86s', '76s', '65s', '54s',
      'ATo', 'A9o', 'KJo', 'KTo', 'QJo', 'QTo', 'JTo',
    },
    TablePosition.btn: {
      '66', '55', '44', '33', '22',
      'A8s', 'A7s', 'A6s',
      'K9s', 'K8s', 'K7s', 'K6s', 'K5s', 'K4s', 'K3s', 'K2s',
      'Q9s', 'Q8s', 'Q7s', 'Q6s', 'J9s', 'J8s', 'J7s',
      'T8s', 'T7s', '98s', '97s', '96s', '87s', '86s', '85s', '76s', '75s', '65s', '64s', '54s', '53s', '43s',
      'ATo', 'A9o', 'A8o', 'A7o', 'A6o', 'A5o', 'A4o', 'A3o', 'A2o',
      'KJo', 'KTo', 'K9o', 'QJo', 'QTo', 'Q9o', 'JTo', 'J9o', 'T9o', '98o',
    },
    TablePosition.sb: {
      '77', '66', '55', '44', '33', '22',
      'A9s', 'A8s', 'A7s', 'A6s',
      'KTs', 'K9s', 'K8s', 'K7s', 'K6s', 'QTs', 'Q9s', 'Q8s', 'JTs', 'J9s', 'J8s',
      'T9s', 'T8s', '98s', '97s', '87s', '86s', '76s', '65s', '54s',
      'ATo', 'A9o', 'A8o', 'KJo', 'KTo', 'K9o', 'QJo', 'QTo', 'JTo', 'T9o',
    },
    TablePosition.bb: {
      '99', '88', 'ATs', 'KJs', 'QJs', 'JTs', 'AQo', 'AJo', 'KQo',
    },
  };

  /// Full RFI lookup: what does the chart say about opening this hand?
  static ChartAction rfi(TablePosition pos, String code) {
    if (_premium4BetCall.contains(code)) return ChartAction.fourBetCall;
    if (_fourBetBluff[pos]!.contains(code)) return ChartAction.fourBetFold;
    if (_orCall3B[pos]!.contains(code)) return ChartAction.orCall3B;
    if (_orFold[pos]!.contains(code)) return ChartAction.orFold;
    return ChartAction.fold;
  }

  // ─────────────────────── DEFENSE CHARTS ───────────────────────

  static const Set<String> _def5Bet = {'AA', 'KK', 'QQ', 'AKs', 'AKo'};
  static const Set<String> _defCall4B = {'JJ', 'TT', 'AQs'};

  static const Map<TablePosition, Set<String>> _def3BetBluff = {
    TablePosition.utg: {'A5s'},
    TablePosition.mp: {'A5s', 'A4s'},
    TablePosition.co: {'A5s', 'A4s', '76s'},
    TablePosition.btn: {'A5s', 'A4s', 'A3s', '76s', '65s'},
    TablePosition.sb: {'A5s', 'A4s', 'A3s', 'A2s', 'K9s', '76s', '65s'},
    TablePosition.bb: {'A5s', 'A4s', 'A3s', 'A2s', 'K9s', 'Q9s', 'J9s', '76s', '65s', '54s'},
  };

  static const Map<TablePosition, Set<String>> _defCall = {
    // Cold-calling an open in position / from the blinds
    TablePosition.utg: {'99', '88', '77', 'AQs', 'AJs', 'KQs'},
    TablePosition.mp: {'99', '88', '77', '66', 'AQs', 'AJs', 'ATs', 'KQs', 'QJs', 'JTs'},
    TablePosition.co: {
      '99', '88', '77', '66', '55', '44', '33', '22',
      'AQs', 'AJs', 'ATs', 'KQs', 'KJs', 'QJs', 'JTs', 'T9s', '98s', '87s', 'AQo',
    },
    TablePosition.btn: {
      '99', '88', '77', '66', '55', '44', '33', '22',
      'AQs', 'AJs', 'ATs', 'A9s', 'KQs', 'KJs', 'KTs', 'QJs', 'QTs', 'JTs',
      'T9s', '98s', '87s', '76s', '65s', 'AQo', 'AJo', 'KQo',
    },
    TablePosition.sb: {
      '99', '88', '77', '66', '55', 'AQs', 'AJs', 'ATs', 'KQs', 'KJs', 'QJs', 'JTs', 'T9s', 'AQo',
    },
    TablePosition.bb: {
      // BB closes the action getting a discount: defend wide
      '99', '88', '77', '66', '55', '44', '33', '22',
      'AQs', 'AJs', 'ATs', 'A9s', 'A8s', 'A7s', 'A6s',
      'KQs', 'KJs', 'KTs', 'K9s', 'K8s', 'K7s', 'K6s', 'K5s',
      'QJs', 'QTs', 'Q9s', 'Q8s', 'JTs', 'J9s', 'J8s',
      'T9s', 'T8s', 'T7s', '98s', '97s', '87s', '86s', '76s', '75s', '64s', '53s', '43s',
      'AQo', 'AJo', 'ATo', 'A9o', 'A8o', 'A7o', 'A5o',
      'KQo', 'KJo', 'KTo', 'K9o', 'QJo', 'QTo', 'Q9o', 'JTo', 'J9o', 'T9o', '98o', '87o',
    },
  };

  /// Defense lookup: facing a single open raise.
  static DefenseAction defense(TablePosition pos, String code) {
    if (_def5Bet.contains(code)) return DefenseAction.threeBetFiveBet;
    if (_defCall4B.contains(code)) return DefenseAction.threeBetCall4B;
    if (_def3BetBluff[pos]!.contains(code)) return DefenseAction.threeBetFold;
    if (_defCall[pos]!.contains(code)) return DefenseAction.call;
    return DefenseAction.fold;
  }
}
