import 'dart:math';

enum Suit { clubs, diamonds, hearts, spades }

class CardModel {
  final int rank;
  final Suit suit;

  const CardModel({required this.rank, required this.suit});

  String get rankSymbol {
    const map = {
      2: '2', 3: '3', 4: '4', 5: '5', 6: '6', 7: '7', 8: '8',
      9: '9', 10: 'T', 11: 'J', 12: 'Q', 13: 'K', 14: 'A',
    };
    return map[rank] ?? '?';
  }

  String get suitSymbol {
    switch (suit) {
      case Suit.clubs: return '♣';
      case Suit.diamonds: return '♦';
      case Suit.hearts: return '♥';
      case Suit.spades: return '♠';
    }
  }

  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;

  @override
  String toString() => '$rankSymbol$suitSymbol';

  Map<String, dynamic> toJson() => {'r': rank, 's': suit.index};

  factory CardModel.fromJson(Map<String, dynamic> j) =>
      CardModel(rank: j['r'] as int, suit: Suit.values[j['s'] as int]);

  @override
  bool operator ==(Object other) =>
      other is CardModel && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => rank * 4 + suit.index;

  static List<CardModel> freshDeck() {
    final deck = <CardModel>[];
    for (final s in Suit.values) {
      for (int r = 2; r <= 14; r++) {
        deck.add(CardModel(rank: r, suit: s));
      }
    }
    return deck;
  }

  static List<CardModel> shuffledDeck() {
    final deck = freshDeck();
    deck.shuffle(Random.secure());
    return deck;
  }

  /// Simplified preflop hand strength 0.0–1.0
  static double preflopStrength(List<CardModel> hole) {
    if (hole.length != 2) return 0.5;
    final r1 = hole[0].rank;
    final r2 = hole[1].rank;
    final suited = hole[0].suit == hole[1].suit;
    final hi = max(r1, r2);
    final lo = min(r1, r2);

    if (hi == lo) {
      return 0.38 + (hi - 2) / 12.0 * 0.62;
    }
    double score = (hi - 2) / 12.0 * 0.42;
    score += (lo - 2) / 12.0 * 0.22;
    if (suited) score += 0.09;
    final gap = hi - lo;
    if (gap == 1) score += 0.06;
    else if (gap == 2) score += 0.03;
    return score.clamp(0.03, 0.82);
  }
}
