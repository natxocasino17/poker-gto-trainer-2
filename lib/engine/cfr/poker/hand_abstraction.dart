import 'dart:math';
import '../../../data/models/card_model.dart';
import '../../../core/utils/poker_concepts.dart';
import '../../../core/utils/hand_evaluator.dart';

/// Maps concrete hole cards and boards to abstract "buckets" so the CFR solver
/// works on a tractable game tree rather than the full 1326-hand space.
///
/// **Preflop buckets (0 = trash, 6 = premium):**
///   0  Trash:    72o-class garbage            (<36% equity HU vs random)
///   1  Weak:     Low suited connectors, Kxo   (36–44%)
///   2  Marginal: Small pairs, weak aces       (44–52%)
///   3  Playable: 55-66, KTs, QJs, ATo, A8s   (52–60%)
///   4  Good:     77-88, AJs, ATs, KQs, AQo   (60–72%)
///   5  Strong:   99-TT, AKs, AKo, AQs        (72–85%)
///   6  Premium:  JJ-AA                        (85%+)
///
/// **Postflop buckets (0 = air, 4 = monster):**
///   0  Air:     No pair, gutshot or worse
///   1  Draw:    Flush-draw / OESD / weak pair
///   2  Medium:  Top pair weak kicker, middle pair, combo draw
///   3  Strong:  Top pair top kicker, two pair, overpair
///   4  Monster: Set, flush, straight, full house, quads, straight flush
class HandAbstraction {
  static const int preflopBuckets = 7;
  static const int postflopBuckets = 5;
  static const int boardBuckets = 4;

  // ---------------------------------------------------------------------------
  // Preflop bucketing
  // ---------------------------------------------------------------------------

  /// Maps any two hole cards to a preflop bucket 0–6.
  static int preflopBucket(List<CardModel> hole) {
    if (hole.length != 2) return 0;
    final r1 = hole[0].rank;
    final r2 = hole[1].rank;
    final hi = max(r1, r2);
    final lo = min(r1, r2);
    final suited = hole[0].suit == hole[1].suit;
    final paired = hi == lo;

    if (paired) {
      if (hi >= 11) return 6; // JJ+
      if (hi >= 9) return 5;  // TT, 99
      if (hi >= 7) return 4;  // 88, 77
      if (hi >= 5) return 3;  // 66, 55
      return 2;                // 44, 33, 22
    }

    if (hi == 14) { // Ace-x
      if (lo >= 13) return 5;                    // AK (both)
      if (lo >= 12) return suited ? 5 : 4;       // AQ
      if (lo >= 11) return suited ? 4 : 4;       // AJ
      if (lo >= 10) return suited ? 4 : 3;       // AT
      if (lo >= 8)  return suited ? 3 : 1;       // A8, A9
      if (lo >= 5)  return suited ? 2 : 0;       // A5-A7
      return suited ? 2 : 0;                     // A2-A4
    }

    if (hi == 13) { // King-x
      if (lo >= 12) return suited ? 4 : 3;       // KQ
      if (lo >= 11) return suited ? 3 : 2;       // KJ
      if (lo >= 10) return suited ? 3 : 2;       // KT
      if (lo >= 9)  return suited ? 2 : 1;       // K9
      if (lo >= 6)  return suited ? 1 : 0;       // K6-K8
      return suited ? 1 : 0;                     // K2-K5
    }

    if (hi == 12) { // Queen-x
      if (lo >= 11) return suited ? 3 : 2;       // QJ
      if (lo >= 10) return suited ? 2 : 1;       // QT
      if (lo >= 9)  return suited ? 1 : 1;       // Q9
      if (lo >= 8)  return suited ? 1 : 0;       // Q8
      return 0;
    }

    if (hi == 11) { // Jack-x
      if (lo >= 10) return suited ? 3 : 1;       // JT
      if (lo >= 9)  return suited ? 2 : 1;       // J9
      if (lo >= 8)  return suited ? 1 : 0;       // J8
      return 0;
    }

    // T and below — only the best suited connectors reach bucket 1
    if (hi == 10 && lo == 9) return suited ? 2 : 1; // T9
    if (hi == 10 && lo == 8) return suited ? 1 : 0; // T8
    if (hi == 9  && lo == 8) return suited ? 1 : 0; // 98
    if (hi == 8  && lo == 7) return suited ? 1 : 0; // 87
    if (hi == 7  && lo == 6) return suited ? 1 : 0; // 76
    if (hi == 6  && lo == 5) return suited ? 1 : 0; // 65
    if (hi == 5  && lo == 4) return suited ? 1 : 0; // 54

    return 0;
  }

