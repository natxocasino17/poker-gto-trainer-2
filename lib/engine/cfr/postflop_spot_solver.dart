import '../../data/models/card_model.dart';
import 'cfr_solver.dart';
import 'poker/bet_sizing_config.dart';
import 'poker/hand_abstraction.dart';
import 'poker/hu_state.dart';
import 'poker/postflop_spot_game.dart';

/// Result of solving one postflop subgame spot (see [PostflopSpotGame]).
class PostflopSpotResult {
  final int heroPostBucket;
  final int boardBucket;
  final HuStreet street;
  final List<ActionStrategy> actions;
  final int iterations;

  const PostflopSpotResult({
    required this.heroPostBucket,
    required this.boardBucket,
    required this.street,
    required this.actions,
    required this.iterations,
  });

  /// Action played most often in equilibrium.
  ActionStrategy get dominantAction =>
      actions.reduce((a, b) => a.frequency >= b.frequency ? a : b);
}

/// Synchronous, single-street CFR "continual re-solving" for postflop spots.
///
/// [SpotSolver] (in `spot_solver.dart`) maintains one long-lived tree that
/// only ever trains preflop nodes in practice (see [PostflopSpotGame]'s doc
/// for why a full 4-street tree isn't tractable on mobile). This solver takes
/// the opposite approach for postflop: build a brand-new, tiny subgame exactly
/// matching the real spot's stacks/pot/facing-bet, and solve it from scratch.
/// Because the tree is so small, that's cheap enough to do on every query
/// (tens of milliseconds for a few hundred iterations) and it always reflects
/// the real money in the pot — no abstraction staleness from a long-lived
/// warm tree solved for different stack depths.
class PostflopSpotSolver {
  static const int defaultIterations = 300;

  /// Solves and queries hero's equilibrium strategy at the given postflop
  /// spot, or null if [board] isn't postflop (fewer than 3 cards) or
  /// [heroCards] aren't a complete hand.
  static PostflopSpotResult? query({
    required List<CardModel> heroCards,
    required List<CardModel> board,
    required int heroSeat,
    required double heroStack,
    required double villainStack,
    required double pot,
    double facingBet = 0,
    BetSizingConfig cfg = BetSizingConfig.fast,
    int iterations = defaultIterations,
  }) {
    if (board.length < 3 || heroCards.length != 2) return null;

    final heroPostBucket = HandAbstraction.postflopBucket(heroCards, board);
    final boardBucket = HandAbstraction.boardBucket(board);
    final streetIdx = board.length == 3 ? 1 : board.length == 4 ? 2 : 3;
    final street = HuStreet.values[streetIdx];

    // Hand-specific terminal equity (real hand + run-out) vs each villain tier,
    // computed once for this spot. This is what makes the solve reflect the
    // ACTUAL hand and value draws correctly instead of a coarse bucket table.
    final heroEq = HandAbstraction.heroEquityByVillainBucket(heroCards, board);

    final game = PostflopSpotGame(
      cfg: cfg,
      heroPostBucket: heroPostBucket,
      boardBucket: boardBucket,
      street: street,
      heroSeat: heroSeat,
      heroStack: heroStack,
      villainStack: villainStack,
      pot: pot,
      facingBet: facingBet,
      heroEqByVillBucket: heroEq,
    );

    final solver = CfrSolver<HuState>(game);
    solver.train(iterations);
    final actions = solver.query(game.dealtRoot());

    return PostflopSpotResult(
      heroPostBucket: heroPostBucket,
      boardBucket: boardBucket,
      street: street,
      actions: actions,
      iterations: iterations,
    );
  }
}
