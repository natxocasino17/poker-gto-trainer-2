import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/player_model.dart';
import '../../../data/gto/hand_classes.dart';
import '../../../data/gto/open_raise.dart';

/// 13×13 RFI (open-raise first-in) range heatmap by position. Read-only view
/// over the GTO database — green = raise, gold = mixed, muted = fold.
class RangeHeatmapScreen extends StatefulWidget {
  const RangeHeatmapScreen({super.key});

  @override
  State<RangeHeatmapScreen> createState() => _RangeHeatmapScreenState();
}

class _RangeHeatmapScreenState extends State<RangeHeatmapScreen> {
  static const _positions = [
    (TablePosition.utg, 'UTG'),
    (TablePosition.mp, 'MP'),
    (TablePosition.co, 'CO'),
    (TablePosition.btn, 'BTN'),
    (TablePosition.sb, 'SB'),
  ];

  TablePosition _pos = TablePosition.btn;

  @override
  Widget build(BuildContext context) {
    final hands = HandClasses.all; // 169, row-major 13×13
    int raises = 0, mixed = 0;
    for (final h in hands) {
      final f = OpenRaiseDB.openFrequency(_pos, h);
      if (f >= 0.99) raises++;
      else if (f > 0) mixed++;
    }
    final pct = ((raises + mixed * 0.5) / hands.length * 100).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Rangos GTO · RFI',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final p in _positions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.$2),
                      selected: _pos == p.$1,
                      onSelected: (_) => setState(() => _pos = p.$1),
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: _pos == p.$1
                            ? const Color(0xFF06231E)
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Open ≈ $pct% de las manos',
              style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 13,
                      mainAxisSpacing: 1.5,
                      crossAxisSpacing: 1.5,
                    ),
                    itemCount: hands.length,
                    itemBuilder: (_, i) => _cell(hands[i]),
                  ),
                ),
              ),
            ),
          ),
          _legend(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _cell(String hand) {
    final f = OpenRaiseDB.openFrequency(_pos, hand);
    final Color bg;
    if (f >= 0.99) {
      bg = AppColors.felt;
    } else if (f > 0) {
      bg = AppColors.goldDark;
    } else {
      bg = AppColors.surfaceElevated;
    }
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            hand,
            style: TextStyle(
              color: f > 0 ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    Widget chip(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        );
    return Wrap(
      spacing: 16,
      children: [
        chip(AppColors.felt, 'Open'),
        chip(AppColors.goldDark, 'Mixto'),
        chip(AppColors.surfaceElevated, 'Fold'),
      ],
    );
  }
}
