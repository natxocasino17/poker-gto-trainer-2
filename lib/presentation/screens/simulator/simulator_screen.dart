import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/equity_calculator.dart';
import '../../../core/utils/poker_concepts.dart';
import '../../../data/models/card_model.dart';
import '../../../data/models/player_model.dart';
import '../play/widgets/card_widget.dart';
import '../../../core/i18n/i18n.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final List<CardModel?> _hero    = [null, null];
  final List<CardModel?> _villain = [null, null];
  final List<CardModel?> _board   = [null, null, null, null, null];

  TablePosition? _heroPos;
  TablePosition? _villainPos;

  List<CardModel> get _usedCards => [
        ..._hero.whereType<CardModel>(),
        ..._villain.whereType<CardModel>(),
        ..._board.whereType<CardModel>(),
      ];

  bool get _heroReady    => _hero.every((c) => c != null);
  bool get _villainReady => _villain.every((c) => c != null);

  List<CardModel> get _knownBoard {
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

  static const _positions = [
    TablePosition.utg,
    TablePosition.mp,
    TablePosition.co,
    TablePosition.btn,
    TablePosition.sb,
    TablePosition.bb,
  ];

  static const _posLabels = {
    TablePosition.utg: 'UTG',
    TablePosition.mp:  'MP',
    TablePosition.co:  'CO',
    TablePosition.btn: 'BTN',
    TablePosition.sb:  'SB',
    TablePosition.bb:  'BB',
  };

  // BTN is IP vs everyone except blinds; SB is IP vs BB only
  bool _isHeroIP() {
    if (_heroPos == null || _villainPos == null) return false;
    const ipOrder = [TablePosition.bb, TablePosition.sb, TablePosition.utg,
                     TablePosition.mp, TablePosition.co, TablePosition.btn];
    return ipOrder.indexOf(_heroPos!) > ipOrder.indexOf(_villainPos!);
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
        padding: const EdgeInsets.all(14),
        children: [
          // ── Hero vs Villain side by side ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _handPanel(
                label: 'TU MANO',
                cards: _hero,
                position: _heroPos,
                color: AppColors.accent,
                onPickCard: (idx) => _pick((c) => setState(() => _hero[idx] = c)),
                onClearCard: (idx) => setState(() => _hero[idx] = null),
                onPickPos: (p) => setState(() => _heroPos = p),
              )),
              const SizedBox(width: 10),
              Expanded(child: _handPanel(
                label: 'RIVAL',
                cards: _villain,
                position: _villainPos,
                color: AppColors.losing,
                onPickCard: (idx) => _pick((c) => setState(() => _villain[idx] = c)),
                onClearCard: (idx) => setState(() => _villain[idx] = null),
                onPickPos: (p) => setState(() => _villainPos = p),
              )),
            ],
          ),

          const SizedBox(height: 12),

          // ── Position advantage badge ──────────────────────────────────
          if (_heroPos != null && _villainPos != null && _heroPos != _villainPos) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: _isHeroIP()
                      ? AppColors.winning.withOpacity(0.12)
                      : AppColors.losing.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isHeroIP() ? AppColors.winning : AppColors.losing,
                  ),
                ),
                child: Text(
                  _isHeroIP()
                      ? '✓ Juegas EN POSICIÓN (IP)'
                      : '⚠ Juegas FUERA DE POSICIÓN (OOP)',
                  style: TextStyle(
                    color: _isHeroIP() ? AppColors.winning : AppColors.losing,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Board ─────────────────────────────────────────────────────
          _boardPanel(),

          const SizedBox(height: 14),

          // ── Results ───────────────────────────────────────────────────
          if (_heroReady)
            _villainReady
                ? _EquityVsVillain(
                    hero: _hero.cast<CardModel>(),
                    villain: _villain.cast<CardModel>(),
                    board: _knownBoard,
                    heroPos: _heroPos,
                    villainPos: _villainPos,
                  )
                : _EquityVsRange(
                    hero: _hero.cast<CardModel>(),
                    board: _knownBoard,
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

  // ── Hand panel (hero or villain) ────────────────────────────────────────
  Widget _handPanel({
    required String label,
    required List<CardModel?> cards,
    required TablePosition? position,
    required Color color,
    required void Function(int) onPickCard,
    required void Function(int) onClearCard,
    required void Function(TablePosition) onPickPos,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          // Position grid 3×2
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 2.2,
            children: _positions.map((p) {
              final sel = position == p;
              return GestureDetector(
                onTap: () => onPickPos(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: sel ? color : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: sel ? null : Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      _posLabels[p]!,
                      style: TextStyle(
                        color: sel ? Colors.white : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // 2 card slots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 2; i++) ...[
                _slot(cards[i], () => onPickCard(i), () => onClearCard(i)),
                if (i == 0) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Board section ───────────────────────────────────────────────────────
  Widget _boardPanel() {
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
          const Text('BOARD',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              // FLOP
              for (int i = 0; i < 3; i++) ...[
                _slot(_board[i],
                    () => _pick((c) => setState(() => _board[i] = c)),
                    () => setState(() => _board[i] = null)),
                const SizedBox(width: 5),
              ],
              // Separator
              Container(width: 1, height: 46, color: AppColors.border),
              const SizedBox(width: 5),
              // TURN
              _slot(_board[3],
                  () => _pick((c) => setState(() => _board[3] = c)),
                  () => setState(() => _board[3] = null)),
              const SizedBox(width: 5),
              // Separator
              Container(width: 1, height: 46, color: AppColors.border),
              const SizedBox(width: 5),
              // RIVER
              _slot(_board[4],
                  () => _pick((c) => setState(() => _board[4] = c)),
                  () => setState(() => _board[4] = null)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _boardLabel('FLOP', 3),
              const SizedBox(width: 5),
              Container(width: 1, height: 10),
              const SizedBox(width: 5),
              _boardLabel('TURN', 1),
              const SizedBox(width: 5),
              Container(width: 1, height: 10),
              const SizedBox(width: 5),
              _boardLabel('RIVER', 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boardLabel(String text, int slots) {
    final slotW = 46.0;
    final gapW  = 5.0;
    return SizedBox(
      width: slotW * slots + gapW * (slots - 1),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 8, letterSpacing: 1)),
    );
  }

  Widget _slot(CardModel? card, VoidCallback onTap, VoidCallback onClear) {
    return GestureDetector(
      onTap: card == null ? onTap : onClear,
      child: card != null
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                CardWidget(card: card, width: 44, height: 63),
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: AppColors.losing, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 9, color: Colors.white),
                  ),
                ),
              ],
            )
          : Container(
              width: 44,
              height: 63,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.accent.withOpacity(0.35), width: 1.2),
              ),
              child: const Icon(Icons.add, color: AppColors.accent, size: 18),
            ),
    );
  }

  void _pick(void Function(CardModel) assign) {
    final used = _usedCards;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(I18n.t('sim_pick'),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final suit in Suit.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int r = 14; r >= 2; r--)
                          Builder(builder: (_) {
                            final c = CardModel(rank: r, suit: suit);
                            final taken = used.any(
                                (u) => u.rank == c.rank && u.suit == c.suit);
                            return GestureDetector(
                              onTap: taken
                                  ? null
                                  : () {
                                      setState(() => assign(c));
                                      Navigator.pop(ctx);
                                    },
                              child: Opacity(
                                opacity: taken ? 0.22 : 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: CardWidget(card: c, width: 33, height: 47),
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

// ── Equity vs specific villain ──────────────────────────────────────────────
class _EquityVsVillain extends StatelessWidget {
  final List<CardModel> hero;
  final List<CardModel> villain;
  final List<CardModel> board;
  final TablePosition? heroPos;
  final TablePosition? villainPos;

  const _EquityVsVillain({
    required this.hero,
    required this.villain,
    required this.board,
    this.heroPos,
    this.villainPos,
  });

  @override
  Widget build(BuildContext context) {
    final heroEq = EquityCalculator.calculateVsVillain(
        heroCards: hero, villainCards: villain, communityCards: board);
    final villEq = 1.0 - heroEq;

    final streetLabel = switch (board.length) {
      0 => 'PREFLOP',
      3 => 'FLOP',
      4 => 'TURN',
      _ => 'RIVER',
    };

    final analysis = board.length >= 3
        ? HandStrengthAnalysis.analyze(hero, board)
        : null;
    final texture  = board.length >= 3 ? BoardTexture.analyze(board) : null;

    final heroColor = heroEq > 0.55
        ? AppColors.winning
        : heroEq < 0.45
            ? AppColors.losing
            : AppColors.gold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: heroColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EQUIDAD — $streetLabel',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 12),

          // ── Equity bar hero vs villain ───────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  Expanded(
                    flex: (heroEq * 1000).round(),
                    child: Container(
                      color: AppColors.accent,
                      child: Center(
                        child: Text('${(heroEq * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: (villEq * 1000).round(),
                    child: Container(
                      color: AppColors.losing,
                      child: Center(
                        child: Text('${(villEq * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TÚ${heroPos != null ? " (${_posLabel(heroPos!)})" : ""}',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              Text('RIVAL${villainPos != null ? " (${_posLabel(villainPos!)})" : ""}',
                  style: const TextStyle(
                      color: AppColors.losing,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),

          if (analysis != null && texture != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _tag('Tu mano: ${_bucketLabel(analysis.bucket)}', AppColors.accent),
                if (analysis.flushDraw)
                  _tag(
                    analysis.nutFlushDraw
                        ? 'Proyecto de color (al as)'
                        : 'Proyecto de color',
                    AppColors.suitDiamonds,
                  ),
                if (analysis.openEnded)
                  _tag('Proyecto abierto de escalera', AppColors.suitClubs),
                if (analysis.gutshot) _tag('Gutshot', AppColors.gtoMarginal),
                if (analysis.outs > 0)
                  _tag(
                    '${analysis.outs} outs (~${(analysis.drawEquity * 100).toStringAsFixed(0)}% regla 2/4)',
                    AppColors.textSecondary,
                  ),
                _tag(_textureName(texture), AppColors.textMuted),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _posLabel(TablePosition p) {
    switch (p) {
      case TablePosition.utg: return 'UTG';
      case TablePosition.mp:  return 'MP';
      case TablePosition.co:  return 'CO';
      case TablePosition.btn: return 'BTN';
      case TablePosition.sb:  return 'SB';
      case TablePosition.bb:  return 'BB';
    }
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  String _bucketLabel(HandBucket b) {
    switch (b) {
      case HandBucket.nuts:        return 'Nuts / casi nuts';
      case HandBucket.strongValue: return 'Valor fuerte';
      case HandBucket.mediumValue: return 'Valor medio';
      case HandBucket.weakShowdown:return 'Showdown débil';
      case HandBucket.comboDraw:   return 'Combo draw';
      case HandBucket.strongDraw:  return 'Proyecto fuerte';
      case HandBucket.weakDraw:    return 'Proyecto débil';
      case HandBucket.air:         return 'Aire';
    }
  }

  String _textureName(BoardTexture t) {
    if (t.monotone) return 'Board monocolor';
    if (t.wetness > 0.55) return 'Board húmedo/coordinado';
    if (t.wetness < 0.35) return 'Board seco';
    return 'Board medio';
  }
}

// ── Equity vs random range (no villain cards picked) ───────────────────────
class _EquityVsRange extends StatefulWidget {
  final List<CardModel> hero;
  final List<CardModel> board;

  const _EquityVsRange({required this.hero, required this.board});

  @override
  State<_EquityVsRange> createState() => _EquityVsRangeState();
}

class _EquityVsRangeState extends State<_EquityVsRange> {
  int _opponents = 1;

  @override
  Widget build(BuildContext context) {
    final equity = EquityCalculator.calculate(
      heroCards: widget.hero,
      communityCards: widget.board,
      numOpponents: _opponents,
      simulations: 600,
    );
    final streetLabel = switch (widget.board.length) {
      0 => 'PREFLOP',
      3 => 'FLOP',
      4 => 'TURN',
      _ => 'RIVER',
    };
    final analysis = widget.board.length >= 3
        ? HandStrengthAnalysis.analyze(widget.hero, widget.board)
        : null;
    final texture =
        widget.board.length >= 3 ? BoardTexture.analyze(widget.board) : null;
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
          Text(I18n.t('sim_equity_in', {'s': streetLabel, 'n': '$_opponents'}),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 6),
          // Hint to add villain hand
          const Text('Añade la mano del rival para ver equidad exacta',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${(equity * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    color: eqColor, fontSize: 36, fontWeight: FontWeight.w900),
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
          const SizedBox(height: 10),
          // Opponent count
          Row(
            children: [
              Text(I18n.t('sim_opponents'),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              for (int n = 1; n <= 5; n++)
                GestureDetector(
                  onTap: () => setState(() => _opponents = n),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _opponents == n
                          ? AppColors.accent
                          : AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$n',
                          style: TextStyle(
                            color: _opponents == n
                                ? Colors.black
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          )),
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
                if (analysis.flushDraw)
                  _tag(
                    analysis.nutFlushDraw
                        ? 'Proyecto de color (al as)'
                        : 'Proyecto de color',
                    AppColors.suitDiamonds,
                  ),
                if (analysis.openEnded)
                  _tag('Proyecto abierto de escalera', AppColors.suitClubs),
                if (analysis.gutshot) _tag('Gutshot', AppColors.gtoMarginal),
                if (analysis.outs > 0)
                  _tag(
                    '${analysis.outs} outs (~${(analysis.drawEquity * 100).toStringAsFixed(0)}% regla 2/4)',
                    AppColors.textSecondary,
                  ),
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

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  String _bucketLabel(HandBucket b) {
    switch (b) {
      case HandBucket.nuts:        return 'Nuts / casi nuts';
      case HandBucket.strongValue: return 'Valor fuerte';
      case HandBucket.mediumValue: return 'Valor medio';
      case HandBucket.weakShowdown:return 'Showdown débil';
      case HandBucket.comboDraw:   return 'Combo draw';
      case HandBucket.strongDraw:  return 'Proyecto fuerte';
      case HandBucket.weakDraw:    return 'Proyecto débil';
      case HandBucket.air:         return 'Aire';
    }
  }
}
