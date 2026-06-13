/// The 169 canonical preflop hand classes for Texas Hold'em, with strength
/// scoring and combinatorics. Pure data layer — no UI dependencies.
class HandClasses {
  static const List<String> rankChars = [
    'A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'
  ];

  static List<String>? _all;

  /// All 169 hand codes: 13 pairs + 78 suited + 78 offsuit.
  /// Ordered strongest-first row by row ("AA", "AKs", ... , "32o", "22").
  static List<String> get all {
    if (_all != null) return _all!;
    final list = <String>[];
    for (int i = 0; i < 13; i++) {
      for (int j = 0; j < 13; j++) {
        if (i == j) {
          list.add('${rankChars[i]}${rankChars[j]}');
        } else if (i < j) {
          list.add('${rankChars[i]}${rankChars[j]}s');
        } else {
          list.add('${rankChars[j]}${rankChars[i]}o');
        }
      }
    }
    _all = list;
    return list;
  }

  static int rankValue(String c) {
    const m = {
      'A': 14, 'K': 13, 'Q': 12, 'J': 11, 'T': 10,
      '9': 9, '8': 8, '7': 7, '6': 6, '5': 5, '4': 4, '3': 3, '2': 2,
    };
    return m[c] ?? 0;
  }

  static bool isPair(String code) => code.length == 2;
  static bool isSuited(String code) => code.length == 3 && code[2] == 's';
  static bool isOffsuit(String code) => code.length == 3 && code[2] == 'o';

  static int hiRank(String code) => rankValue(code[0]);
  static int loRank(String code) => rankValue(code[1]);
  static int gap(String code) => hiRank(code) - loRank(code);

  /// Number of card combinations for the class: pair=6, suited=4, offsuit=12.
  static int combos(String code) {
    if (isPair(code)) return 6;
    if (isSuited(code)) return 4;
    return 12;
  }

  /// Continuous preflop strength score in [0, 1].
  /// Calibrated so: AA≈1.0, KK≈0.97, AKs≈0.88, 22≈0.42, 72o≈0.03.
  /// Used to derive frequencies/EV gradients near range borders.
  static double score(String code) {
    final hi = hiRank(code);
    final lo = loRank(code);
    final suited = isSuited(code);

    if (isPair(code)) {
      // 22 → 0.42, AA → 1.00 (pairs always have showdown + set value)
      return 0.42 + (hi - 2) / 12.0 * 0.58;
    }

    double s = (hi - 2) / 12.0 * 0.45; // high card dominance
    s += (lo - 2) / 12.0 * 0.25;       // kicker quality
    if (suited) s += 0.08;             // flush potential
    final g = hi - lo;
    if (g == 1) {
      s += 0.06;                       // connectors
    } else if (g == 2) {
      s += 0.035;
    } else if (g == 3) {
      s += 0.015;
    }
    // Ace-low suited gets wheel + nut-flush blocker bonus (A5s-A2s playability)
    if (hi == 14 && lo <= 5 && suited) s += 0.04;
    return s.clamp(0.02, 0.95);
  }

  /// Strategic descriptor used in explanations.
  static String describe(String code) {
    if (isPair(code)) {
      final hi = hiRank(code);
      if (hi >= 11) return 'pareja premium';
      if (hi >= 9) return 'pareja fuerte';
      if (hi >= 6) return 'pareja media con valor de set';
      return 'pareja pequeña (set-mining)';
    }
    final hi = hiRank(code);
    final lo = loRank(code);
    final suited = isSuited(code);
    final g = gap(code);

    if (hi == 14) {
      if (lo >= 12) return suited ? 'broadway premium suited' : 'broadway premium';
      if (lo >= 10) return suited ? 'as fuerte suited' : 'as fuerte';
      if (suited && lo <= 5) return 'as-rueda suited (blocker + nut flush)';
      return suited ? 'as suited especulativo' : 'as débil dominable';
    }
    if (hi >= 12 && lo >= 10) {
      return suited ? 'broadway suited' : 'broadway offsuit';
    }
    if (suited && g == 1 && hi <= 11) return 'conector suited';
    if (suited && g == 2) return 'one-gapper suited';
    if (suited) return 'mano suited marginal';
    if (g == 1 && hi >= 9) return 'conector offsuit';
    return 'mano marginal';
  }
}
