import 'dart:math';
import '../../data/models/card_model.dart';
import 'hand_evaluator.dart';

class GTORecommendation {
  final String action;
  final double amount;
  final double equity;
  final double potOdds;
  final String reasoning;
  final double ev;

  const GTORecommendation({
    required this.action,
    required this.amount,
    required this.equity,
    required this.potOdds,
    required this.reasoning,
    required this.ev,
  });
}

class EquityCalculator {
  static final Random _rng = Random();

  static double calculate({
    required List<CardModel> heroCards,
    required List<CardModel> communityCards,
    required int numOpponents,
    int simulations = 400,
  }) {
    if (heroCards.length != 2 || numOpponents <= 0) return 0.5;

    final known = <CardModel>{...heroCards, ...communityCards};
    final deck = CardModel.freshDeck().where((c) => !_has(known, c)).toList();

    int wins = 0;
    int ties = 0;
    final boardNeeded = 5 - communityCards.length;

    for (int sim = 0; sim < simulations; sim++) {
      deck.shuffle(_rng);
      int idx = 0;

      final board = List<CardModel>.from(communityCards);
      for (int i = 0; i < boardNeeded; i++) {
        board.add(deck[idx++]);
      }

      final heroScore = HandEvaluator.evaluateBest([...heroCards, ...board]);

      bool heroWins = true;
      bool isTie = false;

      for (int op = 0; op < numOpponents; op++) {
        final opHole = [deck[idx++], deck[idx++]];
        final opScore = HandEvaluator.evaluateBest([...opHole, ...board]);
        final cmp = heroScore.compareTo(opScore);
        if (cmp < 0) {
          heroWins = false;
          isTie = false;
          break;
        } else if (cmp == 0) {
          isTie = true;
        }
      }

      if (heroWins && !isTie) wins++;
      else if (isTie) ties++;
    }

    return (wins + ties * 0.5) / simulations;
  }

  static bool _has(Set<CardModel> set, CardModel c) =>
      set.any((x) => x.rank == c.rank && x.suit == c.suit);

  static double potOddsRequired(double callAmount, double potSize) {
    if (callAmount <= 0) return 0.0;
    return callAmount / (callAmount + potSize);
  }

  static GTORecommendation recommend({
    required List<CardModel> heroCards,
    required List<CardModel> communityCards,
    required double callAmount,
    required double potSize,
    required int numOpponents,
  }) {
    final equity = calculate(
      heroCards: heroCards,
      communityCards: communityCards,
      numOpponents: max(1, numOpponents),
      simulations: 300,
    );

    final odds = potOddsRequired(callAmount, potSize);
    final ev = equity - odds;
    final eqPct = (equity * 100).toStringAsFixed(1);
    final oddsPct = (odds * 100).toStringAsFixed(1);

    if (callAmount <= 0) {
      if (equity > 0.68) {
        final bet = _snapToBetSize(potSize * 0.75);
        return GTORecommendation(
          action: 'Bet',
          amount: bet,
          equity: equity,
          potOdds: 0,
          ev: equity - 0.5,
          reasoning: 'Equity $eqPct% — mano fuerte de valor. Bet de \$${bet.toStringAsFixed(0)} (75% del bote) para construir bote y protegerte.',
        );
      }
      if (equity > 0.40) {
        final bet = _snapToBetSize(potSize * 0.33);
        if (equity > 0.55) {
          return GTORecommendation(
            action: 'Bet',
            amount: bet,
            equity: equity,
            potOdds: 0,
            ev: equity - 0.45,
            reasoning: 'Equity $eqPct% — valor fino. Bet pequeño (\$${bet.toStringAsFixed(0)}, 33% del bote) para extraer valor controlando el bote.',
          );
        }
        return GTORecommendation(
          action: 'Check',
          amount: 0,
          equity: equity,
          potOdds: 0,
          ev: 0,
          reasoning: 'Equity $eqPct% — fuerza media. Check para controlar el tamaño del bote y seguir con cautela.',
        );
      }
      if (equity > 0.25 && potSize > 20) {
        final bluff = _snapToBetSize(potSize * 0.5);
        return GTORecommendation(
          action: 'Bet',
          amount: bluff,
          equity: equity,
          potOdds: 0,
          ev: 0.1,
          reasoning: 'Equity $eqPct% — spot de farol. Semi-bluff de \$${bluff.toStringAsFixed(0)} (50% del bote) usando fold equity + outs del proyecto.',
        );
      }
      return GTORecommendation(
        action: 'Check',
        amount: 0,
        equity: equity,
        potOdds: 0,
        ev: 0,
        reasoning: 'Equity $eqPct% — mano débil. Check y reevalúa en la siguiente calle.',
      );
    }

    if (equity > 0.72 && ev > 0.20) {
      final raise = _snapToBetSize(callAmount * 2.8);
      return GTORecommendation(
        action: 'Raise',
        amount: raise,
        equity: equity,
        potOdds: odds,
        ev: ev,
        reasoning: 'Tu equity $eqPct% supera de largo las pot odds $oddsPct%. Raise a \$${raise.toStringAsFixed(0)} — una mano así merece extracción máxima.',
      );
    }

    if (ev >= -0.03) {
      return GTORecommendation(
        action: 'Call',
        amount: callAmount,
        equity: equity,
        potOdds: odds,
        ev: ev,
        reasoning: 'Equity $eqPct% vs pot odds $oddsPct% — el call es rentable (EV = ${(ev * 100).toStringAsFixed(1)}%). Call directo.',
      );
    }

    return GTORecommendation(
      action: 'Fold',
      amount: 0,
      equity: equity,
      potOdds: odds,
      ev: ev,
      reasoning: 'Equity $eqPct% por debajo de las pot odds $oddsPct%. Fold — el valor esperado es negativo (${(ev * 100).toStringAsFixed(1)}%).',
    );
  }

  static double _snapToBetSize(double amount) {
    if (amount < 2) return 2;
    return (amount / 2).round() * 2.0;
  }
}
