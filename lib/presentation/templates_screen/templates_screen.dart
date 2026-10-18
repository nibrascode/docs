import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.templates,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t(
                  az: 'Şablonlar hələ yoxdur',
                  en: 'No templates yet',
                  ru: 'Шаблонов пока нет',
                  ar: 'لا توجد قوالب بعد',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t(
                  az: 'Bu bölmə sonra doldurulacaq.',
                  en: 'This section will be filled later.',
                  ru: 'Этот раздел будет заполнен позже.',
                  ar: 'سيتم ملء هذا القسم لاحقاً.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
