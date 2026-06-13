import 'dart:typed_data';

/// A single information set (decision node from the perspective of the acting
/// player, who cannot distinguish between game states that share the same
/// observable history + private cards).
///
/// Holds the two tables at the heart of CFR:
///   * [regretSum]   — accumulated counterfactual regret per action.
///   * [strategySum] — reach-weighted accumulation of the strategy played,
///                     whose normalization yields the *average* strategy that
///                     converges to a Nash equilibrium.
///
/// Storage uses [Float64List] (contiguous, unboxed doubles) so a solved tree of
/// tens of thousands of nodes stays compact and cache-friendly on mobile.
class InformationSet {
  /// Stable, human-readable key (private bucket + public action history).
  final String key;

  /// Number of legal actions at this node.
  final int numActions;

  /// Labels for each action index (e.g. "fold", "call", "raise75", "allin").
  final List<String> actionLabels;

  final Float64List regretSum;
  final Float64List strategySum;

  /// Reusable scratch buffer for the current regret-matching strategy.
  final Float64List _current;

  InformationSet(this.key, this.numActions, this.actionLabels)
      : assert(actionLabels.length == numActions),
        regretSum = Float64List(numActions),
        strategySum = Float64List(numActions),
        _current = Float64List(numActions);

  /// Regret-matching (Hart & Mas-Colell): the current strategy is proportional
  /// to positive accumulated regret; uniform when no action has positive regret.
  ///
  /// Returns the internal scratch buffer — callers that recurse must copy it.
  Float64List currentStrategy() {
    double normalizing = 0;
    for (int a = 0; a < numActions; a++) {
      final r = regretSum[a];
      final positive = r > 0 ? r : 0.0;
      _current[a] = positive;
      normalizing += positive;
    }
    if (normalizing > 0) {
      for (int a = 0; a < numActions; a++) {
        _current[a] /= normalizing;
      }
    } else {
      final uniform = 1.0 / numActions;
      for (int a = 0; a < numActions; a++) {
        _current[a] = uniform;
      }
    }
    return _current;
  }

  /// The equilibrium (average) strategy = normalized [strategySum].
  /// These are the *mixed-strategy frequencies* the solver reports.
  Float64List averageStrategy() {
    final avg = Float64List(numActions);
    double total = 0;
    for (int a = 0; a < numActions; a++) {
      total += strategySum[a];
    }
    if (total > 0) {
      for (int a = 0; a < numActions; a++) {
        avg[a] = strategySum[a] / total;
      }
    } else {
      final uniform = 1.0 / numActions;
      for (int a = 0; a < numActions; a++) {
        avg[a] = uniform;
      }
    }
    return avg;
  }

  /// Returns the average strategy as a label→frequency map for reporting/UI.
  Map<String, double> averageStrategyMap() {
    final avg = averageStrategy();
    return {for (int a = 0; a < numActions; a++) actionLabels[a]: avg[a]};
  }

  Map<String, dynamic> toJson() => {
        'k': key,
        'l': actionLabels,
        // Only the strategySum is needed to reconstruct the equilibrium
        // strategy; regrets are kept too so a solve can be *resumed* later.
        's': strategySum.toList(growable: false),
        'r': regretSum.toList(growable: false),
      };

  factory InformationSet.fromJson(Map<String, dynamic> j) {
    final labels = (j['l'] as List).cast<String>();
    final node = InformationSet(j['k'] as String, labels.length, labels);
    final s = (j['s'] as List).cast<num>();
    final r = (j['r'] as List?)?.cast<num>();
    for (int a = 0; a < node.numActions; a++) {
      node.strategySum[a] = s[a].toDouble();
      if (r != null) node.regretSum[a] = r[a].toDouble();
    }
    return node;
  }
}
