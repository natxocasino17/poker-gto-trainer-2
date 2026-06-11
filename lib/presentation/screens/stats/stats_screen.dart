import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/session_stats_model.dart';
import '../../../presentation/providers/game_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final stats = gp.sessionStats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GLOBAL STATS'),
        centerTitle: true,
      ),
      body: stats.handsPlayed == 0
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _OverviewCard(stats: stats),
                const SizedBox(height: 14),
                _KPIGrid(stats: stats),
                const SizedBox(height: 14),
                _DecisionScoreCard(stats: stats),
                const SizedBox(height: 14),
                _CoachReportCard(gp: gp),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, color: AppColors.textMuted, size: 48),
          SizedBox(height: 12),
          Text('No session data yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          SizedBox(height: 6),
          Text('Play hands to generate your performance report', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final SessionStats stats;
  const _OverviewCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final won = stats.netProfit >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceElevated, AppColors.card],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _OverviewStat(
                label: 'Hands Played',
                value: '${stats.handsPlayed}',
                color: AppColors.textPrimary,
                large: true,
              ),
              Column(
                children: [
                  Text(
                    won ? '+\$${stats.netProfit.toStringAsFixed(2)}' : '-\$${(-stats.netProfit).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: won ? AppColors.winning : AppColors.losing,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text('Net Profit', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.5)),
                ],
              ),
              _OverviewStat(
                label: 'BB/100',
                value: '${stats.bbPer100 >= 0 ? "+" : ""}${stats.bbPer100.toStringAsFixed(1)}',
                color: stats.bbPer100 >= 0 ? AppColors.winning : AppColors.losing,
                large: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _ratingColor(stats.decisionScore).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _ratingColor(stats.decisionScore).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.psychology, color: _ratingColor(stats.decisionScore), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Decision Score: ${stats.decisionScore.toStringAsFixed(0)}/100 — ${_ratingLabel(stats.decisionScore)}',
                  style: TextStyle(color: _ratingColor(stats.decisionScore), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _ratingColor(double score) {
    if (score >= 80) return AppColors.winning;
    if (score >= 60) return AppColors.gtoCorrect;
    if (score >= 40) return AppColors.gtoMarginal;
    return AppColors.gtoBlunder;
  }

  String _ratingLabel(double score) {
    if (score >= 85) return 'Elite';
    if (score >= 70) return 'Strong';
    if (score >= 55) return 'Average';
    if (score >= 40) return 'Leaking';
    return 'Needs Work';
  }
}

class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool large;

  const _OverviewStat({required this.label, required this.value, required this.color, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontSize: large ? 22 : 16, fontWeight: FontWeight.w700),
        ),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

class _KPIGrid extends StatelessWidget {
  final SessionStats stats;
  const _KPIGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PERFORMANCE KPIs', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _KPICell(label: 'VPIP', value: '${stats.vpip.toStringAsFixed(1)}%', target: '22–28%', isGood: stats.vpip >= 22 && stats.vpip <= 28),
            _KPICell(label: 'PFR', value: '${stats.pfr.toStringAsFixed(1)}%', target: '18–24%', isGood: stats.pfr >= 18 && stats.pfr <= 24),
            _KPICell(label: '3-Bet%', value: '${stats.threeBetPct.toStringAsFixed(1)}%', target: '8–12%', isGood: stats.threeBetPct >= 8 && stats.threeBetPct <= 12),
            _KPICell(label: 'C-Bet%', value: '${stats.cBetPct.toStringAsFixed(1)}%', target: '55–70%', isGood: stats.cBetPct >= 55 && stats.cBetPct <= 70),
            _KPICell(label: 'WTSD%', value: '${stats.wtsd.toStringAsFixed(1)}%', target: '25–33%', isGood: stats.wtsd >= 25 && stats.wtsd <= 33),
            _KPICell(label: 'WSD%', value: '${stats.wsd.toStringAsFixed(1)}%', target: '>50%', isGood: stats.wsd >= 50),
            _KPICell(label: 'River Fold%', value: '${stats.riverFoldPct.toStringAsFixed(1)}%', target: '<45%', isGood: stats.riverFoldPct <= 45),
            _KPICell(label: 'Avg Pot Won', value: '\$${stats.avgPotWon.toStringAsFixed(0)}', target: '>20', isGood: stats.avgPotWon >= 20),
            _KPICell(label: 'Blunders', value: '${stats.blunders}', target: '0', isGood: stats.blunders == 0),
          ],
        ),
      ],
    );
  }
}

class _KPICell extends StatelessWidget {
  final String label;
  final String value;
  final String target;
  final bool isGood;

  const _KPICell({required this.label, required this.value, required this.target, required this.isGood});

  @override
  Widget build(BuildContext context) {
    final color = isGood ? AppColors.winning : AppColors.gtoMarginal;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text('Target: $target', style: const TextStyle(color: AppColors.textMuted, fontSize: 8)),
        ],
      ),
    );
  }
}

class _DecisionScoreCard extends StatelessWidget {
  final SessionStats stats;
  const _DecisionScoreCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DECISION BREAKDOWN', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DecisionStat(label: 'Optimal', value: '${stats.optimalDecisions}', color: AppColors.gtoOptimal),
              _DecisionStat(label: 'Blunders', value: '${stats.blunders}', color: AppColors.gtoBlunder),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecisionStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DecisionStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _CoachReportCard extends StatefulWidget {
  final GameProvider gp;
  const _CoachReportCard({required this.gp});

  @override
  State<_CoachReportCard> createState() => _CoachReportCardState();
}

class _CoachReportCardState extends State<_CoachReportCard> {
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
          // Header
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
                if (_expanded && _report == null) {
                  _report = widget.gp.generateCoachReport();
                }
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
                  const Icon(Icons.sports, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI COACH REPORT', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        Text('Personalized tactical analysis', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
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
