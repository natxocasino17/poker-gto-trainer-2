import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'info_set.dart';
import 'spot_solver.dart';

/// Persists solved CFR node maps to [SharedPreferences] so strategies survive
/// app restarts and resume from where the previous solve stopped.
///
/// Storage format: each "spot key" maps to a JSON string containing the
/// serialised node map for that spot. Spot keys are stable across sessions
/// (they encode the config fingerprint so config changes invalidate old data).
class CfrPersistence {
  static const String _prefix = 'cfr_nodes_';
  static const String _metaKey = 'cfr_meta';

  // ─── Save ─────────────────────────────────────────────────────────────────

  /// Serialises the solver's nodes and writes them under [spotKey].
  static Future<void> saveNodes(
    String spotKey,
    Map<String, InformationSet> nodes,
  ) async {
    if (nodes.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final json = <String, dynamic>{};
    for (final e in nodes.entries) {
      json[e.key] = e.value.toJson();
    }
    await prefs.setString(_prefix + spotKey, jsonEncode(json));
    await _updateMeta(prefs, spotKey, nodes.length);
  }

  /// Convenience: saves directly from a [SpotSolver] instance.
  static Future<void> saveSolver(String spotKey, SpotSolver solver) async {
    await saveNodes(spotKey, solver.nodes);
  }

  // ─── Load ─────────────────────────────────────────────────────────────────

  /// Loads nodes for [spotKey] and merges them into [solver] for warm-starting.
  /// Returns the number of nodes loaded, or 0 if nothing was stored.
  static Future<int> loadIntoSolver(String spotKey, SpotSolver solver) async {
    final raw = await loadRaw(spotKey);
    if (raw == null) return 0;
    solver.loadNodes(raw);
    return raw.length;
  }

  /// Returns the raw JSON node map for [spotKey], or null if not stored.
  static Future<Map<String, Map<String, dynamic>>?> loadRaw(String spotKey) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_prefix + spotKey);
    if (encoded == null) return null;

    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    return decoded.map(
      (k, v) => MapEntry(k, (v as Map<String, dynamic>)),
    );
  }

  // ─── Management ───────────────────────────────────────────────────────────

  /// Returns metadata for all stored spots: {spotKey → nodeCount}.
  static Future<Map<String, int>> listSpots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  /// Deletes a stored spot's nodes from persistent storage.
  static Future<void> deleteSpot(String spotKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + spotKey);
    final meta = await listSpots();
    meta.remove(spotKey);
    await prefs.setString(_metaKey, jsonEncode(meta));
  }

  /// Clears ALL stored CFR data. Use with caution.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final spots = await listSpots();
    for (final key in spots.keys) {
      await prefs.remove(_prefix + key);
    }
    await prefs.remove(_metaKey);
  }

  /// Estimated storage usage in kilobytes (approximate).
  static Future<int> estimatedKB() async {
    final prefs = await SharedPreferences.getInstance();
    final spots = await listSpots();
    int total = 0;
    for (final key in spots.keys) {
      final s = prefs.getString(_prefix + key) ?? '';
      total += s.length;
    }
    return total ~/ 1024;
  }

  // ─── Spot key helpers ─────────────────────────────────────────────────────

  /// Generates a stable spot key from solve parameters.
  static String spotKey({
    required String gameType,   // e.g. "hu_preflop", "hu_flop"
    required String configTag,  // e.g. "standard", "fast"
    bool fullTree = false,
  }) {
    return '${gameType}_${configTag}_${fullTree ? 'full' : 'spot'}';
  }

  /// Standard key for the 100BB HU preflop tree.
  static const String huPreflopKey = 'hu_preflop_standard_spot';

  /// Standard key for postflop spots.
  static const String huPostflopKey = 'hu_postflop_standard_spot';

  // ─── Private ──────────────────────────────────────────────────────────────

  static Future<void> _updateMeta(
    SharedPreferences prefs,
    String spotKey,
    int nodeCount,
  ) async {
    final meta = await listSpots();
    meta[spotKey] = nodeCount;
    await prefs.setString(_metaKey, jsonEncode(meta));
  }
}
