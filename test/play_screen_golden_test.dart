// Golden screenshot tests — excluded from CI (run locally with --update-goldens).
// Skip in CI via: flutter test --exclude-tags golden
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poker_gto_trainer/data/models/card_model.dart';
import 'package:poker_gto_trainer/data/models/hand_log_model.dart';
import 'package:poker_gto_trainer/data/models/player_model.dart';
import 'package:poker_gto_trainer/data/models/session_stats_model.dart';
import 'package:poker_gto_trainer/data/repositories/game_repository.dart';
import 'package:poker_gto_trainer/engine/poker_engine.dart';
import 'package:poker_gto_trainer/presentation/providers/game_provider.dart';
import 'package:poker_gto_trainer/presentation/screens/play/play_screen.dart';

class _FakeProvider extends GameProvider {
  _FakeProvider(super.repo);

  late final GameState _gs = GameState(
    players: [
      PlayerModel(
        id: 'human', name: 'You', isHuman: true, stack: 187,
        holeCards: const [
          CardModel(rank: 14, suit: Suit.spades),
          CardModel(rank: 13, suit: Suit.spades),
        ],
        position: TablePosition.btn, isDealer: true, streetBet: 6,
      ),
      PlayerModel(
        id: 'bot0', name: 'Phil Ivey', isHuman: false, stack: 142,
        legendName: 'Phil Ivey', position: TablePosition.sb, streetBet: 1,
        holeCards: const [
          CardModel(rank: 2, suit: Suit.clubs),
          CardModel(rank: 3, suit: Suit.clubs),
        ],
      ),
      PlayerModel(
        id: 'bot1', name: 'Adrián Mateos', isHuman: false, stack: 233,
        legendName: 'Adrián Mateos', position: TablePosition.bb, streetBet: 2,
        holeCards: const [
          CardModel(rank: 4, suit: Suit.clubs),
          CardModel(rank: 5, suit: Suit.clubs),
        ],
      ),
      PlayerModel(
        id: 'bot2', name: 'Tom Dwan', isHuman: false, stack: 98,
        legendName: 'Tom Dwan', position: TablePosition.utg, isFolded: true,
        holeCards: const [
          CardModel(rank: 6, suit: Suit.clubs),
          CardModel(rank: 7, suit: Suit.clubs),
        ],
      ),
      PlayerModel(
        id: 'bot3', name: 'Daniel Negreanu', isHuman: false, stack: 305,
        legendName: 'Daniel Negreanu', position: TablePosition.mp, streetBet: 12,
        holeCards: const [
          CardModel(rank: 8, suit: Suit.clubs),
          CardModel(rank: 9, suit: Suit.clubs),
        ],
      ),
      PlayerModel(
        id: 'bot4', name: 'Papo Lococo', isHuman: false, stack: 164,
        legendName: 'Papo Lococo', position: TablePosition.co, streetBet: 6,
        holeCards: const [
          CardModel(rank: 10, suit: Suit.clubs),
          CardModel(rank: 11, suit: Suit.clubs),
        ],
      ),
    ],
    communityCards: const [
      CardModel(rank: 4, suit: Suit.clubs),
      CardModel(rank: 10, suit: Suit.clubs),
      CardModel(rank: 8, suit: Suit.diamonds),
    ],
    deck: const [],
    pot: 27,
    currentBet: 12,
    activePlayerIndex: 0,
    dealerIndex: 0,
    phase: GamePhase.flop,
    street: 'flop',
    handNumber: 7,
    awaitingHumanAction: true,
    currentHandActions: const [
      HandAction(playerId: 'bot3', playerName: 'Daniel Negreanu', type: ActionType.raise, amount: 12, street: 'flop', sequence: 0),
      HandAction(playerId: 'bot2', playerName: 'Tom Dwan', type: ActionType.fold, amount: 0, street: 'flop', sequence: 1),
      HandAction(playerId: 'bot4', playerName: 'Papo Lococo', type: ActionType.call, amount: 6, street: 'flop', sequence: 2),
    ],
  );

  @override
  bool get initialized => true;
  @override
  bool get sessionActive => true;
  @override
  GameState get gameState => _gs;
  @override
  bool get showGTOOverlay => false;
  @override
  double get bankroll => 800;
  @override
  List<HandLog> get handHistory => [];
  @override
  SessionStats get sessionStats =>
      SessionStats.fromHandLogs([], 'test', DateTime(2026));
}

void main() {
  testWidgets('Play screen renders without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await GameRepository.create();
    final fake = _FakeProvider(repo);

    tester.binding.window.physicalSizeTestValue = const Size(1080, 2340);
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>.value(
        value: fake,
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Just verify the screen renders without errors
    expect(find.byType(PlayScreen), findsOneWidget);
  });
}