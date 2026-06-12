import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/models/card_model.dart';
import '../data/models/player_model.dart';
import '../data/models/hand_log_model.dart';
import '../core/utils/hand_evaluator.dart';
import '../core/utils/equity_calculator.dart';
import '../core/utils/poker_concepts.dart';
import 'legendary_ai.dart';
import '../core/i18n/i18n.dart';

enum GamePhase { idle, preflop, flop, turn, river, showdown, handComplete }

class GameState {
  final List<PlayerModel> players;
  final List<CardModel> communityCards;
  final List<CardModel> deck;
  final double pot;
  final double currentBet;
  final int activePlayerIndex;
  final int dealerIndex;
  final GamePhase phase;
  final String street;
  final int handNumber;
  final bool awaitingHumanAction;
  final String? statusMessage;
  final bool isProcessingBot;
  final String? lastAction;
  final List<HandAction> currentHandActions;
  final bool wasAggressorThisStreet;
  // Tracks how many more players need to act before street ends
  final int actorsRemaining;

  const GameState({
    required this.players,
    required this.communityCards,
    required this.deck,
    required this.pot,
    required this.currentBet,
    required this.activePlayerIndex,
    required this.dealerIndex,
    required this.phase,
    required this.street,
    required this.handNumber,
    this.awaitingHumanAction = false,
    this.statusMessage,
    this.isProcessingBot = false,
    this.lastAction,
    required this.currentHandActions,
    this.wasAggressorThisStreet = false,
    this.actorsRemaining = 0,
  });

  PlayerModel get humanPlayer =>
      players.firstWhere((p) => p.isHuman);

  int get humanIndex =>
      players.indexWhere((p) => p.isHuman);

  List<PlayerModel> get activePlayers =>
      players.where((p) => !p.isFolded && !p.isAllIn).toList();

  int get activeCount =>
      players.where((p) => !p.isFolded).length;

  int get canActCount =>
      players.where((p) => !p.isFolded && !p.isAllIn).length;

  PlayerModel? get actingPlayer =>
      activePlayerIndex >= 0 && activePlayerIndex < players.length
          ? players[activePlayerIndex]
          : null;

  double get callAmount {
    final hp = humanPlayer;
    final diff = currentBet - hp.streetBet;
    return diff.clamp(0.0, hp.stack);
  }

  GameState copyWith({
    List<PlayerModel>? players,
    List<CardModel>? communityCards,
    List<CardModel>? deck,
    double? pot,
    double? currentBet,
    int? activePlayerIndex,
    int? dealerIndex,
    GamePhase? phase,
    String? street,
    int? handNumber,
    bool? awaitingHumanAction,
    String? statusMessage,
    bool? isProcessingBot,
    String? lastAction,
    List<HandAction>? currentHandActions,
    bool? wasAggressorThisStreet,
    int? actorsRemaining,
  }) {
    return GameState(
      players: players ?? this.players,
      communityCards: communityCards ?? this.communityCards,
      deck: deck ?? this.deck,
      pot: pot ?? this.pot,
      currentBet: currentBet ?? this.currentBet,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      phase: phase ?? this.phase,
      street: street ?? this.street,
      handNumber: handNumber ?? this.handNumber,
      awaitingHumanAction: awaitingHumanAction ?? this.awaitingHumanAction,
      statusMessage: statusMessage,
      isProcessingBot: isProcessingBot ?? this.isProcessingBot,
      lastAction: lastAction,
      currentHandActions: currentHandActions ?? this.currentHandActions,
      wasAggressorThisStreet: wasAggressorThisStreet ?? this.wasAggressorThisStreet,
      actorsRemaining: actorsRemaining ?? this.actorsRemaining,
    );
  }
}

class PokerEngine extends ChangeNotifier {
  static const double smallBlind = 1.0;
  static const double bigBlind = 2.0;

  GameState _state;
  bool _disposed = false;
  final HumanReadModel _humanModel = HumanReadModel();

  Function(GameState)? onHandComplete;

  PokerEngine({
    required double tableStack,
    required double bankroll,
    required List<LegendProfile> legends,
  })  : _state = _buildInitialState(tableStack, legends);

