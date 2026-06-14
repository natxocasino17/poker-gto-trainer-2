import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/utils/hand_evaluator.dart';
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
import 'widgets/trainer_feedback_banner.dart';
import 'widgets/puxi_tutorial_overlay.dart';
import '../simulator/simulator_screen.dart';
import '../puxi/puxi_chat_screen.dart';
import '../../../core/i18n/i18n.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();

    if (!gp.initialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.accent),
              const SizedBox(height: 12),
              Text(I18n.t('shuffling'), style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    // The session is opened and closed by the player, whenever they want.
    final Widget content = !gp.sessionActive
        ? _LobbyView(gp: gp)
        : Scaffold(
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
                if (gp.trainerFeedback != null)
                  TrainerFeedbackBanner(
                    feedback: gp.trainerFeedback!,
                    onDismiss: gp.dismissTrainerFeedback,
                  ),
                if (gp.showGTOOverlay) const GTOAdvisorOverlay(),
              ],
            ),
          );

    // First-launch tutorial by EL PUXI (skippable) overlays everything.
    if (gp.tutorialSeen) return content;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: content),
        Positioned.fill(
          child: PuxiTutorialOverlay(onDone: gp.completeTutorial),
        ),
      ],
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
                    onTap: () => gp.reloadBankroll(),
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
                I18n.t('hand_no', {'n': gp.gameState.handNumber.toString()}),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              Text(
                I18n.t('played_count', {'n': stats.handsPlayed.toString()}),
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
              Text(I18n.t('session_lbl'), style: const TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 1)),
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
        title: Text(I18n.t('leave_title'), style: const TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(
          I18n.t('leave_body', {'v': gp.money(stack)}),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(I18n.t('keep_playing'), style: const TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              gp.endSession();
              Navigator.pop(ctx);
            },
            child: Text(I18n.t('leave_btn'), style: const TextStyle(color: AppColors.losing, fontWeight: FontWeight.w700)),
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
              left: cx + rx * 0.90 * cos(_seatAngles[i]) - 32,
              top: cy + ry * 0.88 * sin(_seatAngles[i]) - 11,
              width: 64,
              child: Center(
                child: _BetChip(
                  amount: players[i].streetBet,
                  label: gp.money(players[i].streetBet),
                ),
              ),
            ),
        // Dealer button on the felt, close in front of the dealer's seat
        for (int i = 0; i < 6; i++)
          if (players[i].isDealer)
            Positioned(
              left: cx + rx * 0.89 * cos(_seatAngles[i] - 0.18) - 10,
              top: cy + ry * 0.86 * sin(_seatAngles[i] - 0.18) - 10,
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
                avatarAsset: players[i].isHuman
                    ? null
                    : LegendaryBotEngine.profileByName(players[i].legendName ?? '').avatarAsset,
                bankrollLabel: players[i].isHuman
                    ? gp.money(players[i].stack)
                    : null,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folded cards dim down but stay slightly visible while
              // there is still action on the table.
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: gs.humanPlayer.isFolded ? 0.32 : 1.0,
                child: HoleCardsWidget(
                  cards: gs.humanPlayer.holeCards,
                  faceDown: false,
                  cardWidth: 42,
                  cardHeight: 60,
                  highlighted: gs.humanPlayer.isWinner,
                ),
              ),
              // Live made-hand indicator (pro feature)
              if (gs.humanPlayer.holeCards.length == 2 &&
                  gs.communityCards.length >= 3 &&
                  !gs.humanPlayer.isFolded)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 0.8),
                  ),
                  child: Text(
                    HandEvaluator.evaluateBest(
                      [...gs.humanPlayer.holeCards, ...gs.communityCards],
                    ).description,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Chips fly from the pot to the winner's seat
        if (gs.phase == GamePhase.handComplete && gs.players.any((p) => p.isWinner))
          Builder(builder: (_) {
            final wIdx = gs.players.indexWhere((p) => p.isWinner);
            final ang = _seatAngles[wIdx];
            final endX = cx + rx * 0.9 * cos(ang);
            final endY = cy + ry * 0.88 * sin(ang);
            return _ChipsToWinner(
              key: ValueKey('chips${gs.handNumber}'),
              startX: cx,
              startY: cy,
              endX: endX,
              endY: endY,
            );
          }),
        // Winner announcement banner (a few seconds to read the result)
        if (gs.phase == GamePhase.handComplete)
          Positioned(
            top: cy - ry - 18,
            left: 0,
            right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (_, t, child) => Transform.scale(scale: t, child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldDark]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.5), blurRadius: 18, spreadRadius: 2)],
                  ),
                  child: Text(
                    I18n.t('winner_banner', {
                      'who': gs.players.where((p) => p.isWinner).map((p) => p.isHuman ? I18n.t('you') : p.name).join(' & '),
                    }),
                    style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ),
        // GTO FAB
        const Positioned(right: 12, bottom: 12, child: GTOAdvisorFAB()),
        // Replay the current hand from preflop with the same cards
        Positioned(
          right: 14,
          bottom: 74,
          child: GestureDetector(
            onTap: gp.canReplay ? gp.replayHand : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated
                    .withOpacity(gp.canReplay ? 1 : 0.5),
                border: Border.all(
                    color: AppColors.accent
                        .withOpacity(gp.canReplay ? 0.6 : 0.25),
                    width: 1.5),
              ),
              child: Icon(Icons.replay,
                  color: AppColors.accent.withOpacity(gp.canReplay ? 1 : 0.4),
                  size: 19),
            ),
          ),
        ),
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
        // Two pots, on purpose:
        //  · "BOTE" = total pot (closed pot + all bets in front of players) →
        //    the number you use for MDF and the full-pot reasoning.
        //  · "ronda" = chips wagered in the CURRENT betting round → the part
        //    that drives pot odds when you're facing a bet.
        // The closed/center pot is simply BOTE − ronda.
        if (gs.pot > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Text(
                    I18n.t('pot_lbl', {'v': gp.money(gs.pot)}),
                    key: ValueKey(gs.pot),
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                if (gs.pot - gs.mainPot > 0.01)
                  Text(
                    'ronda ${gp.money(gs.pot - gs.mainPot)}',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                  ),
              ],
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


// ── Vintage palette used only within the lobby ──────────────────────────────
class _VintageColors {
  static const cream       = Color(0xFFF5EDD8);
  static const creamDark   = Color(0xFFE8D9BC);
  static const inkBlack    = Color(0xFF1A0A00);
  static const inkBrown    = Color(0xFF3D1C00);
  static const gold        = Color(0xFFB8922A);
  static const goldLight   = Color(0xFFD4AA44);
  static const suitRed     = Color(0xFF8B1A1A);
  static const borderDark  = Color(0xFF2C1810);
}

/// Pre-session lobby: the player opens the session when they want.
class _LobbyView extends StatelessWidget {
  final GameProvider gp;
  const _LobbyView({required this.gp});

  @override
  Widget build(BuildContext context) {
    final canSit = gp.canAffordBuyIn;
    return Scaffold(
      backgroundColor: _VintageColors.inkBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image ──────────────────────────────────────────
          Image.asset(
            'assets/lobby_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: _VintageColors.cream),
          ),
          // ── Subtle dark vignette so top/bottom text stays readable ────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x66000000),
                ],
                stops: [0.0, 0.18, 0.80, 1.0],
              ),
            ),
          ),
          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _VintageColors.borderDark, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/ipt_logo.png',
                        width: 90,
                        height: 90,
                        errorBuilder: (_, __, ___) =>
                            Container(width: 90, height: 90, color: _VintageColors.cream,
                              child: const Center(child: Text('🃏', style: TextStyle(fontSize: 44)))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Title
                  const Text(
                    'iPT',
                    style: TextStyle(
                      color: _VintageColors.inkBlack,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      fontFamily: 'serif',
                      shadows: [Shadow(color: Color(0x44000000), offset: Offset(1, 2), blurRadius: 4)],
                    ),
                  ),

                  // Suit divider
                  const _SuitDivider(),
                  const SizedBox(height: 4),

                  // Subtitle
                  const Text(
                    'iPoker Training',
                    style: TextStyle(
                      color: _VintageColors.inkBrown,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    I18n.t('tagline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _VintageColors.inkBrown,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'serif',
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Bankroll box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      color: _VintageColors.cream.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _VintageColors.borderDark, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          I18n.t('your_bankroll'),
                          style: const TextStyle(
                            color: _VintageColors.inkBrown,
                            fontSize: 9,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'serif',
                          ),
                        ),
                        Text(
                          gp.money(gp.bankroll),
                          style: const TextStyle(
                            color: _VintageColors.gold,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'serif',
                            shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 3)],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SIT button — deep red with gold border
                  GestureDetector(
                    onTap: canSit ? () => gp.startSession() : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: canSit
                              ? const [Color(0xFF9B2020), Color(0xFF5C0F0F)]
                              : const [Color(0xFF6B5A4E), Color(0xFF3D2B24)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: canSit ? _VintageColors.goldLight : _VintageColors.inkBrown,
                          width: 2,
                        ),
                        boxShadow: canSit
                            ? const [BoxShadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(0, 5))]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            I18n.t('sit_btn'),
                            style: const TextStyle(
                              color: _VintageColors.cream,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              fontFamily: 'serif',
                            ),
                          ),
                          Text(
                            I18n.t('sit_sub'),
                            style: TextStyle(
                              color: _VintageColors.cream.withOpacity(0.75),
                              fontSize: 11,
                              letterSpacing: 1,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Edit Table / Simulator / Settings — centrados ──────
                  Center(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _LobbyChipButton(
                          icon: Icons.group,
                          label: I18n.t('edit_table'),
                          onTap: () => _openTableEditor(context, gp),
                        ),
                        _LobbyChipButton(
                          icon: Icons.calculate,
                          label: I18n.t('simulator'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SimulatorScreen()),
                          ),
                        ),
                        _LobbyChipButton(
                          icon: Icons.settings,
                          label: I18n.t('settings'),
                          onTap: () => _openSettings(context, gp),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Puxi Chat
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PuxiChatScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: _VintageColors.cream.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _VintageColors.borderDark, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: _VintageColors.inkBrown, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '💬 ${I18n.t('puxi_chat')}',
                            style: const TextStyle(
                              color: _VintageColors.inkBrown,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!canSit) ...[
                    const SizedBox(height: 16),
                    Text(
                      I18n.t('no_funds'),
                      style: const TextStyle(color: _VintageColors.suitRed, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => gp.reloadBankroll(),
                      icon: const Icon(Icons.add_card, color: _VintageColors.gold, size: 18),
                      label: Text(
                        I18n.t('reload_plus'),
                        style: const TextStyle(color: _VintageColors.gold, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],

                  if (gp.handHistory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      I18n.t('last_session_note', {'n': gp.handHistory.length.toString()}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _VintageColors.inkBrown,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small ornamental suit row ────────────────────────────────────────────────
class _SuitDivider extends StatelessWidget {
  const _SuitDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('♠', style: TextStyle(color: _VintageColors.inkBlack, fontSize: 13)),
          SizedBox(width: 6),
          Text('♥', style: TextStyle(color: _VintageColors.suitRed, fontSize: 13)),
          SizedBox(width: 6),
          Text('♣', style: TextStyle(color: _VintageColors.inkBlack, fontSize: 13)),
          SizedBox(width: 6),
          Text('♦', style: TextStyle(color: _VintageColors.suitRed, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LobbyChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LobbyChipButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _VintageColors.cream.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _VintageColors.borderDark, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _VintageColors.inkBrown, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _VintageColors.inkBrown,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontFamily: 'serif',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Table editor: pick each of the 5 opponents — a legend, a style
/// archetype, or random.
void _openTableEditor(BuildContext context, GameProvider gp) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(I18n.t('config_title'),
                  style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(I18n.t('config_sub'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 14),
              for (int i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await _pickOpponent(ctx, gp);
                      if (picked != null) {
                        gp.setTableSlot(i, picked == '__random__' ? null : picked);
                        setSheetState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Text(I18n.t('seat_n', {'n': '${i + 1}'}),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const Spacer(),
                          Builder(builder: (_) {
                            final name = gp.tableSlots[i];
                            if (name == null) {
                              return Text(I18n.t('random'),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600));
                            }
                            final prof = LegendaryBotEngine.profileByName(name);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _legendAvatar(prof, size: 24),
                                const SizedBox(width: 6),
                                Text(prof.name,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            );
                          }),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, color: AppColors.accent, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () {
                    for (int i = 0; i < 5; i++) {
                      gp.setTableSlot(i, null);
                    }
                    setSheetState(() {});
                  },
                  child: Text(I18n.t('reset_random'),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Avatar (illustrated portrait) for a legend, falling back to the emoji for
// archetypes / legends without an avatar asset.
Widget _legendAvatar(LegendProfile p, {double size = 38}) {
  final asset = p.avatarAsset;
  if (asset != null) {
    return ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Text(p.emoji, style: TextStyle(fontSize: size * 0.6)),
      ),
    );
  }
  return SizedBox(
    width: size,
    height: size,
    child: Center(
      child: Text(p.emoji, style: TextStyle(fontSize: size * 0.6)),
    ),
  );
}

Future<String?> _pickOpponent(BuildContext context, GameProvider gp) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              dense: true,
              leading: const Text('🎲', style: TextStyle(fontSize: 22)),
              title: Text(I18n.t('random'), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              subtitle: Text(I18n.t('random_sub'), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              onTap: () => Navigator.pop(ctx, '__random__'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(I18n.t('legends_hdr'), style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.5)),
            ),
            for (final p in LegendaryBotEngine.legends)
              ListTile(
                dense: true,
                leading: _legendAvatar(p, size: 40),
                title: Text(p.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                subtitle: Text(p.style, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                onTap: () => Navigator.pop(ctx, p.name),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(I18n.t('styles_hdr'), style: TextStyle(color: AppColors.accent, fontSize: 11, letterSpacing: 1.5)),
            ),
            for (final p in LegendaryBotEngine.archetypes)
              ListTile(
                dense: true,
                leading: _legendAvatar(p, size: 40),
                title: Text(p.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                subtitle: Text(p.style, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                onTap: () => Navigator.pop(ctx, p.name),
              ),
          ],
        ),
      ),
    ),
  );
}


void _openSettings(BuildContext context, GameProvider gp) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(I18n.t('settings').toUpperCase(),
                  style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 16),
              Text(I18n.t('language'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: I18n.supported.entries.map((e) {
                  final selected = gp.localeCode == e.key;
                  return GestureDetector(
                    onTap: () {
                      gp.setLocale(e.key);
                      setSheetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? AppColors.accent : AppColors.border),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: selected ? Colors.black : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Animated stack of chips flying from the pot center to the winner's seat.
class _ChipsToWinner extends StatelessWidget {
  final double startX, startY, endX, endY;
  const _ChipsToWinner({
    super.key,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      builder: (_, t, __) {
        // Ease the chips along the path; fade out as they arrive.
        final x = startX + (endX - startX) * t;
        final y = startY + (endY - startY) * t;
        final opacity = t < 0.85 ? 1.0 : (1.0 - (t - 0.85) / 0.15);
        return Positioned(
          left: x - 14,
          top: y - 14,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: const _ChipStack(),
          ),
        );
      },
    );
  }
}

class _ChipStack extends StatelessWidget {
  const _ChipStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 30,
      child: Stack(
        children: [
          for (int i = 0; i < 4; i++)
            Positioned(
              bottom: i * 4.0,
              left: 0,
              child: Container(
                width: 26,
                height: 9,
                decoration: BoxDecoration(
                  color: i.isEven ? AppColors.gold : AppColors.chipRed,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 1),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 2)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
