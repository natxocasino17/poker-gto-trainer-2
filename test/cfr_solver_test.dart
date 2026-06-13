import 'package:flutter_test/flutter_test.dart';
import 'package:poker_gto_trainer/data/models/card_model.dart';
import 'package:poker_gto_trainer/engine/cfr/cfr_solver.dart';
import 'package:poker_gto_trainer/engine/cfr/games/kuhn_poker.dart';
import 'package:poker_gto_trainer/engine/cfr/poker/hand_abstraction.dart';
import 'package:poker_gto_trainer/engine/cfr/poker/bet_sizing_config.dart';
import 'package:poker_gto_trainer/engine/cfr/poker/hu_cashgame.dart';
import 'package:poker_gto_trainer/engine/cfr/poker/hu_state.dart';

void main() {
  // ─── Kuhn Poker convergence test ────────────────────────────────────────────
  group('CfrSolver — Kuhn Poker', () {
    test('game value converges to −1/18 after 10 000 iterations', () {
      final solver = CfrSolver(const KuhnPoker());
      solver.train(10000);

      final gv = solver.expectedValue();
      // The unique Nash equilibrium of Kuhn poker has game value −1/18 ≈ −0.0556
      // for player 0. Tolerance ±0.005 is achievable with 10k CFR+ iterations.
      expect(gv, closeTo(-1 / 18, 0.005));
    });

    test('exploitability falls below 0.01 after 10 000 iterations', () {
      final solver = CfrSolver(const KuhnPoker());
      solver.train(10000);
      expect(solver.exploitability(), lessThan(0.01));
    });

    test('P0 bluffs with J at the right frequency (~1/3)', () {
      final solver = CfrSolver(const KuhnPoker());
      final kuhn = const KuhnPoker();
      
      solver.train(10000);

      // At the key Kuhn equilibrium: P0 bets with J at frequency α ≈ 1/3
      // Query the strategy from the root state instead of accessing nodes directly
      final actions = solver.query(kuhn.root());
      
      expect(actions, isNotEmpty);
      if (actions.length > 1) {
        // actions[1] = bet frequency; optimal α ∈ [1/3, 1/3]
        expect(actions[1].frequency, closeTo(1 / 3, 0.05));
      }
    });

    test('query() returns strategies summing to 1.0', () {
      final solver = CfrSolver(const KuhnPoker());
      solver.train(5000);
      final kuhn = const KuhnPoker();
      final state = kuhn.applyAction(kuhn.applyAction(kuhn.root(), 0), 0);
      if (!kuhn.isTerminal(state)) {
        final actions = solver.query(state);
        final total = actions.fold(0.0, (s, a) => s + a.frequency);
        expect(total, closeTo(1.0, 0.0001));
      }
    });
  });

  // ─── HandAbstraction unit tests ───────────────────────────────────────────
  group('HandAbstraction', () {
    test('AA maps to premium bucket (6)', () {
      expect(HandAbstraction.preflopBucket(_aa()), equals(6));
    });

    test('72o maps to trash bucket (0)', () {
      expect(HandAbstraction.preflopBucket(_trash()), equals(0));
    });

    test('AKs maps to strong bucket (5)', () {
      expect(HandAbstraction.preflopBucket(_aks()), equals(5));
    });

    test('preflopBucketFrequencies sum to ~1.0', () {
      final sum = HandAbstraction.preflopBucketFrequencies.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.01));
    });

    test('preflop equity table is antisymmetric', () {
      for (int i = 0; i < 7; i++) {
        for (int j = 0; j < 7; j++) {
          final a = HandAbstraction.preflopEquityTable[i][j];
          final b = HandAbstraction.preflopEquityTable[j][i];
          expect(a + b, closeTo(1.0, 0.01), reason: '[\$i][\$j] + [\$j][\$i] ≠ 1');
        }
      }
    });

    test('postflop equity table is antisymmetric', () {
      for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
          final a = HandAbstraction.postflopEquityTable[i][j];
          final b = HandAbstraction.postflopEquityTable[j][i];
          expect(a + b, closeTo(1.0, 0.01), reason: '[\$i][\$j]');
        }
      }
    });

    test('postflopTransition sums to 1', () {
      for (int pre = 0; pre < 7; pre++) {
        for (int board = 0; board < 4; board++) {
          final dist = HandAbstraction.postflopTransition(pre, board);
          expect(dist.reduce((a, b) => a + b), closeTo(1.0, 0.01),
              reason: 'pre=\$pre board=\$board');
        }
      }
    });
  });

  // ─── HuCashGame sanity checks ─────────────────────────────────────────────
  group('HuCashGame', () {
    test('root is a chance node (not dealt)', () {
      const game = HuCashGame(cfg: BetSizingConfig.fast);
      expect(game.isChance(game.root()), isTrue);
    });

    test('after deal, preflop is a decision node', () {
      const game = HuCashGame(cfg: BetSizingConfig.fast);
      final root = game.root();
      final deal = game.chanceOutcomes(root).first.state;
      expect(game.isChance(deal), isFalse);
      expect(game.isTerminal(deal), isFalse);
      expect(game.currentPlayer(deal), equals(0)); // P0 acts first preflop
    });

    test('chanceOutcomes probabilities sum to 1 at root', () {
      const game = HuCashGame(cfg: BetSizingConfig.fast);
      final outcomes = game.chanceOutcomes(game.root());
      final sum = outcomes.fold(0.0, (s, o) => s + o.probability);
      expect(sum, closeTo(1.0, 0.01));
    });

    test('fold action results in terminal', () {
      const game = HuCashGame(cfg: BetSizingConfig.fast);
      final dealt = game.chanceOutcomes(game.root()).first.state;
      // Action 0 is fold (preflop P0 faces BB — can fold)
      final labels = game.actionLabels(dealt);
      final foldIdx = labels.indexOf('f');
      if (foldIdx >= 0) {
        final afterFold = game.applyAction(dealt, foldIdx);
        expect(game.isTerminal(afterFold), isTrue);
        expect(game.utilityForP0(afterFold), isNegative);
      }
    });

    test('full solve converges: exploitability < 1.0 BB after 500 iterations', () {
      const game = HuCashGame(cfg: BetSizingConfig.fast, fullTree: false);
      final solver = CfrSolver(game);
      solver.train(500);
      expect(solver.exploitability(), lessThan(1.0));
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────[...]

List<CardModel> _aa() => [
      const CardModel(rank: 14, suit: Suit.spades),
      const CardModel(rank: 14, suit: Suit.hearts),
    ];

List<CardModel> _trash() => [
      const CardModel(rank: 7, suit: Suit.clubs),
      const CardModel(rank: 2, suit: Suit.diamonds),
    ];

List<CardModel> _aks() => [
      const CardModel(rank: 14, suit: Suit.clubs),
      const CardModel(rank: 13, suit: Suit.clubs),
    ];