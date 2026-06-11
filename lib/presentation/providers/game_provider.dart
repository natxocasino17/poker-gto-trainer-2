import 'package:flutter/foundation.dart';
import '../../data/models/hand_log_model.dart';
import '../../data/models/session_stats_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../engine/legendary_ai.dart';
import '../../engine/poker_engine.dart';
import '../../engine/ai_analyst.dart';
import '../../core/utils/equity_calculator.dart';

class GameProvider extends ChangeNotifier {
  final GameRepository _repo;
  late PokerEngine _engine;
  late HandReviewerEngine _analyst;

  List<LegendProfile> _activeLegends = [];
  List<HandLog> _handHistory = [];
  bool _initialized = false;
  bool _showGTOOverlay = false;
  GTORecommendation? _lastGTOAdvice;
  double _bankroll = 1000.0;

  GameProvider(this._repo);

  bool get initialized => _initialized;
  GameState get gameState => _engine.state;
  List<LegendProfile> get activeLegends => _activeLegends;
  List<HandLog> get handHistory => _handHistory;
  bool get showGTOOverlay => _showGTOOverlay;
  GTORecommendation? get lastGTOAdvice => _lastGTOAdvice;
  double get bankroll => _bankroll;
  double get tableStack => _repo.getTableStack();

  SessionStats get sessionStats =>
      SessionStats.fromHandLogs(_handHistory, _repo.getSessionId(), _repo.getSessionStart());

  Future<void> initialize() async {
    _bankroll = _repo.getBankroll();
    _handHistory = _repo.getHandLogs();
    _activeLegends = LegendaryBotEngine.selectTable();
    _analyst = HandReviewerEngine(_repo);

    _engine = PokerEngine(
      tableStack: _repo.getTableStack(),
      bankroll: _bankroll,
      legends: _activeLegends,
    );

    _engine.onHandComplete = _onHandComplete;
    _engine.addListener(_onEngineChanged);

    _initialized = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));
    _engine.startNewHand();
  }

  void _onEngineChanged() => notifyListeners();

  Future<void> _onHandComplete(GameState state) async {
    final human = state.humanPlayer;
    final humanBet = state.players
        .firstWhere((p) => p.isHuman)
        .totalHandBet;

    final humanWinner = state.players.any((p) => p.isHuman && p.isWinner);
    final share = humanWinner ? state.pot / state.players.where((p) => p.isWinner).length : 0.0;
    final profit = share - humanBet;

    await _repo.applyHandResult(
      humanProfit: profit,
      newTableStack: human.stack,
    );

    _bankroll = _repo.getBankroll();

    await _analyst.recordHand(
      completedState: state,
      humanProfit: profit,
      handNumber: state.handNumber,
    );

    _handHistory = _repo.getHandLogs();

    if (human.stack <= 0 && _bankroll >= 50) {
      await _repo.rebuy(200.0.clamp(0.0, _bankroll));
      _engine.updateTableStack(_repo.getTableStack());
      _bankroll = _repo.getBankroll();
    }

    notifyListeners();
  }

  void humanAction(ActionType type, double amount) {
    _engine.humanAction(type, amount);
  }

  void requestGTOAdvice() {
    if (!gameState.awaitingHumanAction) return;
    _lastGTOAdvice = _engine.getGTOAdvice();
    _showGTOOverlay = true;
    notifyListeners();
  }

  void dismissGTOOverlay() {
    _showGTOOverlay = false;
    notifyListeners();
  }

  Future<void> rebuyFromBankroll(double amount) async {
    await _repo.rebuy(amount);
    _engine.updateTableStack(amount);
    _bankroll = _repo.getBankroll();
    notifyListeners();
  }

  String generateCoachReport() {
    return AICoach.generateReport(sessionStats, _handHistory);
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    super.dispose();
  }
}