  GameState get state => _state;

  /// Seeds the bots' shared read model from the persisted human profile so
  /// they exploit known tendencies from the first hand (cross-session learning).
  void seedHumanModel(Map<String, double> profile) => _humanModel.seedFrom(profile);

  static GameState _buildInitialState(double tableStack, List<LegendProfile> legends) {
    const botStack = 200.0;
    final players = [
      PlayerModel(id: 'human', name: 'You', isHuman: true, stack: tableStack),
      PlayerModel(id: 'bot0', name: legends[0].name, isHuman: false, stack: botStack, legendName: legends[0].name),
      PlayerModel(id: 'bot1', name: legends[1].name, isHuman: false, stack: botStack, legendName: legends[1].name),
      PlayerModel(id: 'bot2', name: legends[2].name, isHuman: false, stack: botStack, legendName: legends[2].name),
      PlayerModel(id: 'bot3', name: legends[3].name, isHuman: false, stack: botStack, legendName: legends[3].name),
      PlayerModel(id: 'bot4', name: legends[4].name, isHuman: false, stack: botStack, legendName: legends[4].name),
    ];
    return GameState(
      players: players,
      communityCards: const [],
      deck: const [],
      pot: 0,
      currentBet: 0,
      activePlayerIndex: 0,
      dealerIndex: 0,
      phase: GamePhase.idle,
      street: '',
      handNumber: 0,
      currentHandActions: const [],
    );
  }

  void startNewHand() {
    if (_disposed) return;

    // Busted bots leave the table; fresh legends take their seats.
    final seated = _state.players.map((p) => p.name).toList();
    var roster = List<PlayerModel>.from(_state.players);
    String? rotationMsg;
    for (int i = 0; i < roster.length; i++) {
      final p = roster[i];
      if (!p.isHuman && p.stack < bigBlind) {
        final fresh = LegendaryBotEngine.replacementFor(seated);
        seated.add(fresh.name);
        rotationMsg = I18n.t('bot_busts', {'out': p.name, 'inn': fresh.name});
        roster[i] = PlayerModel(
          id: p.id,
          name: fresh.name,
          isHuman: false,
          stack: 200.0,
          legendName: fresh.name,
        );
      }
    }
    if (rotationMsg != null) {
      _state = _state.copyWith(players: roster, lastAction: rotationMsg);
      notifyListeners();
    }

    final deck = CardModel.shuffledDeck();
    final handNum = _state.handNumber + 1;
    final dealerIdx = handNum == 1 ? 0 : (_state.dealerIndex + 1) % 6;

    final positions = [
      TablePosition.btn,
      TablePosition.sb,
      TablePosition.bb,
      TablePosition.utg,
      TablePosition.mp,
      TablePosition.co,
    ];

    var players = _state.players.asMap().entries.map((e) {
      final seatOffset = (e.key - dealerIdx + 6) % 6;
      return e.value.copyWith(
        holeCards: [],
        isFolded: false,
        isAllIn: false,
        streetBet: 0,
        totalHandBet: 0,
        position: positions[seatOffset],
        isDealer: seatOffset == 0,
        cardsVisible: e.value.isHuman,
        isWinner: false,
      );
    }).toList();

    // Deal 2 hole cards
    int deckIdx = 0;
    players = players.map((p) {
      final c1 = deck[deckIdx++];
      final c2 = deck[deckIdx++];
      return p.copyWith(holeCards: [c1, c2]);
    }).toList();

    final remainingDeck = deck.sublist(deckIdx);

    // Post blinds
    final sbIdx = (dealerIdx + 1) % 6;
    final bbIdx = (dealerIdx + 2) % 6;
    final utgIdx = (dealerIdx + 3) % 6;

    // Safe blind posting: a short stack posts what it has and is all-in,
    // never going negative (negative stacks froze the game).
    final sbPost = min(smallBlind, players[sbIdx].stack);
    players[sbIdx] = players[sbIdx].copyWith(
      stack: players[sbIdx].stack - sbPost,
      streetBet: sbPost,
      totalHandBet: sbPost,
      isAllIn: players[sbIdx].stack - sbPost <= 0,
    );
    final bbPost = min(bigBlind, players[bbIdx].stack);
    players[bbIdx] = players[bbIdx].copyWith(
      stack: players[bbIdx].stack - bbPost,
      streetBet: bbPost,
      totalHandBet: bbPost,
      isAllIn: players[bbIdx].stack - bbPost <= 0,
    );

    // Preflop: 6 players need to act (including BB who has the option)
    final canActPlayers = players.where((p) => !p.isFolded && !p.isAllIn).length;

    _state = _state.copyWith(
      players: players,
      communityCards: [],
      deck: remainingDeck,
      pot: sbPost + bbPost,
      currentBet: bigBlind,
      activePlayerIndex: utgIdx,
      dealerIndex: dealerIdx,
      phase: GamePhase.preflop,
      street: 'preflop',
      handNumber: handNum,
      awaitingHumanAction: false,
      actorsRemaining: canActPlayers,
      currentHandActions: [],
      wasAggressorThisStreet: false,
      lastAction: null,
    );

    notifyListeners();
    _advanceTurn();
  }

