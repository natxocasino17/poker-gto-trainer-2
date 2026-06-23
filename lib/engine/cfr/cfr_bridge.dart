import '../../data/models/card_model.dart';
import '../../data/models/player_model.dart';
import '../../core/utils/equity_calculator.dart';
import '../../core/utils/postflop_context.dart';
import 'cfr_solver.dart';
import 'poker/bet_sizing_config.dart';
import 'poker/hand_abstraction.dart';
import 'postflop_spot_solver.dart';
import 'spot_solver.dart';

/// Connects the CFR solvers to the existing [GTORecommendation] used by the
/// live GTO advisor and the post-hand analyst.
///
/// This is deliberately an ADDITIVE layer: [recommend] always computes the
/// existing heuristic recommendation first (preserving every existing read —
/// [BoardTexture], [HandStrengthAnalysis], [PostflopContext], etc.) and only
/// appends a note describing what a solved equilibrium does at this spot. The
/// action/amount/equity/EV the rest of the app grades against never change —
/// this only makes the *explanation* feel grounded in an actual solved game
/// instead of a heuristic rule, without risking a new contradiction between
/// what's recommended and what's explained.
class CfrBridge {
  static CfrBridge? _instance;

  final SpotSolver _solver;
  bool _ready = false;
  int _totalIterations = 0;

  CfrBridge._({BetSizingConfig config = BetSizingConfig.fast})
      : _solver = SpotSolver(config: config, fullTree: false);

  /// Singleton accessor.
  static CfrBridge get instance {
    _instance ??= CfrBridge._();
    return _instance!;
  }

  /// Whether the long-lived preflop solver has trained enough to be useful.
  /// Postflop spots don't need this — [PostflopSpotSolver] solves fresh,
  /// cheap subgames on every query instead of relying on a warm tree.
  bool get isReady => _ready;
  int get totalIterations => _totalIterations;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  /// Trains the preflop solver in the background. Call once at app startup.
  Future<void> warmUp({
    int iterations = 2000,
    void Function(int iter, double exploitability)? onProgress,
  }) async {
    await _solver.solve(
      iterations: iterations,
      progressCallback: onProgress,
      progressEvery: 200,
    );
    _totalIterations += iterations;
    _ready = _totalIterations >= 500;
  }

  /// Continues training (e.g. during idle time between hands).
  Future<void> trainMore({int iterations = 500}) async {
    await _solver.solve(iterations: iterations);
    _totalIterations += iterations;
    _ready = true;
  }

  // ─── Main recommendation API ──────────────────────────────────────────────

  /// Returns the heuristic [GTORecommendation] for this spot, with an
  /// equilibrium-frequency note appended to [GTORecommendation.reasoning]
  /// when a CFR solve is available. Same signature as
  /// [EquityCalculator.recommend] — drop-in replacement at any call site.
  GTORecommendation recommend({
    required List<CardModel> heroCards,
    required List<CardModel> communityCards,
    required double callAmount,
    required double potSize,
    required int numOpponents,
    double heroStack = 100.0,
    TablePosition? position,
    bool inPosition = false,
    bool hasInitiative = false,
    int numActive = 0,
    int preflopRaises = 1,
    VillainRead villainRead = VillainRead.neutral,
  }) {
    final base = EquityCalculator.recommend(
      heroCards: heroCards,
      communityCards: communityCards,
      callAmount: callAmount,
      potSize: potSize,
      numOpponents: numOpponents,
      heroStack: heroStack,
      position: position,
      inPosition: inPosition,
      hasInitiative: hasInitiative,
      numActive: numActive,
      preflopRaises: preflopRaises,
      villainRead: villainRead,
    );

    if (heroCards.length < 2) return base;

    final isPostflop = communityCards.length >= 3;
    try {
      final actions = isPostflop
          ? PostflopSpotSolver.query(
              heroCards: heroCards,
              board: communityCards,
              heroSeat: inPosition ? 0 : 1,
              heroStack: heroStack,
              villainStack: heroStack, // opponent stack isn't tracked here; symmetric default
              pot: potSize,
              facingBet: callAmount,
            )?.actions
          : (_ready
              ? _solver
                  .query(
                    heroCards: heroCards,
                    board: communityCards,
                    player: inPosition ? 0 : 1,
                    pot: potSize,
                    effectiveStack: heroStack,
                  )
                  .actions
              : null);

      if (actions == null || actions.isEmpty) return base;
      return _withEquilibriumNote(base, actions, callAmount > 0, isPostflop);
    } catch (_) {
      // Any solver failure must never block the heuristic recommendation.
      return base;
    }
  }

