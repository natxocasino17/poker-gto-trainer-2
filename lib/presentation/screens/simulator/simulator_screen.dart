import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/equity_calculator.dart';
import '../../../core/utils/poker_concepts.dart';
import '../../../data/models/card_model.dart';
import '../play/widgets/card_widget.dart';
import '../../../core/i18n/i18n.dart';

/// Hand simulator: pick your hole cards and the exact flop/turn/river
/// and see your equity street by street.
class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final List<CardModel?> _hero = [null, null];
  final List<CardModel?> _board = [null, null, null, null, null];
  int _opponents = 1;

  List<CardModel> get _usedCards => [
        ..._hero.whereType<CardModel>(),
        ..._board.whereType<CardModel>(),
      ];

  bool get _heroReady => _hero.every((c) => c != null);

  List<CardModel> get _knownBoard {
    // The board fills in order: incomplete flop means preflop equity only
    final flop = _board.take(3).toList();
    final result = <CardModel>[];
    if (flop.every((c) => c != null)) {
      result.addAll(flop.cast<CardModel>());
      if (_board[3] != null) {
        result.add(_board[3]!);
        if (_board[4] != null) result.add(_board[4]!);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(I18n.t('sim_title')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(I18n.t('your_hand'), [
            _slot(_hero[0], () => _pick((c) => _hero[0] = c), () => setState(() => _hero[0] = null)),
            _slot(_hero[1], () => _pick((c) => _hero[1] = c), () => setState(() => _hero[1] = null)),
          ]),
          const SizedBox(height: 14),
          _section('FLOP', [
            for (int i = 0; i < 3; i++)
              _slot(_board[i], () => _pick((c) => _board[i] = c), () => setState(() => _board[i] = null)),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _section('TURN', [
                  _slot(_board[3], () => _pick((c) => _board[3] = c), () => setState(() => _board[3] = null)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _section('RIVER', [
                  _slot(_board[4], () => _pick((c) => _board[4] = c), () => setState(() => _board[4] = null)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _opponentSelector(),
          const SizedBox(height: 20),
          if (_heroReady) _EquityPanel(
            hero: _hero.cast<CardModel>(),
            board: _knownBoard,
            opponents: _opponents,
          )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  I18n.t('sim_prompt'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> slots) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final s in slots) Padding(padding: const EdgeInsets.only(right: 8), child: s),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slot(CardModel? card, VoidCallback onTap, VoidCallback onClear) {
    return GestureDetector(
      onTap: card == null ? onTap : onClear,
      child: card != null
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                CardWidget(card: card, width: 46, height: 66),
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppColors.losing, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                  ),
                ),
              ],
            )
          : Container(
              width: 46,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.2),
              ),
              child: const Icon(Icons.add, color: AppColors.accent, size: 20),
            ),
    );
  }

  Widget _opponentSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(I18n.t('sim_opponents'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          for (int n = 1; n <= 5; n++)
            GestureDetector(
              onTap: () => setState(() => _opponents = n),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _opponents == n ? AppColors.accent : AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$n',
                    style: TextStyle(
                      color: _opponents == n ? Colors.black : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _pick(void Function(CardModel) assign) {
    final used = _usedCards;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(I18n.t('sim_pick'),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final suit in Suit.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int r = 14; r >= 2; r--)
                          Builder(builder: (_) {
                            final c = CardModel(rank: r, suit: suit);
                            final taken = used.contains(c);
                            return GestureDetector(
                              onTap: taken
                                  ? null
                                  : () {
                                      setState(() => assign(c));
                                      Navigator.pop(ctx);
                                    },
                              child: Opacity(
                                opacity: taken ? 0.25 : 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: CardWidget(card: c, width: 34, height: 48),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquityPanel extends StatelessWidget {
  final List<CardModel> hero;
  final List<CardModel> board;
  final int opponents;

  const _EquityPanel({required this.hero, required this.board, required this.opponents});

  @override
  Widget build(BuildContext context) {
    final equity = EquityCalculator.calculate(
      heroCards: hero,
      communityCards: board,
      numOpponents: opponents,
      simulations: 600,
    );
    final streetLabel = switch (board.length) {
      0 => 'PREFLOP',
      3 => 'FLOP',
      4 => 'TURN',
      _ => 'RIVER',
    };

    final analysis = board.length >= 3
        ? HandStrengthAnalysis.analyze(hero, board)
        : null;
    final texture = board.length >= 3 ? BoardTexture.analyze(board) : null;

    final eqColor = equity > 0.60
        ? AppColors.winning
        : equity > 0.40
            ? AppColors.gold
            : AppColors.losing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: eqColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(I18n.t('sim_equity_in', {'s': streetLabel, 'n': '$opponents'}),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${(equity * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: eqColor, fontSize: 36, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: equity,
                    minHeight: 14,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation(eqColor),
                  ),
                ),
              ),
            ],
          ),
          if (analysis != null && texture != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _tag('Mano: ${_bucketLabel(analysis.bucket)}', AppColors.accent),
                if (analysis.flushDraw) _tag(analysis.nutFlushDraw ? 'Proyecto de color (al as)' : 'Proyecto de color', AppColors.suitDiamonds),
                if (analysis.openEnded) _tag('Proyecto abierto de escalera', AppColors.suitClubs),
                if (analysis.gutshot) _tag('Gutshot', AppColors.gtoMarginal),
                if (analysis.outs > 0) _tag('${analysis.outs} outs (~${(analysis.drawEquity * 100).toStringAsFixed(0)}% regla 2/4)', AppColors.textSecondary),
                _tag(
                  texture.monotone
                      ? 'Board monocolor'
                      : texture.wetness > 0.55
                          ? 'Board húmedo/coordinado'
                          : texture.wetness < 0.35
                              ? 'Board seco'
                              : 'Board medio',
                  AppColors.textMuted,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _bucketLabel(HandBucket b) {
    switch (b) {
      case HandBucket.nuts: return 'Nuts / casi nuts';
      case HandBucket.strongValue: return 'Valor fuerte';
      case HandBucket.mediumValue: return 'Valor medio';
      case HandBucket.weakShowdown: return 'Showdown débil';
      case HandBucket.comboDraw: return 'Combo draw';
      case HandBucket.strongDraw: return 'Proyecto fuerte';
      case HandBucket.weakDraw: return 'Proyecto débil';
      case HandBucket.air: return 'Aire';
    }
  }
}