  /// Approximate fraction of all 1326 hole-card combos in each preflop bucket.
  /// Used to weight the initial chance node. Pre-computed, sums to 1.
  static const List<double> preflopBucketFrequencies = [
    0.310, // 0 trash   ≈411 combos
    0.173, // 1 weak    ≈229 combos
    0.138, // 2 marg    ≈183 combos
    0.128, // 3 play    ≈170 combos
    0.108, // 4 good    ≈143 combos
    0.089, // 5 strong  ≈118 combos
    0.054, // 6 premium ≈72 combos
  ];

  // ---------------------------------------------------------------------------
  // Postflop bucketing
  // ---------------------------------------------------------------------------

  /// Maps hole cards + board to a postflop bucket 0–4.
  /// Delegates to the existing [HandStrengthAnalysis] from poker_concepts.
  static int postflopBucket(List<CardModel> hole, List<CardModel> board) {
    if (hole.length < 2 || board.isEmpty) return 2;
    final analysis = HandStrengthAnalysis.analyze(hole, board);
    switch (analysis.bucket) {
      case HandBucket.nuts:
      case HandBucket.strongValue:
        return 4;
      case HandBucket.mediumValue:
        return 3;
      case HandBucket.weakShowdown:
        return 2;
      case HandBucket.comboDraw:
      case HandBucket.strongDraw:
        return 1;
      case HandBucket.weakDraw:
      case HandBucket.air:
        return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Board bucketing
  // ---------------------------------------------------------------------------

  /// Classifies community cards into a board bucket:
  ///   0 Dry:      K72r, uncoordinated rainbow
  ///   1 Semi-wet: one draw possible (flush OR straight, not both)
  ///   2 Wet:      Flush draw + straight draw, highly coordinated
  ///   3 Paired:   Board has a paired rank
  static int boardBucket(List<CardModel> community) {
    if (community.isEmpty) return 0;
    final texture = BoardTexture.analyze(community);
    if (texture.paired) return 3;
    if ((texture.monotone || texture.twoTone) && texture.connected) return 2;
    if (texture.twoTone || texture.connected) return 1;
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Equity tables
  // ---------------------------------------------------------------------------

  /// P0's showdown equity vs P1 at PREFLOP, indexed [p0Bucket][p1Bucket].
  /// Rows and columns: 0=trash, 6=premium.
  /// Values approximate HU equity when both players go to showdown.
  /// Antisymmetric: table[i][j] + table[j][i] ≈ 1.0
  static const List<List<double>> preflopEquityTable = [
    // p1:  0     1     2     3     4     5     6
    [0.50, 0.38, 0.33, 0.30, 0.27, 0.22, 0.15], // p0=0 trash
    [0.62, 0.50, 0.44, 0.40, 0.36, 0.30, 0.22], // p0=1 weak
    [0.67, 0.56, 0.50, 0.46, 0.42, 0.35, 0.26], // p0=2 marg
    [0.70, 0.60, 0.54, 0.50, 0.46, 0.39, 0.30], // p0=3 play
    [0.73, 0.64, 0.58, 0.54, 0.50, 0.43, 0.33], // p0=4 good
    [0.78, 0.70, 0.65, 0.61, 0.57, 0.50, 0.38], // p0=5 strong
    [0.85, 0.78, 0.74, 0.70, 0.67, 0.62, 0.50], // p0=6 prem
  ];

  /// P0's showdown equity vs P1 at POSTFLOP, indexed [p0PostBucket][p1PostBucket].
  /// 0=air, 4=monster.
  static const List<List<double>> postflopEquityTable = [
    // p1:  0     1     2     3     4
    [0.50, 0.32, 0.20, 0.11, 0.05], // p0=0 air
    [0.68, 0.50, 0.36, 0.24, 0.13], // p0=1 draw
    [0.80, 0.64, 0.50, 0.37, 0.22], // p0=2 medium
    [0.89, 0.76, 0.63, 0.50, 0.32], // p0=3 strong
    [0.95, 0.87, 0.78, 0.68, 0.50], // p0=4 monster
  ];

  /// P0's showdown equity given preflop buckets only (used for preflop-only solve).
  static double preflopShowdownEquity(int p0, int p1) {
    return preflopEquityTable[p0.clamp(0, 6)][p1.clamp(0, 6)];
  }

  /// P0's showdown equity given postflop buckets (used at terminal nodes).
  static double postflopShowdownEquity(int p0, int p1) {
    return postflopEquityTable[p0.clamp(0, 4)][p1.clamp(0, 4)];
  }

  /// The HERO's REAL showdown equity (with the full board run-out) split by the
  /// villain's CURRENT-board postflop bucket (0..4). This is the key to a
  /// realistic postflop solve: instead of the coarse static [postflopEquityTable]
  /// (which says "bucket 3 beats bucket 2 63% of the time" for any hand), this
  /// measures THIS exact hand on THIS board vs each villain tier, and runs the
  /// remaining cards out — so draws get their real realized equity and made
  /// hands are valued for what they actually are.
  ///
  /// One Monte Carlo pass tallies all five buckets at once (deterministic seed
  /// from the hero+board, so the advisor/analyzer are reproducible). Buckets
  /// with no sampled villain hands return -1 (caller falls back to the table).
  static final Map<String, List<double>> _heroEqCache = {};

  static List<double> heroEquityByVillainBucket(
    List<CardModel> hero,
    List<CardModel> board, {
    int simulations = 1600,
  }) {
    if (hero.length != 2 || board.length < 3 || board.length > 5) {
      return List.filled(5, -1.0);
    }
    int id(CardModel c) => c.rank * 4 + c.suit.index;
    // Cache by exact hand+board (the advisor and the analyzer often query the
    // very same spot) so each is only Monte-Carlo'd once.
    final cacheKey =
        '${(hero.map(id).toList()..sort()).join(",")}|${(board.map(id).toList()..sort()).join(",")}';
    final cached = _heroEqCache[cacheKey];
    if (cached != null) return cached;

    final wins = List<double>.filled(5, 0.0);
    final counts = List<int>.filled(5, 0);
    final known = <int>{for (final c in hero) id(c), for (final c in board) id(c)};
    final deck = [
      for (final c in CardModel.freshDeck()) if (!known.contains(id(c))) c
    ];
    final boardNeeded = 5 - board.length;

    int seed = 17;
    for (final c in [...hero, ...board]) {
      seed = seed * 131 + id(c);
    }
    final rng = Random(seed & 0x7fffffff);

    for (int sim = 0; sim < simulations; sim++) {
      deck.shuffle(rng);
      final villain = [deck[0], deck[1]];
      final vb = postflopBucket(villain, board);
      final full = boardNeeded > 0
          ? [...board, ...deck.sublist(2, 2 + boardNeeded)]
          : board;
      final hs = HandEvaluator.evaluateBest([...hero, ...full]);
      final vs = HandEvaluator.evaluateBest([...villain, ...full]);
      final cmp = hs.compareTo(vs);
      wins[vb] += cmp > 0 ? 1.0 : (cmp == 0 ? 0.5 : 0.0);
      counts[vb]++;
    }
    final result = [
      for (int i = 0; i < 5; i++) counts[i] > 0 ? wins[i] / counts[i] : -1.0
    ];
    if (_heroEqCache.length >= 4000) _heroEqCache.clear();
    _heroEqCache[cacheKey] = result;
    return result;
  }

  // ---------------------------------------------------------------------------
  // Street transition: preflop bucket → postflop bucket distribution
  // ---------------------------------------------------------------------------

  /// P(postflop_bucket | preflop_bucket, board_bucket).
  /// [preflopBkt] 0-6, [boardBkt] 0-3.
  /// Returns a 5-element probability vector summing to 1.
  ///
  /// Higher preflop buckets shift the distribution toward stronger postflop
  /// holdings. Wet boards (boardBkt=2) increase the weight of draw bucket (1).
  static List<double> postflopTransition(int preflopBkt, int boardBkt) {
    // Base transition for a dry board [0], indexed by preflop bucket.
    const base = [
      [0.50, 0.24, 0.16, 0.07, 0.03], // 0 trash
      [0.35, 0.28, 0.22, 0.11, 0.04], // 1 weak
      [0.24, 0.28, 0.27, 0.15, 0.06], // 2 marg
      [0.18, 0.23, 0.30, 0.20, 0.09], // 3 play
      [0.13, 0.18, 0.30, 0.25, 0.14], // 4 good
      [0.09, 0.13, 0.26, 0.30, 0.22], // 5 strong
      [0.05, 0.10, 0.22, 0.33, 0.30], // 6 prem
    ];

    final dist = List<double>.from(base[preflopBkt.clamp(0, 6)]);

    // Board wetness shifts weight toward draw bucket (1) and away from air (0).
    if (boardBkt == 2) {        // wet
      dist[0] -= 0.06;
      dist[1] += 0.08;
      dist[2] -= 0.02;
      dist[4] += 0.00;
    } else if (boardBkt == 1) { // semi-wet
      dist[0] -= 0.03;
      dist[1] += 0.04;
      dist[2] -= 0.01;
    } else if (boardBkt == 3) { // paired board
      dist[3] += 0.04;
      dist[0] -= 0.02;
      dist[1] -= 0.02;
    }

    // Clamp negatives and re-normalise.
    for (int i = 0; i < 5; i++) {
      if (dist[i] < 0) dist[i] = 0;
    }
    final sum = dist.reduce((a, b) => a + b);
    return sum > 0 ? dist.map((v) => v / sum).toList() : List.filled(5, 0.2);
  }

  /// Approximate probability of each board type given the dealt hand.
  /// Board types: 0=dry, 1=semi, 2=wet, 3=paired.
  /// Higher suited / connected preflop hands prefer wet/semi boards (they
  /// interact better), but the board distribution is mostly independent.
  static const List<double> boardTypeProbabilities = [0.30, 0.32, 0.26, 0.12];
}
