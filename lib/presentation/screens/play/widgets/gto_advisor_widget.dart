import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../presentation/providers/game_provider.dart';
import 'package:provider/provider.dart';
import '../../../widgets/zeros_avatar.dart';

class GTOAdvisorFAB extends StatelessWidget {
  const GTOAdvisorFAB({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final isMyTurn = gp.gameState.awaitingHumanAction;

    return AnimatedOpacity(
      opacity: isMyTurn ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: isMyTurn ? () => gp.requestGTOAdvice() : null,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceElevated,
            border: Border.all(color: AppColors.accent, width: 2),
            boxShadow: const [BoxShadow(color: AppColors.accentGlow, blurRadius: 10, spreadRadius: 1)],
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              const Center(child: ZerosAvatar(size: 44)),
              // Small "GTO" badge so its purpose stays clear (Puxi = the AI face)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('GTO',
                      style: TextStyle(color: Color(0xFF06231E), fontSize: 7, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GTOAdvisorOverlay extends StatelessWidget {
  const GTOAdvisorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    if (!gp.showGTOOverlay || gp.lastGTOAdvice == null) return const SizedBox.shrink();

    final advice = gp.lastGTOAdvice!;

    return GestureDetector(
      onTap: gp.dismissGTOOverlay,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
                boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ZerosAvatar(size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'EL PUXI · GTO',
                        style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: gp.dismissGTOOverlay,
                        child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMetricRow('Tu Equity', '${(advice.equity * 100).toStringAsFixed(1)}%', _equityColor(advice.equity)),
                  if (advice.potOdds > 0)
                    _buildMetricRow('Pot Odds', '${(advice.potOdds * 100).toStringAsFixed(1)}%', AppColors.textSecondary),
                  _buildMetricRow('EV', '${advice.ev >= 0 ? "+" : ""}${(advice.ev * 100).toStringAsFixed(1)}%', advice.ev >= 0 ? AppColors.winning : AppColors.losing),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _actionColor(advice.action).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _actionColor(advice.action).withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          advice.action.toUpperCase(),
                          style: TextStyle(
                            color: _actionColor(advice.action),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (advice.amount > 0)
                          Text(
                            '\$${advice.amount.toStringAsFixed(0)}',
                            style: TextStyle(color: _actionColor(advice.action).withOpacity(0.8), fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    advice.reasoning,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                  // Personalized note: the app has learned how YOU play.
                  if (gp.personalizedTip().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🧠 ', style: TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              gp.personalizedTip(),
                              style: const TextStyle(color: AppColors.gold, fontSize: 11.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    'Toca en cualquier sitio para cerrar',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Color _equityColor(double equity) {
    if (equity > 0.65) return AppColors.winning;
    if (equity > 0.40) return AppColors.gold;
    return AppColors.losing;
  }

  Color _actionColor(String action) {
    switch (action.toLowerCase()) {
      case 'fold': return AppColors.actionFold;
      case 'call': return AppColors.actionCall;
      case 'raise': return AppColors.actionRaise;
      case 'bet': return AppColors.actionRaise;
      case 'check': return AppColors.actionCheck;
      default: return AppColors.textPrimary;
    }
  }
}
