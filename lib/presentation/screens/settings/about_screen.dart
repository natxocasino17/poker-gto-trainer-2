import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/zeros_avatar.dart';

/// "Acerca de" — app identity, version, credits and links.
/// NOTE: author/contact/links are placeholders until the owner provides them.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // TODO(owner): replace with the real values you send me.
  static const String appName = 'EL PUXI · GTO Poker Trainer';
  static const String version = '1.0';
  static const String author = 'natxocasino17';
  static const String contact = '';
  static const List<(String, String)> links = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Acerca de',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          const Center(child: ZerosAvatar(size: 84)),
          const SizedBox(height: 16),
          const Center(
            child: Text(appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Versión $version',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          const SizedBox(height: 28),
          _card(
            'Entrenador GTO de poker con EL PUXI como coach: análisis en vivo '
            'por calle, revisión mano por mano y rivales inspirados en leyendas.',
          ),
          const SizedBox(height: 16),
          _row(Icons.person_outline, 'Autor', author),
          if (contact.isNotEmpty) _row(Icons.mail_outline, 'Contacto', contact),
          for (final l in links) _linkRow(context, l.$1, l.$2),
          const SizedBox(height: 24),
          const Text('CRÉDITOS',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _card('Diseño, motor GTO y coach EL PUXI. Hecho con Flutter.'),
          const SizedBox(height: 28),
          const Center(
            child: Text('Juega responsable · solo dinero ficticio',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _card(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.45)),
      );

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 12),
            Text('$label: ',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _linkRow(BuildContext context, String label, String url) => InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Enlace copiado: $url')),
          );
        },
        child: _row(Icons.link, label, url),
      );
}
