import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'legal_texts.dart';

/// Privacy policy / terms page in the current UI language.
class LegalScreen extends StatelessWidget {
  final LegalDoc Function(AppLanguage) doc;
  final IconData icon;
  const LegalScreen({super.key, required this.doc, required this.icon});

  @override
  Widget build(BuildContext context) {
    final d = doc(AppLocalizations.of(context).language);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppTheme.goldLight,
          onPressed: () => context.pop(),
        ),
        title: Text(
          d.screenTitle,
          style: const TextStyle(color: AppTheme.goldLight, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.surfaceDark, AppTheme.surfaceVariantDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gold.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppTheme.gold, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nibras Docs',
                            style: TextStyle(color: AppTheme.goldLight, fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(d.intro, style: const TextStyle(color: Color(0xFF8899BB), fontSize: 12, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (final s in d.sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style: const TextStyle(color: AppTheme.goldLight, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(s.body, style: const TextStyle(color: Color(0xFFCCD5EE), fontSize: 13, height: 1.7)),
                    const SizedBox(height: 8),
                    const Divider(color: AppTheme.outlineDark, thickness: 1),
                  ],
                ),
              ),
            Center(
              child: Text(
                '${d.updated}  ·  ${LegalTexts.contact}',
                style: TextStyle(color: AppTheme.goldLight.withAlpha(100), fontSize: 12),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
