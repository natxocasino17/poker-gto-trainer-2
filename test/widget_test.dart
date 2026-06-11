import 'package:flutter_test/flutter_test.dart';
import 'package:poker_gto_trainer/core/utils/hand_evaluator.dart';
import 'package:poker_gto_trainer/data/models/card_model.dart';

void main() {
  test('Hand evaluator detects a flush correctly', () {
    final cards = [
      const CardModel(rank: 14, suit: Suit.spades),
      const CardModel(rank: 10, suit: Suit.spades),
      const CardModel(rank: 7, suit: Suit.spades),
      const CardModel(rank: 4, suit: Suit.spades),
      const CardModel(rank: 2, suit: Suit.spades),
      const CardModel(rank: 9, suit: Suit.hearts),
      const CardModel(rank: 3, suit: Suit.diamonds),
    ];
    final score = HandEvaluator.evaluateBest(cards);
    expect(score.category, HandCategory.flush);
  });

  test('Full house beats flush', () {
    final fullHouse = HandEvaluator.evaluateBest([
      const CardModel(rank: 9, suit: Suit.spades),
      const CardModel(rank: 9, suit: Suit.hearts),
      const CardModel(rank: 9, suit: Suit.clubs),
      const CardModel(rank: 5, suit: Suit.diamonds),
      const CardModel(rank: 5, suit: Suit.spades),
    ]);
    final flush = HandEvaluator.evaluateBest([
      const CardModel(rank: 14, suit: Suit.spades),
      const CardModel(rank: 10, suit: Suit.spades),
      const CardModel(rank: 7, suit: Suit.spades),
      const CardModel(rank: 4, suit: Suit.spades),
      const CardModel(rank: 2, suit: Suit.spades),
    ]);
    expect(fullHouse.compareTo(flush) > 0, true);
  });
}
