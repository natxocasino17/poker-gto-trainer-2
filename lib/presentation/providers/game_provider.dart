import 'package:flutter/foundation.dart';
import '../../data/models/hand_log_model.dart';
import '../../data/models/player_model.dart';
import '../../data/models/session_stats_model.dart';
import '../../data/models/session_summary_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../engine/cfr/cfr_bridge.dart';
import '../../engine/legendary_ai.dart';
import '../../engine/poker_engine.dart';
import '../../engine/ai_analyst.dart';
import '../../core/utils/equity_calculator.dart';
import '../../core/utils/progress_service.dart';
import '../../core/utils/trainer_feedback.dart';
import '../../core/i18n/i18n.dart';

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
  List<String?> _tableSlots = List<String?>.filled(5, null);
  String _localeCode = 'es';

  // ── User settings (mirrored from the repository) ──
  int _difficulty = 1; // 0 easy, 1 medium, 2 hard
  bool _autoRebuy = true;
  double _rebuyAmount = GameRepository.defaultBuyIn;
  double _smallBlind = 1.0;
  double _bigBlind = 2.0;
  double _startingStack = GameRepository.defaultBuyIn;
  bool _trainerMode = false;
  int _tableBackground = 0;

  GameProvider(this._repo);

  int get tableBackground => _tableBackground;

  Future<void> setTableBackground(int i) async {
    _tableBackground = i;
    await _repo.saveTableBackground(i);
    notifyListeners();
  }

  int get difficulty => _difficulty;
  bool get autoRebuy => _autoRebuy;
  double get rebuyAmount => _rebuyAmount;
  double get smallBlind => _smallBlind;
  double get bigBlind => _bigBlind;
  double get startingStack => _startingStack;
  bool get trainerMode => _trainerMode;
  bool get tutorialSeen => _repo.getTutorialSeen();

  bool get initialized => _initialized;
  bool get sessionActive => _sessionActive && _engine != null;
  GameState get gameState => _engine!.state;
  List<LegendProfile> get activeLegends => _activeLegends;
  List<HandLog> get handHistory => _handHistory;
  bool get showGTOOverlay => _showGTOOverlay;
  GTORecommendation? get lastGTOAdvice => _lastGTOAdvice;

  /// Villain position + hero hand for the live per-spot range viewer, or null
  /// when there's no specific preflop range to show right now.
  ({TablePosition villainPos, String heroHand, String label})? preflopRangeSpot() =>
      _engine?.preflopRangeSpot();

  /// Main + side pots (by contribution) when there's an all-in; empty otherwise.
  List<({double amount, List<int> eligible})> get sidePots =>
      _engine?.currentSidePots ?? const [];
  double get bankroll => _bankroll;
  bool get displayInBB => _displayInBB;
  bool get canAffordBuyIn => _bankroll >= _startingStack;
  List<String?> get tableSlots => List.unmodifiable(_tableSlots);
  List<SessionSummary> get sessionArchive => _repo.getSessionArchive();
  String get localeCode => _localeCode;

  void setLocale(String code) {
    if (!I18n.supported.containsKey(code)) return;
    _localeCode = code;
    I18n.locale = code;
    _repo.saveLocale(code);
    notifyListeners();
  }

  /// Table editor: assign a profile name (or null = random) to a seat slot.
  void setTableSlot(int index, String? name) {
    if (index < 0 || index >= 5) return;
    _tableSlots[index] = name;
    _repo.saveTableConfig(_tableSlots);
    notifyListeners();
  }

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

  SessionStats? _statsCache;
  SessionStats get sessionStats => _statsCache ??= SessionStats.fromHandLogs(
      _handHistory, _repo.getSessionId(), _repo.getSessionStart());

  Future<void> initialize() async {
    _bankroll = _repo.getBankroll();
    _displayInBB = _repo.getDisplayInBB();
    _handHistory = _repo.getHandLogs();
    _statsCache = null;
    _tableSlots = _repo.getTableConfig();
    _localeCode = _repo.getLocale();
    I18n.locale = _localeCode;
    _loadSettings();
    _analyst = HandReviewerEngine(_repo);
    _initialized = true;
    notifyListeners();
    // Fire-and-forget: trains the preflop CFR tree in a background isolate so
    // CfrBridge.recommend has equilibrium frequencies to cite once it's done.
    // Never blocks startup, and the advisor falls back to the heuristic-only
    // recommendation (identical to before) until this completes.
    CfrBridge.instance.warmUp();
  }

  /// Loads user settings and applies the engine-global ones (blinds, difficulty).
  void _loadSettings() {
    _difficulty = _repo.getDifficulty();
    _autoRebuy = _repo.getAutoRebuy();
    _rebuyAmount = _repo.getRebuyAmount();
    _smallBlind = _repo.getSmallBlind();
    _bigBlind = _repo.getBigBlind();
    _startingStack = _repo.getStartingStack();
    _trainerMode = _repo.getTrainerMode();
    _tableBackground = _repo.getTableBackground();
    _applyEngineSettings();
  }

  void _applyEngineSettings() {
    PokerEngine.smallBlind = _smallBlind;
    PokerEngine.bigBlind = _bigBlind;
    LegendaryBotEngine.difficulty =
        _difficulty == 0 ? 0.0 : (_difficulty == 2 ? 1.0 : 0.5);
  }

  // ── Settings mutators (persist + apply + notify) ──
  Future<void> setDifficulty(int d) async {
    _difficulty = d.clamp(0, 2);
    await _repo.saveDifficulty(_difficulty);
    _applyEngineSettings();
    notifyListeners();
  }

  Future<void> setAutoRebuy(bool v) async {
    _autoRebuy = v;
    await _repo.saveAutoRebuy(v);
    notifyListeners();
  }

  Future<void> setRebuyAmount(double v) async {
    _rebuyAmount = v.clamp(20.0, 100000.0);
    await _repo.saveRebuyAmount(_rebuyAmount);
    notifyListeners();
  }

  Future<void> setBlinds(double sb, double bb) async {
    _smallBlind = sb;
    _bigBlind = bb < sb * 2 ? sb * 2 : bb;
    await _repo.saveSmallBlind(_smallBlind);
    await _repo.saveBigBlind(_bigBlind);
    _applyEngineSettings();
    notifyListeners();
  }

  Future<void> setStartingStack(double v) async {
    _startingStack = v.clamp(20.0, 1000000.0);
    await _repo.saveStartingStack(_startingStack);
    notifyListeners();
  }

  Future<void> setTrainerMode(bool v) async {
    _trainerMode = v;
    await _repo.saveTrainerMode(v);
    notifyListeners();
  }

  Future<void> markTutorialSeen() => _repo.saveTutorialSeen(true);

  // ── Progreso: racha, objetivos diarios y logros ──
  int get streakCount => _repo.getStreakCount();

  ProgressFacts progressFacts() {
    final archive = _repo.getSessionArchive();
    final cur = _sessionActive ? sessionStats : null;
    final lifetimeHands =
        archive.fold<int>(0, (a, s) => a + s.hands) + _handHistory.length;
    final sessionsPlayed =
        archive.length + ((cur != null && cur.handsPlayed > 0) ? 1 : 0);
    var totalProfit = archive.fold<double>(0, (a, s) => a + s.netProfit);
    if (cur != null) totalProfit += cur.netProfit;
    var bestProfit =
        archive.fold<double>(0, (a, s) => s.netProfit > a ? s.netProfit : a);
    if (cur != null && cur.netProfit > bestProfit) bestProfit = cur.netProfit;
    final flawless = archive.any((s) => s.hands >= 5 && s.blunders == 0) ||
        (cur != null && cur.handsPlayed >= 5 && cur.blunders == 0);
    var bestScore =
        archive.fold<double>(0, (a, s) => s.decisionScore > a ? s.decisionScore : a);
    if (cur != null && cur.decisionScore > bestScore) {
      bestScore = cur.decisionScore;
    }
    return ProgressFacts(
      lifetimeHands: lifetimeHands,
      sessionsPlayed: sessionsPlayed,
      totalProfit: totalProfit,
      bestSessionProfit: bestProfit,
      bestDecisionScore: bestScore,
      hadFlawlessSession: flawless,
      streak: _repo.getStreakCount(),
    );
  }

  List<DailyGoal> dailyGoals() {
    final now = DateTime.now();
    bool sameDay(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    final todays = _handHistory.where((h) => sameDay(h.timestamp)).toList();
    var blunders = 0;
    for (final h in todays) {
      for (final s in h.streetAnalyses) {
        if (s.quality == DecisionQuality.blunder) blunders++;
      }
    }
    return ProgressService.daily(
      todayHands: todays.length,
      todayProfit: todays.fold<double>(0, (a, h) => a + h.humanProfit),
      todayBlunders: blunders,
    );
  }

  /// Currently unlocked achievement ids (persisted union — never re-lock).
  Set<String> achievements() {
    final unlocked = ProgressService.evaluate(progressFacts());
    final merged = _repo.getAchievements().union(unlocked);
    _repo.saveAchievements(merged);
    return merged;
  }

  /// The player decides when to sit down. Everyone — human included —
  /// enters with exactly $200, never more.
  Future<void> startSession() async {
    if (_sessionActive || !canAffordBuyIn) return;

    // New session: fresh stats/history and a fresh random legend lineup
    await _repo.resetSession();
    _handHistory = [];
    _statsCache = null;
    _liveAdvice.clear();
    await _repo.touchStreak(); // counts a play day
    _applyEngineSettings(); // blinds + difficulty in effect for this session

    _bankroll -= _startingStack;
    await _repo.saveBankroll(_bankroll);
    await _repo.saveTableStack(_startingStack);

    _activeLegends = LegendaryBotEngine.buildLineup(_tableSlots);
    final engine = PokerEngine(
      tableStack: _startingStack,
      bankroll: _bankroll,
      legends: _activeLegends,
      botBuyIn: _startingStack,
    );
    engine.seedHumanModel(_repo.getHumanProfile());
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

    // Archive the session for the yearly review.
    final stats = sessionStats;
    if (stats.handsPlayed > 0) {
      await _repo.archiveSession(SessionSummary.fromStats(stats));
      await _updateHumanProfile(stats);
    }

    engine.removeListener(_onEngineChanged);
    engine.dispose();
    _engine = null;
    _sessionActive = false;
    _showGTOOverlay = false;
    notifyListeners();
  }

  void _onEngineChanged() {
    notifyListeners();
  }

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
      liveAdvice: Map<String, GTORecommendation>.from(_liveAdvice),
    );
    _liveAdvice.clear();

    _handHistory = _repo.getHandLogs();
    _statsCache = null;

    // Persist any achievement unlocked this hand.
    achievements();

    // Busted (or below one blind): automatic re-entry for the configured
    // rebuy amount while the bankroll can cover it — but only if auto-rebuy
    // is enabled. Leftover cents are swept back to the bankroll.
    if (_autoRebuy &&
        human.stack < PokerEngine.bigBlind &&
        _bankroll >= _rebuyAmount) {
      _bankroll += human.stack;
      _bankroll -= _rebuyAmount;
      await _repo.saveBankroll(_bankroll);
      await _repo.saveTableStack(_rebuyAmount);
      engine.updateTableStack(_rebuyAmount);
    }

    notifyListeners();
  }

  TrainerFeedback? _trainerFeedback;
  TrainerFeedback? get trainerFeedback => _trainerFeedback;
  void dismissTrainerFeedback() {
    _trainerFeedback = null;
    notifyListeners();
  }

  // GTO advice captured live at each human decision, keyed by street, so the
  // post-hand analyzer reuses the EXACT same recommendation (no incongruence
  // between EL PUXI in-game and the hand-by-hand review).
  final Map<String, GTORecommendation> _liveAdvice = {};

  void humanAction(ActionType type, double amount) {
    final engine = _engine;
    if (engine == null) return;
    if (engine.state.awaitingHumanAction) {
      // Capture the GTO recommendation for THIS exact decision/snapshot.
      // A solver hiccup here must NEVER suppress the Trainer banner nor block
      // the human's action, so the advice/grade runs inside try/catch and the
      // action is always applied afterwards.
      try {
        final rec = engine.getGTOAdvice();
        _liveAdvice[engine.state.street] = rec;
        if (_trainerMode) {
          _trainerFeedback = TrainerGrader.grade(type, amount, rec);
        } else {
          _trainerFeedback = null;
        }
      } catch (_) {
        _trainerFeedback = null;
      }
      // Mount the banner immediately instead of relying solely on the engine's
      // change propagation timing.
      notifyListeners();
    } else {
      _trainerFeedback = null;
    }
    engine.humanAction(type, amount);
  }

  Future<void> completeTutorial() async {
    await _repo.saveTutorialSeen(true);
    notifyListeners();
  }

  bool get canReplay => _engine?.canReplay ?? false;

  /// Replays the current hand from preflop with the same cards.
  void replayHand() {
    _trainerFeedback = null;
    _showGTOOverlay = false;
    _engine?.replayHand();
    notifyListeners();
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

  /// Blends this session's tendencies into the persisted cross-session
  /// profile (exponential moving average). This is how the app "learns"
  /// your style and gives sharper advice over time.
  Future<void> _updateHumanProfile(SessionStats stats) async {
    final old = _repo.getHumanProfile();
    final oldHands = old['hands'] ?? 0;
    final newHands = oldHands + stats.handsPlayed;
    // Weight by hand volume, but cap so recent play keeps mattering.
    final w = (stats.handsPlayed / (newHands.clamp(1, 99999))).clamp(0.15, 0.6);
    double blend(String key, double now) =>
        (old[key] ?? now) * (1 - w) + now * w;
    // Aggression proxy from PFR/VPIP gap + 3-bet (rough but persistent).
    final aggression =
        (stats.pfr / (stats.vpip <= 0 ? 1 : stats.vpip) * 2).clamp(0.2, 4.0);
    final profile = <String, double>{
      'hands': newHands.toDouble(),
      'vpip': blend('vpip', stats.vpip),
      'pfr': blend('pfr', stats.pfr),
      'threeBet': blend('threeBet', stats.threeBetPct),
      'riverFold': blend('riverFold', stats.riverFoldPct),
      'foldVsBet': blend('foldVsBet', stats.riverFoldPct), // best available proxy
      'aggression': blend('aggression', aggression),
    };
    await _repo.saveHumanProfile(profile);
  }

  /// A personalized one-liner the advisor appends, based on your learned
  /// tendencies across sessions. Empty until there's enough history.
  String personalizedTip() {
    final p = _repo.getHumanProfile();
    if ((p['hands'] ?? 0) < 15) return '';
    final riverFold = p['riverFold'] ?? 0;
    final vpip = p['vpip'] ?? 0;
    final threeBet = p['threeBet'] ?? 0;
    if (riverFold > 55) {
      return 'He aprendido que sueles foldear de más en river (${riverFold.toStringAsFixed(0)}%). Hoy, paga algún bluff-catcher más.';
    }
    if (vpip > 33) {
      return 'Tu histórico dice que juegas demasiadas manos (VPIP ${vpip.toStringAsFixed(0)}%). Cierra el rango y elige mejor.';
    }
    if (threeBet < 5 && threeBet > 0) {
      return 'Apenas 3-beteas (${threeBet.toStringAsFixed(0)}%). Añade faroles con Axs para no ser tan predecible.';
    }
    return '';
  }

  String generateCoachReport() {
    return AICoach.generateReport(sessionStats, _handHistory);
  }

  String generateYearReport() {
    return YearCoach.progressReport(_repo.getSessionArchive());
  }

  @override
  void dispose() {
    _engine?.removeListener(_onEngineChanged);
    _engine?.dispose();
    super.dispose();
  }
}
