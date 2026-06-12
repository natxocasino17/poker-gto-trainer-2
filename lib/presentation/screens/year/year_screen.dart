import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/session_summary_model.dart';
import '../../providers/game_provider.dart';
import '../../widgets/zeros_avatar.dart';
import '../../../core/i18n/i18n.dart';

/// Yearly progress hub: every closed session is archived here, with a
/// results table and el Puxi's long-term evolution report.
class YearScreen extends StatelessWidget {
  const YearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final sessions = gp.sessionArchive.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(I18n.t('year_title')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _CoinsCard(coins: gp.coins),
          const SizedBox(height: 14),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  const Icon(Icons.timeline, color: AppColors.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text(I18n.t('no_archive1'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    I18n.t('no_archive2'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            )
          else ...[
            _TotalsCard(sessions: sessions),
            const SizedBox(height: 14),
            _ProgressCoachCard(gp: gp),
            const SizedBox(height: 14),
            Text(I18n.t('history_hdr'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            _SessionsTable(sessions: sessions, gp: gp),
          ],
        ],
      ),
    );
  }
}

/// Free in-game currency earned by playing. No real money involved.
class _CoinsCard extends StatelessWidget {
  final int coins;
  const _CoinsCard({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gold.withOpacity(0.15), AppColors.card],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.t('coins_amount', {'n': '$coins'}),
                  style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  I18n.t('coins_free'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final List<SessionSummary> sessions;
  const _TotalsCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final hands = sessions.fold<int>(0, (a, s) => a + s.hands);
    final profit = sessions.fold<double>(0, (a, s) => a + s.netProfit);
    final bb100 = hands > 0 ? (profit / 2.0) / hands * 100 : 0.0;
    final blunders = sessions.fold<int>(0, (a, s) => a + s.blunders);
    final won = profit >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(I18n.t('sessions_lbl'), '${sessions.length}', AppColors.textPrimary),
          _stat(I18n.t('hands_lbl'), '$hands', AppColors.textPrimary),
          _stat(I18n.t('net_lbl'), '${won ? "+" : "-"}\$${profit.abs().toStringAsFixed(0)}',
              won ? AppColors.winning : AppColors.losing),
          _stat('BB/100', '${bb100 >= 0 ? "+" : ""}${bb100.toStringAsFixed(1)}',
              bb100 >= 0 ? AppColors.winning : AppColors.losing),
          _stat(I18n.t('blunders_pl'), '$blunders',
              blunders == 0 ? AppColors.winning : AppColors.gtoMarginal),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
      ],
    );
  }
}

class _SessionsTable extends StatelessWidget {
  final List<SessionSummary> sessions;
  final GameProvider gp;
  const _SessionsTable({required this.sessions, required this.gp});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(I18n.t('date_lbl'), style: _h)),
                Expanded(flex: 2, child: Text(I18n.t('hands_lbl'), style: _h, textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text(I18n.t('net_lbl'), style: _h, textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text('BB/100', style: _h, textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(I18n.t('note_lbl'), style: _h, textAlign: TextAlign.right)),
              ],
            ),
          ),
          for (final s in sessions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${s.closedAt.day.toString().padLeft(2, "0")}/${s.closedAt.month.toString().padLeft(2, "0")}/${s.closedAt.year % 100}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${s.hands}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${s.netProfit >= 0 ? "+" : "-"}\$${s.netProfit.abs().toStringAsFixed(0)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: s.netProfit >= 0 ? AppColors.winning : AppColors.losing,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${s.bbPer100 >= 0 ? "+" : ""}${s.bbPer100.toStringAsFixed(1)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: s.bbPer100 >= 0 ? AppColors.winning : AppColors.losing,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      s.decisionScore.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: s.decisionScore >= 70
                            ? AppColors.winning
                            : s.decisionScore >= 50
                                ? AppColors.gtoMarginal
                                : AppColors.losing,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _h = TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.5);
}

class _ProgressCoachCard extends StatefulWidget {
  final GameProvider gp;
  const _ProgressCoachCard({required this.gp});

  @override
  State<_ProgressCoachCard> createState() => _ProgressCoachCardState();
}

class _ProgressCoachCardState extends State<_ProgressCoachCard> {
  bool _expanded = false;
  String? _report;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
                if (_expanded) _report = widget.gp.generateYearReport();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentGlow,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: _expanded ? Radius.zero : const Radius.circular(14),
                  bottomRight: _expanded ? Radius.zero : const Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const ZerosAvatar(size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(I18n.t('evolution_hdr'),
                            style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        Text(I18n.t('evolution_sub'),
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.accent),
                ],
              ),
            ),
          ),
          if (_expanded && _report != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _report!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.7,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
