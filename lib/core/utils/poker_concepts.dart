import 'dart:math';
import '../../data/models/card_model.dart';
import 'hand_evaluator.dart';

/// Relative strength buckets of a hand versus the board.
enum HandBucket {
  nuts,          // straight flush, quads, top full house, nut flush/straight, top set
  strongValue,   // flush, straight, set, two pair (both hole cards), overpair
  mediumValue,   // top pair, strong pocket pair, weak two pair
  weakShowdown,  // middle/bottom pair, ace high
  comboDraw,     // flush draw + straight draw / pair (12+ outs)
  strongDraw,    // flush draw or open-ended straight draw (8-9 outs)
  weakDraw,      // gutshot or two overcards (4-6 outs)
  air,           // nothing
}

/// Static texture analysis of community cards ("flop mapping": dry,
/// coordinated, monotone, paired boards).
class BoardTexture {
  final bool monotone;     // 3+ cards same suit
  final bool twoTone;      // flush draw possible
  final bool rainbow;
  final bool paired;
  final bool connected;    // 3 cards within a 4-rank window
  final bool aceHigh;
  final bool broadwayHeavy; // 2+ cards T or higher
  final bool low;          // all cards 9 or lower
  final int highestRank;
  /// 0.0 = very dry (K72 rainbow), 1.0 = very wet (9♠8♠7♥)
  final double wetness;

  const BoardTexture({
    required this.monotone,
    required this.twoTone,
    required this.rainbow,
    required this.paired,
    required this.connected,
    required this.aceHigh,
    required this.broadwayHeavy,
    required this.low,
    required this.highestRank,
    required this.wetness,
  });

  static BoardTexture analyze(List<CardModel> board) {
    if (board.isEmpty) {
      return const BoardTexture(
        monotone: false, twoTone: false, rainbow: true, paired: false,
        connected: false, aceHigh: false, broadwayHeavy: false, low: false,
        highestRank: 0, wetness: 0.5,
      );
    }

    final suitCounts = <Suit, int>{};
    for (final c in board) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    final maxSuit = suitCounts.values.reduce(max);
    final monotone = maxSuit >= 3;
    final twoTone = maxSuit == 2;
    final rainbow = maxSuit <= 1;

    final ranks = board.map((c) => c.rank).toList()..sort();
    final paired = ranks.toSet().length < ranks.length;
    final highest = ranks.last;

    // Connectivity: any 3 distinct ranks inside a 4-rank window
    final unique = ranks.toSet().toList()..sort();
    bool connected = false;
    for (int i = 0; i + 2 < unique.length; i++) {
      if (unique[i + 2] - unique[i] <= 4) connected = true;
    }
    // Wheel-style connectivity with the ace
    if (unique.contains(14)) {
      final wheel = unique.map((r) => r == 14 ? 1 : r).toList()..sort();
      for (int i = 0; i + 2 < wheel.length; i++) {
        if (wheel[i + 2] - wheel[i] <= 4) connected = true;
      }
    }

    final broadwayCount = ranks.where((r) => r >= 10).length;

    double wetness = 0.0;
    if (monotone) wetness += 0.40;
    if (twoTone) wetness += 0.22;
    if (connected) wetness += 0.30;
    if (paired) wetness -= 0.12;
    if (ranks.every((r) => r <= 9)) wetness += 0.12;
    wetness = wetness.clamp(0.0, 1.0).toDouble();

    return BoardTexture(
      monotone: monotone,
      twoTone: twoTone,
      rainbow: rainbow,
      paired: paired,
      connected: connected,
      aceHigh: highest == 14,
      broadwayHeavy: broadwayCount >= 2,
      low: ranks.every((r) => r <= 9),
      highestRank: highest,
      wetness: wetness,
    );
  }
}

/// Made-hand + draw analysis of two hole cards against a board.
class HandStrengthAnalysis {
  final HandBucket bucket;
  final HandCategory madeCategory;
  final bool flushDraw;
  final bool nutFlushDraw;
  final bool openEnded;
  final bool gutshot;
  final bool twoOvercards;
  final int outs;
  final double drawEquity; // rule of 2 and 4

