import 'dart:async';
import 'dart:isolate';
import '../../data/models/card_model.dart';
import 'cfr_solver.dart';
import 'info_set.dart';
import 'poker/bet_sizing_config.dart';
import 'poker/hand_abstraction.dart';
import 'poker/hu_cashgame.dart';
import 'poker/hu_state.dart';

/// High-level result for a single information set after solving.
class SpotResult {
  /// Player 0 or 1 (BTN=0, BB=1 in HU).
  final int player;

  /// Preflop bucket of the hero's hand (0=trash, 6=premium).
  final int handBucket;

  /// Postflop bucket (0=air, 4=monster), or null on preflop.
  final int? postBucket;

  /// Action frequencies and EVs at this information set.
  final List<ActionStrategy> actions;

  /// Total pot at this node (in BB).
  final double pot;

  /// Effective stack at this node (in BB).
  final double effectiveStack;

  /// Street.
  final HuStreet street;

  /// Exploitability estimate at time of query (in BB per hand).
  final double exploitability;

  /// Number of CFR iterations completed.
  final int iterations;

  const SpotResult({
    required this.player,
    required this.handBucket,
    this.postBucket,
    required this.actions,
    required this.pot,
    required this.effectiveStack,
    required this.street,
    required this.exploitability,
    required this.iterations,
  });

  /// Best action by frequency (the action played most in equilibrium).
  ActionStrategy get dominantAction =>
      actions.reduce((a, b) => a.frequency >= b.frequency ? a : b);

  /// Best action by EV.
  ActionStrategy get highestEvAction =>
      actions.reduce((a, b) => a.ev >= b.ev ? a : b);
}

/// Asynchronous CFR spot-solver.
///
/// For preflop and fast postflop spots, [solve] runs the training loop on an
/// [Isolate] so the UI thread stays responsive. For sub-200ms quick queries,
/// the synchronous [solveSync] overload is also available.
class SpotSolver {
  final BetSizingConfig config;
  final bool fullTree;

  /// Shared node map — persists across successive [solve] calls so later solves
  /// benefit from earlier work (warm-start behaviour).
  final Map<String, InformationSet> _sharedNodes = {};

  CfrSolver<HuState>? _solver;

