import '../../data/models/hand_log_model.dart';

/// Builds shareable exports of the hand history. No external packages are
/// available, so the caller copies the returned string to the clipboard.
class HandExporter {
  /// Human-readable plain-text export with EL PUXI's per-street review.
  static String toText(List<HandLog> logs) {
    if (logs.isEmpty) return 'Sin manos en el historial.';
    final b = StringBuffer();
    b.writeln('═══ HISTORIAL DE MANOS · EL PUXI ═══');
    b.writeln('${logs.length} manos\n');
    for (final h in logs) {
      final hole = h.humanHoleCards.map((c) => c.toString()).join(' ');
      final board = h.communityCards.map((c) => c.toString()).join(' ');
      final profit = h.humanProfit >= 0
          ? '+\$${h.humanProfit.toStringAsFixed(0)}'
          : '-\$${h.humanProfit.abs().toStringAsFixed(0)}';
      b.writeln('#${h.handNumber}  $hole   ${board.isEmpty ? '(preflop)' : '[ $board ]'}');
      b.writeln('   ${h.humanHandDescription} · ${h.resultLabel} · $profit');
      for (final s in h.streetAnalyses) {
        b.writeln('   · ${s.street}: ${s.heroAction} '
            '(eq ${(s.heroEquity * 100).toStringAsFixed(0)}%, ${s.quality.name})');
      }
      b.writeln();
    }
    return b.toString().trimRight();
  }

  /// Raw JSON export (re-importable / backup), reusing the model codec.
  static String toJson(List<HandLog> logs) => HandLog.encodeList(logs);
}