  void _advanceTurn() {
    if (_disposed) return;
    if (_state.activeCount <= 1) {
      _awardPot();
      return;
    }

    // Skip folded or all-in players
    var idx = _state.activePlayerIndex;
    int tries = 0;
    while (tries < 6) {
      final p = _state.players[idx];
      if (!p.isFolded && !p.isAllIn) break;
      idx = (idx + 1) % 6;
      tries++;
    }

    if (tries >= 6) {
      _advanceStreet();
      return;
    }

    if (idx != _state.activePlayerIndex) {
      _state = _state.copyWith(activePlayerIndex: idx);
    }

    final player = _state.players[idx];
    if (player.isHuman) {
      _state = _state.copyWith(awaitingHumanAction: true, isProcessingBot: false);
      notifyListeners();
    } else {
      _state = _state.copyWith(awaitingHumanAction: false, isProcessingBot: true);
      notifyListeners();
      _processBotTurn(idx);
    }
  }

  Future<void> _processBotTurn(int idx) async {
    if (_disposed) return;
    final player = _state.players[idx];
    final profile = LegendaryBotEngine.profileByName(player.legendName ?? '');
    final callAmount = (_state.currentBet - player.streetBet).clamp(0.0, player.stack);

    final streetActions = _state.currentHandActions
        .where((a) => a.street == _state.street)
        .toList();
    final raiseCount = streetActions
        .where((a) => a.type == ActionType.raise ||
            a.type == ActionType.bet ||
            (a.type == ActionType.allIn && a.amount > bigBlind))
        .length;
    final callersThisStreet =
        streetActions.where((a) => a.type == ActionType.call).length;

    final decision = await LegendaryBotEngine.decide(
      profile: profile,
      holeCards: player.holeCards,
      communityCards: _state.communityCards,
      position: player.position,
      callAmount: callAmount.toDouble(),
      currentBet: _state.currentBet,
      myStreetBet: player.streetBet,
      currentPot: _state.pot,
      botStack: player.stack,
      humanModel: _humanModel,
      isPreflop: _state.phase == GamePhase.preflop,
      wasAggressor: _state.wasAggressorThisStreet,
      activePlayers: _state.activeCount,
      street: _state.street,
      raiseCount: raiseCount,
      callersThisStreet: callersThisStreet,
      bigBlind: bigBlind,
    );

    if (_disposed) return;
    _applyAction(idx, decision.type, decision.amount);
  }

  void humanAction(ActionType type, double amount) {
    if (!_state.awaitingHumanAction) return;
    final idx = _state.humanIndex;
    _trackHumanTendencies(type);
    _applyAction(idx, type, amount);
  }