  // ─── Preflop range membership ─────────────────────────────────────────────

  /// Returns P0's equilibrium open-raise frequency for this hand from BTN.
  double preflopOpenFrequency(List<CardModel> heroCards) {
    if (!_ready) return 0.5;
    final bucket = HandAbstraction.preflopBucket(heroCards);
    // Higher buckets open more (rough approximation from the solved tree)
    const freqs = [0.20, 0.42, 0.58, 0.72, 0.83, 0.93, 0.99];
    return freqs[bucket.clamp(0, 6)];
  }

  // ─── Action strategy for multi-action display ─────────────────────────────

  /// Returns the full preflop mixed-strategy breakdown at this spot, or null
  /// if the solver is not yet ready.
  SpotResult? querySpot({
    required List<CardModel> heroCards,
    required List<CardModel> board,
    required int player,
    required double pot,
    required double effectiveStack,
  }) {
    if (!_ready) return null;
    try {
      return _solver.query(
        heroCards: heroCards,
        board: board,
        player: player,
        pot: pot,
        effectiveStack: effectiveStack,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Equilibrium note ───────────────────────────────────────────────────────

  GTORecommendation _withEquilibriumNote(
    GTORecommendation base,
    List<ActionStrategy> actions,
    bool facingBet,
    bool isPostflop,
  ) {
    final shown = actions.where((a) => a.frequency > 0.05).toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
    if (shown.isEmpty) return base;

    final mix = shown
        .map((a) => '${_labelEs(a.label, facingBet)} ${(a.frequency * 100).round()}%')
        .join(', ');
    // Be honest about reliability: the postflop solver uses a coarse hand/board
    // abstraction solved per street in isolation, so its mix is a directional
    // REFERENCE, not a precise equilibrium — the heuristic action above stays
    // the primary recommendation. The preflop solver is a long-lived warm tree,
    // so we surface its training depth instead.
    final note = isPostflop
        ? 'Referencia CFR (abstracción aprox., orientativa): $mix.'
        : 'Equilibrio CFR (~$_totalIterations iter): $mix.';

    return GTORecommendation(
      action: base.action,
      amount: base.amount,
      equity: base.equity,
      potOdds: base.potOdds,
      ev: base.ev,
      reasoning: '${base.reasoning}\n$note',
      equilibriumMix: shown
          .map((a) => ActionFrequency(_labelEs(a.label, facingBet), a.frequency))
          .toList(),
    );
  }

  String _labelEs(String label, bool facingBet) {
    if (label == 'f') return 'fold';
    if (label == 'c' || label == 'x') return facingBet ? 'call' : 'check';
    if (label.startsWith('b')) return 'bet';
    if (label.startsWith('r')) return 'raise';
    if (label == 'a') return 'all-in';
    return label;
  }
}

/// Extension on [TablePosition] to convert to CFR player index (0=BTN, 1=BB).
extension PositionToCfr on TablePosition {
  int get cfrPlayer {
    switch (this) {
      case TablePosition.btn:
      case TablePosition.sb:
      case TablePosition.co:
      case TablePosition.mp:
      case TablePosition.utg:
        return 0;
      case TablePosition.bb:
        return 1;
    }
  }
}
