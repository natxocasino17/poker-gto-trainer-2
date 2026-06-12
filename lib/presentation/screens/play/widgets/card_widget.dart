import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/card_model.dart';

/// Comic-style card rendered as pure vectors: razor sharp at any
/// resolution (4K included). Optional four-color deck so suits can
/// never be confused (pro standard: ♥ red, ♦ blue, ♣ green, ♠ black).
class CardWidget extends StatelessWidget {
  final CardModel? card;
  final bool faceDown;
  final double width;
  final double height;
  final bool highlighted;

  /// Global deck mode, persisted via settings. true = four-color deck.
  static bool fourColorDeck = true;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 32,
    this.height = 46,
    this.highlighted = false,
  });

  static Color suitColor(Suit s) {
    if (fourColorDeck) {
      switch (s) {
        case Suit.hearts: return const Color(0xFFD7263D);
        case Suit.diamonds: return const Color(0xFF1565C0);
        case Suit.clubs: return const Color(0xFF2E7D32);
        case Suit.spades: return const Color(0xFF1A1A1A);
      }
    }
    switch (s) {
      case Suit.hearts:
      case Suit.diamonds:
        return const Color(0xFFD7263D);
      case Suit.clubs:
      case Suit.spades:
        return const Color(0xFF1A1A1A);
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
          colors: [Color(0xFF7A1020), Color(0xFFB0182E)],
        ),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: Colors.white, width: width * 0.055),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Center(
        child: Container(
          width: width * 0.5,
          height: width * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.4),
          ),
          child: Center(
            child: Text('❖', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: width * 0.28)),
          ),
        ),
      ),
    );
  }

  Widget _buildFace(CardModel c) {
    // Clean classic deck: crisp white card, thin border, corner indices
    // (rank over suit) in both corners and a single large central pip.
    // Pure vectors → razor-sharp at any resolution.
    final ink = suitColor(c.suit);
    final isCourt = c.rank >= 11; // J, Q, K

    Widget cornerIndex() => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              c.rankSymbol,
              style: TextStyle(
                color: ink,
                fontSize: width * 0.34,
                fontWeight: FontWeight.w800,
                height: 0.9,
              ),
            ),
            Text(
              c.suitSymbol,
              style: TextStyle(color: ink, fontSize: width * 0.24, height: 0.9),
            ),
          ],
        );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: highlighted ? AppColors.gold : const Color(0xFF2A2A2A),
          width: highlighted ? 2.2 : width * 0.035,
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
          // Central pip (or court crown + pip)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCourt)
                  Text('♛', style: TextStyle(color: ink, fontSize: width * 0.22, height: 1.0)),
                Text(
                  c.suitSymbol,
                  style: TextStyle(color: ink, fontSize: width * (isCourt ? 0.4 : 0.5), height: 1.0),
                ),
              ],
            ),
          ),
          // Top-left corner index
          Positioned(left: width * 0.07, top: height * 0.04, child: cornerIndex()),
          // Bottom-right corner index (rotated 180°)
          Positioned(
            right: width * 0.07,
            bottom: height * 0.04,
            child: Transform.rotate(angle: 3.14159, child: cornerIndex()),
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
