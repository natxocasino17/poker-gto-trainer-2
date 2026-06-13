import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/card_model.dart';

class CardWidget extends StatelessWidget {
  final CardModel? card;
  final bool faceDown;
  final double width;
  final double height;
  final bool highlighted;

  // kept for settings compatibility — value ignored; always classic 2-color
  static bool fourColorDeck = false;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 32,
    this.height = 46,
    this.highlighted = false,
  });

  static Color suitColor(Suit s) {
    switch (s) {
      case Suit.hearts:
      case Suit.diamonds:
        return const Color(0xFFCC0000);
      case Suit.clubs:
      case Suit.spades:
        return const Color(0xFF111111);
    }
  }

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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: Colors.white, width: width * 0.05),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(1, 2))],
      ),
    );
  }

  Widget _buildFace(CardModel c) {
    final ink = suitColor(c.suit);
    final rank = Text(
      c.rankSymbol,
      style: TextStyle(
        color: ink,
        fontSize: width * 0.36,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: highlighted ? AppColors.gold : const Color(0xFF2A2A2A),
          width: highlighted ? 2.0 : width * 0.035,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted ? AppColors.gold.withOpacity(0.45) : Colors.black45,
            blurRadius: highlighted ? 8 : 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Big suit symbol centered
          Center(
            child: Text(
              c.suitSymbol,
              style: TextStyle(color: ink, fontSize: width * 0.52, height: 1.0),
            ),
          ),
          // Top-left rank
          Positioned(left: width * 0.08, top: height * 0.04, child: rank),
          // Bottom-right rank (rotated)
          Positioned(
            right: width * 0.08,
            bottom: height * 0.04,
            child: Transform.rotate(angle: 3.14159, child: rank),
          ),
        ],
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
      return SizedBox(width: cardWidth * 2 + 4, height: cardHeight);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -0.06,
          child: CardWidget(
            card: faceDown ? null : cards[0],
            faceDown: faceDown,
            width: cardWidth,
            height: cardHeight,
            highlighted: highlighted,
          ),
        ),
        const SizedBox(width: 2),
        Transform.rotate(
          angle: 0.06,
          child: CardWidget(
            card: faceDown ? null : (cards.length > 1 ? cards[1] : null),
            faceDown: faceDown || cards.length < 2,
            width: cardWidth,
            height: cardHeight,
            highlighted: highlighted,
          ),
        ),
      ],
    );
  }
}