  /// Feeds the live exploit model used by the legendary bots.
  void _trackHumanTendencies(ActionType type) {
    final facingBet = _state.callAmount > 0;
    final isTurnRiver = _state.street == 'turn' || _state.street == 'river';

    if (_state.street == 'preflop') {
      _humanModel.handsObserved++;
      if (type == ActionType.fold) {
        _humanModel.preflopFolds++;
      } else if (type != ActionType.check) {
        _humanModel.preflopVpip++;
      }
    }

    if (facingBet) {
      _humanModel.facedBets++;
      if (isTurnRiver) _humanModel.facedTurnRiverBets++;
      switch (type) {
        case ActionType.fold:
          _humanModel.foldsVsBet++;
          if (isTurnRiver) _humanModel.foldsVsTurnRiverBets++;
          break;
        case ActionType.raise:
        case ActionType.allIn:
          _humanModel.raisesVsBet++;
          _humanModel.aggressiveActions++;
          break;
        case ActionType.call:
          _humanModel.passiveActions++;
          break;
        default:
          break;
      }
    } else if (type == ActionType.bet || type == ActionType.raise ||
        type == ActionType.allIn) {
      _humanModel.aggressiveActions++;
    }
  }

  void _applyAction(int playerIdx, ActionType type, double rawAmount) {
    if (_disposed) return;
    final player = _state.players[playerIdx];
    var players = List<PlayerModel>.from(_state.players);
    var pot = _state.pot;
    var currentBet = _state.currentBet;
    var actorsRemaining = _state.actorsRemaining;
    var wasAggressor = _state.wasAggressorThisStreet;

    final actionEntry = HandAction(
      playerId: player.id,
      playerName: player.name,
      type: type,
      amount: rawAmount,
      street: _state.street,
      sequence: _state.currentHandActions.length,
    );

    PlayerModel updated;

    switch (type) {
      case ActionType.fold:
        updated = player.copyWith(isFolded: true);
        // Folded player no longer needs to act
        actorsRemaining = max(0, actorsRemaining - 1);
        break;

      case ActionType.check:
        updated = player;
        actorsRemaining = max(0, actorsRemaining - 1);
        break;

      case ActionType.call:
        final toCall = (currentBet - player.streetBet).clamp(0.0, player.stack);
        pot += toCall;
        updated = player.copyWith(
          stack: player.stack - toCall,
          streetBet: player.streetBet + toCall,
          totalHandBet: player.totalHandBet + toCall,
          isAllIn: player.stack - toCall <= 0,
        );
        // If calling makes player all-in, they're done; otherwise decrement
        actorsRemaining = max(0, actorsRemaining - 1);
        break;

      case ActionType.bet:
      case ActionType.raise:
        final amount = rawAmount.clamp(bigBlind, player.stack);
        final extraBet = amount - player.streetBet;
        pot += extraBet;
        currentBet = amount;
        wasAggressor = true;
        updated = player.copyWith(
          stack: player.stack - extraBet,
          streetBet: amount,
          totalHandBet: player.totalHandBet + extraBet,
          isAllIn: player.stack - extraBet <= 0,
        );
        // After a raise, all OTHER active players need to act again
        final otherActiveCount = players.where((p) =>
            !p.isFolded && !p.isAllIn && p.id != player.id).length;
        actorsRemaining = otherActiveCount;
        break;

      case ActionType.allIn:
        final allInAmount = player.stack;
        pot += allInAmount;
        final newStreetBet = player.streetBet + allInAmount;
        if (newStreetBet > currentBet) {
          currentBet = newStreetBet;
          wasAggressor = true;
          final otherActiveCount = players.where((p) =>
              !p.isFolded && !p.isAllIn && p.id != player.id).length;
          actorsRemaining = otherActiveCount;
        } else {
          actorsRemaining = max(0, actorsRemaining - 1);
        }
        updated = player.copyWith(
          stack: 0,
          streetBet: newStreetBet,
          totalHandBet: player.totalHandBet + allInAmount,
          isAllIn: true,
        );
        break;
    }

    players[playerIdx] = updated;
    final actions = List<HandAction>.from(_state.currentHandActions)..add(actionEntry);
    final actionLabel = '${player.name}: ${actionEntry.label}';

    _state = _state.copyWith(
      players: players,
      pot: pot,
      currentBet: currentBet,
      awaitingHumanAction: false,
      isProcessingBot: false,
      lastAction: actionLabel,
      currentHandActions: actions,
      wasAggressorThisStreet: wasAggressor,
      actorsRemaining: actorsRemaining,
    );

    notifyListeners();

    // Check end conditions
    if (_state.activeCount <= 1) {
      _awardPot();
      return;
    }

    if (actorsRemaining <= 0) {
      _advanceStreet();
    } else {
      _moveToNextPlayer();
    }
  }

