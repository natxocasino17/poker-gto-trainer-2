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
  static const _coinsKey = 'coins';
  static const _tableConfigKey = 'table_config';
  static const _fourColorDeckKey = 'four_color_deck';
  static const _localeKey = 'app_locale';
  static const _humanProfileKey = 'human_profile';

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

  List<HandLog> getHandLogs() {
    final raw = _prefs.getString(_handLogsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return HandLog.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHandLog(HandLog log) async {
    final logs = getHandLogs()..add(log);
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

  // ── Coins: free in-game currency earned by playing ──
  int getCoins() => _prefs.getInt(_coinsKey) ?? 0;

  Future<void> addCoins(int amount) =>
      _prefs.setInt(_coinsKey, getCoins() + amount);

  String getLocale() => _prefs.getString(_localeKey) ?? 'es';

  Future<void> saveLocale(String code) =>
      _prefs.setString(_localeKey, code);

  bool getFourColorDeck() => _prefs.getBool(_fourColorDeckKey) ?? true;

  Future<void> saveFourColorDeck(bool v) =>
      _prefs.setBool(_fourColorDeckKey, v);

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
}
