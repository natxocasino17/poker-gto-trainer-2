import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/card_model.dart';

class CardWidget extends StatelessWidget {
  final CardModel? card;
  final bool faceDown;
  final double width;
  final double height;
  final bool highlighted;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 32,
    this.height = 46,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (faceDown || card == null) return _buildBack();
    return _buildFace(card!);
  }

  Widget _buildBack() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardBack, AppColors.cardBackPattern],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(Icons.grid_3x3, color: Colors.white.withOpacity(0.2), size: width * 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFace(CardModel c) {
    final color = c.isRed ? AppColors.redSuit : AppColors.blackSuit;
    final textColor = c.isRed ? AppColors.redSuit : const Color(0xFF212121);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardFace,
        borderRadius: BorderRadius.circular(4),
        border: highlighted
            ? Border.all(color: AppColors.accent, width: 1.5)
            : Border.all(color: Colors.grey.shade400, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: highlighted ? AppColors.accentGlow : Colors.black45,
            blurRadius: highlighted ? 6 : 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.rankSymbol,
              style: TextStyle(
                color: textColor,
                fontSize: width * 0.32,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            Text(
              c.suitSymbol,
              style: TextStyle(
                color: textColor,
                fontSize: width * 0.30,
                height: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HoleCardsWidget extends StatelessWidget {
  final List<CardModel> cards;
  final bool faceDown;
  final double cardWidth;
  final double cardHeight;
  final bool highlighted;

  const HoleCardsWidget({
    super.key,
    required this.cards,
    this.faceDown = false,
    this.cardWidth = 32,
    this.cardHeight = 46,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return SizedBox(
        width: cardWidth * 2 + 4,
        height: cardHeight,
        child: const Center(
          child: Text('—', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CardWidget(
          card: faceDown ? null : cards[0],
          faceDown: faceDown,
          width: cardWidth,
          height: cardHeight,
          highlighted: highlighted,
        ),
        const SizedBox(width: 3),
        CardWidget(
          card: faceDown ? null : (cards.length > 1 ? cards[1] : null),
          faceDown: faceDown || cards.length < 2,
          width: cardWidth,
          height: cardHeight,
          highlighted: highlighted,
        ),
      ],
    );
  }
}
