import 'package:flutter/foundation.dart';
import '../../data/models/hand_log_model.dart';
import '../../data/models/session_stats_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../engine/legendary_ai.dart';
import '../../engine/poker_engine.dart';
import '../../engine/ai_analyst.dart';
import '../../core/utils/equity_calculator.dart';

/// Session economy model:
/// - Bankroll = money OFF the table.
/// - Sitting down ALWAYS costs exactly $200 (everyone enters even-stacked).
/// - Profits live in the table stack during the session.
/// - Closing the session cashes the stack back into the bankroll.
class GameProvider extends ChangeNotifier {
  final GameRepository _repo;
  PokerEngine? _engine;
  late HandReviewerEngine _analyst;

  List<LegendProfile> _activeLegends = [];
  List<HandLog> _handHistory = [];
  bool _initialized = false;
  bool _sessionActive = false;
  bool _showGTOOverlay = false;
  GTORecommendation? _lastGTOAdvice;
  double _bankroll = 1000.0;
  bool _displayInBB = false;

  GameProvider(this._repo);

  bool get initialized => _initialized;
  bool get sessionActive => _sessionActive && _engine != null;
  GameState get gameState => _engine!.state;
  List<LegendProfile> get activeLegends => _activeLegends;
  List<HandLog> get handHistory => _handHistory;
  bool get showGTOOverlay => _showGTOOverlay;
  GTORecommendation? get lastGTOAdvice => _lastGTOAdvice;
  double get bankroll => _bankroll;
  bool get displayInBB => _displayInBB;
  bool get canAffordBuyIn => _bankroll >= GameRepository.defaultBuyIn;

  void toggleDisplayUnits() {
    _displayInBB = !_displayInBB;
    _repo.saveDisplayInBB(_displayInBB);
    notifyListeners();
  }

  /// Formats a money amount in USD or Big Blinds depending on user preference.
  String money(double v) {
    if (_displayInBB) {
      final bb = v / PokerEngine.bigBlind;
      final s = bb == bb.roundToDouble()
          ? bb.toStringAsFixed(0)
          : bb.toStringAsFixed(1);
      return '$s BB';
    }
    return v == v.roundToDouble()
        ? '\$${v.toStringAsFixed(0)}'
        : '\$${v.toStringAsFixed(2)}';
  }

  /// Adds a fresh $1,000 to the bankroll when the player goes broke.
  Future<void> reloadBankroll() async {
    _bankroll += GameRepository.initialBankroll;
    await _repo.saveBankroll(_bankroll);
    notifyListeners();
  }

  SessionStats get sessionStats =>
      SessionStats.fromHandLogs(_handHistory, _repo.getSessionId(), _repo.getSessionStart());

  Future<void> initialize() async {
    _bankroll = _repo.getBankroll();
    _displayInBB = _repo.getDisplayInBB();
    _handHistory = _repo.getHandLogs();
    _analyst = HandReviewerEngine(_repo);
    _initialized = true;
    notifyListeners();
  }

  /// The player decides when to sit down. Everyone — human included —
  /// enters with exactly $200, never more.
  Future<void> startSession() async {
    if (_sessionActive || !canAffordBuyIn) return;

    // New session: fresh stats/history and a fresh random legend lineup
    await _repo.resetSession();
    _handHistory = [];

    _bankroll -= GameRepository.defaultBuyIn;
    await _repo.saveBankroll(_bankroll);
    await _repo.saveTableStack(GameRepository.defaultBuyIn);

    _activeLegends = LegendaryBotEngine.selectTable();
    final engine = PokerEngine(
      tableStack: GameRepository.defaultBuyIn,
      bankroll: _bankroll,
      legends: _activeLegends,
    );
    engine.onHandComplete = _onHandComplete;
    engine.addListener(_onEngineChanged);
    _engine = engine;
    _sessionActive = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    engine.startNewHand();
  }

  /// The player decides when to leave: the table stack is cashed back
  /// into the bankroll and the table closes.
  Future<void> endSession() async {
    final engine = _engine;
    if (engine == null) return;

    final stack = engine.state.humanPlayer.stack;
    _bankroll += stack;
    await _repo.saveBankroll(_bankroll);
    await _repo.saveTableStack(0);

    engine.removeListener(_onEngineChanged);
    engine.dispose();
    _engine = null;
    _sessionActive = false;
    _showGTOOverlay = false;
    notifyListeners();
  }

  void _onEngineChanged() => notifyListeners();

  Future<void> _onHandComplete(GameState state) async {
    final engine = _engine;
    if (engine == null) return;

    final human = state.humanPlayer;
    final humanBet = human.totalHandBet;
    final humanWinner = state.players.any((p) => p.isHuman && p.isWinner);
    final share = humanWinner
        ? state.pot / state.players.where((p) => p.isWinner).length
        : 0.0;
    final profit = share - humanBet;

    // Profits stay on the table; we only persist the stack snapshot.
    await _repo.saveTableStack(human.stack);

    await _analyst.recordHand(
      completedState: state,
      humanProfit: profit,
      handNumber: state.handNumber,
    );

    _handHistory = _repo.getHandLogs();

    // Busted (or below one blind): automatic re-entry for another exact
    // $200 while the bankroll can cover it. Leftover cents are swept back.
    if (human.stack < PokerEngine.bigBlind && canAffordBuyIn) {
      _bankroll += human.stack;
      _bankroll -= GameRepository.defaultBuyIn;
      await _repo.saveBankroll(_bankroll);
      await _repo.saveTableStack(GameRepository.defaultBuyIn);
      engine.updateTableStack(GameRepository.defaultBuyIn);
    }

    notifyListeners();
  }

  void humanAction(ActionType type, double amount) {
    _engine?.humanAction(type, amount);
  }

  void requestGTOAdvice() {
    final engine = _engine;
    if (engine == null || !engine.state.awaitingHumanAction) return;
    _lastGTOAdvice = engine.getGTOAdvice();
    _showGTOOverlay = true;
    notifyListeners();
  }

  void dismissGTOOverlay() {
    _showGTOOverlay = false;
    notifyListeners();
  }

  String generateCoachReport() {
    return AICoach.generateReport(sessionStats, _handHistory);
  }

  @override
  void dispose() {
    _engine?.removeListener(_onEngineChanged);
    _engine?.dispose();
    super.dispose();
  }
}
