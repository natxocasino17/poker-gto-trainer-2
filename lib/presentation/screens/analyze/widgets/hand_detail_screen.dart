import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/hand_log_model.dart';

class HandDetailScreen extends StatelessWidget {
  final HandLog log;
  const HandDetailScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Hand #${log.handNumber}'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ResultBanner(log: log),
          const SizedBox(height: 16),
          _BoardSection(log: log),
          const SizedBox(height: 16),
          _AIAssistantHeader(),
          const SizedBox(height: 10),
          for (final sa in log.streetAnalyses)
            _StreetAnalysisCard(sa: sa),
          const SizedBox(height: 16),
          _AllHandsReveal(log: log),
          const SizedBox(height: 16),
          _ActionTimeline(log: log),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final HandLog log;
  const _ResultBanner({required this.log});

  @override
  Widget build(BuildContext context) {
    final won = log.humanProfit > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: won
              ? [AppColors.winning.withOpacity(0.2), AppColors.winning.withOpacity(0.05)]
              : [AppColors.losing.withOpacity(0.2), AppColors.losing.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: won ? AppColors.winning : AppColors.losing, width: 1),
      ),
      child: Row(
        children: [
          Icon(won ? Icons.emoji_events : Icons.trending_down,
              color: won ? AppColors.winning : AppColors.losing, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                won ? 'You Won This Hand' : 'You Lost This Hand',
                style: TextStyle(
                  color: won ? AppColors.winning : AppColors.losing,
                  fontSize: 16, fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                log.resultLabel,
                style: TextStyle(
                  color: won ? AppColors.winning : AppColors.losing,
                  fontSize: 22, fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Winner: ${log.winnerName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              Text('Pot: \$${log.finalPot.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              Text(log.humanHandDescription, style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoardSection extends StatelessWidget {
  final HandLog log;
  const _BoardSection({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR HAND', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final c in log.humanHoleCards)
                _CardChip(card: c),
              const SizedBox(width: 12),
              const Text('→', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(width: 12),
              for (final c in log.communityCards)
                _CardChip(card: c, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  final dynamic card;
  final bool small;
  const _CardChip({required this.card, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = card;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 6, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: AppColors.cardFace,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        c.toString(),
        style: TextStyle(
          color: c.isRed ? AppColors.redSuit : AppColors.blackSuit,
          fontWeight: FontWeight.w800,
          fontSize: small ? 11 : 14,
        ),
      ),
    );
  }
}

class _AIAssistantHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentGlow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.smart_toy, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI EQUITY ASSISTANT', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            Text('Street-by-street analysis of your decisions', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _StreetAnalysisCard extends StatelessWidget {
  final StreetAnalysis sa;
  const _StreetAnalysisCard({required this.sa});

  @override
  Widget build(BuildContext context) {
    final qColor = _qualityColor(sa.quality);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qColor.withOpacity(0.4), width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: qColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  sa.street.toUpperCase(),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: qColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: qColor),
                  ),
                  child: Text(
                    sa.qualityLabel.toUpperCase(),
                    style: TextStyle(color: qColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MetricPill(label: 'Equity', value: '${(sa.heroEquity * 100).toStringAsFixed(1)}%', color: _equityColor(sa.heroEquity)),
                    const SizedBox(width: 8),
                    if (sa.potOdds > 0)
                      _MetricPill(label: 'Pot Odds', value: '${(sa.potOdds * 100).toStringAsFixed(1)}%', color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    _MetricPill(label: 'Action', value: sa.heroAction, color: AppColors.textPrimary),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.smart_toy, color: AppColors.accent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sa.explanation,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _qualityColor(DecisionQuality q) {
    switch (q) {
      case DecisionQuality.optimal: return AppColors.gtoOptimal;
      case DecisionQuality.correct: return AppColors.gtoCorrect;
      case DecisionQuality.marginal: return AppColors.gtoMarginal;
      case DecisionQuality.blunder: return AppColors.gtoBlunder;
    }
  }

  Color _equityColor(double eq) {
    if (eq > 0.65) return AppColors.winning;
    if (eq > 0.40) return AppColors.gold;
    return AppColors.losing;
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AllHandsReveal extends StatelessWidget {
  final HandLog log;
  const _AllHandsReveal({required this.log});

  @override
  Widget build(BuildContext context) {
    if (log.allHoleCards.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ALL HANDS (SHOWDOWN)', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...log.allHoleCards.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    e.key == 'human' ? 'You' : e.key,
                    style: TextStyle(
                      color: e.key == 'human' ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...e.value.map((c) => _CardChip(card: c)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _ActionTimeline extends StatelessWidget {
  final HandLog log;
  const _ActionTimeline({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACTION TIMELINE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 10),
          ..._buildStreetWidgets(),
        ],
      ),
    );
  }

  List<Widget> _buildStreetWidgets() {
    const streets = ['preflop', 'flop', 'turn', 'river'];
    final widgets = <Widget>[];
    for (final street in streets) {
      final acts = log.actions.where((a) => a.street == street).toList();
      if (acts.isEmpty) continue;
      widgets.add(Text(street.toUpperCase(),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)));
      widgets.add(const SizedBox(height: 4));
      for (final a in acts) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 3),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: _actionColor(a.type), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${a.playerName}: ${a.label}',
                style: TextStyle(
                    color: a.playerId == 'human' ? AppColors.accent : AppColors.textSecondary,
                    fontSize: 11)),
          ]),
        ));
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Color _actionColor(ActionType t) {
    switch (t) {
      case ActionType.fold: return AppColors.actionFold;
      case ActionType.check: return AppColors.actionCheck;
      case ActionType.call: return AppColors.actionCall;
      case ActionType.bet:
      case ActionType.raise:
      case ActionType.allIn: return AppColors.actionRaise;
    }
  }
}
