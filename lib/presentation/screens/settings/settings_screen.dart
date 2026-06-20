import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/utils/hand_export.dart';
import '../../providers/game_provider.dart';
import '../heatmap/range_heatmap_screen.dart';
import '../progress/progress_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Ajustes',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _section('JUEGO'),
          _tile(
            title: 'Dificultad de los oponentes',
            subtitle: 'Fácil = pasivos y predecibles · Difícil = pagan fino y equilibrados',
            child: Wrap(
              spacing: 8,
              children: [
                for (final e in const ['Fácil', 'Media', 'Difícil'].asMap().entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: gp.difficulty == e.key,
                    onSelected: (_) => gp.setDifficulty(e.key),
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surfaceElevated,
                    labelStyle: TextStyle(
                      color: gp.difficulty == e.key
                          ? const Color(0xFF06231E)
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          _switchTile(
            title: 'Modo Trainer',
            subtitle: 'EL PUXI puntúa cada decisión vs GTO con el coste en EV, en vivo',
            value: gp.trainerMode,
            onChanged: gp.setTrainerMode,
          ),
          _switchTile(
            title: 'Mostrar fichas en BB',
            subtitle: 'Stacks y botes en big blinds en vez de dólares',
            value: gp.displayInBB,
            onChanged: (_) => gp.toggleDisplayUnits(),
          ),
          _switchTile(
            title: 'Sonido',
            subtitle: 'Efectos de fichas, cartas y avisos en la mesa',
            value: gp.soundEnabled,
            onChanged: gp.setSoundEnabled,
          ),
          _tile(
            title: I18n.t('language'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in I18n.supported.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: gp.localeCode == e.key,
                    onSelected: (_) => gp.setLocale(e.key),
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surfaceElevated,
                    labelStyle: TextStyle(
                      color: gp.localeCode == e.key
                          ? const Color(0xFF06231E)
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),

          _section('MESA  (se aplica al empezar una nueva sesión)'),
          _valueTile(
            title: 'Ciegas',
            value: '\$${_fmt(gp.smallBlind)} / \$${_fmt(gp.bigBlind)}',
            onTap: () => _editBlinds(context, gp),
          ),
          _valueTile(
            title: 'Stack inicial (buy-in)',
            value: '\$${_fmt(gp.startingStack)}',
            onTap: () async {
              final v = await _promptNumber(
                  context, 'Stack inicial (\$)', gp.startingStack);
              if (v != null) gp.setStartingStack(v);
            },
          ),

          _section('REBUY'),
          _switchTile(
            title: 'Auto-rebuy',
            subtitle: 'Recompra automática cuando te quedas sin fichas',
            value: gp.autoRebuy,
            onChanged: gp.setAutoRebuy,
          ),
          _valueTile(
            title: 'Monto de rebuy',
            value: '\$${_fmt(gp.rebuyAmount)}',
            enabled: gp.autoRebuy,
            onTap: () async {
              final v = await _promptNumber(
                  context, 'Monto de rebuy (\$)', gp.rebuyAmount);
              if (v != null) gp.setRebuyAmount(v);
            },
          ),

          _section('PROGRESO'),
          _valueTile(
            title: 'Objetivos, racha y logros',
            value: '',
            icon: Icons.emoji_events_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProgressScreen()),
            ),
          ),

          _section('ESTUDIO'),
          _valueTile(
            title: 'Rangos GTO (heatmap RFI)',
            value: '13×13',
            icon: Icons.grid_on,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RangeHeatmapScreen()),
            ),
          ),

          _section('DATOS'),
          _valueTile(
            title: 'Exportar historial de manos',
            value: '${gp.handHistory.length} manos',
            icon: Icons.ios_share,
            onTap: () => _exportDialog(context, gp),
          ),
          _valueTile(
            title: 'Acerca de',
            value: '',
            icon: Icons.info_outline,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ── Section + tiles ──
  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
      );

  Widget _tile({required String title, String? subtitle, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.accent,
        value: value,
        onChanged: onChanged,
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
      ),
    );
  }

  Widget _valueTile({
    required String title,
    required String value,
    VoidCallback? onTap,
    IconData? icon,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          onTap: enabled ? onTap : null,
          title: Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value.isNotEmpty)
                Text(value,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Icon(icon ?? Icons.chevron_right, color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialogs ──
  Future<void> _editBlinds(BuildContext context, GameProvider gp) async {
    final sb = await _promptNumber(context, 'Small blind (\$)', gp.smallBlind);
    if (sb == null) return;
    if (!context.mounted) return;
    final bb = await _promptNumber(context, 'Big blind (\$)', gp.bigBlind);
    if (bb == null) {
      gp.setBlinds(sb, sb * 2);
    } else {
      gp.setBlinds(sb, bb);
    }
  }

  Future<double?> _promptNumber(
      BuildContext context, String title, double initial) {
    final ctrl = TextEditingController(text: _fmt(initial));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _exportDialog(BuildContext context, GameProvider gp) {
    final logs = gp.handHistory;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Exportar historial',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '${logs.length} manos. Se copiará al portapapeles para que lo pegues donde quieras.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => _copy(ctx, HandExporter.toText(logs), 'Texto'),
            child: const Text('Texto', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => _copy(ctx, HandExporter.toJson(logs), 'JSON'),
            child: const Text('JSON', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext ctx, String data, String label) {
    Clipboard.setData(ClipboardData(text: data));
    Navigator.pop(ctx);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('$label copiado al portapapeles')),
    );
  }
}
