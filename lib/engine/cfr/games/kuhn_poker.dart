import '../cfr_game.dart';

/// Immutable Kuhn-poker state: the two dealt cards (J=0, Q=1, K=2) and the
/// public betting history as a string of 'p' (pass/check) and 'b' (bet/call).
class KuhnState {
  final int c0;
  final int c1;
  final String history;
  final bool dealt;
  const KuhnState(this.c0, this.c1, this.history, this.dealt);
}

/// Kuhn poker — the canonical toy game used to validate CFR implementations.
/// Three cards, one each, single bet of size 1 over a 1-chip ante. The unique
/// Nash equilibrium has a known value of -1/18 to the first player, which the
/// accompanying test asserts to prove the solver is correct.
class KuhnPoker extends CfrGame<KuhnState> {
  const KuhnPoker();

  @override
  KuhnState root() => const KuhnState(-1, -1, '', false);

  @override
  bool isChance(KuhnState s) => !s.dealt;

  @override
  List<ChanceOutcome<KuhnState>> chanceOutcomes(KuhnState s) {
    final outcomes = <ChanceOutcome<KuhnState>>[];
    for (int a = 0; a < 3; a++) {
      for (int b = 0; b < 3; b++) {
        if (a == b) continue;
        outcomes.add(ChanceOutcome(KuhnState(a, b, '', true), 1 / 6));
      }
    }
    return outcomes;
  }

  @override
  bool isTerminal(KuhnState s) {
    final h = s.history;
    return h == 'pp' || h == 'bp' || h == 'bb' || h == 'pbp' || h == 'pbb';
  }

  @override
  double utilityForP0(KuhnState s) {
    final h = s.history;
    final p0Wins = s.c0 > s.c1;
    switch (h) {
      case 'pp':
        return p0Wins ? 1 : -1;
      case 'bp': // p0 bet, p1 folded
        return 1;
      case 'pbp': // p0 checked, p1 bet, p0 folded
        return -1;
      case 'bb':
      case 'pbb':
        return p0Wins ? 2 : -2;
      default:
        throw StateError('utility on non-terminal: "$h"');
    }
  }

  @override
  int currentPlayer(KuhnState s) => s.history.length % 2;

  @override
  int numActions(KuhnState s) => 2;

  @override
  List<String> actionLabels(KuhnState s) => const ['pass', 'bet'];

  @override
  String infoSetKey(KuhnState s) {
    final card = currentPlayer(s) == 0 ? s.c0 : s.c1;
    return '$card:${s.history}';
  }

  @override
  KuhnState applyAction(KuhnState s, int action) {
    final mark = action == 0 ? 'p' : 'b';
    return KuhnState(s.c0, s.c1, s.history + mark, true);
  }
}
