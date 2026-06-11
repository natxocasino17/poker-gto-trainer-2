import '../../data/models/card_model.dart';

enum HandCategory {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
}

class HandScore implements Comparable<HandScore> {
  final HandCategory category;
  final List<int> tiebreakers;
  final String description;

  const HandScore({
    required this.category,
    required this.tiebreakers,
    required this.description,
  });

  @override
  int compareTo(HandScore other) {
    final c = category.index.compareTo(other.category.index);
    if (c != 0) return c;
    for (int i = 0; i < tiebreakers.length && i < other.tiebreakers.length; i++) {
      final d = tiebreakers[i].compareTo(other.tiebreakers[i]);
      if (d != 0) return d;
    }
    return 0;
  }

  bool operator >(HandScore o) => compareTo(o) > 0;
  bool operator <(HandScore o) => compareTo(o) < 0;
  bool operator >=(HandScore o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object o) => o is HandScore && compareTo(o) == 0;
  @override
  int get hashCode => Object.hashAll([category, ...tiebreakers]);

  static String categoryLabel(HandCategory c) {
    switch (c) {
      case HandCategory.highCard: return 'High Card';
      case HandCategory.onePair: return 'One Pair';
      case HandCategory.twoPair: return 'Two Pair';
      case HandCategory.threeOfAKind: return 'Three of a Kind';
      case HandCategory.straight: return 'Straight';
      case HandCategory.flush: return 'Flush';
      case HandCategory.fullHouse: return 'Full House';
      case HandCategory.fourOfAKind: return 'Four of a Kind';
      case HandCategory.straightFlush: return 'Straight Flush';
    }
  }
}

class HandEvaluator {
  static HandScore evaluateBest(List<CardModel> cards) {
    assert(cards.length >= 5 && cards.length <= 7,
        'Need 5-7 cards, got ${cards.length}');

    if (cards.length == 5) return _eval5(cards);

    HandScore? best;
    final n = cards.length;
    for (int a = 0; a < n - 4; a++) {
      for (int b = a + 1; b < n - 3; b++) {
        for (int c = b + 1; c < n - 2; c++) {
          for (int d = c + 1; d < n - 1; d++) {
            for (int e = d + 1; e < n; e++) {
              final s = _eval5([cards[a], cards[b], cards[c], cards[d], cards[e]]);
              if (best == null || s > best) best = s;
            }
          }
        }
      }
    }
    return best!;
  }

  static HandScore _eval5(List<CardModel> cards) {
    final sorted = List<CardModel>.from(cards)
      ..sort((a, b) => b.rank.compareTo(a.rank));
    final ranks = sorted.map((c) => c.rank).toList();

    final Map<int, int> freq = {};
    for (final r in ranks) freq[r] = (freq[r] ?? 0) + 1;

    final isFlush = cards.map((c) => c.suit).toSet().length == 1;

    bool isStraight = false;
    int straightHigh = 0;

    if (freq.length == 5) {
      if (ranks.first - ranks.last == 4) {
        isStraight = true;
        straightHigh = ranks.first;
      }
      // Wheel A-2-3-4-5
      if (ranks.first == 14 && ranks[1] == 5 && ranks[2] == 4 &&
          ranks[3] == 3 && ranks[4] == 2) {
        isStraight = true;
        straightHigh = 5;
      }
    }

    final groups = freq.entries.toList()
      ..sort((a, b) {
        if (a.value != b.value) return b.value.compareTo(a.value);
        return b.key.compareTo(a.key);
      });

    if (isFlush && isStraight) {
      final desc = straightHigh == 14
          ? 'Royal Flush'
          : 'Straight Flush, ${_rn(straightHigh)} high';
      return HandScore(
          category: HandCategory.straightFlush,
          tiebreakers: [straightHigh],
          description: desc);
    }

    if (groups[0].value == 4) {
      final q = groups[0].key;
      final k = groups[1].key;
      return HandScore(
          category: HandCategory.fourOfAKind,
          tiebreakers: [q, k],
          description: 'Four of a Kind, ${_rn(q)}s');
    }

    if (groups[0].value == 3 && groups[1].value == 2) {
      return HandScore(
          category: HandCategory.fullHouse,
          tiebreakers: [groups[0].key, groups[1].key],
          description: 'Full House, ${_rn(groups[0].key)}s full of ${_rn(groups[1].key)}s');
    }

    if (isFlush) {
      return HandScore(
          category: HandCategory.flush,
          tiebreakers: ranks,
          description: 'Flush, ${_rn(ranks.first)} high');
    }

    if (isStraight) {
      return HandScore(
          category: HandCategory.straight,
          tiebreakers: [straightHigh],
          description: 'Straight, ${_rn(straightHigh)} high');
    }

    if (groups[0].value == 3) {
      final t = groups[0].key;
      final ks = groups.skip(1).map((e) => e.key).toList();
      return HandScore(
          category: HandCategory.threeOfAKind,
          tiebreakers: [t, ...ks],
          description: 'Three of a Kind, ${_rn(t)}s');
    }

    if (groups[0].value == 2 && groups[1].value == 2) {
      final p1 = groups[0].key;
      final p2 = groups[1].key;
      final k = groups[2].key;
      return HandScore(
          category: HandCategory.twoPair,
          tiebreakers: [p1, p2, k],
          description: 'Two Pair, ${_rn(p1)}s and ${_rn(p2)}s');
    }

    if (groups[0].value == 2) {
      final p = groups[0].key;
      final ks = groups.skip(1).map((e) => e.key).toList();
      return HandScore(
          category: HandCategory.onePair,
          tiebreakers: [p, ...ks],
          description: 'One Pair, ${_rn(p)}s');
    }

    return HandScore(
        category: HandCategory.highCard,
        tiebreakers: ranks,
        description: 'High Card, ${_rn(ranks.first)}');
  }

  static String _rn(int r) {
    const m = {
      2: 'Two', 3: 'Three', 4: 'Four', 5: 'Five', 6: 'Six',
      7: 'Seven', 8: 'Eight', 9: 'Nine', 10: 'Ten',
      11: 'Jack', 12: 'Queen', 13: 'King', 14: 'Ace',
    };
    return m[r] ?? '$r';
  }

  static List<int> findWinners(List<List<CardModel>> playerCards, List<CardModel> board) {
    final scores = playerCards.map((hole) {
      if (hole.isEmpty) return null;
      return evaluateBest([...hole, ...board]);
    }).toList();

    HandScore? best;
    for (final s in scores) {
      if (s != null && (best == null || s > best)) best = s;
    }

    final winners = <int>[];
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] != null && scores[i]! >= best!) {
        winners.add(i);
      }
    }
    return winners;
  }
}