  void _moveToNextPlayer() {
    int nextIdx = (_state.activePlayerIndex + 1) % 6;
    for (int i = 0; i < 6; i++) {
      final p = _state.players[nextIdx];
      if (!p.isFolded && !p.isAllIn) break;
      nextIdx = (nextIdx + 1) % 6;
    }
    _state = _state.copyWith(activePlayerIndex: nextIdx);
    notifyListeners();
    _advanceTurn();
  }

  void _advanceStreet() {
    if (_disposed) return;
    final phase = _state.phase;

    // Check if we should go straight to showdown (all but one all-in)
    final canAct = _state.players.where((p) => !p.isFolded && !p.isAllIn).length;

    // Reset street bets
    final resetPlayers = _state.players.map((p) => p.copyWith(streetBet: 0)).toList();

    GamePhase nextPhase;
    String nextStreet;
    var newCommunity = List<CardModel>.from(_state.communityCards);
    var newDeck = List<CardModel>.from(_state.deck);

    switch (phase) {
      case GamePhase.preflop:
        // The flop is dealt ONE CARD AT A TIME (slower, dramatic reveal).
        _dealFlopStaggered(resetPlayers, newDeck, canAct);
        return;
      case GamePhase.flop:
        nextPhase = GamePhase.turn;
        nextStreet = 'turn';
        newCommunity.add(newDeck.first);
        newDeck = newDeck.sublist(1);
        break;
      case GamePhase.turn:
        nextPhase = GamePhase.river;
        nextStreet = 'river';
        newCommunity.add(newDeck.first);
        newDeck = newDeck.sublist(1);
        break;
      case GamePhase.river:
        // The river is the LAST card. After it, the hand goes straight to
        // showdown — there is no further street, no more pot odds.
        _runShowdown();
        return;
      default:
        return;
    }

    final firstActiveIdx = _firstActiveAfterDealer();
    final activePlayers = resetPlayers.where((p) => !p.isFolded && !p.isAllIn).length;

    _state = _state.copyWith(
      players: resetPlayers,
      communityCards: newCommunity,
      deck: newDeck,
      currentBet: 0,
      activePlayerIndex: firstActiveIdx,
      phase: nextPhase,
      street: nextStreet,
      wasAggressorThisStreet: false,
      actorsRemaining: activePlayers,
    );

    notifyListeners();

    // If all active players are all-in, run the remaining board out (one
    // card at a time) and then showdown.
    if (canAct <= 1 && newCommunity.length < 5) {
      _runOutBoard();
      return;
    }

    _advanceTurn();
  }

  /// Deals the three flop cards individually, with a short pause between
  /// each, before opening the flop betting round.
  void _dealFlopStaggered(List<PlayerModel> resetPlayers, List<CardModel> deck, int canAct) {
    final flop = deck.take(3).toList();
    final rest = deck.sublist(3);
    final firstActiveIdx = _firstActiveAfterDealer();
    final activePlayers = resetPlayers.where((p) => !p.isFolded && !p.isAllIn).length;

    _state = _state.copyWith(
      players: resetPlayers,
      communityCards: const [],
      deck: rest,
      currentBet: 0,
      activePlayerIndex: firstActiveIdx,
      phase: GamePhase.flop,
      street: 'flop',
      wasAggressorThisStreet: false,
      actorsRemaining: activePlayers,
      awaitingHumanAction: false,
      isProcessingBot: false,
    );
    notifyListeners();
    _revealFlopCard(flop, 0, canAct);
  }

