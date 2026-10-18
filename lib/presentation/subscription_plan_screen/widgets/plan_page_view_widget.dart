import 'package:flutter/material.dart';

import '../subscription_plan_screen.dart';
import './plan_card_widget.dart';

class PlanPageViewWidget extends StatelessWidget {
  final List<PlanModel> plans;
  final PageController pageController;
  final int currentPlanIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<PlanModel> onSubscribeTap;

  const PlanPageViewWidget({
    required this.plans,
    required this.pageController,
    required this.currentPlanIndex,
    required this.onPageChanged,
    required this.onSubscribeTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pageController,
      onPageChanged: onPageChanged,
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isActive = index == currentPlanIndex;

        return AnimatedScale(
          scale: isActive ? 1.0 : 0.94,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: PlanCardWidget(
              plan: plan,
              onSubscribeTap: () => onSubscribeTap(plan),
            ),
          ),
        );
      },
    );
  }
}
