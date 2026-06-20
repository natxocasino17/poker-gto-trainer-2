import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/trainer_feedback.dart';
import '../../../../data/models/hand_log_model.dart';

/// Trainer-mode banner: grades the player's last decision vs GTO. Auto-hides
/// after a few seconds; tap to dismiss now.
class TrainerFeedbackBanner extends StatefulWidget {
  final TrainerFeedback feedback;
  final VoidCallback onDismiss;
  const TrainerFeedbackBanner(
      {super.key, required this.feedback, required this.onDismiss});

  @override
  State<TrainerFeedbackBanner> createState() => _TrainerFeedbackBannerState();
}

class _TrainerFeedbackBannerState extends State<TrainerFeedbackBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(TrainerFeedbackBanner old) {
    super.didUpdateWidget(old);
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1800), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color get _color {
    switch (widget.feedback.quality) {
      case DecisionQuality.optimal:
        return AppColors.gtoOptimal;
      case DecisionQuality.correct:
        return AppColors.gtoCorrect;
      case DecisionQuality.marginal:
        return AppColors.gtoMarginal;
      case DecisionQuality.blunder:
        return AppColors.gtoBlunder;
    }
  }

  String get _label {
    switch (widget.feedback.quality) {
      case DecisionQuality.optimal:
        return 'ÓPTIMO';
      case DecisionQuality.correct:
        return 'CORRECTO';
      case DecisionQuality.marginal:
        return 'MARGINAL';
      case DecisionQuality.blunder:
        return 'BLUNDER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = widget.feedback;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 56,
      left: 12,
      right: 12,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: AnimatedSlide(
          offset: Offset.zero,
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _color, width: 1.5),
                boxShadow: [BoxShadow(color: _color.withOpacity(0.25), blurRadius: 14)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_label,
                            style: const TextStyle(
                                color: Color(0xFF06231E),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Tú: ${fb.chosen}   ·   GTO: ${fb.recommended}',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(fb.note,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11.5, height: 1.3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
