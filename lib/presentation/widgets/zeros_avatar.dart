import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// ZerosPoker's avatar. Loads the bundled cartoon portrait; if the asset
/// is missing it falls back to a bold "Z" monogram.
class ZerosAvatar extends StatelessWidget {
  final double size;
  const ZerosAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 2))],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/zeros_avatar.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.suitSpades,
            child: Center(
              child: Text(
                'Z',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
