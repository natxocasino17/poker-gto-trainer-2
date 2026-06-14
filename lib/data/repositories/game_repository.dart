import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hand_log_model.dart';
import '../models/session_stats_model.dart';
import '../models/session_summary_model.dart';

class GameRepository {
  static const _bankrollKey = 'bankroll';
  static const _tableStackKey = 'table_stack';
  static const _handLogsKey = 'hand_logs';
  static const _handCountKey = 'hand_count';
  static const _sessionIdKey = 'session_id';
  static const _sessionStartKey = 'session_start';
  static const _displayInBBKey = 'display_in_bb';
  static const _sessionArchiveKey = 'session_archive';
  static const _tableConfigKey = 'table_config';
  static const _localeKey = 'app_locale';
  static const _humanProfileKey = 'human_profile';
  // ── User settings keys ──
  static const _difficultyKey = 'opt_difficulty';
  static const _autoRebuyKey = 'opt_auto_rebuy';
  static const _rebuyAmountKey = 'opt_rebuy_amount';
  static const _smallBlindKey = 'opt_small_blind';
  static const _bigBlindKey = 'opt_big_blind';
  static const _startingStackKey = 'opt_starting_stack';
  static const _tutorialSeenKey = 'opt_tutorial_seen';
  static const _trainerModeKey = 'opt_trainer_mode';

  static const double initialBankroll = 1000.0;
  static const double defaultBuyIn = 200.0;

  final SharedPreferences _prefs;

  GameRepository._(this._prefs);

