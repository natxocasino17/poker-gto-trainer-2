import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/gto/gto_database.dart';
import '../data/models/card_model.dart';
import '../data/models/player_model.dart';
import '../data/models/hand_log_model.dart';
import '../core/utils/hand_evaluator.dart';
import '../core/utils/equity_calculator.dart';
import '../core/utils/poker_concepts.dart';
import '../core/utils/postflop_context.dart';
import '../core/utils/preflop_charts.dart';
import 'cfr/cfr_bridge.dart';
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

  /// Chips committed from COMPLETED streets — what belongs to the "closed" pot.
  /// Current street bets are shown "in front of" each player via [PlayerModel.streetBet].
  /// The center display shows this value; the solver uses [pot] (total) for correct odds.
  double get mainPot {
    final streetTotal = players.fold(0.0, (double s, p) => s + p.streetBet);
    return (pot - streetTotal).clamp(0.0, double.infinity);
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
  // Configurable blinds (set from user settings before a session starts).
  static double smallBlind = 1.0;
  static double bigBlind = 2.0;

  /// Buy-in a busted bot reloads with (matches the table stack by default).
  final double botBuyIn;

  GameState _state;
  bool _disposed = false;
  final HumanReadModel _humanModel = HumanReadModel();

  // Snapshot of the current hand's deal so it can be replayed from preflop
  // with the identical cards ("deshacer / repetir mano").
  List<CardModel>? _replayDeck;
  int? _replayDealer;
  int? _replayHandNum;
  List<PlayerModel>? _replayRoster;

  Function(GameState)? onHandComplete;

  PokerEngine({
    required double tableStack,
    required double bankroll,
    required List<LegendProfile> legends,
    this.botBuyIn = 200.0,
  })  : _state = _buildInitialState(tableStack, legends, botBuyIn);

  GameState get state => _state;

  /// Seeds the bots' shared read model from the persisted human profile so
  /// they exploit known tendencies from the first hand (cross-session learning).
  void seedHumanModel(Map<String, double> profile) => _humanModel.seedFrom(profile);

  static GameState _buildInitialState(
      double tableStack, List<LegendProfile> legends, double botStack) {
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
          stack: botBuyIn,
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
    final positioned = _positionedRoster(dealerIdx);

    // Snapshot the deal so the player can replay this exact hand (same cards)
    // from preflop.
    _replayDeck = List<CardModel>.from(deck);
    _replayDealer = dealerIdx;
    _replayHandNum = handNum;
    _replayRoster = positioned.map((p) => p.copyWith()).toList();

    _dealPreflop(
        deck: deck, dealerIdx: dealerIdx, handNum: handNum, positioned: positioned);
  }

  /// Builds the cleared, positioned roster for a new deal.
  List<PlayerModel> _positionedRoster(int dealerIdx) {
    const positions = [
      TablePosition.btn,
      TablePosition.sb,
      TablePosition.bb,
      TablePosition.utg,
      TablePosition.mp,
      TablePosition.co,
    ];
    return _state.players.asMap().entries.map((e) {
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
  }

  /// Deals hole cards + posts blinds from a given (possibly replayed) deck and
  /// roster, then starts preflop action.
  void _dealPreflop({
    required List<CardModel> deck,
    required int dealerIdx,
    required int handNum,
    required List<PlayerModel> positioned,
  }) {
    var players = positioned;

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

  bool get canReplay => _replayDeck != null;

  /// Replays the current hand from preflop with the identical deck (same hole
  /// cards and board), restoring the pre-hand stacks.
  void replayHand() {
    if (_disposed || _replayDeck == null) return;
    _dealPreflop(
      deck: List<CardModel>.from(_replayDeck!),
      dealerIdx: _replayDealer!,
      handNum: _replayHandNum!,
      positioned: _replayRoster!.map((p) => p.copyWith()).toList(),
    );
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

    // ── INITIATIVE: the last player to make an aggressive action (bet/raise/
    // all-in) in the WHOLE hand carries it. A call NEVER takes initiative, so
    // calling a 4-bet leaves it with the 4-bettor; a later bet/raise (even
    // postflop) transfers it to whoever made it.
    final hasInitiative = _lastAggressorId() == player.id;

    // ── POSITION: postflop, action runs SB→BB→UTG→MP→CO→BTN (button last).
    // This bot is IN POSITION if no still-active opponent acts after it.
    const postflopOrder = {
      TablePosition.sb: 0,
      TablePosition.bb: 1,
      TablePosition.utg: 2,
      TablePosition.mp: 3,
      TablePosition.co: 4,
      TablePosition.btn: 5,
    };
    final myOrder = postflopOrder[player.position] ?? 0;
    final inPosition = !_state.players.any((p) =>
        !p.isFolded &&
        p.id != player.id &&
        (postflopOrder[p.position] ?? 0) > myOrder);

    // ── PROBE BET DETECTION: did the IP player check back last street?
    // If so, they showed weakness and the OOP player can probe bet this street.
    String? prevStreetName;
    if (_state.street == 'turn') prevStreetName = 'flop';
    else if (_state.street == 'river') prevStreetName = 'turn';
    bool villainCheckedBack = false;
    if (prevStreetName != null) {
      final prevActions = _state.currentHandActions
          .where((a) => a.street == prevStreetName)
          .toList();
      if (prevActions.isNotEmpty && prevActions.last.type == ActionType.check) {
        final checker = _state.players.firstWhere(
            (p) => p.name == prevActions.last.playerName,
            orElse: () => _state.players[0]);
        final checkerOrder = postflopOrder[checker.position] ?? 0;
        if (!player.isFolded && checkerOrder > myOrder) {
          villainCheckedBack = true;
        }
      }
    }
    // ── PREVIOUS BOARD CARDS: for draw-completion detection ──
    final prevBoard = _state.street == 'turn' &&
            _state.communityCards.length >= 4
        ? _state.communityCards.sublist(0, 3)
        : _state.street == 'river' &&
                _state.communityCards.length >= 5
            ? _state.communityCards.sublist(0, 4)
            : <CardModel>[];

    // ── PREFLOP OPENER: the first player to open-raise this hand. Defending
    // ranges depend heavily on WHO opened (tight vs UTG, wide vs BTN/blinds).
    TablePosition? openerPosition;
    for (final a in _state.currentHandActions
        .where((a) => a.street == 'preflop')) {
      final isRaise = a.type == ActionType.raise ||
          (a.type == ActionType.allIn && a.amount > bigBlind);
      if (isRaise) {
        openerPosition = _state.players
            .firstWhere((p) => p.name == a.playerName,
                orElse: () => _state.players[0])
            .position;
        break;
      }
    }

    // ── PREFLOP POT TYPE: count preflop raises to know if this is an SRP,
    // 3-bet or 4-bet+ pot (ranges/SPR differ a lot). Drives PostflopContext.
    final preflopRaiseCount = _state.currentHandActions
        .where((a) =>
            a.street == 'preflop' &&
            (a.type == ActionType.raise ||
                a.type == ActionType.bet ||
                (a.type == ActionType.allIn && a.amount > bigBlind)))
        .length;

    // ── OPPONENT READ: bots should read the player they're actually up against,
    // not always the human. If the last aggressor is another bot, derive a read
    // from that bot's style; otherwise fall back to the human model only while
    // the human is still live, else a neutral (baseline) read.
    final readModel = _readModelFacing(player);

    // ── VILLAIN BARRELS: how many postflop streets BEFORE this one the current
    // aggressor has bet/raised. Each extra barrel condenses their range, so the
    // bot narrows the range it runs equity against (a 3rd barrel ≫ a lone bet).
    final aggressorId = _lastAggressorId();
    final villainBarrels = aggressorId == null
        ? 0
        : _state.currentHandActions
            .where((a) =>
                a.playerId == aggressorId &&
                a.street != 'preflop' &&
                a.street != _state.street &&
                (a.type == ActionType.bet ||
                    a.type == ActionType.raise ||
                    a.type == ActionType.allIn))
            .map((a) => a.street)
            .toSet()
            .length;

    BotDecision decision;
    try {
      decision = await LegendaryBotEngine.decide(
        profile: profile,
        holeCards: player.holeCards,
        communityCards: _state.communityCards,
        position: player.position,
        callAmount: callAmount.toDouble(),
        currentBet: _state.currentBet,
        myStreetBet: player.streetBet,
        currentPot: _state.pot,
        botStack: player.stack,
        humanModel: readModel,
        isPreflop: _state.phase == GamePhase.preflop,
        wasAggressor: hasInitiative,
        inPosition: inPosition,
        activePlayers: _state.activeCount,
        street: _state.street,
        raiseCount: raiseCount,
        callersThisStreet: callersThisStreet,
        bigBlind: bigBlind,
        openerPosition: openerPosition,
        preflopRaiseCount: max(1, preflopRaiseCount),
        villainBarrels: villainBarrels,
        villainCheckedBack: villainCheckedBack,
        prevBoard: prevBoard,
      );
    } catch (e, st) {
      // A bot decision must never freeze the table. Fall back to the safest
      // legal action: check if free, otherwise fold (never crash the hand).
      debugPrint('Bot decision error (safe fallback applied): $e\n$st');
      final safeType =
          callAmount <= 0 ? ActionType.check : ActionType.fold;
      decision = BotDecision(type: safeType, amount: 0, thinkMs: 0);
    }

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

  void _applyAction(int playerIdx, ActionType type, double rawAmountIn) {
    if (_disposed) return;
    // Sanitize the incoming amount: a NaN/Infinity here would poison stacks and
    // widget sizes (grey-screen crash). Clamp to a sane finite value.
    final rawAmount = (rawAmountIn.isFinite ? rawAmountIn : 0.0)
        .clamp(0.0, 100000000.0)
        .toDouble();
    final player = _state.players[playerIdx];
    var players = List<PlayerModel>.from(_state.players);
    var pot = _state.pot;
    var currentBet = _state.currentBet;
    var actorsRemaining = _state.actorsRemaining;
    var wasAggressor = _state.wasAggressorThisStreet;

    // Whether this action takes the betting lead (set inside the switch).
    bool actionAggressive = false;

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
        // Target total street bet. The most a player can put in is their whole
        // remaining stack (streetBet + stack); never clamp with a lower bound
        // above the upper bound (that throws on short stacks).
        final maxTotal = player.streetBet + player.stack;
        final minTotal = min(bigBlind.toDouble(), maxTotal);
        final amount = rawAmount.clamp(minTotal, maxTotal).toDouble();
        final extraBet = amount - player.streetBet;
        pot += extraBet;
        final goesAllIn = player.stack - extraBet <= 0;
        // A short "raise" that can't exceed the current bet is really a call/
        // all-in — it must NOT lower the current bet or reopen the action.
        final reopens = amount > currentBet;
        actionAggressive = reopens;
        if (reopens) {
          currentBet = amount;
          wasAggressor = true;
        }
        updated = player.copyWith(
          stack: player.stack - extraBet,
          streetBet: amount,
          totalHandBet: player.totalHandBet + extraBet,
          isAllIn: goesAllIn,
        );
        if (reopens) {
          // After a genuine raise, all OTHER active players must act again.
          actorsRemaining = players.where((p) =>
              !p.isFolded && !p.isAllIn && p.id != player.id).length;
        } else {
          // Undersized all-in that doesn't reopen: this player has acted.
          actorsRemaining = max(0, actorsRemaining - 1);
        }
        break;

      case ActionType.allIn:
        final allInAmount = player.stack;
        pot += allInAmount;
        final newStreetBet = player.streetBet + allInAmount;
        if (newStreetBet > currentBet) {
          actionAggressive = true;
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
    final actionEntry = HandAction(
      playerId: player.id,
      playerName: player.name,
      type: type,
      amount: rawAmount,
      street: _state.street,
      sequence: _state.currentHandActions.length,
      isAggressive: actionAggressive,
    );
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
      // Hold the last action of the street (check/call/fold) on screen for a
      // beat so the player can read the decision before the next card.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_disposed) _advanceStreet();
      });
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

    // Defensive: a bad hand evaluation (e.g. a seat with missing cards) must
    // never crash the app into a grey screen. Fall back to splitting among the
    // remaining players if evaluation fails or yields no winner.
    List<int> winnerPlayerIndices;
    try {
      final allCards = activeIndices.map((i) => _state.players[i].holeCards).toList();
      final winnerLocalIndices = HandEvaluator.findWinners(allCards, _state.communityCards);
      winnerPlayerIndices = winnerLocalIndices.map((i) => activeIndices[i]).toList();
      if (winnerPlayerIndices.isEmpty) winnerPlayerIndices = activeIndices;
    } catch (_) {
      winnerPlayerIndices = activeIndices;
    }

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

    var winners = winnerPlayerIndices ?? notFolded;
    if (winners.isEmpty) winners = notFolded;
    // Last-resort guard: never divide by zero (would make stacks NaN → grey
    // screen). If somehow nobody is eligible, just start a fresh hand.
    if (winners.isEmpty) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_disposed) startNewHand();
      });
      return;
    }
    final pot = _state.pot.isFinite ? _state.pot : 0.0;
    final share = pot / winners.length;

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

  /// Player id of the last aggressive action (bet / raise / all-in over a
  /// blind) in the whole hand = who holds the initiative right now. Returns
  /// null if only checks/calls have happened. Matched by stable [playerId]
  /// (never by name), and a CALL never confers initiative.
  String? _lastAggressorId() {
    String? id;
    for (final a in _state.currentHandActions) {
      if (a.isAggressive) id = a.playerId;
    }
    return id;
  }

  /// The read a deciding bot should use, based on WHO it's actually facing.
  /// Reacting to a bet → read the last aggressor (human model if it's the
  /// human, a style-derived read if it's another bot). When no one is leading
  /// (opening / checked round) exploit the human only while they're still live;
  /// otherwise use a neutral baseline read instead of the human's tendencies.
  HumanReadModel _readModelFacing(PlayerModel actor) {
    final aggId = _lastAggressorId();
    if (aggId != null && aggId != actor.id) {
      final villain = _state.players.firstWhere(
          (p) => p.id == aggId,
          orElse: () => actor);
      if (villain.isHuman) return _humanModel;
      return LegendaryBotEngine.readModelFor(
          LegendaryBotEngine.profileByName(villain.legendName ?? ''));
    }
    final humanLive = _state.players.any((p) => p.isHuman && !p.isFolded);
    return humanLive ? _humanModel : HumanReadModel();
  }

  GTORecommendation getGTOAdvice() {
    final human = _state.humanPlayer;

    // ── Preflop: DB-driven decision hierarchy ────────────────────────────────
    if (_state.phase == GamePhase.preflop && human.holeCards.length == 2) {
      return _preflopGTOAdvice(human);
    }

    // ── Postflop: factor-aware recommendation (same reads the bots use) ──────
    final preflopRaises = _state.currentHandActions
        .where((a) =>
            a.street == 'preflop' &&
            (a.type == ActionType.raise ||
                a.type == ActionType.bet ||
                (a.type == ActionType.allIn && a.amount > bigBlind)))
        .length;

    // Initiative: the last aggressor (bet/raise/all-in) of the hand. A call —
    // e.g. calling a 4-bet — never confers it, so it stays with the aggressor
    // until someone bets/raises again (even postflop).
    final hasInitiative = _lastAggressorId() == human.id;

    // Position: postflop the button acts last (SB→BB→…→BTN).
    const postflopOrder = {
      TablePosition.sb: 0,
      TablePosition.bb: 1,
      TablePosition.utg: 2,
      TablePosition.mp: 3,
      TablePosition.co: 4,
      TablePosition.btn: 5,
    };
    final myOrder = postflopOrder[human.position] ?? 0;
    final inPosition = !_state.players.any((p) =>
        !p.isFolded &&
        p.id != human.id &&
        (postflopOrder[p.position] ?? 0) > myOrder);

    // Villain read: heads-up → exploit the single opponent's legend style.
    var read = VillainRead.neutral;
    if (_state.activeCount == 2) {
      final villain = _state.players.firstWhere(
          (p) => !p.isFolded && p.id != human.id,
          orElse: () => _state.players[0]);
      if (!villain.isHuman) {
        read = LegendaryBotEngine.villainReadFor(
            LegendaryBotEngine.profileByName(villain.legendName ?? ''));
      }
    }

    final rec = CfrBridge.instance.recommend(
      heroCards: human.holeCards,
      communityCards: _state.communityCards,
      callAmount: _state.callAmount,
      potSize: _state.pot,
      numOpponents: max(1, _state.activeCount - 1),
      heroStack: human.stack,
      position: human.position,
      inPosition: inPosition,
      hasInitiative: hasInitiative,
      numActive: _state.activeCount,
      preflopRaises: max(1, preflopRaises),
      villainRead: read,
    );
    // Postflop EV is a fraction of the pot; express it in BB for display.
    final evBB = bigBlind > 0 ? rec.ev * _state.pot / bigBlind : 0.0;
    return rec.copyWith(evBB: evBB);
  }

  /// Preflop GTO advice using the full database hierarchy:
  ///   Open → Facing Open → Facing 3B → Facing 4B → BvB → Squeeze → Multiway
  GTORecommendation _preflopGTOAdvice(PlayerModel human) {
    final handCode = PreflopCharts.handCode(human.holeCards);
    final hero = human.position;

    // Build context from current hand actions (preflop street only).
    final preflopActions = _state.currentHandActions
        .where((a) => a.street == 'preflop')
        .toList();

    int numRaisers = preflopActions
        .where((a) =>
            a.type == ActionType.raise ||
            a.type == ActionType.bet ||
            (a.type == ActionType.allIn && a.amount > bigBlind))
        .length;
    int numCallers = preflopActions
        .where((a) => a.type == ActionType.call)
        .length;

    // Find the first aggressor and the most recent aggressor.
    TablePosition? opener;
    TablePosition? lastAggressor;
    for (final a in preflopActions) {
      final isRaise = a.type == ActionType.raise ||
          a.type == ActionType.bet ||
          (a.type == ActionType.allIn && a.amount > bigBlind);
      if (isRaise) {
        final p = _state.players.firstWhere(
            (pl) => pl.name == a.playerName, orElse: () => _state.players[0]);
        opener ??= p.position;
        lastAggressor = p.position;
      }
    }

    final ctx = GTODatabase.inferContext(
      hero: hero,
      numRaisers: numRaisers,
      numCallers: numCallers,
      opener: opener,
      lastAggressor: lastAggressor,
    );

    // If BB is just opening (no prior action, only blind posted), detect BvB.
    final effectiveCtx = (ctx.action == PreflopAction.rfi &&
            (hero == TablePosition.bb || hero == TablePosition.sb) &&
            _state.activeCount == 2)
        ? const PreflopContext(action: PreflopAction.blindVsBlind)
        : ctx;

    final strategy = GTODatabase.preflop(hero, handCode, effectiveCtx);
    // primary = the highest-frequency action (a SpotRecord).
    final primary = strategy.primary;
    final action = primary.action;
    final ev = primary.ev;

    // Map the GTO DB action to the GTORecommendation format.
    double amount = 0;
    final callAmount = _state.callAmount;

    if (action == 'open' || action == '3bet' || action == '4bet' ||
        action == 'squeeze' || action == '5bet_jam') {
      final multiplier = action == '5bet_jam' ? 99.0 : 3.2;
      // Safe clamp: stack can be below one BB — never let the lower bound
      // exceed the upper bound (clamp would throw).
      amount = (callAmount > 0 ? callAmount * multiplier : bigBlind * 3.0)
          .clamp(min(bigBlind.toDouble(), human.stack), human.stack);
    } else if (action == 'call') {
      amount = callAmount;
    }

    // Explanation comes straight from the primary action's coach note.
    final explanation = primary.explanation.isNotEmpty
        ? primary.explanation
        : '$handCode → $action (EV ≈ +${ev.toStringAsFixed(2)}BB)';

    // ── #8 STACK-DEPTH ADJUSTMENT ───────────────────────────────────────────
    // The ranges in the DB are studied at ~100bb. Adjust + explain by effective
    // stack: short = jam/fold and fewer speculative flats; deep = better implied
    // odds for pairs / suited connectors.
    final effBB = bigBlind > 0 ? human.stack / bigBlind : 100.0;
    var finalAction = action;
    var finalAmount = amount;
    final String depthNote;
    if (effBB <= 12) {
      // Push/fold zone: at ~12bb or less, min-raising and flat-calling are
      // dominated by jam-or-fold. Collapse the studied line accordingly —
      // open/3bet/squeeze become a shove; flats become folds.
      depthNote =
          '🚀 Stack muy corto (~${effBB.toStringAsFixed(0)}bb): zona push/fold. '
          'Abrir small o pagar es dominado; juega jam o fold. Con manos para '
          'continuar, jamea por fold-equity en vez de inflar un bote sin SPR.';
      if (finalAction == 'open' ||
          finalAction == '3bet' ||
          finalAction == 'squeeze' ||
          finalAction == '4bet') {
        finalAction = '5bet_jam';
        finalAmount = human.stack;
      } else if (finalAction == 'call') {
        finalAction = 'fold';
        finalAmount = 0;
      }
    } else if (effBB <= 25) {
      depthNote =
          '⛏️ Stack corto (~${effBB.toStringAsFixed(0)}bb): peores implícitas → '
          'menos flats especulativos; prioriza 3bet/jam o fold. Pares pequeños y '
          'suited connectors pierden valor para flotar.';
      // Flatting a 4-bet this short is a clear leak — jam or fold, not call.
      if (finalAction == 'call' &&
          effectiveCtx.action == PreflopAction.facing4bet) {
        finalAction = 'fold';
        finalAmount = 0;
      }
    } else if (effBB >= 175) {
      depthNote =
          '🌊 Stack profundo (~${effBB.toStringAsFixed(0)}bb): mejores implícitas '
          'para pares y suited connectors (set-mining/flats rentables); ojo con '
          'dominadas (AJ/KQ) en botes grandes.';
    } else {
      depthNote =
          '📏 Stack estándar (~${effBB.toStringAsFixed(0)}bb): los rangos '
          'estudiados de la base aplican directamente.';
    }
    final explanationWithDepth = '$explanation\n\n$depthNote';

    // Preflop equity for display — vs the villain's ESTIMATED range for this
    // spot (open/3bet/4bet/squeeze/BvB), not vs random cards. Showing "AKo 65%"
    // (vs random) when it's ~48% vs a UTG open is misleading; this mirrors the
    // ranges the bots actually play.
    final villainRangeWidth = PreflopCharts.estimateVillainRangeWidth(
      numRaises: numRaisers,
      aggressorPos: lastAggressor ?? opener,
      blindVsBlind: effectiveCtx.action == PreflopAction.blindVsBlind,
      squeeze: effectiveCtx.action == PreflopAction.squeeze,
    );
    final preflopEquity = EquityCalculator.calculate(
      heroCards: human.holeCards,
      communityCards: const [],
      numOpponents: max(1, _state.activeCount - 1),
      simulations: 400,
      deterministic: true,
      rangeWidth: villainRangeWidth,
    );

    // Surface the chart's MIXED strategy so the user learns GTO often splits a
    // hand between actions (e.g. "Open 50% / Fold 50%") instead of a single
    // verdict. Skipped when short-stack logic rewrote the action (the chart mix
    // no longer matches the push/fold line).
    List<ActionFrequency>? mix;
    if (finalAction == action) {
      final m = strategy.actions
          .where((a) => a.frequency > 0.05)
          .toList()
        ..sort((a, b) => b.frequency.compareTo(a.frequency));
      if (m.length > 1) {
        mix = m
            .map((a) => ActionFrequency(_actionLabel(a.action), a.frequency))
            .toList();
      }
    }

    return GTORecommendation(
      action: _actionLabel(finalAction),
      amount: finalAmount,
      equity: preflopEquity,
      potOdds: callAmount > 0
          ? EquityCalculator.potOddsRequired(callAmount, _state.pot)
          : 0,
      ev: ev,
      evBB: ev, // preflop chart EV is already in big blinds
      reasoning: explanationWithDepth,
      equilibriumMix: mix,
    );
  }

  static String _actionLabel(String a) {
    switch (a) {
      case 'open': return 'Raise';
      case '3bet': return 'Raise';
      case '4bet': return 'Raise';
      case 'squeeze': return 'Raise';
      case '5bet_jam': return 'All-In';
      case 'call': return 'Call';
      case 'fold': return 'Fold';
      default: return a[0].toUpperCase() + a.substring(1);
    }
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
