import 'package:flutter_test/flutter_test.dart';
import 'package:poker_gto_trainer/core/utils/hand_evaluator.dart';
import 'package:poker_gto_trainer/data/models/card_model.dart';

void main() {
  test('Two pair on board: higher kicker wins, NOT a tie', () {
    // Board: K K Q Q 7  (two pair on the board, kicker 7)
    final board = [
      const CardModel(rank: 13, suit: Suit.spades),
      const CardModel(rank: 13, suit: Suit.hearts),
      const CardModel(rank: 12, suit: Suit.spades),
      const CardModel(rank: 12, suit: Suit.hearts),
      const CardModel(rank: 7, suit: Suit.clubs),
    ];
    // Player A has an Ace, Player B has a 3.  A must win (KKQQ-A > KKQQ-7).
    final a = [const CardModel(rank: 14, suit: Suit.diamonds), const CardModel(rank: 2, suit: Suit.diamonds)];
    final b = [const CardModel(rank: 3, suit: Suit.diamonds), const CardModel(rank: 4, suit: Suit.diamonds)];
    final winners = HandEvaluator.findWinners([a, b], board);
    print('winners=$winners (expected [0])');
    expect(winners, [0]);
  });
}
