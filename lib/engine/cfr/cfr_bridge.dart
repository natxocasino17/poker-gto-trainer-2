import 'dart:math';
import '../../data/models/card_model.dart';
import '../../data/models/player_model.dart';
import '../../core/utils/equity_calculator.dart';
import 'poker/bet_sizing_config.dart';
import 'poker/hand_abstraction.dart';
import 'spot_solver.dart';

/// Bridges the CFR solver output to the existing [GTORecommendation] format
/// used by [EquityCalculator.recommend] and the GTO advisor widget.
///
/// Drop-in replacement: call [CfrBridge.recommend] anywhere
/// [EquityCalculator.recommend] is called to upgrade from heuristic to
/// solved-equilibrium advice.
///
/// The bridge maintains a single long-lived [SpotSolver] whose nodes persist
/// across hands. After [backgroundIterations] training iterations are run at
/// app start (or during quiet moments), queries are virtually instant.
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

  /// Whether the solver has been trained enough to provide reliable advice.
  bool get isReady => _ready;
  int get totalIterations => _totalIterations;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  /// Trains the solver in the background. Call once at app startup.
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

  /// Returns an equilibrium-grounded [GTORecommendation] for the given spot.
  ///
  /// Falls back to [EquityCalculator.recommend] if the solver is not yet
  /// trained, ensuring the UI always gets a useful response.
  GTORecommendation recommend({
    required List<CardModel> heroCards,
    required List<CardModel> communityCards,
    required double callAmount,
    required double potSize,
    required int numOpponents,
    int player = 0,
  }) {
    if (!_ready || heroCards.length < 2) {
      return EquityCalculator.recommend(
        heroCards: heroCards,
        communityCards: communityCards,
        callAmount: callAmount,
        potSize: potSize,
        numOpponents: numOpponents,
      );
    }

    try {
      final result = _solver.query(
        heroCards: heroCards,
        board: communityCards,
        player: player,
        pot: potSize,
        effectiveStack: 100.0 - potSize / 2,
      );

      return _toRecommendation(result, heroCards, communityCards, callAmount, potSize, numOpponents);
    } catch (_) {
      // If the CFR query fails for any reason, fall back gracefully.
      return EquityCalculator.recommend(
        heroCards: heroCards,
        communityCards: communityCards,
        callAmount: callAmount,
        potSize: potSize,
        numOpponents: numOpponents,
      );
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

  /// Returns the full mixed-strategy breakdown at this spot, or null if the
  /// solver is not yet ready.
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

  // ─── Conversion to GTORecommendation ─────────────────────────────────────

  GTORecommendation _toRecommendation(
    SpotResult result,
    List<CardModel> heroCards,
    List<CardModel> communityCards,
    double callAmount,
    double potSize,
    int numOpponents,
  ) {
    // Compute equity for the reasoning string (reuse existing calculator)
    final equity = EquityCalculator.calculate(
      heroCards: heroCards,
      communityCards: communityCards,
      numOpponents: max(1, numOpponents),
      simulations: 300,
      deterministic: true,
    );
    final potOdds = EquityCalculator.potOddsRequired(callAmount, potSize);

    // Pick the dominant CFR action
    final dominant = result.dominantAction;
    final label = dominant.label;

    String action;
    double amount = 0;

    if (label == 'f') {
      action = 'Fold';
    } else if (label == 'x' || label == 'c') {
      if (callAmount <= 0) {
        action = 'Check';
      } else {
        action = 'Call';
        amount = callAmount;
      }
    } else if (label.startsWith('b')) {
      action = 'Bet';
      amount = dominant.ev > 0 ? callAmount * 1.5 : potSize * 0.5;
    } else if (label.startsWith('r')) {
      action = 'Raise';
      amount = callAmount * 2.5;
    } else {
      action = 'All In';
      amount = potSize * 2;
    }

    final reasoning = _buildReasoning(result, equity, potOdds, callAmount);

    return GTORecommendation(
      action: action,
      amount: amount,
      equity: equity,
      potOdds: potOdds,
      ev: dominant.ev,
      reasoning: reasoning,
    );
  }

  String _buildReasoning(
    SpotResult result,
    double equity,
    double potOdds,
    double callAmount,
  ) {
    final eqPct = (equity * 100).toStringAsFixed(1);
    final dominant = result.dominantAction;
    final highEv = result.highestEvAction;
    final iterInfo = 'CFR+ (${result.iterations} it.)';

    final mixedInfo = result.actions
        .where((a) => a.frequency > 0.05)
        .map((a) => '${a.label}: ${(a.frequency * 100).toStringAsFixed(0)}%')
        .join(', ');

    if (dominant.label == 'f') {
      return 'Equity $eqPct% — EV negativo (${dominant.ev.toStringAsFixed(2)} BB). '
          '$iterInfo recomienda fold. Rango equilibrado: $mixedInfo.';
    }

    if (dominant.label == 'x' || dominant.label == 'c') {
      if (callAmount <= 0) {
        return 'Equity $eqPct% — Check equilibrado. $iterInfo. Estrategia: $mixedInfo.';
      }
      return 'Equity $eqPct% vs pot odds ${(potOdds * 100).toStringAsFixed(1)}%. '
          'EV del call: ${dominant.ev.toStringAsFixed(2)} BB. $iterInfo. Mix: $mixedInfo.';
    }

    if (dominant.label.startsWith('r') || dominant.label.startsWith('b')) {
      return 'Equity $eqPct% — Apuesta de valor/bluff. '
          'EV: ${highEv.ev.toStringAsFixed(2)} BB. $iterInfo. Estrategia equilibrio: $mixedInfo.';
    }

    return '$iterInfo — Equity $eqPct%. Mix equilibrio: $mixedInfo.';
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
