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
          colors: [Color(0xFF263238), Color(0xFF37474F)],
        ),
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(color: const Color(0xFF1A1A1A), width: width * 0.05),
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
    // Comic-style deck: white card, black ink outline, oversized pips.
    // Vector rendering = perfectly sharp on any screen density.
    final ink = suitColor(c.suit);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(
          color: highlighted ? AppColors.gold : const Color(0xFF1A1A1A),
          width: highlighted ? 2.2 : width * 0.05,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted ? AppColors.gold.withOpacity(0.45) : Colors.black54,
            blurRadius: highlighted ? 8 : 3,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Oversized center suit (cartoon pip)
          Align(
            alignment: const Alignment(0.45, 0.55),
            child: Text(
              c.suitSymbol,
              style: TextStyle(
                color: ink,
                fontSize: width * 0.58,
                height: 1.0,
              ),
            ),
          ),
          // Rank top-left with small suit under it
          Positioned(
            left: width * 0.08,
            top: height * 0.03,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  c.rankSymbol,
                  style: TextStyle(
                    color: ink,
                    fontSize: width * 0.40,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
                Text(
                  c.suitSymbol,
                  style: TextStyle(color: ink, fontSize: width * 0.26, height: 1.0),
                ),
              ],
            ),
          ),
          // Inverted rank bottom-right, like the reference art
          Positioned(
            right: width * 0.07,
            bottom: height * 0.02,
            child: Transform.rotate(
              angle: 3.14159,
              child: Text(
                c.rankSymbol,
                style: TextStyle(
                  color: ink,
                  fontSize: width * 0.26,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
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
