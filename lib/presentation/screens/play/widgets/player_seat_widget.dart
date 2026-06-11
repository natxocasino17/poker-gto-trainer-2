import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/player_model.dart';
import 'card_widget.dart';

class PlayerSeatWidget extends StatelessWidget {
  final PlayerModel player;
  final bool isActive;
  final bool isHuman;

  const PlayerSeatWidget({
    super.key,
    required this.player,
    required this.isActive,
    required this.isHuman,
  });

  @override
  Widget build(BuildContext context) {
    if (isHuman) return _buildHumanSeat();
    return _buildBotSeat();
  }

  Widget _buildBotSeat() {
    final isFolded = player.isFolded;
    final opacity = isFolded ? 0.4 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cards
          HoleCardsWidget(
            cards: player.holeCards,
            faceDown: !player.cardsVisible,
            cardWidth: 22,
            cardHeight: 32,
            highlighted: player.isWinner,
          ),
          const SizedBox(height: 3),
          // Seat info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent.withOpacity(0.2)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AppColors.accent : AppColors.border,
                width: isActive ? 1.5 : 0.5,
              ),
              boxShadow: isActive
                  ? [const BoxShadow(color: AppColors.accentGlow, blurRadius: 8)]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (player.isDealer)
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('D', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    Text(
                      _shortName(player.name),
                      style: TextStyle(
                        color: isActive ? AppColors.accent : AppColors.textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${player.stack.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 8),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _positionColor(player.position).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    player.positionLabel,
                    style: TextStyle(
                      color: _positionColor(player.position),
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (player.streetBet > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.chipBlue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '\$${player.streetBet.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHumanSeat() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HoleCardsWidget(
          cards: player.holeCards,
          faceDown: false,
          cardWidth: 38,
          cardHeight: 54,
          highlighted: player.isWinner,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (player.isDealer)
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                      child: const Center(
                        child: Text('D', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  const Text(
                    'YOU',
                    style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ],
              ),
              Text(
                '\$${player.stack.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _positionColor(player.position).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  player.positionLabel,
                  style: TextStyle(color: _positionColor(player.position), fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (player.streetBet > 0)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.chipBlue,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '\$${player.streetBet.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  String _shortName(String name) {
    final parts = name.split(' ');
    if (parts.length == 1) return name.length > 8 ? name.substring(0, 8) : name;
    return '${parts.first[0]}. ${parts.last}';
  }

  Color _positionColor(TablePosition pos) {
    switch (pos) {
      case TablePosition.btn: return AppColors.gold;
      case TablePosition.sb: return const Color(0xFF64B5F6);
      case TablePosition.bb: return const Color(0xFFEF9A9A);
      case TablePosition.utg: return const Color(0xFFCE93D8);
      case TablePosition.mp: return const Color(0xFF80CBC4);
      case TablePosition.co: return const Color(0xFFA5D6A7);
    }
  }
}
