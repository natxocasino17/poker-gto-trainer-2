/// A weighted outcome of a chance (nature) node — e.g. a particular deal.
class ChanceOutcome<S> {
  final S state;
  final double probability;
  const ChanceOutcome(this.state, this.probability);
}

/// Abstract definition of a two-player, zero-sum extensive-form game with
/// imperfect information, expressed as a tree the [CfrSolver] can traverse.
///
/// The game is defined over an opaque immutable state type [S]. Implementations
/// describe *what the game is*; the solver provides the CFR machinery on top.
///
/// Contract:
///   * Exactly two players, indexed 0 and 1.
///   * Zero-sum: [utilityForP0] is player 0's payoff; player 1's is its negation.
///   * Chance is enumerated (not sampled) via [chanceOutcomes] whose
///     probabilities sum to 1 — this keeps small abstracted games solvable to an
///     *exact* equilibrium, which is what makes the engine tractable on mobile.
///   * Information sets are identified by [infoSetKey]: two states the acting
///     player cannot tell apart MUST return the same key, and that key MUST
///     encode the player's private knowledge + the public action history.
abstract class CfrGame<S> {
  const CfrGame();

  /// The initial state — typically a chance node that deals the cards.
  S root();

  bool isTerminal(S state);

  /// Player 0's payoff at a terminal state (player 1's is the negation).
  /// By convention this is measured in big blinds.
  double utilityForP0(S state);

  bool isChance(S state);

  /// Enumerated chance transitions. Probabilities must sum to 1.
  List<ChanceOutcome<S>> chanceOutcomes(S state);

  /// Index (0 or 1) of the player to act at a decision node.
  int currentPlayer(S state);

  /// Number of legal actions at a decision node.
  int numActions(S state);

  /// Human-readable labels for each action index.
  List<String> actionLabels(S state);

  /// Information-set key for the acting player at [state].
  String infoSetKey(S state);

  /// The state resulting from taking [action] (0-based) at a decision node.
  S applyAction(S state, int action);
}
