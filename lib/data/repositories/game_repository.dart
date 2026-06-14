import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hand_log_model.dart';
import '../models/session_stats_model.dart';

class GameRepository {
  static const _bankrollKey = 'bankroll';
  static const _tableStackKey = 'table_stack';
  static const _handLogsKey = 'hand_logs';
  static const _handCountKey = 'hand_count';
  static const _sessionIdKey = 'session_id';
  static const _sessionStartKey = 'session_start';

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

  Future<void> addBankroll(double amount) async {
    await saveBankroll(getBankroll() + amount);
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

  SessionStats computeStats() {
    final logs = getHandLogs();
    return SessionStats.fromHandLogs(logs, getSessionId(), getSessionStart());
  }
}
