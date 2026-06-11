import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/hand_log_model.dart';
import '../../../engine/legendary_ai.dart';
import '../../../engine/poker_engine.dart';
import '../../../presentation/providers/game_provider.dart';
import 'widgets/card_widget.dart';
import 'widgets/player_seat_widget.dart';
import 'widgets/action_buttons_widget.dart';
import 'widgets/gto_advisor_widget.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();

    if (!gp.initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 12),
              Text('Barajando...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    // The session is opened and closed by the player, whenever they want.
    if (!gp.sessionActive) {
      return _LobbyView(gp: gp);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(gp: gp),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) => _PokerTable(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    gp: gp,
                  ),
                ),
              ),
              _BottomPanel(gp: gp),
            ],
          ),
          if (gp.showGTOOverlay) const GTOAdvisorOverlay(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final GameProvider gp;
  const _Header({required this.gp});

  @override
  Widget build(BuildContext context) {
    final stats = gp.sessionStats;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 12,
        right: 12,
        bottom: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BANKROLL', style: TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 1)),
              Row(
                children: [
                  Text(
                    gp.money(gp.bankroll),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _confirmReload(context, gp),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold.withOpacity(0.6), width: 1),
                      ),
                      child: const Icon(Icons.add, color: AppColors.gold, size: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'Mano #${gp.gameState.handNumber}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              Text(
                '${stats.handsPlayed} jugadas',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
              ),
            ],
          ),
          const Spacer(),
          // Leave the table: cash the stack back into the bankroll
          GestureDetector(
            onTap: () => _confirmLeave(context, gp),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.losing.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.losing.withOpacity(0.45)),
              ),
              child: const Icon(Icons.logout, color: AppColors.losing, size: 15),
            ),
          ),
          // Quick BB/$ display toggle
          GestureDetector(
            onTap: gp.toggleDisplayUnits,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.5)),
              ),
              child: Text(
                gp.displayInBB ? 'BB' : '\$',
                style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('SESIÓN', style: TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 1)),
              Text(
                '${stats.netProfit >= 0 ? "+" : "-"}${gp.money(stats.netProfit.abs())}',
                style: TextStyle(
                  color: stats.netProfit >= 0 ? AppColors.winning : AppColors.losing,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, GameProvider gp) {
    final stack = gp.gameState.humanPlayer.stack;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(
          '¿Levantarte de la mesa? Te llevas ${gp.money(stack)} de vuelta al bankroll. Podrás revisar toda la sesión en ANALIZAR y VALORACIÓN.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Seguir jugando', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              gp.endSession();
              Navigator.pop(ctx);
            },
            child: const Text('Levantarme', style: TextStyle(color: AppColors.losing, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmReload(BuildContext context, GameProvider gp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recargar bankroll', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: const Text(
          '¿Añadir \$1.000 a tu bankroll? Si estás sin fichas en la mesa, también se te sentará con un stack nuevo.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              gp.reloadBankroll();
              Navigator.pop(ctx);
            },
            child: const Text('Recargar', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _PokerTable extends StatelessWidget {
  final double width;
  final double height;
  final GameProvider gp;

  const _PokerTable({required this.width, required this.height, required this.gp});

  // Seat angles: screen-space (y grows downward).
  // Index 0 = human at the BOTTOM, then clockwise around the table.
  static const List<double> _seatAngles = [
    pi / 2,        // 0 human — bottom center
    5 * pi / 6,    // 1 — bottom left
    7 * pi / 6,    // 2 — top left
    3 * pi / 2,    // 3 — top center
    11 * pi / 6,   // 4 — top right
    pi / 6,        // 5 — bottom right
  ];

  @override
  Widget build(BuildContext context) {
    final gs = gp.gameState;
    final players = gs.players;
    final activeIdx = gs.activePlayerIndex;

    final cx = width / 2;
    final cy = height / 2 - 6;
    final rx = width * 0.36;
    final ry = height * 0.33;

    HandAction? lastActionOf(String playerId) {
      for (final a in gs.currentHandActions.reversed) {
        if (a.playerId == playerId && a.street == gs.street) return a;
      }
      return null;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(width, height),
          painter: _TablePainter(cx: cx, cy: cy, rx: rx * 1.02, ry: ry * 1.06),
        ),
        // Community cards + pot center
        Positioned(
          left: cx - 95,
          top: cy - 44,
          width: 190,
          child: _CenterDisplay(gs: gs, gp: gp),
        ),
        // Bet chips in front of each player (on the felt)
        for (int i = 0; i < 6; i++)
          if (players[i].streetBet > 0)
            Positioned(
              left: cx + rx * 0.58 * cos(_seatAngles[i]) - 32,
              top: cy + ry * 0.52 * sin(_seatAngles[i]) - 10,
              width: 64,
              child: Center(
                child: _BetChip(
                  amount: players[i].streetBet,
                  label: gp.money(players[i].streetBet),
                ),
              ),
            ),
        // Dealer button on the felt next to the dealer's seat
        for (int i = 0; i < 6; i++)
          if (players[i].isDealer)
            Positioned(
              left: cx + rx * 0.82 * cos(_seatAngles[i] - 0.45) - 10,
              top: cy + ry * 0.78 * sin(_seatAngles[i] - 0.45) - 10,
              child: const _DealerButton(),
            ),
        // Player seats around the table
        for (int i = 0; i < 6; i++)
          Positioned(
            left: cx + (rx + 50) * cos(_seatAngles[i]) - 48,
            top: cy + (ry + (players[i].isHuman ? 64 : 52)) * sin(_seatAngles[i]) -
                (players[i].isHuman ? 52 : 58),
            width: 96,
            child: Center(
              child: PlayerSeatWidget(
                player: players[i],
                isActive: (i == activeIdx && gs.isProcessingBot) ||
                    (players[i].isHuman && gs.awaitingHumanAction),
                isHuman: players[i].isHuman,
                emoji: players[i].isHuman
                    ? '😎'
                    : LegendaryBotEngine.profileByName(players[i].legendName ?? '').emoji,
                stackLabel: gp.money(players[i].stack),
                lastStreetAction: lastActionOf(players[i].id),
                actionAmountLabel: _amountLabelFor(lastActionOf(players[i].id)),
              ),
            ),
          ),
        // Human hole cards — big, next to the bottom seat
        Positioned(
          left: cx - 110,
          top: cy + ry + 8,
          child: HoleCardsWidget(
            cards: gs.humanPlayer.holeCards,
            faceDown: false,
            cardWidth: 42,
            cardHeight: 60,
            highlighted: gs.humanPlayer.isWinner,
          ),
        ),
        // GTO FAB
        const Positioned(right: 12, bottom: 12, child: GTOAdvisorFAB()),
        // Street label
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                key: ValueKey(gs.street),
                gs.street.toUpperCase(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _amountLabelFor(HandAction? a) {
    if (a == null) return null;
    if (a.type == ActionType.fold || a.type == ActionType.check) return null;
    return gp.money(a.amount);
  }
}

class _TablePainter extends CustomPainter {
  final double cx, cy, rx, ry;
  const _TablePainter({required this.cx, required this.cy, required this.rx, required this.ry});

  @override
  void paint(Canvas canvas, Size size) {
    // Warm wood backdrop
    final woodPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.3),
        radius: 1.4,
        colors: [AppColors.woodLight, AppColors.wood, AppColors.woodDark],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), woodPaint);

    final shadowPaint = Paint()
      ..color = Colors.black54
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 3, cy + 6), width: rx * 2.14, height: ry * 2.14),
      shadowPaint,
    );

    // Rail
    final railPaint = Paint()
      ..shader = RadialGradient(
        colors: const [AppColors.tableRailLight, AppColors.tableRail],
        radius: 0.8,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.4, height: ry * 2.4));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.22, height: ry * 2.24),
      railPaint,
    );

    // Felt
    final feltPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        colors: const [AppColors.feltLight, AppColors.felt, AppColors.feltDark],
        stops: const [0.0, 0.7, 1.0],
        radius: 1.0,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      feltPaint,
    );

    // Inner betting line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.5, height: ry * 1.45),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BetChip extends StatelessWidget {
  final double amount;
  final String label;
  const _BetChip({required this.amount, required this.label});

  Color get _chipColor {
    if (amount >= 100) return AppColors.chipBlack;
    if (amount >= 50) return const Color(0xFF6A1B9A);
    if (amount >= 20) return AppColors.chipGreen;
    if (amount >= 10) return AppColors.chipBlue;
    return AppColors.chipRed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _chipColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
        const SizedBox(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DealerButton extends StatelessWidget {
  const _DealerButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFD8D8D8)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldDark, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(1, 1))],
      ),
      child: const Center(
        child: Text('D', style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _CenterDisplay extends StatelessWidget {
  final GameState gs;
  final GameProvider gp;
  const _CenterDisplay({required this.gs, required this.gp});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gs.pot > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                'Bote: ${gp.money(gs.pot)}',
                key: ValueKey(gs.pot),
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: i < gs.communityCards.length
                      ? CardWidget(
                          key: ValueKey('cc$i-${gs.communityCards[i]}'),
                          card: gs.communityCards[i],
                          width: 32,
                          height: 46,
                        )
                      : _EmptySlot(key: ValueKey('empty$i')),
                ),
              ),
          ],
        ),
        if (gs.lastAction != null && gs.phase == GamePhase.handComplete)
          Container(
            margin: const EdgeInsets.only(top: 5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withOpacity(0.5)),
            ),
            child: Text(
              gs.lastAction!,
              style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 46,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12, width: 1),
        borderRadius: BorderRadius.circular(5),
        color: Colors.black26,
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final GameProvider gp;
  const _BottomPanel({required this.gp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: const ActionButtonsWidget(),
    );
  }
}


