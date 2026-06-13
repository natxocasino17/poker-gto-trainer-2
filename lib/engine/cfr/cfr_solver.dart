import 'dart:typed_data';

import 'cfr_game.dart';
import 'info_set.dart';

/// Result of querying a solved tree at one information set.
class ActionStrategy {
  final String label;

  /// Equilibrium frequency in [0, 1] — how often the action is taken.
  final double frequency;

  /// Expected value of the action in big blinds (from the acting player's view).
  final double ev;

  const ActionStrategy(this.label, this.frequency, this.ev);
}

/// Counterfactual Regret Minimization solver.
///
/// Implements **vanilla CFR** (Zinkevich et al., 2007) with full enumeration of
/// chance, plus the **CFR+** refinements (regret flooring at zero and linear
/// strategy-averaging weight `t`) which converge an order of magnitude faster —
/// important so a spot resolves in a fraction of a second on a phone.
///
/// The traversal carries three reach probabilities — `p0`, `p1` (the two
/// players) and `pc` (chance) — and always measures sub-tree value from
/// player 0's perspective, converting to the acting player's perspective with a
/// sign flip. This handles non-alternating turns and chance nodes correctly.
class CfrSolver<S> {
  final CfrGame<S> game;
  final Map<String, InformationSet> nodes = {};

  /// Enable CFR+ (regret flooring + linear averaging). On by default.
  final bool cfrPlus;

  int iterations = 0;

  CfrSolver(this.game, {this.cfrPlus = true});

  InformationSet _node(S state) {
    final key = game.infoSetKey(state);
    return nodes.putIfAbsent(
        key, () => InformationSet(key, game.numActions(state), game.actionLabels(state)));
  }

  /// Runs [count] CFR iterations. [onProgress] (if given) is called every
  /// [progressEvery] iterations with the iteration index and the current
  /// exploitability estimate (game value imbalance) for live UI feedback.
  void train(int count, {void Function(int iter, double exploitability)? onProgress, int progressEvery = 500}) {
    final root = game.root();
    for (int t = 1; t <= count; t++) {
      iterations++;
      _cfr(root, 1.0, 1.0, 1.0, iterations);
      if (onProgress != null && t % progressEvery == 0) {
        onProgress(t, exploitability());
      }
    }
  }

  double _cfr(S s, double p0, double p1, double pc, int t) {
    if (game.isTerminal(s)) {
      return game.utilityForP0(s);
    }
    if (game.isChance(s)) {
      double value = 0;
      for (final o in game.chanceOutcomes(s)) {
        value += o.probability * _cfr(o.state, p0, p1, pc * o.probability, t);
      }
      return value;
    }

    final player = game.currentPlayer(s);
    final node = _node(s);
    final n = node.numActions;

    // Copy the regret-matching strategy: the scratch buffer is reused by deeper
    // recursion, and we still need these values for the regret update below.
    final strategy = Float64List.fromList(node.currentStrategy());

    final childUtil = Float64List(n);
    double nodeUtil0 = 0;
    for (int a = 0; a < n; a++) {
      final next = game.applyAction(s, a);
      final u0 = _cfr(
        next,
        player == 0 ? p0 * strategy[a] : p0,
        player == 1 ? p1 * strategy[a] : p1,
        pc,
        t,
      );
      childUtil[a] = u0;
      nodeUtil0 += strategy[a] * u0;
    }

    // Convert player-0 utilities to the acting player's perspective.
    final sign = player == 0 ? 1.0 : -1.0;
    final counterfactualReach = (player == 0 ? p1 : p0) * pc;
    final ownReach = player == 0 ? p0 : p1;
    final strategyWeight = cfrPlus ? t.toDouble() : 1.0;

    for (int a = 0; a < n; a++) {
      final regret = sign * (childUtil[a] - nodeUtil0);
      node.regretSum[a] += counterfactualReach * regret;
      if (cfrPlus && node.regretSum[a] < 0) {
        node.regretSum[a] = 0;
      }
      node.strategySum[a] += strategyWeight * ownReach * strategy[a];
    }

    return nodeUtil0;
  }

  /// Expected game value to player 0 when both players follow their current
  /// *average* (equilibrium) strategies. At convergence in a zero-sum game this
  /// equals the game value.
  double expectedValue() => _ev(game.root());

  double _ev(S s) {
    if (game.isTerminal(s)) return game.utilityForP0(s);
    if (game.isChance(s)) {
      double v = 0;
      for (final o in game.chanceOutcomes(s)) {
        v += o.probability * _ev(o.state);
      }
      return v;
    }
    final node = nodes[game.infoSetKey(s)];
    final n = game.numActions(s);
    final avg = node?.averageStrategy() ?? _uniform(n);
    double v = 0;
    for (int a = 0; a < n; a++) {
      if (avg[a] == 0) continue;
      v += avg[a] * _ev(game.applyAction(s, a));
    }
    return v;
  }

  /// Exploitability proxy: how far the average strategies are from equilibrium,
  /// measured as the gap between each player's best-response value and the game
  /// value, averaged. Returns 0 at a perfect equilibrium. Computable because
  /// chance is fully enumerated.
  double exploitability() {
    final br0 = _bestResponseValue(0);
    final br1 = _bestResponseValue(1);
    // br0 is the most player 0 can win; -br1 is the most player 1 lets player 0
    // win. Their gap is the total exploitability of the profile.
    return ((br0) + (br1)) / 2.0;
  }