  const HandStrengthAnalysis({
    required this.bucket,
    required this.madeCategory,
    required this.flushDraw,
    required this.nutFlushDraw,
    required this.openEnded,
    required this.gutshot,
    required this.twoOvercards,
    required this.outs,
    required this.drawEquity,
  });

  bool get hasStrongDraw => flushDraw || openEnded;
  bool get isComboDraw => bucket == HandBucket.comboDraw;
  bool get isMadeValue =>
      bucket == HandBucket.nuts ||
      bucket == HandBucket.strongValue ||
      bucket == HandBucket.mediumValue;

  static HandStrengthAnalysis analyze(List<CardModel> hole, List<CardModel> board) {
    if (hole.length != 2 || board.length < 3) {
      return const HandStrengthAnalysis(
        bucket: HandBucket.air, madeCategory: HandCategory.highCard,
        flushDraw: false, nutFlushDraw: false, openEnded: false,
        gutshot: false, twoOvercards: false, outs: 0, drawEquity: 0,
      );
    }

    final all = [...hole, ...board];
    final made = HandEvaluator.evaluateBest(all);
    final boardOnly = board.length >= 5
        ? HandEvaluator.evaluateBest(board)
        : null;

    final boardRanks = board.map((c) => c.rank).toList()..sort();
    final topBoard = boardRanks.last;
    final r1 = hole[0].rank, r2 = hole[1].rank;
    final isPocketPair = r1 == r2;

    // ---- Draw detection ----
    final suitCountAll = <Suit, int>{};
    for (final c in all) {
      suitCountAll[c.suit] = (suitCountAll[c.suit] ?? 0) + 1;
    }
    bool flushDraw = false;
    bool nutFlushDraw = false;
    if (board.length < 5) {
      for (final e in suitCountAll.entries) {
        final holeOfSuit = hole.where((c) => c.suit == e.key).length;
        if (e.value == 4 && holeOfSuit >= 1) {
          flushDraw = true;
          // Nut flush draw: we hold the ace of that suit
          nutFlushDraw = hole.any((c) => c.suit == e.key && c.rank == 14);
        }
      }
    }

    // Straight draws: count 5-rank windows containing exactly 4 of our ranks
    final uniqueAll = all.map((c) => c.rank).toSet();
    final withWheelAce = <int>{...uniqueAll, if (uniqueAll.contains(14)) 1};
    int windowsWith4 = 0;
    bool alreadyStraight = made.category == HandCategory.straight ||
        made.category == HandCategory.straightFlush;
    if (!alreadyStraight && board.length < 5) {
      for (int low = 1; low <= 10; low++) {
        final window = [low, low + 1, low + 2, low + 3, low + 4];
        final present = window.where(withWheelAce.contains).length;
        if (present == 4) {
          // Require at least one hole card inside the window
          final holeRanks = <int>{r1, r2, if (r1 == 14) 1, if (r2 == 14) 1};
          if (window.any(holeRanks.contains)) windowsWith4++;
        }
      }
    }
    final openEnded = windowsWith4 >= 2;
    final gutshot = windowsWith4 == 1;

    final twoOvercards = !isPocketPair && r1 > topBoard && r2 > topBoard &&
        made.category == HandCategory.highCard;

    // ---- Outs (with overlap discount) ----
    int outs = 0;
    if (flushDraw) outs += 9;
    if (openEnded) outs += flushDraw ? 6 : 8; // discount shared outs
    if (gutshot) outs += flushDraw ? 3 : 4;
    if (twoOvercards) outs += 6;
    if (made.category == HandCategory.onePair && !isPocketPair) outs += 5; // trips/two-pair outs
    outs = min(outs, 15);

    final cardsToCome = board.length == 3 ? 2 : 1;
    final drawEquity = (outs * (cardsToCome == 2 ? 4 : 2)) / 100.0;

    // ---- Bucket classification ----
    HandBucket bucket;
    final cat = made.category;

    bool boardPlaysItself = boardOnly != null && boardOnly.compareTo(made) == 0;

    if (cat == HandCategory.straightFlush || cat == HandCategory.fourOfAKind) {
      bucket = HandBucket.nuts;
    } else if (cat == HandCategory.fullHouse) {
      bucket = boardPlaysItself ? HandBucket.mediumValue : HandBucket.nuts;
    } else if (cat == HandCategory.flush) {
      final ourFlushHigh = _flushHighCard(hole, board);
      bucket = ourFlushHigh == 14 ? HandBucket.nuts : HandBucket.strongValue;
    } else if (cat == HandCategory.straight) {
      bucket = boardPlaysItself ? HandBucket.weakShowdown : HandBucket.strongValue;
    } else if (cat == HandCategory.threeOfAKind) {
      // Set (pocket pair) vs trips
      if (isPocketPair) {
        bucket = r1 >= topBoard ? HandBucket.nuts : HandBucket.strongValue;
      } else {
        bucket = HandBucket.strongValue;
      }
    } else if (cat == HandCategory.twoPair) {
      final usesBothHole = !isPocketPair && boardRanks.contains(r1) && boardRanks.contains(r2);
      bucket = usesBothHole ? HandBucket.strongValue : HandBucket.mediumValue;
    } else if (cat == HandCategory.onePair) {
      if (isPocketPair && r1 > topBoard) {
        bucket = HandBucket.strongValue; // overpair
      } else if (boardRanks.contains(max(r1, r2)) && max(r1, r2) == topBoard) {
        bucket = HandBucket.mediumValue; // top pair
      } else if (isPocketPair) {
        bucket = r1 >= boardRanks[boardRanks.length ~/ 2]
            ? HandBucket.mediumValue
            : HandBucket.weakShowdown;
      } else {
        bucket = HandBucket.weakShowdown; // middle/bottom pair
      }
    } else {
      // No made hand: classify by draws
      if (flushDraw && (openEnded || gutshot)) {
        bucket = HandBucket.comboDraw;
      } else if (flushDraw || openEnded) {
        bucket = HandBucket.strongDraw;
      } else if (gutshot || twoOvercards) {
        bucket = HandBucket.weakDraw;
      } else if (max(r1, r2) == 14 && board.length == 5) {
        bucket = HandBucket.weakShowdown; // ace high at river
      } else {
        bucket = HandBucket.air;
      }
    }

    // Pair + strong draw upgrades to combo draw strength
    if ((cat == HandCategory.onePair) && flushDraw && bucket != HandBucket.nuts &&
        bucket != HandBucket.strongValue) {
      bucket = HandBucket.comboDraw;
    }

    return HandStrengthAnalysis(
      bucket: bucket,
      madeCategory: cat,
      flushDraw: flushDraw,
      nutFlushDraw: nutFlushDraw,
      openEnded: openEnded,
      gutshot: gutshot,
      twoOvercards: twoOvercards,
      outs: outs,
      drawEquity: drawEquity,
    );
  }