/// Pre-session lobby: the player opens the session when they want.
class _LobbyView extends StatelessWidget {
  final GameProvider gp;
  const _LobbyView({required this.gp});

  @override
  Widget build(BuildContext context) {
    final canSit = gp.canAffordBuyIn;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🃏', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text(
                'GTO POKER TRAINER',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                '6-Max Cash · Ciegas \$1/\$2 · 5 leyendas te esperan',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('TU BANKROLL', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
                    Text(
                      gp.money(gp.bankroll),
                      style: const TextStyle(color: AppColors.gold, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: canSit ? () => gp.startSession() : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canSit
                          ? [AppColors.accent, AppColors.accentDark]
                          : [AppColors.textMuted, AppColors.surfaceElevated],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: canSit
                        ? [const BoxShadow(color: AppColors.accentGlow, blurRadius: 16, spreadRadius: 2)]
                        : null,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'SENTARSE EN LA MESA',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      Text(
                        'Buy-in: \$200 exactos — igual que todos',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              if (!canSit) ...[
                const SizedBox(height: 16),
                const Text(
                  'Sin fondos para el buy-in de \$200',
                  style: TextStyle(color: AppColors.losing, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => gp.reloadBankroll(),
                  icon: const Icon(Icons.add_card, color: AppColors.gold, size: 18),
                  label: const Text(
                    'Recargar +\$1.000',
                    style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              if (gp.handHistory.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Tu última sesión (${gp.handHistory.length} manos) sigue disponible en ANALIZAR y VALORACIÓN',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
