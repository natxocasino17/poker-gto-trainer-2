import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/hand_log_model.dart';
import '../../../presentation/providers/game_provider.dart';
import 'widgets/hand_detail_screen.dart';

class AnalyzeScreen extends StatelessWidget {
  const AnalyzeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final hands = List<HandLog>.from(gp.handHistory).reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ANALIZAR JUGADAS'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${hands.length} manos',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: hands.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: hands.length,
              itemBuilder: (ctx, i) => _HandCard(
                log: hands[i],
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => HandDetailScreen(log: hands[i])),
                ),
              ),
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
          Icon(Icons.history_edu, color: AppColors.textMuted, size: 48),
          SizedBox(height: 12),
          Text('Aún no hay manos jugadas', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          SizedBox(height: 6),
          Text('Juega manos y ZerosPoker te las destripará aquí', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _HandCard extends StatelessWidget {
  final HandLog log;
  final VoidCallback onTap;

  const _HandCard({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final won = log.humanProfit > 0;
    final cleanFold = log.isCleanFold && !won;

    final qualityCounts = <DecisionQuality, int>{};
    for (final sa in log.streetAnalyses) {
      qualityCounts[sa.quality] = (qualityCounts[sa.quality] ?? 0) + 1;
    }
    final hasBlunder = (qualityCounts[DecisionQuality.blunder] ?? 0) > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasBlunder ? AppColors.gtoBlunder.withOpacity(0.4) : AppColors.border,
            width: hasBlunder ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Hand number
            Column(
              children: [
                Text(
                  '#${log.handNumber}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: won
                        ? AppColors.winning.withOpacity(0.15)
                        : cleanFold
                            ? AppColors.neutral.withOpacity(0.15)
                            : AppColors.losing.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: won
                          ? AppColors.winning
                          : cleanFold
                              ? AppColors.neutral
                              : AppColors.losing,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      won ? 'W' : (cleanFold ? 'F' : 'L'),
                      style: TextStyle(
                        color: won
                            ? AppColors.winning
                            : cleanFold
                                ? AppColors.neutral
                                : AppColors.losing,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Cards
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final c in log.humanHoleCards)
                      Container(
                        margin: const EdgeInsets.only(right: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.cardFace,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c.toString(),
                          style: TextStyle(
                            color: c.isRed ? AppColors.redSuit : AppColors.blackSuit,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  log.humanHandDescription,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                ),
                Text(
                  'vs ${log.botNames.take(3).join(", ")}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                ),
              ],
            ),
            const Spacer(),
            // Profit + quality
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  cleanFold ? 'Fold limpio' : log.resultLabel,
                  style: TextStyle(
                    color: won
                        ? AppColors.winning
                        : cleanFold
                            ? AppColors.neutral
                            : AppColors.losing,
                    fontSize: cleanFold ? 12 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((qualityCounts[DecisionQuality.optimal] ?? 0) > 0)
                      _QualityDot(color: AppColors.gtoOptimal, count: qualityCounts[DecisionQuality.optimal]!),
                    if ((qualityCounts[DecisionQuality.correct] ?? 0) > 0)
                      _QualityDot(color: AppColors.gtoCorrect, count: qualityCounts[DecisionQuality.correct]!),
                    if ((qualityCounts[DecisionQuality.marginal] ?? 0) > 0)
                      _QualityDot(color: AppColors.gtoMarginal, count: qualityCounts[DecisionQuality.marginal]!),
                    if ((qualityCounts[DecisionQuality.blunder] ?? 0) > 0)
                      _QualityDot(color: AppColors.gtoBlunder, count: qualityCounts[DecisionQuality.blunder]!),
                  ],
                ),
                const SizedBox(height: 2),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Revisar', style: TextStyle(color: AppColors.accent, fontSize: 10)),
                    Icon(Icons.chevron_right, color: AppColors.accent, size: 14),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityDot extends StatelessWidget {
  final Color color;
  final int count;
  const _QualityDot({required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
