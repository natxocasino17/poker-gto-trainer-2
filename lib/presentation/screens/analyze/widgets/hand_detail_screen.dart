import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/hand_log_model.dart';
import '../../../widgets/zeros_avatar.dart';
import '../../../../core/i18n/i18n.dart';

class HandDetailScreen extends StatelessWidget {
  final HandLog log;
  const HandDetailScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(I18n.t('hand_title', {'n': log.handNumber.toString()})),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ResultBanner(log: log),
          const SizedBox(height: 16),
          _BoardSection(log: log),
          const SizedBox(height: 16),
          _AIAssistantHeader(),
          const SizedBox(height: 10),
          _PuxiSummaryCard(log: log),
          const SizedBox(height: 10),
          for (final sa in log.streetAnalyses)
            _StreetAnalysisCard(sa: sa),
          const SizedBox(height: 16),
          _AllHandsReveal(log: log),
          const SizedBox(height: 16),
          _ActionTimeline(log: log),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final HandLog log;
  const _ResultBanner({required this.log});

  @override
  Widget build(BuildContext context) {
    final won = log.humanProfit > 0;
    final cleanFold = log.isCleanFold && !won;
    final color = won
        ? AppColors.winning
        : cleanFold
            ? AppColors.neutral
            : AppColors.losing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            won
                ? Icons.emoji_events
                : cleanFold
                    ? Icons.shield_outlined
                    : Icons.trending_down,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                won
                    ? I18n.t('won_hand')
                    : cleanFold
                        ? I18n.t('clean_fold_banner')
                        : I18n.t('lost_hand'),
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                log.resultLabel,
                style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(I18n.t('winner_lbl', {'w': log.winnerName}), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              Text(I18n.t('pot_short', {'v': log.finalPot.toStringAsFixed(0)}), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              Text(log.humanHandDescription, style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoardSection extends StatelessWidget {
  final HandLog log;
  const _BoardSection({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(I18n.t('your_hand'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final c in log.humanHoleCards)
                _CardChip(card: c),
              const SizedBox(width: 12),
              const Text('→', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(width: 12),
              for (final c in log.communityCards)
                _CardChip(card: c, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  final dynamic card;
  final bool small;
  const _CardChip({required this.card, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = card;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 6, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: AppColors.cardFace,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        c.toString(),
        style: TextStyle(
          color: c.isRed ? AppColors.redSuit : AppColors.blackSuit,
          fontWeight: FontWeight.w800,
          fontSize: small ? 11 : 14,
        ),
      ),
    );
  }
}

class _AIAssistantHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ZerosAvatar(size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EL PUXI', style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              Text(I18n.t('zeros_sub'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}

/// El Puxi's overall read of the hand: a short narrative in his voice plus a
/// concrete "what you could have done better" list, derived from the per-street
/// decision quality. Purely presentational — no stored data is changed.
class _PuxiSummaryCard extends StatelessWidget {
  final HandLog log;
  const _PuxiSummaryCard({required this.log});

  ActionType _typeOf(String label) {
    if (label.startsWith('Fold')) return ActionType.fold;
    if (label.startsWith('Check')) return ActionType.check;
    if (label.startsWith('Call')) return ActionType.call;
    if (label.startsWith('Bet')) return ActionType.bet;
    if (label.startsWith('Raise')) return ActionType.raise;
    return ActionType.allIn;
  }

  /// A concrete improvement line for a sub-optimal street, or null if the
  /// decision was fine.
  String? _improve(StreetAnalysis sa) {
    if (sa.quality == DecisionQuality.optimal ||
        sa.quality == DecisionQuality.correct) {
      return null;
    }
    final eq = (sa.heroEquity * 100).toStringAsFixed(0);
    final odds = (sa.potOdds * 100).toStringAsFixed(0);
    final st = sa.street.toUpperCase();
    switch (_typeOf(sa.heroAction)) {
      case ActionType.fold:
        return '$st · Foldeaste con $eq% de equity. Con esa fuerza la jugada era continuar (call o raise), no soltar la mano.';
      case ActionType.call:
        if (sa.heroEquity < sa.potOdds) {
          return '$st · Pagaste con $eq% de equity frente a pot odds del $odds%. Sin precio, esto es fold.';
        }
        return '$st · Te limitaste a pagar una mano que pedía subir por valor. Un raise construye el bote y niega equity al rival.';
      case ActionType.check:
        return '$st · Check con $eq% de equity. Tenías para apostar por valor; dar cartas gratis es regalar EV.';
      case ActionType.bet:
      case ActionType.raise:
        return '$st · Agrediste con solo $eq% de equity. Sin bloqueadores ni proyecto, el farol es −EV; aquí check/fold rinde más.';
      case ActionType.allIn:
        return '$st · Te jugaste el stack con $eq% de equity. Demasiada varianza sin una ventaja clara.';
    }
  }

  String _narrative() {
    final blunders = log.streetAnalyses
        .where((s) => s.quality == DecisionQuality.blunder)
        .length;
    final margs = log.streetAnalyses
        .where((s) => s.quality == DecisionQuality.marginal)
        .length;
    final b = StringBuffer();
    if (log.isCleanFold) {
      b.write('Fold limpio y disciplinado: dinero ahorrado, que también es ganar. ');
    } else if (log.humanWon) {
      b.write('Te llevaste el bote (${log.resultLabel}). ');
    } else {
      b.write('Mano perdida (${log.resultLabel}). ');
    }
    if (log.humanHandDescription.isNotEmpty &&
        log.humanHandDescription != 'Fold') {
      b.write('Terminaste con ${log.humanHandDescription}. ');
    }
    if (blunders > 0) {
      b.write('Pero hubo $blunders error${blunders > 1 ? "es" : ""} grave${blunders > 1 ? "s" : ""} que te costó EV — y eso no lo perdona ni tu madre. ');
    } else if (margs > 0) {
      b.write('Jugaste decente, con $margs decisión${margs > 1 ? "es" : ""} mejorable${margs > 1 ? "s" : ""}. ');
    } else {
      b.write('Línea sólida de principio a fin. Poco que reprocharte, por una vez. ');
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final tips = log.streetAnalyses
        .map(_improve)
        .whereType<String>()
        .toList();
    final worst = log.streetAnalyses.fold<DecisionQuality>(
      DecisionQuality.optimal,
      (w, s) => s.quality.index > w.index ? s.quality : w,
    );
    final accent = switch (worst) {
      DecisionQuality.blunder => AppColors.gtoBlunder,
      DecisionQuality.marginal => AppColors.gtoMarginal,
      _ => AppColors.gtoCorrect,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.14), accent.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ZerosAvatar(size: 24),
              const SizedBox(width: 8),
              const Text('RESUMEN DE EL PUXI',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _narrative(),
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, height: 1.5),
          ),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('QUÉ PUDISTE HACER MEJOR',
                style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•',
                          style: TextStyle(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(t,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.45)),
                      ),
                    ],
                  ),
                )),
          ] else ...[
            const SizedBox(height: 8),
            const Text('✅ Nada que reprochar — así se juega.',
                style: TextStyle(
                    color: AppColors.winning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _StreetAnalysisCard extends StatelessWidget {
  final StreetAnalysis sa;
  const _StreetAnalysisCard({required this.sa});

  @override
  Widget build(BuildContext context) {
    final qColor = _qualityColor(sa.quality);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qColor.withOpacity(0.4), width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: qColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  sa.street.toUpperCase(),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: qColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: qColor),
                  ),
                  child: Text(
                    sa.qualityLabel.toUpperCase(),
                    style: TextStyle(color: qColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MetricPill(label: 'Equity', value: '${(sa.heroEquity * 100).toStringAsFixed(1)}%', color: _equityColor(sa.heroEquity)),
                    const SizedBox(width: 8),
                    if (sa.potOdds > 0)
                      _MetricPill(label: 'Pot Odds', value: '${(sa.potOdds * 100).toStringAsFixed(1)}%', color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    _MetricPill(label: I18n.t('action_lbl'), value: sa.heroAction, color: AppColors.textPrimary),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ZerosAvatar(size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sa.localizedExplanation,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _qualityColor(DecisionQuality q) {
    switch (q) {
      case DecisionQuality.optimal: return AppColors.gtoOptimal;
      case DecisionQuality.correct: return AppColors.gtoCorrect;
      case DecisionQuality.marginal: return AppColors.gtoMarginal;
      case DecisionQuality.blunder: return AppColors.gtoBlunder;
    }
  }

  Color _equityColor(double eq) {
    if (eq > 0.65) return AppColors.winning;
    if (eq > 0.40) return AppColors.gold;
    return AppColors.losing;
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AllHandsReveal extends StatelessWidget {
  final HandLog log;
  const _AllHandsReveal({required this.log});

  /// Resolves player ids (bot0, bot1...) to legend names using the
  /// hand's action history.
  String _displayName(String playerId) {
    if (playerId == 'human') return 'Tú';
    for (final a in log.actions) {
      if (a.playerId == playerId) return a.playerName;
    }
    return playerId;
  }

  @override
  Widget build(BuildContext context) {
    if (log.allHoleCards.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(I18n.t('all_hands_sd'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...log.allHoleCards.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    _displayName(e.key),
                    style: TextStyle(
                      color: e.key == 'human' ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...e.value.map((c) => _CardChip(card: c)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _ActionTimeline extends StatelessWidget {
  final HandLog log;
  const _ActionTimeline({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(I18n.t('timeline'), style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 10),
          ..._buildStreetWidgets(),
        ],
      ),
    );
  }

  List<Widget> _buildStreetWidgets() {
    const streets = ['preflop', 'flop', 'turn', 'river'];
    final widgets = <Widget>[];
    for (final street in streets) {
      final acts = log.actions.where((a) => a.street == street).toList();
      if (acts.isEmpty) continue;
      widgets.add(Text(street.toUpperCase(),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)));
      widgets.add(const SizedBox(height: 4));
      for (final a in acts) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 3),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: _actionColor(a.type), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${a.playerName}: ${a.label}',
                style: TextStyle(
                    color: a.playerId == 'human' ? AppColors.accent : AppColors.textSecondary,
                    fontSize: 11)),
          ]),
        ));
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Color _actionColor(ActionType t) {
    switch (t) {
      case ActionType.fold: return AppColors.actionFold;
      case ActionType.check: return AppColors.actionCheck;
      case ActionType.call: return AppColors.actionCall;
      case ActionType.bet:
      case ActionType.raise:
      case ActionType.allIn: return AppColors.actionRaise;
    }
  }
}
