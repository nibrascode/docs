import 'package:flutter/material.dart';
import '../subscription_plan_screen.dart';
import '../../../theme/app_theme.dart';

class PlanCardWidget extends StatelessWidget {
  final PlanModel plan;
  final VoidCallback onSubscribeTap;

  const PlanCardWidget({
    required this.plan,
    required this.onSubscribeTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [plan.bgGradientStart, plan.bgGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: plan.accentColor.withAlpha(102), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: plan.accentColor.withAlpha(40),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: [
            if (plan.isPopular)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.gold, AppTheme.goldLight],
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Ən Populyar',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            // Icon container
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: plan.accentColor.withAlpha(31),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: plan.accentColor.withAlpha(102),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  plan.iconEmoji,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              plan.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: plan.accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              plan.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8899BB),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Price row with dividers
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: plan.accentColor.withAlpha(51),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Text(
                        plan.price,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: plan.accentColor,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (plan.period != 'həmişəlik')
                        Text(
                          plan.period,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8899BB),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: plan.accentColor.withAlpha(51),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Feature list
            ...plan.features.map(
              (f) =>
                  _FeatureRowWidget(feature: f, accentColor: plan.accentColor),
            ),
            const Spacer(),
            const SizedBox(height: 16),
            // CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSubscribeTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: plan.accentColor,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  plan.id == 'free'
                      ? 'Pulsuz Başla'
                      : '${plan.name} Planını Seç',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRowWidget extends StatelessWidget {
  final PlanFeature feature;
  final Color accentColor;

  const _FeatureRowWidget({required this.feature, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: feature.included
                  ? accentColor.withAlpha(51)
                  : AppTheme.outlineDark,
              shape: BoxShape.circle,
            ),
            child: Icon(
              feature.included ? Icons.check_rounded : Icons.close_rounded,
              size: 12,
              color: feature.included ? accentColor : const Color(0xFF4A5A7A),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            feature.label,
            style: TextStyle(
              fontSize: 12,
              color: feature.included
                  ? const Color(0xFFE8EAF6)
                  : const Color(0xFF4A5A7A),
              fontWeight: feature.included ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
