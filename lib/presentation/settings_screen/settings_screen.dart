import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../l10n/app_localizations.dart';
import '../../services/doc_import_service.dart';
import '../../services/local_docs_cache.dart';
import '../../services/mobile_export_service.dart';
import '../../widgets/language_selector_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String t(String az, String en, String ru, String ar) => l10n.t(az: az, en: en, ru: ru, ar: ar);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        iconTheme: const IconThemeData(color: AppTheme.goldLight),
        title: Text(
          t('Parametrlər', 'Settings', 'Настройки', 'الإعدادات'),
          style: const TextStyle(color: AppTheme.goldLight, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: const [LanguageSelectorWidget()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppHeader(context),
            const SizedBox(height: 24),
            _buildSectionTitle(t('Məlumatlar', 'Data', 'Данные', 'البيانات')),
            _buildTile(
              context,
              icon: Icons.backup_rounded,
              iconColor: const Color(0xFF34D399),
              title: t('Ehtiyat nüsxə çıxar', 'Back up all documents', 'Резервная копия', 'نسخ احتياطي'),
              subtitle: t('Bütün sənədlər bir JSON faylında', 'All documents in one JSON file', 'Все документы в одном JSON', 'كل المستندات في ملف JSON'),
              onTap: () async {
                final json = await LocalDocsCache.exportAll();
                final d = DateTime.now();
                final name = 'nibras-docs-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
                await MobileExportService.shareFile(Uint8List.fromList(utf8.encode(json)), name, 'application/json');
              },
            ),
            _buildTile(
              context,
              icon: Icons.restore_rounded,
              iconColor: const Color(0xFF60A5FA),
              title: t('Ehtiyat nüsxədən bərpa et', 'Restore from backup', 'Восстановить из копии', 'استعادة من نسخة'),
              subtitle: t('Mövcud sənədlər silinmir', 'Existing documents are kept', 'Существующие документы сохраняются', 'لا تُحذف المستندات الحالية'),
              onTap: () async {
                try {
                  final n = await DocImportService.pickAndRestoreBackup();
                  if (n == null || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(t('$n sənəd bərpa olundu', '$n documents restored', 'Восстановлено: $n', 'تمت استعادة $n'))));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(t('Bu fayl ehtiyat nüsxə deyil', 'This file is not a backup', 'Это не резервная копия', 'هذا الملف ليس نسخة احتياطية'))));
                }
              },
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(t('Abunəlik', 'Subscription', 'Подписка', 'الاشتراك')),
            _buildTile(
              context,
              icon: Icons.workspace_premium_rounded,
              iconColor: AppTheme.gold,
              title: t('Premium planlar', 'Premium plans', 'Премиум', 'الخطط المميزة'),
              subtitle: t('İndi bütün alətlər pulsuz açıqdır', 'All tools are free for now', 'Сейчас все инструменты бесплатны', 'كل الأدوات مجانية حالياً'),
              onTap: () => context.push(AppRoutes.subscriptionPlanScreen),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(t('Hüquqi', 'Legal', 'Правовое', 'قانوني')),
            _buildTile(
              context,
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF60A5FA),
              title: t('Məxfilik siyasəti', 'Privacy policy', 'Политика конфиденциальности', 'سياسة الخصوصية'),
              subtitle: t('Məlumatlarınızın necə qorunduğunu öyrənin', 'How your data is protected', 'Как защищены ваши данные', 'كيف نحمي بياناتك'),
              onTap: () => context.push(AppRoutes.privacyPolicyScreen),
            ),
            _buildTile(
              context,
              icon: Icons.gavel_rounded,
              iconColor: const Color(0xFF34D399),
              title: t('İstifadə şərtləri', 'Terms of service', 'Условия использования', 'شروط الاستخدام'),
              subtitle: t('Xidmət şərtləri', 'Terms of the service', 'Условия сервиса', 'شروط الخدمة'),
              onTap: () => context.push(AppRoutes.termsOfServiceScreen),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(t('Tətbiq haqqında', 'About', 'О приложении', 'حول التطبيق')),
            _buildInfoTile(t('Tətbiq adı', 'App name', 'Название', 'الاسم'), 'Nibras Docs'),
            _buildInfoTile(t('Versiya', 'Version', 'Версия', 'الإصدار'), '1.1.0'),
            _buildInfoTile(t('Əlaqə', 'Contact', 'Контакт', 'التواصل'), 'nibrascode@gmail.com'),
            _buildInfoTile(t('Sayt', 'Website', 'Сайт', 'الموقع'), 'NibrasCode.com'),
            if (_signedIn()) ...[
              const SizedBox(height: 16),
              _buildSectionTitle(t('Hesab', 'Account', 'Аккаунт', 'الحساب')),
              _buildLogoutTile(context),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  bool _signedIn() {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Widget _buildAppHeader(BuildContext context) {
    return Container(
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/b7c8f687-0142-455b-9d2d-4f9b3b19f58a__2_-1789309184322.jpg',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: AppTheme.gold,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nibras Docs',
                style: TextStyle(
                  color: AppTheme.goldLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Sənəd idarəetmə platforması',
                style: TextStyle(color: Color(0xFF8899BB), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.gold,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineDark),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE8EAF6),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF8899BB), fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppTheme.outlineDark,
          size: 14,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8899BB), fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8EAF6),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(80)),
      ),
      child: ListTile(
        onTap: () async {
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (_) {}
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Çıxış edildi. Sənədlər bu cihazda qalır.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
        ),
        title: const Text(
          'Çıxış',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          'Hesabdan çıxış edin',
          style: TextStyle(color: Color(0xFF8899BB), fontSize: 12),
        ),
      ),
    );
  }
}