  /// Best-response value for [brPlayer] when the opponent plays their average
  /// strategy. Returned from [brPlayer]'s perspective. Uses two-pass
  /// infoset-level aggregation so the responder respects imperfect information.
  double _bestResponseValue(int brPlayer) {
    final actionValues = <String, Float64List>{};
    final reach = <String, double>{};
    final order = <String>[];
    _brCollect(game.root(), brPlayer, 1.0, actionValues, reach, order);

    // Choose, per infoset, the action maximizing aggregated counterfactual
    // value, then read off the total value at the root via a second pass.
    final bestAction = <String, int>{};
    for (final key in actionValues.keys) {
      final vals = actionValues[key]!;
      int best = 0;
      for (int a = 1; a < vals.length; a++) {
        if (vals[a] > vals[best]) best = a;
      }
      bestAction[key] = best;
    }
    return _brValue(game.root(), brPlayer, bestAction);
  }

  void _brCollect(S s, int br, double cfReach, Map<String, Float64List> actionValues,
      Map<String, double> reach, List<String> order) {
    if (game.isTerminal(s)) return;
    if (game.isChance(s)) {
      for (final o in game.chanceOutcomes(s)) {
        _brCollect(o.state, br, cfReach * o.probability, actionValues, reach, order);
      }
      return;
    }
    final player = game.currentPlayer(s);
    final n = game.numActions(s);
    if (player == br) {
      final key = game.infoSetKey(s);
      final vals = actionValues.putIfAbsent(key, () {
        order.add(key);
        return Float64List(n);
      });
      for (int a = 0; a < n; a++) {
        final sign = br == 0 ? 1.0 : -1.0;
        vals[a] += cfReach * sign * _ev(game.applyAction(s, a));
      }
      reach[key] = (reach[key] ?? 0) + cfReach;
      // Descend without scaling by br's own reach (counterfactual for br).
      for (int a = 0; a < n; a++) {
        _brCollect(game.applyAction(s, a), br, cfReach, actionValues, reach, order);
      }
    } else {
      final node = nodes[game.infoSetKey(s)];
      final avg = node?.averageStrategy() ?? _uniform(n);
      for (int a = 0; a < n; a++) {
        if (avg[a] == 0) continue;
        _brCollect(game.applyAction(s, a), br, cfReach * avg[a], actionValues, reach, order);
      }
    }
  }

  double _brValue(S s, int br, Map<String, int> bestAction) {
    if (game.isTerminal(s)) {
      final sign = br == 0 ? 1.0 : -1.0;
      return sign * game.utilityForP0(s);
    }
    if (game.isChance(s)) {
      double v = 0;
      for (final o in game.chanceOutcomes(s)) {
        v += o.probability * _brValue(o.state, br, bestAction);
      }
      return v;
    }
    final player = game.currentPlayer(s);
    final n = game.numActions(s);
    if (player == br) {
      final a = bestAction[game.infoSetKey(s)] ?? 0;
      return _brValue(game.applyAction(s, a), br, bestAction);
    } else {
      final node = nodes[game.infoSetKey(s)];
      final avg = node?.averageStrategy() ?? _uniform(n);
      double v = 0;
      for (int a = 0; a < n; a++) {
        if (avg[a] == 0) continue;
        v += avg[a] * _brValue(game.applyAction(s, a), br, bestAction);
      }
      return v;
    }
  }

  /// Equilibrium strategy + per-action EV at one information set, identified by
  /// the [queryState] (whose acting player owns the infoset). EVs are exact,
  /// aggregated over the opponent's range reaching the infoset (reach-weighted
  /// under the average strategies).
  List<ActionStrategy> query(S queryState) {
    final key = game.infoSetKey(queryState);
    final target = game.currentPlayer(queryState);
    final node = nodes[key];
    final n = game.numActions(queryState);
    final labels = game.actionLabels(queryState);
    final freq = node?.averageStrategy() ?? _uniform(n);

    final actionVal = Float64List(n);
    final acc = _EvAccumulator(actionVal);
    _aggregateActionEVs(game.root(), key, target, 1.0, acc);

    final result = <ActionStrategy>[];
    for (int a = 0; a < n; a++) {
      final ev = acc.totalReach > 0 ? actionVal[a] / acc.totalReach : 0.0;
      result.add(ActionStrategy(labels[a], freq[a], ev));
    }
    return result;
  }

  void _aggregateActionEVs(S s, String key, int target, double cfReach, _EvAccumulator acc) {
    if (game.isTerminal(s)) return;
    if (game.isChance(s)) {
      for (final o in game.chanceOutcomes(s)) {
        _aggregateActionEVs(o.state, key, target, cfReach * o.probability, acc);
      }
      return;
    }
    final player = game.currentPlayer(s);
    final n = game.numActions(s);

    if (player == target && game.infoSetKey(s) == key) {
      final sign = target == 0 ? 1.0 : -1.0;
      for (int a = 0; a < n; a++) {
        acc.actionVal[a] += cfReach * sign * _ev(game.applyAction(s, a));
      }
      acc.totalReach += cfReach;
    }

    final node = nodes[game.infoSetKey(s)];
    final avg = node?.averageStrategy() ?? _uniform(n);
    for (int a = 0; a < n; a++) {
      // Exclude the target player's own reach (counterfactual), scale others.
      final scale = player == target ? 1.0 : avg[a];
      if (scale == 0) continue;
      _aggregateActionEVs(game.applyAction(s, a), key, target, cfReach * scale, acc);
    }
  }

  static Float64List _uniform(int n) {
    final u = Float64List(n);
    final v = 1.0 / n;
    for (int a = 0; a < n; a++) {
      u[a] = v;
    }
    return u;
  }
}

class _EvAccumulator {
  final Float64List actionVal;
  double totalReach = 0;
  _EvAccumulator(this.actionVal);
}
