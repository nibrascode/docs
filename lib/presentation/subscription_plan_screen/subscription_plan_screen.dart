import '../../services/billing_service.dart';
import '../../l10n/ui_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './widgets/plan_page_view_widget.dart';
import './widgets/pricing_header_widget.dart';
import '../../theme/app_theme.dart';
import '../../services/premium_service.dart';

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
    _loadPrices();
  }

  List<PlanModel> get _plans => [
    PlanModel(
      id: 'free',
      name: tr('Free'),
      description: tr('Start writing — daily limits.'),
      price: tr('Free'),
      period: tr('forever'),
      iconEmoji: '📝',
      accentColor: AppTheme.gold,
      bgGradientStart: const Color(0xFF1A2540),
      bgGradientEnd: const Color(0xFF0D1B3E),
      features: [
        PlanFeature(label: tr('3 new documents per day'), included: true),
        PlanFeature(label: tr('Up to 20 pages per document'), included: true),
        PlanFeature(label: tr('All editing features'), included: true),
        PlanFeature(
          label: tr('PDF / Word / EPUB / TXT export'),
          included: true,
        ),
        PlanFeature(
          label: tr('Unlimited documents and pages'),
          included: false,
        ),
        PlanFeature(label: tr('Premium book covers'), included: false),
      ],
      isPopular: false,
    ),
    PlanModel(
      id: 'pro',
      name: 'Pro',
      description: tr('Unlimited writing. Premium covers not included.'),
      price: _price('pro', r'$1.99'),
      period:
          tr('/mo') +
          ' · ' +
          _price('pro', r'$14.99', annual: true) +
          tr('/yr'),
      iconEmoji: '⚡',
      accentColor: AppTheme.goldLight,
      bgGradientStart: const Color(0xFF1E2D50),
      bgGradientEnd: const Color(0xFF0D1B3E),
      features: [
        PlanFeature(label: tr('Unlimited documents and pages'), included: true),
        PlanFeature(label: tr('All editing features'), included: true),
        PlanFeature(
          label: tr('PDF / Word / EPUB / TXT export'),
          included: true,
        ),
        PlanFeature(
          label: tr('Cloud sync with Google account'),
          included: true,
        ),
        PlanFeature(label: tr('Premium book covers'), included: false),
      ],
      isPopular: true,
    ),
    PlanModel(
      id: 'ultra',
      name: 'Ultra',
      description: tr('Everything unlocked, including premium covers.'),
      price: _price('ultra', r'$3.99'),
      period:
          tr('/mo') +
          ' · ' +
          _price('ultra', r'$29.99', annual: true) +
          tr('/yr'),
      iconEmoji: '🚀',
      accentColor: AppTheme.gold,
      bgGradientStart: const Color(0xFF243055),
      bgGradientEnd: const Color(0xFF0D1B3E),
      features: [
        PlanFeature(label: tr('Unlimited documents and pages'), included: true),
        PlanFeature(label: tr('All editing features'), included: true),
        PlanFeature(
          label: tr('PDF / Word / EPUB / TXT export'),
          included: true,
        ),
        PlanFeature(
          label: tr('Cloud sync with Google account'),
          included: true,
        ),
        PlanFeature(label: tr('Premium book covers'), included: true),
      ],
      isPopular: false,
    ),
  ];

  final Map<String, String> _live = {};

  String _price(String plan, String fallback, {bool annual = false}) =>
      _live[BillingService.packageId(plan, annual: annual)] ?? fallback;

  Future<void> _loadPrices() async {
    for (final plan in ['pro', 'ultra']) {
      for (final annual in [false, true]) {
        try {
          final pkg = await BillingService.instance.package(
            plan,
            annual: annual,
          );
          if (pkg != null) _live[pkg.identifier] = pkg.storeProduct.priceString;
        } catch (_) {}
      }
    }
    if (mounted) setState(() {});
  }

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
                  TextButton(
                    onPressed: _restore,
                    child: Text(
                      tr('Restore purchases'),
                      style: TextStyle(color: AppTheme.goldLight),
                    ),
                  ),
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

  Future<void> _onSubscribeTap(PlanModel plan) async {
    if (plan.id == 'free') {
      context.pop();
      return;
    }
    final annual = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '${plan.name} — ${tr('Monthly')} · ${_price(plan.id, plan.id == 'pro' ? r'$1.99' : r'$3.99')}',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              title: Text(
                '${plan.name} — ${tr('Yearly')} · ${_price(plan.id, plan.id == 'pro' ? r'$14.99' : r'$29.99', annual: true)}',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (annual == null || !mounted) return;
    await _launchPayment(plan, annual: annual);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _launchPayment(PlanModel plan, {bool annual = false}) async {
    try {
      if (!BillingService.instance.available) {
        await BillingService.instance.init();
      }
      if (!BillingService.instance.available) {
        _snack(
          tr(
            'Billing unavailable. Check Google Play and internet, then try again.',
          ),
        );
        return;
      }
      final pkg = await BillingService.instance.package(
        plan.id,
        annual: annual,
      );
      if (pkg == null) {
        _snack(
          tr('This plan is not available right now. Please try again later.'),
        );
        return;
      }
      final ok = await BillingService.instance.buy(plan.id, annual: annual);
      if (ok) {
        _snack(tr('Subscription active. Thank you!'));
        if (mounted) context.pop();
      }
    } catch (e) {
      _snack('${tr('Purchase failed. Please try again.')} ($e)');
    }
  }

  Future<void> _restore() async {
    try {
      if (!BillingService.instance.available)
        await BillingService.instance.init();
      if (!BillingService.instance.available) {
        _snack(
          tr(
            'Billing unavailable. Check Google Play and internet, then try again.',
          ),
        );
        return;
      }
      final t = await BillingService.instance.restore();
      _snack(
        t == PlanTier.free
            ? tr('No active subscription found.')
            : tr('Subscription restored.'),
      );
    } catch (_) {
      _snack(tr('Purchase failed. Please try again.'));
    }
  }
}
