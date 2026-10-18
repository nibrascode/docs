import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class PricingHeaderWidget extends StatelessWidget {
  final int currentPlanIndex;
  final int totalPlans;

  const PricingHeaderWidget({
    required this.currentPlanIndex,
    required this.totalPlans,
    super.key,
  });

  static const _tools = [
    _ToolItem(icon: Icons.description_outlined, label: 'Sənəd Şablonları'),
    _ToolItem(icon: Icons.calendar_month_outlined, label: 'Layihə Təqvimi'),
    _ToolItem(icon: Icons.inbox_outlined, label: 'Gələn Qutusu'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Pricing pill tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: AppTheme.gold.withAlpha(128),
                width: 1.5,
              ),
            ),
            child: Text(
              '{ Qiymətlər }',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.gold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Hər Planda\nPremium Alətlərdən Zövq Alın',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: const Color(0xFFE8EAF6),
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Feature tools row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _tools.map((t) => _FeatureToolItem(tool: t)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  const _ToolItem({required this.icon, required this.label});
}

class _FeatureToolItem extends StatelessWidget {
  final _ToolItem tool;
  const _FeatureToolItem({required this.tool});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.gold.withAlpha(77), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(tool.icon, size: 24, color: AppTheme.gold),
        ),
        const SizedBox(height: 6),
        Text(
          tool.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF8899BB),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