  static int _flushHighCard(List<CardModel> hole, List<CardModel> board) {
    final suitCounts = <Suit, int>{};
    for (final c in [...hole, ...board]) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    for (final e in suitCounts.entries) {
      if (e.value >= 5) {
        final holeOfSuit = hole.where((c) => c.suit == e.key).map((c) => c.rank);
        return holeOfSuit.isEmpty ? 0 : holeOfSuit.reduce(max);
      }
    }
    return 0;
  }
}

/// Card-removal effects: which strong combos of the villain do we block?
class Blockers {
  final bool nutFlushBlocker;  // we hold the ace of a 3-flush board suit
  final bool straightBlocker;  // we hold a card completing the obvious straight
  final bool topCardBlocker;   // we hold a card pairing the top board card
  final bool hasAce;

  const Blockers({
    required this.nutFlushBlocker,
    required this.straightBlocker,
    required this.topCardBlocker,
    required this.hasAce,
  });

  /// Good bluff candidates block villain's continues without having showdown value.
  bool get goodBluffBlockers => nutFlushBlocker || straightBlocker;

  static Blockers analyze(List<CardModel> hole, List<CardModel> board) {
    if (hole.length != 2 || board.isEmpty) {
      return Blockers(
        nutFlushBlocker: false, straightBlocker: false,
        topCardBlocker: false, hasAce: hole.any((c) => c.rank == 14),
      );
    }

    final suitCounts = <Suit, int>{};
    for (final c in board) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    bool nutFlushBlocker = false;
    for (final e in suitCounts.entries) {
      if (e.value >= 3 && hole.any((c) => c.suit == e.key && c.rank == 14)) {
        nutFlushBlocker = true;
      }
    }

    // Straight blocker: hole rank inside the tightest 5-window around board ranks
    final boardRanks = board.map((c) => c.rank).toSet();
    bool straightBlocker = false;
    for (final h in hole) {
      for (int low = 1; low <= 10; low++) {
        final window = List.generate(5, (i) => low + i);
        final boardIn = window.where(boardRanks.contains).length;
        final holeRank = h.rank == 14 && low == 1 ? 1 : h.rank;
        if (boardIn >= 3 && window.contains(holeRank) && !boardRanks.contains(h.rank)) {
          straightBlocker = true;
        }
      }
    }

    final topBoard = board.map((c) => c.rank).reduce(max);
    final topCardBlocker = hole.any((c) => c.rank == topBoard);

    return Blockers(
      nutFlushBlocker: nutFlushBlocker,
      straightBlocker: straightBlocker,
      topCardBlocker: topCardBlocker,
      hasAce: hole.any((c) => c.rank == 14),
    );
  }
}