  static Future<GameRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return GameRepository._(prefs);
  }

  double getBankroll() => _prefs.getDouble(_bankrollKey) ?? initialBankroll;

  Future<void> saveBankroll(double amount) =>
      _prefs.setDouble(_bankrollKey, amount);

  bool getDisplayInBB() => _prefs.getBool(_displayInBBKey) ?? false;

  Future<void> saveDisplayInBB(bool value) =>
      _prefs.setBool(_displayInBBKey, value);

  double getTableStack() => _prefs.getDouble(_tableStackKey) ?? defaultBuyIn;

  Future<void> saveTableStack(double amount) =>
      _prefs.setDouble(_tableStackKey, amount);

  int getHandCount() => _prefs.getInt(_handCountKey) ?? 0;

  Future<void> incrementHandCount() =>
      _prefs.setInt(_handCountKey, getHandCount() + 1);

  String getSessionId() {
    final id = _prefs.getString(_sessionIdKey);
    if (id == null) {
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      _prefs.setString(_sessionIdKey, newId);
      return newId;
    }
    return id;
  }

  DateTime getSessionStart() {
    final ms = _prefs.getInt(_sessionStartKey);
    if (ms == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _prefs.setInt(_sessionStartKey, now);
      return DateTime.fromMillisecondsSinceEpoch(now);
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // In-memory mirror of the persisted hand list so we don't re-decode the
  // whole JSON blob on every read/append (was O(n²) over a session).
  List<HandLog>? _logsCache;

  List<HandLog> getHandLogs() {
    if (_logsCache != null) return _logsCache!;
    final raw = _prefs.getString(_handLogsKey);
    if (raw == null || raw.isEmpty) return _logsCache = [];
    try {
      return _logsCache = HandLog.decodeList(raw);
    } catch (_) {
      return _logsCache = [];
    }
  }

  Future<void> saveHandLog(HandLog log) async {
    final logs = getHandLogs()..add(log);
    _logsCache = logs;
    await _prefs.setString(_handLogsKey, HandLog.encodeList(logs));
    await incrementHandCount();
  }

  Future<void> applyHandResult({
    required double humanProfit,
    required double newTableStack,
  }) async {
    final bankroll = getBankroll() + humanProfit;
    await saveBankroll(bankroll);
    await saveTableStack(newTableStack);
  }

  Future<void> rebuy(double amount) async {
    final bankroll = getBankroll();
    if (amount > bankroll) return;
    await saveBankroll(bankroll - amount);
    await saveTableStack(amount);
  }

  Future<void> resetSession() async {
    _logsCache = null;
    await _prefs.remove(_handLogsKey);
    await _prefs.remove(_handCountKey);
    await _prefs.remove(_sessionIdKey);
    await _prefs.remove(_sessionStartKey);
  }

  // ── Yearly archive ──
  List<SessionSummary> getSessionArchive() {
    final raw = _prefs.getString(_sessionArchiveKey);
    if (raw == null || raw.isEmpty) return [];
    return SessionSummary.decodeList(raw);
  }

  Future<void> archiveSession(SessionSummary summary) async {
    final archive = getSessionArchive()..add(summary);
    await _prefs.setString(
        _sessionArchiveKey, SessionSummary.encodeList(archive));
  }

  String getLocale() => _prefs.getString(_localeKey) ?? 'es';

  Future<void> saveLocale(String code) =>
      _prefs.setString(_localeKey, code);

  /// Cross-session model of how the human plays (EMA-blended). The bots
  /// seed their reads from this so they exploit you from hand 1, and the
  /// advisor personalizes its tips. Keys: hands, vpip, riverFold, pfr,
  /// threeBet, foldVsBet, aggression.
  Map<String, double> getHumanProfile() {
    final raw = _prefs.getString(_humanProfileKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveHumanProfile(Map<String, double> p) =>
      _prefs.setString(_humanProfileKey, jsonEncode(p));

  // ── Table editor config: 5 opponent slots; '' = random ──
  List<String?> getTableConfig() {
    final raw = _prefs.getStringList(_tableConfigKey);
    if (raw == null) return List<String?>.filled(5, null);
    return raw.map((e) => e.isEmpty ? null : e).toList()
      ..length = 5;
  }

  Future<void> saveTableConfig(List<String?> slots) => _prefs.setStringList(
      _tableConfigKey, slots.take(5).map((e) => e ?? '').toList());

  SessionStats computeStats() {
    final logs = getHandLogs();
    return SessionStats.fromHandLogs(logs, getSessionId(), getSessionStart());
  }

  // ── User settings ────────────────────────────────────────────────────────
  /// 0 = easy, 1 = medium, 2 = hard.
  int getDifficulty() => _prefs.getInt(_difficultyKey) ?? 1;
  Future<void> saveDifficulty(int d) =>
      _prefs.setInt(_difficultyKey, d.clamp(0, 2));

  bool getAutoRebuy() => _prefs.getBool(_autoRebuyKey) ?? true;
  Future<void> saveAutoRebuy(bool v) => _prefs.setBool(_autoRebuyKey, v);

  double getRebuyAmount() => _prefs.getDouble(_rebuyAmountKey) ?? defaultBuyIn;
  Future<void> saveRebuyAmount(double v) =>
      _prefs.setDouble(_rebuyAmountKey, v.clamp(20.0, 100000.0));

  double getSmallBlind() => _prefs.getDouble(_smallBlindKey) ?? 1.0;
  Future<void> saveSmallBlind(double v) =>
      _prefs.setDouble(_smallBlindKey, v.clamp(0.5, 50000.0));

  double getBigBlind() => _prefs.getDouble(_bigBlindKey) ?? 2.0;
  Future<void> saveBigBlind(double v) =>
      _prefs.setDouble(_bigBlindKey, v.clamp(1.0, 100000.0));

  double getStartingStack() =>
      _prefs.getDouble(_startingStackKey) ?? defaultBuyIn;
  Future<void> saveStartingStack(double v) =>
      _prefs.setDouble(_startingStackKey, v.clamp(20.0, 1000000.0));

  bool getTutorialSeen() => _prefs.getBool(_tutorialSeenKey) ?? false;
  Future<void> saveTutorialSeen(bool v) =>
      _prefs.setBool(_tutorialSeenKey, v);

  bool getTrainerMode() => _prefs.getBool(_trainerModeKey) ?? false;
  Future<void> saveTrainerMode(bool v) => _prefs.setBool(_trainerModeKey, v);

  // ── Daily streak + achievements ───────────────────────────────────────────
  static const _streakCountKey = 'streak_count';
  static const _streakLastKey = 'streak_last';
  static const _achievementsKey = 'achievements_unlocked';

  static String _dayStamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int getStreakCount() => _prefs.getInt(_streakCountKey) ?? 0;

  /// Registers activity for today and returns the resulting day-streak:
  /// +1 if the last active day was yesterday, reset to 1 if there was a gap,
  /// unchanged if already counted today.
  Future<int> touchStreak() async {
    final today = _dayStamp(DateTime.now());
    final last = _prefs.getString(_streakLastKey);
    if (last == today) return getStreakCount();
    final yesterday = _dayStamp(DateTime.now().subtract(const Duration(days: 1)));
    final count = (last == yesterday) ? getStreakCount() + 1 : 1;
    await _prefs.setInt(_streakCountKey, count);
    await _prefs.setString(_streakLastKey, today);
    return count;
  }

  Set<String> getAchievements() =>
      (_prefs.getStringList(_achievementsKey) ?? const []).toSet();

  Future<void> saveAchievements(Set<String> ids) =>
      _prefs.setStringList(_achievementsKey, ids.toList());
}