  void _revealFlopCard(List<CardModel> flop, int i, int canAct) {
    if (_disposed) return;
    if (i >= flop.length) {
      if (canAct <= 1) {
        _runOutBoard();
      } else {
        _advanceTurn();
      }
      return;
    }
    final board = List<CardModel>.from(_state.communityCards)..add(flop[i]);
    _state = _state.copyWith(communityCards: board);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 420), () => _revealFlopCard(flop, i + 1, canAct));
  }

  /// All-in runout: reveals every live player's hole cards, then deals the
  /// remaining board cards ONE AT A TIME before the showdown.
  void _runOutBoard() {
    if (_disposed) return;
    final players = _state.players
        .map((p) => p.copyWith(cardsVisible: !p.isFolded))
        .toList();
    _state = _state.copyWith(players: players);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 600), _revealRunoutCard);
  }

  void _revealRunoutCard() {
    if (_disposed) return;
    if (_state.communityCards.length >= 5 || _state.deck.isEmpty) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!_disposed) _runShowdown();
      });
      return;
    }
    final remain = List<CardModel>.from(_state.deck);
    final next = remain.removeAt(0);
    final board = List<CardModel>.from(_state.communityCards)..add(next);
    _state = _state.copyWith(communityCards: board, deck: remain);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 750), _revealRunoutCard);
  }

  int _firstActiveAfterDealer() {
    int idx = (_state.dealerIndex + 1) % 6;
    for (int i = 0; i < 6; i++) {
      if (!_state.players[idx].isFolded) return idx;
      idx = (idx + 1) % 6;
    }
    return _state.dealerIndex;
  }

  void _runShowdown() {
    if (_disposed) return;
    final activeIndices = _state.players
        .asMap().entries
        .where((e) => !e.value.isFolded)
        .map((e) => e.key)
        .toList();

    final allCards = activeIndices.map((i) => _state.players[i].holeCards).toList();
    final winnerLocalIndices = HandEvaluator.findWinners(allCards, _state.communityCards);
    final winnerPlayerIndices = winnerLocalIndices.map((i) => activeIndices[i]).toList();

    var players = List<PlayerModel>.from(_state.players);
    for (int i = 0; i < players.length; i++) {
      players[i] = players[i].copyWith(
        cardsVisible: !players[i].isFolded,
        isWinner: winnerPlayerIndices.contains(i),
      );
    }

    _state = _state.copyWith(players: players, phase: GamePhase.showdown);
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!_disposed) _awardPot(winnerPlayerIndices: winnerPlayerIndices);
    });
  }

  void _awardPot({List<int>? winnerPlayerIndices}) {
    if (_disposed) return;

    final notFolded = _state.players.asMap().entries
        .where((e) => !e.value.isFolded)
        .map((e) => e.key)
        .toList();

    final winners = winnerPlayerIndices ?? notFolded;
    final share = _state.pot / winners.length;

    var players = List<PlayerModel>.from(_state.players);
    for (final idx in winners) {
      players[idx] = players[idx].copyWith(
        stack: players[idx].stack + share,
        isWinner: true,
        cardsVisible: true,
      );
    }

    final winnerNames = winners.map((i) => players[i].name).join(' & ');
    final resultMsg = I18n.t('wins_msg', {'who': winnerNames, 'amt': _state.pot.toStringAsFixed(0)});

    _state = _state.copyWith(
      players: players,
      phase: GamePhase.handComplete,
      lastAction: resultMsg,
    );
    notifyListeners();

    onHandComplete?.call(_state);

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!_disposed) startNewHand();
    });
  }

  GTORecommendation getGTOAdvice() {
    final human = _state.humanPlayer;
    return EquityCalculator.recommend(
      heroCards: human.holeCards,
      communityCards: _state.communityCards,
      callAmount: _state.callAmount,
      potSize: _state.pot,
      numOpponents: max(1, _state.activeCount - 1),
    );
  }

  void updateTableStack(double newStack) {
    final idx = _state.players.indexWhere((p) => p.isHuman);
    final players = List<PlayerModel>.from(_state.players);
    players[idx] = players[idx].copyWith(stack: newStack);
    _state = _state.copyWith(players: players);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
