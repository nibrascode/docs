import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './widgets/plan_page_view_widget.dart';
import './widgets/pricing_header_widget.dart';
import '../../theme/app_theme.dart';
import '../../services/premium_service.dart';
import '../../l10n/app_localizations.dart';

class PlanModel {
  final String id;
  final String name;
  final String description;
  final String price;
  final String period;
  final String iconEmoji;
  final Color accentColor;
  final Color bgGradientStart;
  final Color bgGradientEnd;
  final List<PlanFeature> features;
  final bool isPopular;

  const PlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.period,
    required this.iconEmoji,
    required this.accentColor,
    required this.bgGradientStart,
    required this.bgGradientEnd,
    required this.features,
    required this.isPopular,
  });
}

class PlanFeature {
  final String label;
  final bool included;
  const PlanFeature({required this.label, required this.included});
}

class SubscriptionPlanScreen extends StatefulWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  State<SubscriptionPlanScreen> createState() => _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState extends State<SubscriptionPlanScreen> {
  int _currentPlanIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentPlanIndex,
      viewportFraction: 0.88,
    );
  }

  static final List<PlanModel> _plans = [
    PlanModel(
      id: 'free',
      name: 'Başlanğıc',
      description:
          'Sənədlərinizi yazmaq və təşkil etmək üçün lazım olan hər şey.',
      price: 'Pulsuz',
      period: 'həmişəlik',
      iconEmoji: '📝',
      accentColor: AppTheme.gold,
      bgGradientStart: const Color(0xFF1A2540),
      bgGradientEnd: const Color(0xFF0D1B3E),
      features: const [
        PlanFeature(label: 'Up to 5 documents', included: true),
        PlanFeature(label: 'Up to 15 pages per document', included: true),
        PlanFeature(label: 'All editing features', included: true),
        PlanFeature(label: 'PDF / Word / TXT export', included: true),
        PlanFeature(label: 'Templates', included: true),
        PlanFeature(label: '150+ page books', included: false),
        PlanFeature(label: 'Unlimited documents', included: false),
      ],
      isPopular: false,
    ),
    PlanModel(
      id: 'pro',
      name: 'Pro',
      description:
          'Hər gün yazan frilanser və mütəxəssislər üçün qabaqcıl alətlər.',
      price: r'$2.75',
      period: '/ay',
      iconEmoji: '⚡',
      accentColor: AppTheme.goldLight,
      bgGradientStart: const Color(0xFF1E2D50),
      bgGradientEnd: const Color(0xFF0D1B3E),
      features: const [
        PlanFeature(label: 'Unlimited documents', included: true),
        PlanFeature(label: 'Up to 150 pages per document', included: true),
        PlanFeature(label: 'All editing features', included: true),
        PlanFeature(label: 'PDF / Word / EPUB export', included: true),
        PlanFeature(label: 'Templates & cloud save', included: true),
        PlanFeature(label: 'Books over 150 pages', included: false),
        PlanFeature(label: 'Priority support', included: false),
      ],
      isPopular: true,
    ),
    PlanModel(
      id: 'elite',
      name: 'Elite',
      description:
          'Komandalar və güclü istifadəçilər üçün tam Nibras Docs təcrübəsi.',
      price: r'$5.75',
      period: '/ay',
      iconEmoji: '🚀',
      accentColor: AppTheme.gold,
      bgGradientStart: const Color(0xFF243055),
      bgGradientEnd: const Color(0xFF0D1B3E),
      features: const [
        PlanFeature(label: 'Unlimited documents', included: true),
        PlanFeature(label: 'Unlimited page length', included: true),
        PlanFeature(label: 'All editing features', included: true),
        PlanFeature(label: 'PDF / Word / EPUB export', included: true),
        PlanFeature(label: 'Templates & cloud save', included: true),
        PlanFeature(label: 'Best for long books', included: true),
        PlanFeature(label: 'Priority support', included: true),
      ],
      isPopular: false,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PremiumService.billingEnabled) return _comingSoon(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => context.pop(),
                    color: AppTheme.goldLight,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            PricingHeaderWidget(
              currentPlanIndex: _currentPlanIndex,
              totalPlans: _plans.length,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PlanPageViewWidget(
                plans: _plans,
                pageController: _pageController,
                currentPlanIndex: _currentPlanIndex,
                onPageChanged: (index) =>
                    setState(() => _currentPlanIndex = index),
                onSubscribeTap: (plan) => _onSubscribeTap(plan),
              ),
            ),
            const SizedBox(height: 16),
            _buildPageIndicators(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_plans.length, (i) {
        final isActive = i == _currentPlanIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.gold : AppTheme.outlineDark,
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }

  void _onSubscribeTap(PlanModel plan) {
    if (plan.id == 'free') {
      context.pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${plan.name} planına abunə ol',
          style: const TextStyle(
            color: Color(0xFFE8EAF6),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '${plan.name} planına ${plan.price}${plan.period} qiymətinə abunə olmaq üzrəsiniz.\n\nGoogle Play vasitəsilə təhlükəsiz ödəniş.',
          style: const TextStyle(color: Color(0xFF8899BB)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ləğv et', style: TextStyle(color: AppTheme.gold)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _launchPayment(plan);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.primary,
            ),
            child: Text('${plan.name} planını seç'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPayment(PlanModel plan) async {
    if (plan.id == 'free') return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Abunəlik tezliklə RevenueCat ilə qoşulacaq. İndi bütün yazı alətləri açıqdır.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Premium is not on sale yet: every feature is free. Flip
  /// PremiumService.billingEnabled to bring the plans back.
  Widget _comingSoon(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget perk(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(i, color: AppTheme.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 15))),
          ]),
        );
    return Scaffold(
      key: const ValueKey('premium-coming-soon'),
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: AppTheme.goldLight,
                  onPressed: () => context.pop(),
                ),
              ),
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFE8C97A), Color(0xFFC9A84C), Color(0xFF8A6A1A)]),
                  boxShadow: [BoxShadow(color: AppTheme.gold.withAlpha(90), blurRadius: 30)],
                ),
                child: const Icon(Icons.workspace_premium_rounded, size: 52, color: Color(0xFF0D1B3E)),
              ),
              const SizedBox(height: 24),
              const Text('Nibras Premium',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFE8C97A), fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.gold),
                  ),
                  child: Text(l.t(az: 'Tezliklə', en: 'Coming soon', ru: 'Скоро', ar: 'قريباً'),
                      style: const TextStyle(color: Color(0xFFE8C97A), fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l.t(
                  az: 'Hazırda bütün alətlər hamı üçün pulsuzdur. Premium planlar tezliklə əlavə olunacaq.',
                  en: 'All tools are free for everyone right now. Premium plans are coming soon.',
                  ru: 'Сейчас все инструменты бесплатны. Премиум-планы появятся скоро.',
                  ar: 'كل الأدوات مجانية للجميع حالياً. الخطط المميزة قادمة قريباً.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 24),
              perk(Icons.all_inclusive_rounded, l.t(az: 'Limitsiz sənəd və səhifə', en: 'Unlimited documents and pages', ru: 'Без лимита документов и страниц', ar: 'مستندات وصفحات بلا حدود')),
              perk(Icons.picture_as_pdf_rounded, l.t(az: 'PDF, DOCX, EPUB ixracı', en: 'PDF, DOCX, EPUB export', ru: 'Экспорт PDF, DOCX, EPUB', ar: 'تصدير PDF وDOCX وEPUB')),
              perk(Icons.auto_stories_rounded, l.t(az: 'Bütün üzlüklər və kitab alətləri', en: 'All covers and book tools', ru: 'Все обложки и инструменты', ar: 'كل الأغلفة وأدوات الكتاب')),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
