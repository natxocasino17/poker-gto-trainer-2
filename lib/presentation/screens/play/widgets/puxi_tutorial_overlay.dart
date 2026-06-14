import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../widgets/zeros_avatar.dart';

/// First-launch tutorial narrated by EL PUXI. Skippable at any point; calls
/// [onDone] when finished or skipped (the provider persists "seen").
class PuxiTutorialOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const PuxiTutorialOverlay({super.key, required this.onDone});

  @override
  State<PuxiTutorialOverlay> createState() => _PuxiTutorialOverlayState();
}

class _PuxiTutorialOverlayState extends State<PuxiTutorialOverlay> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      '¡Hola! Soy EL PUXI 🐧',
      'Tu coach de poker GTO. Te enseño a tomar las decisiones +EV en cada '
          'mano, calle por calle.'
    ),
    (
      'Juega y pídeme consejo',
      'En la mesa, toca mi botón GTO en cualquier momento: leo el board, tu '
          'mano, posición, multiway, iniciativa y rival, y te digo la mejor '
          'jugada con su porqué.'
    ),
    (
      'Revisa tus manos',
      'En ANALIZAR repaso cada mano con su análisis postflop completo: plan de '
          'SPR, bloqueadores y spots de farol, leyendo tus cartas reales.'
    ),
    (
      'Mejora cada día',
      'Activa el Modo Trainer para puntuar tus decisiones en vivo, sube tu '
          'racha, completa objetivos y desbloquea logros en Progreso.'
    ),
  ];

  void _next() {
    if (_page >= _pages.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Material(
      color: Colors.black.withOpacity(0.86),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text('Omitir',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ZerosAvatar(size: 110),
                        const SizedBox(height: 28),
                        Text(p.$1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 16),
                        Text(p.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.accent : AppColors.textMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF06231E),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _next,
                  child: Text(last ? '¡Empezar!' : 'Siguiente',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
