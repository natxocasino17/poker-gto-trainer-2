import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/player_model.dart';
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
              Text('Shuffling deck...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
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
        left: 16,
        right: 16,
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
              Text(
                '\$${gp.bankroll.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'Hand #${gp.gameState.handNumber}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              Text(
                '${stats.handsPlayed} played',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('SESSION', style: TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 1)),
              Text(
                stats.netProfit >= 0
                    ? '+\$${stats.netProfit.toStringAsFixed(2)}'
                    : '-\$${(-stats.netProfit).toStringAsFixed(2)}',
                style: TextStyle(
                  color: stats.netProfit >= 0 ? AppColors.winning : AppColors.losing,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    final gs = gp.gameState;
    final players = gs.players;
    final activeIdx = gs.activePlayerIndex;

    final cx = width / 2;
    final cy = height / 2;
    final rx = width * 0.38;
    final ry = height * 0.34;

    // Seat angles in radians, starting from bottom (human), going clockwise
    final seatAngles = [
      pi / 2,           // 0 = Human bottom
      pi / 6,           // 1 = bottom-right
      -pi / 6,          // 2 = right
      -pi / 2,          // 3 = top
      -5 * pi / 6,      // 4 = top-left
      5 * pi / 6,       // 5 = left
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(width, height),
          painter: _TablePainter(cx: cx, cy: cy, rx: rx * 1.02, ry: ry * 1.06),
        ),
        // Community cards + pot center
        Positioned(
          left: cx - 90,
          top: cy - 38,
          child: _CenterDisplay(gs: gs),
        ),
        // Player seats
        for (int i = 0; i < 6; i++)
          Positioned(
            left: cx + (rx + 48) * cos(seatAngles[i]) - 46,
            top: cy - (ry + 44) * sin(seatAngles[i]) - 46,
            width: 92,
            height: 92,
            child: Center(
              child: PlayerSeatWidget(
                player: players[i],
                isActive: (i == activeIdx && gs.isProcessingBot) ||
                    (players[i].isHuman && gs.awaitingHumanAction),
                isHuman: players[i].isHuman,
              ),
            ),
          ),
        // GTO FAB
        const Positioned(right: 12, bottom: 12, child: GTOAdvisorFAB()),
        // Street label
        Positioned(
          top: 8,
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
        Positioned(
          left: 8,
          bottom: 8,
          child: _LegendRoster(players: players),
        ),
      ],
    );
  }
}

class _TablePainter extends CustomPainter {
  final double cx, cy, rx, ry;
  const _TablePainter({required this.cx, required this.cy, required this.rx, required this.ry});

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black54
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 3, cy + 5), width: rx * 2.1, height: ry * 2.1),
      shadowPaint,
    );

    final railPaint = Paint()
      ..shader = RadialGradient(
        colors: const [AppColors.tableRailLight, AppColors.tableRail],
        radius: 0.8,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.4, height: ry * 2.4));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.18, height: ry * 2.18),
      railPaint,
    );

    final feltPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        colors: const [AppColors.feltLight, AppColors.felt],
        radius: 0.9,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      feltPaint,
    );

    final linePaint = Paint()
      ..color = AppColors.tableRailLight.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.98, height: ry * 1.98),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CenterDisplay extends StatelessWidget {
  final GameState gs;
  const _CenterDisplay({required this.gs});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gs.pot > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.chipBlue, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(
                  'Pot: \$${gs.pot.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: i < gs.communityCards.length
                    ? CardWidget(card: gs.communityCards[i], width: 30, height: 44)
                    : _EmptySlot(),
              ),
          ],
        ),
        if (gs.lastAction != null && gs.phase == GamePhase.handComplete)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              gs.lastAction!,
              style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12, width: 1),
        borderRadius: BorderRadius.circular(4),
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

class _LegendRoster extends StatelessWidget {
  final List<PlayerModel> players;
  const _LegendRoster({required this.players});

  @override
  Widget build(BuildContext context) {
    final bots = players.where((p) => !p.isHuman).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: bots.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Text(
          p.isFolded ? '✗ ${p.name}' : '• ${p.name}',
          style: TextStyle(
            color: p.isFolded ? AppColors.textMuted : AppColors.textSecondary,
            fontSize: 8,
            decoration: p.isFolded ? TextDecoration.lineThrough : null,
          ),
        ),
      )).toList(),
    );
  }
}
