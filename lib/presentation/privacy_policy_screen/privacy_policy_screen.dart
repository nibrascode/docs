import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          'Privacy Policy',
          style: TextStyle(
            color: AppTheme.goldLight,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Toplanılan Məlumatlar',
              'Nibras Docs tətbiqi aşağıdakı məlumatları toplaya bilər:\n\n'
                  '• Hesab məlumatları: e-poçt ünvanı, istifadəçi adı\n'
                  '• Sənəd məzmunu: yaratdığınız və redaktə etdiyiniz sənədlər\n'
                  '• İstifadə məlumatları: tətbiqin necə istifadə edildiyi haqqında anonim statistika\n'
                  '• Cihaz məlumatları: cihaz növü, əməliyyat sistemi versiyası',
            ),
            _buildSection(
              context,
              '2. Məlumatların İstifadəsi',
              'Toplanılan məlumatlar aşağıdakı məqsədlər üçün istifadə edilir:\n\n'
                  '• Hesabınızın idarə edilməsi və autentifikasiyası\n'
                  '• Sənədlərinizin cihazlar arasında sinxronizasiyası\n'
                  '• Tətbiqin funksionallığının yaxşılaşdırılması\n'
                  '• Texniki dəstəyin təmin edilməsi\n'
                  '• Abunəlik ödənişlərinin emalı',
            ),
            _buildSection(
              context,
              '3. Məlumatların Saxlanması',
              'Məlumatlarınız Supabase infrastrukturundan istifadə edərək şifrəli şəkildə saxlanılır. '
                  'Hesabınızı silsəniz, bütün şəxsi məlumatlarınız 30 gün ərzində silinəcəkdir.',
            ),
            _buildSection(
              context,
              '4. Üçüncü Tərəf Xidmətlər',
              'Nibras Docs aşağıdakı üçüncü tərəf xidmətlərindən istifadə edir:\n\n'
                  '• Supabase — verilənlər bazası və autentifikasiya\n'
                  '• Google Play Billing — abunəlik ödənişləri\n'
                  '• Supabase — bulud sync (istəyə bağlı hesab)\n\n'
                  'Bu xidmətlər öz məxfilik siyasətlərinə malikdir.',
            ),
            _buildSection(
              context,
              '5. Uşaqların Məxfiliyi',
              'Nibras Docs 13 yaşdan kiçik uşaqlardan şəxsi məlumat toplamır. '
                  'Tətbiqimiz 13+ yaş qrupu üçün nəzərdə tutulmuşdur.',
            ),
            _buildSection(
              context,
              '6. Məlumat Təhlükəsizliyi',
              'Məlumatlarınızın qorunması üçün sənaye standartı şifrələmə və '
                  'təhlükəsizlik tədbirlərindən istifadə edirik. Bununla belə, '
                  'heç bir internet ötürülməsi 100% təhlükəsiz deyil.',
            ),
            _buildSection(
              context,
              '7. İstifadəçi Hüquqları',
              'Siz aşağıdakı hüquqlara maliksiniz:\n\n'
                  '• Məlumatlarınıza giriş hüququ\n'
                  '• Məlumatlarınızın düzəldilməsi hüququ\n'
                  '• Məlumatlarınızın silinməsi hüququ\n'
                  '• Məlumat portativliyi hüququ',
            ),
            _buildSection(
              context,
              '8. Dəyişikliklər',
              'Bu məxfilik siyasəti vaxtaşırı yenilənə bilər. '
                  'Əhəmiyyətli dəyişikliklər haqqında sizi e-poçt vasitəsilə məlumatlandıracağıq.',
            ),
            _buildSection(
              context,
              '9. Əlaqə',
              'Məxfilik siyasəti ilə bağlı suallarınız üçün bizimlə əlaqə saxlayın:',
            ),
            _buildContactCard(context),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Son yenilənmə: Sentyabr 2026',
                style: TextStyle(
                  color: AppTheme.goldLight.withAlpha(100),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
            child: const Icon(
              Icons.shield_rounded,
              color: AppTheme.gold,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nibras Docs',
                  style: TextStyle(
                    color: AppTheme.goldLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Məxfiliyiniz bizim üçün önəmlidir. Bu siyasət məlumatlarınızın necə toplandığını və istifadə edildiyini izah edir.',
                  style: TextStyle(
                    color: const Color(0xFF8899BB),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.goldLight,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFFCCD5EE),
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: AppTheme.outlineDark, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_rounded, color: AppTheme.gold, size: 20),
          const SizedBox(width: 12),
          const Text(
            'nibrascode@gmail.com',
            style: TextStyle(
              color: AppTheme.goldLight,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
