import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/progress_service.dart';
import '../../providers/game_provider.dart';

/// Objetivos diarios, racha y logros.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final goals = gp.dailyGoals();
    final unlocked = gp.achievements();
    final streak = gp.streakCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Progreso',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Streak ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.goldDark, AppColors.gold],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$streak ${streak == 1 ? 'día' : 'días'} de racha',
                        style: const TextStyle(
                            color: Color(0xFF2A1A10),
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    const Text('Vuelve mañana para no perderla',
                        style: TextStyle(color: Color(0xFF4A3416), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Daily goals ──
          const Text('OBJETIVOS DE HOY',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          for (final g in goals) _goalTile(g),

          const SizedBox(height: 24),
          // ── Achievements ──
          Text('LOGROS  (${unlocked.length}/${ProgressService.all.length})',
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              for (final a in ProgressService.all)
                _badge(a, unlocked.contains(a.id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalTile(DailyGoal g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: g.done ? AppColors.accent : AppColors.border,
            width: g.done ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(g.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(g.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              if (g.done)
                const Icon(Icons.check_circle, color: AppColors.accent, size: 18)
              else if (g.target > 1)
                Text('${g.current}/${g.target}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: g.progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(
                  g.done ? AppColors.accent : AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(Achievement a, bool unlocked) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.surfaceElevated : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: unlocked ? AppColors.gold : AppColors.border,
            width: unlocked ? 1.3 : 1),
      ),
      child: Opacity(
        opacity: unlocked ? 1 : 0.4,
        child: Row(
          children: [
            Text(unlocked ? a.emoji : '🔒', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                  Text(a.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
