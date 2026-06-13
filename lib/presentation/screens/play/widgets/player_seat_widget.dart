import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/hand_log_model.dart';
import 'card_widget.dart';
import '../../../../core/i18n/i18n.dart';

/// Seat with cartoon avatar circle, name plate with stack, position tag,
/// and a small action bubble announcing the player's last move this street.
class PlayerSeatWidget extends StatelessWidget {
  final PlayerModel player;
  final bool isActive;
  final bool isHuman;
  final String emoji;
  final String? avatarAsset; // illustrated image overrides emoji when set
  final String stackLabel;
  final HandAction? lastStreetAction;
  final String? actionAmountLabel;

  const PlayerSeatWidget({
    super.key,
    required this.player,
    required this.isActive,
    required this.isHuman,
    required this.emoji,
    this.avatarAsset,
    required this.stackLabel,
    this.lastStreetAction,
    this.actionAmountLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isFolded = player.isFolded;
    final avatarSize = isHuman ? 50.0 : 44.0;

    return Opacity(
      opacity: isFolded ? 0.45 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action bubble (small alert per player)
          SizedBox(
            height: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: lastStreetAction != null
                  ? _ActionBubble(
                      key: ValueKey('${lastStreetAction!.sequence}'),
                      action: lastStreetAction!,
                      amountLabel: actionAmountLabel,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Bot cards peek behind avatar
          if (!isHuman)
            SizedBox(
              height: 30,
              child: HoleCardsWidget(
                cards: player.holeCards,
                faceDown: !player.cardsVisible,
                cardWidth: 20,
                cardHeight: 29,
                highlighted: player.isWinner,
              ),
            ),
          const SizedBox(height: 2),
          // Avatar circle
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: player.isWinner
                    ? [AppColors.gold, AppColors.goldDark]
                    : [AppColors.surfaceElevated, AppColors.surface],
              ),
              border: Border.all(
                color: isActive
                    ? AppColors.accent
                    : (player.isWinner ? AppColors.gold : AppColors.woodLight),
                width: isActive ? 2.5 : 1.5,
              ),
              boxShadow: isActive
                  ? [const BoxShadow(color: AppColors.accentGlow, blurRadius: 12, spreadRadius: 2)]
                  : [const BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2))],
            ),
            child: Center(
              child: avatarAsset != null
                  ? ClipOval(
                      child: Image.asset(
                        avatarAsset!,
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Text(emoji, style: TextStyle(fontSize: avatarSize * 0.52)),
                      ),
                    )
                  : Text(emoji, style: TextStyle(fontSize: avatarSize * 0.52)),
            ),
          ),
          const SizedBox(height: 2),
          // Name plate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AppColors.accent : Colors.white12,
                width: isActive ? 1.2 : 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isHuman ? I18n.t('you') : _shortName(player.name),
                          style: TextStyle(
                            color: isHuman ? AppColors.accent : AppColors.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          player.positionLabel,
                          style: TextStyle(
                            color: _positionColor(player.position),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  player.isAllIn ? 'ALL-IN' : stackLabel,
                  style: TextStyle(
                    color: player.isAllIn ? AppColors.gtoMarginal : AppColors.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortName(String name) {
    final parts = name.split(' ');
    if (parts.length == 1) return name.length > 9 ? name.substring(0, 9) : name;
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

class _ActionBubble extends StatelessWidget {
  final HandAction action;
  final String? amountLabel;

  const _ActionBubble({super.key, required this.action, this.amountLabel});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _style(action.type);
    final text = amountLabel != null && amountLabel!.isNotEmpty
        ? '$label $amountLabel'
        : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (String, Color) _style(ActionType t) {
    switch (t) {
      case ActionType.fold: return ('FOLD', AppColors.actionFold);
      case ActionType.check: return ('CHECK', AppColors.actionCheck);
      case ActionType.call: return ('CALL', AppColors.actionCall);
      case ActionType.bet: return ('BET', AppColors.actionRaise);
      case ActionType.raise: return ('RAISE', const Color(0xFFE65100));
      case ActionType.allIn: return ('ALL-IN', const Color(0xFF8E24AA));
    }
  }
}
