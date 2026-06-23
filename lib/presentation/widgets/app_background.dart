import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A subtle decorative background for study / menu screens (NOT the poker
/// table). Paints the standard app background colour and overlays the ornamental
/// pattern at very low opacity so it reads as a faint texture without fighting
/// the modern, high-contrast UI on top.
///
/// Usage: set the screen's `Scaffold(backgroundColor: Colors.transparent)` and
/// wrap its body in `AppBackground(child: ...)`.
class AppBackground extends StatelessWidget {
  final Widget child;

  /// 0..1 — how visible the pattern is. Kept low by default so text stays
  /// perfectly legible on top.
  final double patternOpacity;

  const AppBackground({
    super.key,
    required this.child,
    this.patternOpacity = 0.07,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: patternOpacity,
              child: Image.asset(
                'assets/ui_pattern.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