  SpotSolver({
    this.config = BetSizingConfig.standard,
    this.fullTree = false,
  });

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Runs [iterations] CFR+ iterations on the HU tree.
  ///
  /// [progressCallback] is invoked from the calling isolate (via a
  /// [ReceivePort]) every [progressEvery] iterations.
  Future<void> solve({
    int iterations = 1000,
    void Function(int iter, double exploitability)? progressCallback,
    int progressEvery = 200,
  }) {
    final completer = Completer<void>();
    final port = ReceivePort();

    // Serialise the current nodes so the isolate can warm-start.
    final serialised = <String, Map<String, dynamic>>{};
    for (final e in _sharedNodes.entries) {
      serialised[e.key] = e.value.toJson();
    }

    Isolate.spawn(
      _isolateEntry,
      _IsolateArgs(
        sendPort: port.sendPort,
        config: config,
        fullTree: fullTree,
        iterations: iterations,
        progressEvery: progressEvery,
        warmNodes: serialised,
      ),
    );

    port.listen((msg) {
      if (msg is _ProgressMsg) {
        progressCallback?.call(msg.iter, msg.exploitability);
      } else if (msg is _DoneMsg) {
        // Merge solved nodes back into shared map.
        for (final e in msg.nodes.entries) {
          _sharedNodes[e.key] = InformationSet.fromJson(e.value);
        }
        _solver = null; // will be rebuilt on next query
        port.close();
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Synchronous solve — runs directly on the calling thread.
  /// Suitable for small iteration counts or background-isolate contexts.
  void solveSync({int iterations = 500}) {
    final solver = _getSolver();
    solver.train(
      iterations,
      onProgress: null,
      progressEvery: iterations,
    );
  }

  /// Queries the equilibrium strategy for a specific spot.
  ///
  /// [heroCards] are the actual hole cards (bucketed internally).
  /// [board] is the current board (empty = preflop).
  /// [player] 0=BTN, 1=BB.
  /// [pot] total pot size in BB.
  /// [effectiveStack] remaining stack in BB.
  SpotResult query({
    required List<CardModel> heroCards,
    required List<CardModel> board,
    required int player,
    required double pot,
    required double effectiveStack,
    String publicHistory = '',
  }) {
    final solver = _getSolver();
    final isPreflop = board.isEmpty;

    final prefBkt = HandAbstraction.preflopBucket(heroCards);
    final postBkt = isPreflop ? -1 : HandAbstraction.postflopBucket(heroCards, board);
    final boardBkt = isPreflop ? -1 : HandAbstraction.boardBucket(board);
    final streetIdx = board.length == 0 ? 0 : board.length == 3 ? 1 : board.length == 4 ? 2 : 3;
    final street = HuStreet.values[streetIdx];

    // Build a representative query state.
    final oppPrefBkt = 3; // assume opponent at "playable" bucket (median)
    final oppPostBkt = isPreflop ? -1 : 2;

    final p0PreBkt = player == 0 ? prefBkt : oppPrefBkt;
    final p1PreBkt = player == 1 ? prefBkt : oppPrefBkt;
    final p0PostBkt = player == 0 ? postBkt : oppPostBkt;
    final p1PostBkt = player == 1 ? postBkt : oppPostBkt;

    final queryState = HuState(
      p0PreflopBucket:  p0PreBkt,
      p1PreflopBucket:  p1PreBkt,
      p0PostBucket:     p0PostBkt,
      p1PostBucket:     p1PostBkt,
      boardBucket:      boardBkt,
      street:           street,
      pot:              pot,
      p0Stack:          player == 0 ? effectiveStack : effectiveStack,
      p1Stack:          player == 1 ? effectiveStack : effectiveStack,
      p0StreetBet:      0,
      p1StreetBet:      0,
      toAct:            player,
      actorsLeft:       2,
      history:          publicHistory,
    );

    final actionStrategies = solver.query(queryState);

    return SpotResult(
      player: player,
      handBucket: prefBkt,
      postBucket: isPreflop ? null : postBkt,
      actions: actionStrategies,
      pot: pot,
      effectiveStack: effectiveStack,
      street: street,
      exploitability: solver.exploitability(),
      iterations: solver.iterations,
    );
  }

  /// Exposes the raw node map for persistence.
  Map<String, InformationSet> get nodes {
    _getSolver(); // ensures _sharedNodes is loaded
    return Map.unmodifiable(_sharedNodes);
  }

  /// Merges externally loaded nodes (e.g., from persistence) into the solver.
  void loadNodes(Map<String, Map<String, dynamic>> jsonNodes) {
    for (final e in jsonNodes.entries) {
      _sharedNodes[e.key] = InformationSet.fromJson(e.value);
    }
    _solver = null;
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  CfrSolver<HuState> _getSolver() {
    if (_solver != null) return _solver!;
    final game = HuCashGame(cfg: config, fullTree: fullTree);
    final solver = CfrSolver<HuState>(game);
    solver.nodes.addAll(_sharedNodes);
    _solver = solver;
    return solver;
  }

  // ─── Isolate entry ────────────────────────────────────────────────────────

  static void _isolateEntry(_IsolateArgs args) {
    final game = HuCashGame(cfg: args.config, fullTree: args.fullTree);
    final solver = CfrSolver<HuState>(game);

    // Warm-start from serialised nodes.
    for (final e in args.warmNodes.entries) {
      solver.nodes[e.key] = InformationSet.fromJson(e.value);
    }

    solver.train(
      args.iterations,
      onProgress: (iter, expl) {
        args.sendPort.send(_ProgressMsg(iter, expl));
      },
      progressEvery: args.progressEvery,
    );

    final serialised = <String, Map<String, dynamic>>{};
    for (final e in solver.nodes.entries) {
      serialised[e.key] = e.value.toJson();
    }
    args.sendPort.send(_DoneMsg(serialised));
  }
}

// ─── Isolate message types ────────────────────────────────────────────────────

class _IsolateArgs {
  final SendPort sendPort;
  final BetSizingConfig config;
  final bool fullTree;
  final int iterations;
  final int progressEvery;
  final Map<String, Map<String, dynamic>> warmNodes;

  const _IsolateArgs({
    required this.sendPort,
    required this.config,
    required this.fullTree,
    required this.iterations,
    required this.progressEvery,
    required this.warmNodes,
  });
}

class _ProgressMsg {
  final int iter;
  final double exploitability;
  const _ProgressMsg(this.iter, this.exploitability);
}

class _DoneMsg {
  final Map<String, Map<String, dynamic>> nodes;
  const _DoneMsg(this.nodes);
}
