import 'package:flutter_test/flutter_test.dart';
import 'package:poker_gto_trainer/engine/poker_engine.dart';

void main() {
  group('Side pots by contribution (not 50/50)', () {
    test('Two uneven all-ins HU: excess returns to the bigger stack', () {
      // A all-in 100, B all-in 60. Only 60 of A's bet is matched; the extra 40
      // is uncalled and must go back to A. The 120 main pot goes to the winner.
      // Seat 0 = A, seat 1 = B. Make B (seat 1) the best hand.
      final w = PokerEngine.computeSidePotWinnings(
        contrib: [100, 60],
        folded: [false, false],
        bestAmong: (eligible) =>
            eligible.contains(1) ? [1] : [eligible.first],
      );
      expect(w[0], closeTo(40, 1e-9)); // A gets the uncalled 40 back
      expect(w[1], closeTo(120, 1e-9)); // B wins the 120 main pot
      expect(w[0] + w[1], closeTo(160, 1e-9)); // chips conserved
    });

    test('Same spot but the big stack wins: takes main pot + its excess', () {
      final w = PokerEngine.computeSidePotWinnings(
        contrib: [100, 60],
        folded: [false, false],
        bestAmong: (eligible) =>
            eligible.contains(0) ? [0] : [eligible.first],
      );
      expect(w[0], closeTo(160, 1e-9)); // 120 main + 40 uncalled
      expect(w[1], closeTo(0, 1e-9));
    });

    test('Short all-in wins only the main pot; side pot to the bigger contributors', () {
      // A all-in 20 (best hand), B and C each put 60. Main pot = 20*3 = 60 → A.
      // Side pot = (60-20)*2 = 80 contested between B and C only → say C wins.
      final w = PokerEngine.computeSidePotWinnings(
        contrib: [20, 60, 60],
        folded: [false, false, false],
        bestAmong: (eligible) {
          if (eligible.contains(0)) return [0]; // A wins layers it's in
          return eligible.contains(2) ? [2] : [eligible.first];
        },
      );
      expect(w[0], closeTo(60, 1e-9)); // A capped at the main pot
      expect(w[2], closeTo(80, 1e-9)); // side pot to C
      expect(w[1], closeTo(0, 1e-9));
      expect(w[0] + w[1] + w[2], closeTo(140, 1e-9));
    });

    test('Folded players are dead money, not refunded', () {
      // A 100 (folded), B 100, C 100. B wins. Whole 300 to B.
      final w = PokerEngine.computeSidePotWinnings(
        contrib: [100, 100, 100],
        folded: [true, false, false],
        bestAmong: (eligible) => eligible.contains(1) ? [1] : [eligible.first],
      );
      expect(w[1], closeTo(300, 1e-9));
      expect(w[0], closeTo(0, 1e-9));
    });

    test('Split pot of a contested layer divides evenly', () {
      final w = PokerEngine.computeSidePotWinnings(
        contrib: [50, 50],
        folded: [false, false],
        bestAmong: (eligible) => eligible, // tie
      );
      expect(w[0], closeTo(50, 1e-9));
      expect(w[1], closeTo(50, 1e-9));
    });
  });
}
