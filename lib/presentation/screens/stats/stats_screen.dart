import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/session_stats_model.dart';
import '../../../presentation/providers/game_provider.dart';
import '../../widgets/zeros_avatar.dart';
import '../../widgets/app_background.dart';
import '../../../core/i18n/i18n.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final stats = gp.sessionStats;

    return AppBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(I18n.t('stats_title')),
        centerTitle: true,
      ),
      body: stats.handsPlayed == 0
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _OverviewCard(stats: stats, gp: gp),
                const SizedBox(height: 14),
                _KPIGrid(stats: stats),
                const SizedBox(height: 14),
                _DecisionScoreCard(stats: stats),
                const SizedBox(height: 14),
                _CoachReportCard(gp: gp),
              ],
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(I18n.t('no_data1'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 6),
          Text(I18n.t('no_data2'), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final SessionStats stats;
  final GameProvider gp;
  const _OverviewCard({required this.stats, required this.gp});

  @override
  Widget build(BuildContext context) {
    final won = stats.netProfit >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
                label: I18n.t('hands_played'),
                value: '${stats.handsPlayed}',
                color: AppColors.textPrimary,
              ),
              Column(
                children: [
                  Text(
                    '${won ? "+" : "-"}${gp.money(stats.netProfit.abs())}',
                    style: TextStyle(
                      color: won ? AppColors.winning : AppColors.losing,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(I18n.t('net_result'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.5)),
                ],
              ),
              _OverviewStat(
                label: 'BB/100',
                value: '${stats.bbPer100 >= 0 ? "+" : ""}${stats.bbPer100.toStringAsFixed(1)}',
                color: stats.bbPer100 >= 0 ? AppColors.winning : AppColors.losing,
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
                  I18n.t('decision_note', {'s': stats.decisionScore.toStringAsFixed(0), 'r': _ratingLabel(stats.decisionScore)}),
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
    if (score >= 85) return I18n.t('rating_elite');
    if (score >= 70) return I18n.t('rating_solid');
    if (score >= 55) return I18n.t('rating_avg');
    if (score >= 40) return I18n.t('rating_leaky');
    return I18n.t('rating_bad');
  }
}

class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _OverviewStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

/// Per-KPI knowledge base: what it means, what's wrong, how to fix it.
/// Tapping a cell opens el Puxi's explanation.
class _KpiInfo {
  final String label;
  final String meaning;
  final String target;
  final String howToImprove;

  const _KpiInfo({
    required this.label,
    required this.meaning,
    required this.target,
    required this.howToImprove,
  });
}

const Map<String, _KpiInfo> _kpiKnowledge = {
  'VPIP': _KpiInfo(
    label: 'VPIP — Voluntarily Put In Pot',
    meaning: 'Porcentaje de manos en las que metes dinero voluntariamente preflop (call o raise, las ciegas obligatorias no cuentan). Mide lo selectivo que eres con tus manos iniciales.',
    target: '22–28% en 6-Max',
    howToImprove: 'Si está alto: deja de jugar basura tipo J4o "porque te aburres". Si está bajo: añade aperturas en CO/BTN con conectores suited y Ax suited. La posición manda: juega más manos cuanto más cerca del botón.',
  ),
  'PFR': _KpiInfo(
    label: 'PFR — Preflop Raise',
    meaning: 'Porcentaje de manos que juegas SUBIENDO preflop. Junto al VPIP define tu perfil: si pagas mucho y subes poco, eres presa fácil.',
    target: '18–24% (cerca de tu VPIP)',
    howToImprove: 'La regla de oro: si una mano merece ser jugada, casi siempre merece ser subida. Reduce los limps y cold-calls. Entra al bote con agresión o no entres.',
  ),
  '3-Bet%': _KpiInfo(
    label: '3-Bet% — Frecuencia de resubida',
    meaning: 'Con qué frecuencia resubes contra una apertura rival. Un 3-bet equilibrado mezcla manos de valor (QQ+, AK) con faroles con bloqueadores (A5s).',
    target: '8–12%',
    howToImprove: 'Si está bajo: añade 3-bets de farol con Axs (el as bloquea AA/AK del rival). Si está alto: recorta los faroles, que te están pillando. Defiende tus ciegas con 3-bets polarizados vs aperturas del BTN.',
  ),
  'C-Bet%': _KpiInfo(
    label: 'C-Bet% — Apuesta de continuación',
    meaning: 'Cuando subes preflop y llega el flop, ¿apuestas de nuevo? Esa es la c-bet. Mantiene la iniciativa y gana muchos botes sin pelea.',
    target: '55–70%',
    howToImprove: 'Apuesta más en boards secos que favorecen tu rango (A72 rainbow) con tamaño pequeño (33%). Frena en boards húmedos y conectados (987 con color) donde el rival conecta más. No dispares por inercia.',
  ),
  'WTSD%': _KpiInfo(
    label: 'WTSD — Went To Showdown',
    meaning: 'Porcentaje de manos jugadas que llegan al showdown. Alto = pagas demasiado para "ver". Bajo = te rinden con facilidad.',
    target: '25–33%',
    howToImprove: 'Si está alto: suelta los segundos pares ante agresión sostenida en river. Si está bajo: defiende más bluff-catchers contra rivales agresivos, que te están faroleando vivo.',
  ),
  'WSD%': _KpiInfo(
    label: 'WSD — Won at Showdown',
    meaning: 'De las veces que llegas al showdown, cuántas ganas. Mide si llegas al final con las manos correctas.',
    target: '>50%',
    howToImprove: 'Si está bajo del 50%, llegas al river con manos perdedoras: estás pagando de más en turn y river. Sé más exigente con qué manos ves las dos últimas calles.',
  ),
  'Fold River%': _KpiInfo(
    label: 'Fold en River',
    meaning: 'Con qué frecuencia foldeas en el river ante una apuesta. Los bots explotadores (Ivey, Dwan) monitorizan esto: si foldeas mucho, te disparan faroles sin parar.',
    target: '<45%',
    howToImprove: 'Calcula las pot odds antes de foldear: ante apuesta de medio bote solo necesitas ganar el 25% de las veces. Paga al menos un bluff-catcher decente por sesión para mantenerlos honestos.',
  ),
  'Bote medio': _KpiInfo(
    label: 'Bote medio ganado',
    meaning: 'Tamaño medio de los botes que ganas. Si solo ganas botes enanos, extraes poco valor con tus manos grandes.',
    target: '>\$20',
    howToImprove: 'Construye botes con tus manos fuertes desde el flop: apuesta 66-75% en boards húmedos en vez de hacer slowplay eterno. El dinero que no apuestas con la mejor mano es dinero perdido.',
  ),
  'Errores graves': _KpiInfo(
    label: 'Errores graves (Blunders)',
    meaning: 'Decisiones con pérdida masiva de EV detectadas por el Puxi: calls sin odds, faroles imposibles, folds con la mano ganadora. Cada uno es dinero quemado.',
    target: '0',
    howToImprove: 'Entra en ANALIZAR y revisa cada blunder marcado en rojo. Identifica el patrón: ¿pagas de más en turn? ¿faroleas sin bloqueadores? El primer paso para no repetirlo es saber por qué pasó.',
  ),
};

class _KPIGrid extends StatelessWidget {
  final SessionStats stats;
  const _KPIGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(I18n.t('kpi_title'), style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(I18n.t('kpi_hint'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _KPICell(kpiKey: 'VPIP', value: '${stats.vpip.toStringAsFixed(1)}%', target: '22–28%', isGood: stats.vpip >= 22 && stats.vpip <= 28),
            _KPICell(kpiKey: 'PFR', value: '${stats.pfr.toStringAsFixed(1)}%', target: '18–24%', isGood: stats.pfr >= 18 && stats.pfr <= 24),
            _KPICell(kpiKey: '3-Bet%', value: '${stats.threeBetPct.toStringAsFixed(1)}%', target: '8–12%', isGood: stats.threeBetPct >= 8 && stats.threeBetPct <= 12),
            _KPICell(kpiKey: 'C-Bet%', value: '${stats.cBetPct.toStringAsFixed(1)}%', target: '55–70%', isGood: stats.cBetPct >= 55 && stats.cBetPct <= 70),
            _KPICell(kpiKey: 'WTSD%', value: '${stats.wtsd.toStringAsFixed(1)}%', target: '25–33%', isGood: stats.wtsd >= 25 && stats.wtsd <= 33),
            _KPICell(kpiKey: 'WSD%', value: '${stats.wsd.toStringAsFixed(1)}%', target: '>50%', isGood: stats.wsd >= 50),
            _KPICell(kpiKey: 'Fold River%', value: '${stats.riverFoldPct.toStringAsFixed(1)}%', target: '<45%', isGood: stats.riverFoldPct <= 45),
            _KPICell(kpiKey: 'Bote medio', value: '\$${stats.avgPotWon.toStringAsFixed(0)}', target: '>\$20', isGood: stats.avgPotWon >= 20),
            _KPICell(kpiKey: 'Errores graves', value: '${stats.blunders}', target: '0', isGood: stats.blunders == 0),
          ],
        ),
      ],
    );
  }
}

class _KPICell extends StatelessWidget {
  final String kpiKey;
  final String value;
  final String target;
  final bool isGood;

  const _KPICell({required this.kpiKey, required this.value, required this.target, required this.isGood});

  @override
  Widget build(BuildContext context) {
    final color = isGood ? AppColors.winning : AppColors.gtoMarginal;
    return GestureDetector(
      onTap: () => _showExplanation(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(kpiKey, style: const TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(I18n.t('target_lbl', {'t': target}), style: const TextStyle(color: AppColors.textMuted, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    final info = _kpiKnowledge[kpiKey];
    if (info == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ZerosAvatar(size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.label,
                    style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isGood ? AppColors.winning : AppColors.gtoMarginal).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isGood ? AppColors.winning : AppColors.gtoMarginal,
                      fontSize: 13, fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(I18n.t('what_means'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(info.meaning, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(I18n.t('objective_lbl'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
                Text(info.target, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (!isGood)
                  Text(I18n.t('out_of_range'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(height: 12),
            Text(I18n.t('how_improve'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(info.howToImprove, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          ],
        ),
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
          Text(I18n.t('decisions_hdr'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DecisionStat(label: I18n.t('optimal_pl'), value: '${stats.optimalDecisions}', color: AppColors.gtoOptimal),
              _DecisionStat(label: I18n.t('blunders_pl'), value: '${stats.blunders}', color: AppColors.gtoBlunder),
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
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
                if (_expanded) {
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
                  const ZerosAvatar(size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(I18n.t('coach_hdr'), style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        Text(I18n.t('coach_sub'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
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
