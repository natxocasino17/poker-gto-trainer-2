import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/hand_log_model.dart';
import '../../../../presentation/providers/game_provider.dart';

class ActionButtonsWidget extends StatefulWidget {
  const ActionButtonsWidget({super.key});

  @override
  State<ActionButtonsWidget> createState() => _ActionButtonsWidgetState();
}

class _ActionButtonsWidgetState extends State<ActionButtonsWidget> {
  double _raiseAmount = 4.0;
  bool _showRaiseSlider = false;

  static const double bigBlindAmount = 2.0;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final gs = gp.gameState;

    if (!gs.awaitingHumanAction) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gs.isProcessingBot)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  ),
                  SizedBox(width: 8),
                  Text('Pensando...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            if (gs.lastAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  gs.lastAction!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
          ],
        ),
      );
    }

    final callAmount = gs.callAmount;
    final human = gs.humanPlayer;
    final canCheck = callAmount <= 0;
    final potSize = gs.pot;

    if (_raiseAmount < callAmount + 2) {
      _raiseAmount = (callAmount + bigBlindAmount).clamp(bigBlindAmount, human.stack);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showRaiseSlider) _buildRaiseSlider(gp, callAmount, potSize, human.stack),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Fold',
                sublabel: null,
                color: AppColors.actionFold,
                onTap: () => _doAction(gp, ActionType.fold, 0),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ActionBtn(
                label: canCheck ? 'Check' : 'Call',
                sublabel: canCheck ? null : gp.money(callAmount),
                color: AppColors.actionCall,
                onTap: () => _doAction(gp, canCheck ? ActionType.check : ActionType.call, callAmount),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ActionBtn(
                label: callAmount > 0 ? 'Raise' : 'Bet',
                sublabel: gp.money(_raiseAmount),
                color: AppColors.actionRaise,
                onTap: () {
                  if (_showRaiseSlider) {
                    _doAction(gp, callAmount > 0 ? ActionType.raise : ActionType.bet, _raiseAmount);
                  } else {
                    setState(() => _showRaiseSlider = true);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRaiseSlider(GameProvider gp, double minBet, double pot, double stack) {
    final min = (minBet + 2.0).clamp(2.0, stack);
    final max = stack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cantidad', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              Text(
                gp.money(_raiseAmount),
                style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              GestureDetector(
                onTap: () => setState(() => _showRaiseSlider = false),
                child: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accentGlow,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _raiseAmount.clamp(min, max).toDouble(),
              min: min.toDouble(),
              max: max,
              divisions: max > min ? ((max - min) / 2).round().clamp(1, 100) : 1,
              onChanged: (v) => setState(() => _raiseAmount = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickSizeBtn(label: '½ Bote', amount: pot * 0.5, onTap: (a) => setState(() => _raiseAmount = a.clamp(min, max).toDouble())),
              _QuickSizeBtn(label: '¾ Bote', amount: pot * 0.75, onTap: (a) => setState(() => _raiseAmount = a.clamp(min, max).toDouble())),
              _QuickSizeBtn(label: 'Bote', amount: pot, onTap: (a) => setState(() => _raiseAmount = a.clamp(min, max).toDouble())),
              _QuickSizeBtn(label: 'All-In', amount: stack, onTap: (a) => setState(() => _raiseAmount = a)),
            ],
          ),
        ],
      ),
    );
  }

  void _doAction(GameProvider gp, ActionType type, double amount) {
    setState(() => _showRaiseSlider = false);
    gp.humanAction(type, amount);
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final String? sublabel;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickSizeBtn extends StatelessWidget {
  final String label;
  final double amount;
  final void Function(double) onTap;

  const _QuickSizeBtn({required this.label, required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
