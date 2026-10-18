import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppTheme.goldLight,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'İstifadə Şərtləri',
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
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSection(
              '1. Qəbul',
              'Nibras Docs tətbiqindən istifadə etməklə siz bu İstifadə Şərtlərini qəbul etmiş olursunuz. '
                  'Bu şərtləri qəbul etmirsinizsə, tətbiqdən istifadə etməyin.',
            ),
            _buildSection(
              '2. Xidmət Təsviri',
              'Nibras Docs sənəd yaratma, redaktə etmə və idarə etmə platformasıdır. '
                  'Pulsuz və premium abunəlik planları mövcuddur.',
            ),
            _buildSection(
              '3. Hesab Məsuliyyəti',
              'Siz hesabınızın təhlükəsizliyindən məsulsunuz. '
                  'Hesabınızda baş verən bütün fəaliyyətlər üçün məsuliyyət daşıyırsınız. '
                  'Şübhəli fəaliyyət aşkar etsəniz, dərhal bizimlə əlaqə saxlayın.',
            ),
            _buildSection(
              '4. Qadağan Edilmiş İstifadə',
              'Aşağıdakılar qadağandır:\n\n'
                  '• Qeyri-qanuni məzmun yaratmaq\n'
                  '• Digər istifadəçilərin hüquqlarını pozmaq\n'
                  '• Tətbiqin təhlükəsizliyini pozmağa cəhd etmək\n'
                  '• Spam və ya zərərli məzmun yaymaq\n'
                  '• Müəllif hüquqlarını pozan məzmun paylaşmaq',
            ),
            _buildSection(
              '5. Premium Abunəlik',
              'Premium planlar aylıq ödəniş əsasında təqdim edilir. '
                  'Ödənişlər Lemon Squeezy vasitəsilə emal edilir. '
                  'Abunəliyi istənilən vaxt ləğv edə bilərsiniz. '
                  'Ödənilmiş dövr üçün geri ödəmə edilmir.',
            ),
            _buildSection(
              '6. Məzmun Mülkiyyəti',
              'Tətbiqdə yaratdığınız bütün sənədlər sizə məxsusdur. '
                  'Nibras Docs xidmət göstərmək üçün lazımi texniki əməliyyatları həyata keçirmək hüququna malikdir.',
            ),
            _buildSection(
              '7. Xidmətin Dayandırılması',
              'Şərtlərə riayət edilmədikdə hesabınız dayandırıla bilər. '
                  'Xidmət texniki səbəblər üzündən müvəqqəti olaraq əlçatmaz ola bilər.',
            ),
            _buildSection(
              '8. Məsuliyyətin Məhdudlaşdırılması',
              'Nibras Docs xidmətin fasiləsiz işləməsinə zəmanət vermir. '
                  'Məlumat itkisi halında məsuliyyət məhdudlaşdırılmışdır.',
            ),
            _buildSection(
              '9. Dəyişikliklər',
              'Bu şərtlər vaxtaşırı yenilənə bilər. '
                  'Dəyişikliklər haqqında e-poçt vasitəsilə məlumatlandırılacaqsınız.',
            ),
            _buildSection(
              '10. Əlaqə',
              'Suallarınız üçün: nibrascode@gmail.com',
            ),
            _buildDataSafetySection(),
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

  Widget _buildHeader() {
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
              Icons.gavel_rounded,
              color: AppTheme.gold,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nibras Docs',
                  style: TextStyle(
                    color: AppTheme.goldLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tətbiqdən istifadə etməzdən əvvəl bu şərtləri diqqətlə oxuyun.',
                  style: TextStyle(
                    color: Color(0xFF8899BB),
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

  Widget _buildSection(String title, String content) {
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
          const Divider(color: AppTheme.outlineDark, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildDataSafetySection() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.security_rounded,
                color: AppTheme.gold,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Məlumat Təhlükəsizliyi (Play Store)',
                style: TextStyle(
                  color: AppTheme.goldLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDataRow(
            Icons.person_outline,
            'Toplanılan məlumat',
            'E-poçt, istifadəçi adı, sənəd məzmunu',
          ),
          _buildDataRow(
            Icons.lock_outline,
            'Şifrələmə',
            'Bütün məlumatlar ötürülmə zamanı şifrələnir',
          ),
          _buildDataRow(
            Icons.child_care_outlined,
            'Yaş qrupu',
            '13+ (Uşaqlar üçün nəzərdə tutulmayıb)',
          ),
          _buildDataRow(
            Icons.share_outlined,
            'Paylaşım',
            'Məlumatlar üçüncü tərəflərlə paylaşılmır',
          ),
          _buildDataRow(
            Icons.delete_outline,
            'Silinmə',
            'İstifadəçi tələbi ilə məlumatlar silinir',
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.gold.withAlpha(180), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: Color(0xFF8899BB),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: Color(0xFFCCD5EE),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
