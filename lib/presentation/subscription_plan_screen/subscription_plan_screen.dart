import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './widgets/plan_page_view_widget.dart';
import './widgets/pricing_header_widget.dart';
import '../../theme/app_theme.dart';

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
}
