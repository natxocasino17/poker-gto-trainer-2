import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/card_model.dart';

/// Cartoon-style four-color card: solid colored background per suit
/// with big white rank and suit symbols (Knockout Poker look).
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

  static Color suitColor(Suit s) {
    switch (s) {
      case Suit.hearts: return AppColors.suitHearts;
      case Suit.diamonds: return AppColors.suitDiamonds;
      case Suit.clubs: return AppColors.suitClubs;
      case Suit.spades: return AppColors.suitSpades;
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardBack, AppColors.cardBackPattern],
        ),
        borderRadius: BorderRadius.circular(width * 0.16),
        border: Border.all(color: Colors.white38, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Center(
        child: Container(
          width: width * 0.55,
          height: height * 0.6,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1.2),
            borderRadius: BorderRadius.circular(width * 0.1),
          ),
          child: Center(
            child: Text(
              '♠',
              style: TextStyle(color: Colors.white24, fontSize: width * 0.34),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFace(CardModel c) {
    final bg = suitColor(c.suit);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, Color.lerp(bg, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(width * 0.16),
        border: highlighted
            ? Border.all(color: AppColors.gold, width: 2)
            : Border.all(color: Colors.white.withOpacity(0.55), width: 1),
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
          // Big watermark suit bottom-right
          Positioned(
            right: width * 0.04,
            bottom: -height * 0.06,
            child: Text(
              c.suitSymbol,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: width * 0.62,
                height: 1.0,
              ),
            ),
          ),
          // Rank top-left
          Positioned(
            left: width * 0.10,
            top: height * 0.04,
            child: Text(
              c.rankSymbol,
              style: TextStyle(
                color: Colors.white,
                fontSize: width * 0.46,
                fontWeight: FontWeight.w900,
                height: 1.0,
                shadows: const [Shadow(color: Colors.black26, offset: Offset(0.5, 1))],
              ),
            ),
          ),
          // Small suit under rank
          Positioned(
            left: width * 0.12,
            top: height * 0.40,
            child: Text(
              c.suitSymbol,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: width * 0.26,
                height: 1.0,
              ),
            ),
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