/// Core GTO equations.
class GtoMath {
  /// Minimum Defense Frequency vs a bet: pot / (pot + bet).
  static double mdf(double pot, double bet) =>
      pot + bet <= 0 ? 1.0 : pot / (pot + bet);

  /// Alpha: how often villain must fold for a 0-equity bluff to break even.
  static double alpha(double pot, double bet) =>
      pot + bet <= 0 ? 0.0 : bet / (pot + bet);

  /// Required equity to call: call / (pot + call) where pot includes the bet.
  static double potOdds(double call, double potIncludingBet) =>
      call <= 0 ? 0.0 : call / (potIncludingBet + call);

  /// Stack-to-pot ratio — commitment metric.
  static double spr(double stack, double pot) => pot <= 0 ? 99.0 : stack / pot;
}

/// Live model of the human's tendencies, fed by the engine — used by
/// exploitative legends (Ivey, Hansen) and by everyone's bluff math.
class HumanReadModel {
  int handsObserved = 0;
  int preflopFolds = 0;
  int preflopVpip = 0;

  int facedBets = 0;
  int foldsVsBet = 0;
  int raisesVsBet = 0;

  int facedTurnRiverBets = 0;
  int foldsVsTurnRiverBets = 0;

  int aggressiveActions = 0;
  int passiveActions = 0;

  /// Overall fold-vs-bet frequency (default 0.5 with Laplace smoothing).
  double get foldVsBetRate =>
      (foldsVsBet + 2) / (facedBets + 4);

  /// Fold rate specifically on turn/river — drives Ivey's barrel exploit.
  double get foldVsBarrelRate =>
      (foldsVsTurnRiverBets + 2) / (facedTurnRiverBets + 4);

  /// Aggression factor: raises+bets / calls.
  double get aggressionFactor =>
      passiveActions == 0 ? 1.0 : aggressiveActions / passiveActions;

  /// Is the human a calling station? Bluff less, value bet thinner.
  bool get isCallingStation => facedBets >= 6 && foldVsBetRate < 0.30;

  /// Does the human overfold? Bluff relentlessly.
  bool get overFolds => facedBets >= 4 && foldVsBetRate > 0.55;
}

/// Heuristic range-vs-range edge on a given texture.
class RangeModel {
  /// Returns [-0.3 .. +0.3]: positive = the preflop aggressor's range
  /// connects better with this board (range advantage), enabling
  /// higher c-bet frequency and bigger sizings (nut advantage proxy).
  static double aggressorRangeAdvantage(BoardTexture t) {
    double adv = 0.0;
    if (t.aceHigh || t.highestRank == 13) adv += 0.18;
    if (t.broadwayHeavy) adv += 0.10;
    if (t.paired && t.highestRank >= 10) adv += 0.05;
    if (t.low) adv -= 0.15;
    if (t.connected) adv -= 0.10;
    if (t.monotone) adv -= 0.05;
    return adv.clamp(-0.3, 0.3).toDouble();
  }
}
