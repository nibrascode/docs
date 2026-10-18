import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

enum PlanTier { free, pro, elite }

/// Document/page caps. Billing is off until RevenueCat is connected.
class PremiumService {
  static const maxDocsFree = 5;
  static const maxPagesFree = 15;
  static const maxPagesPro = 150;
  static const maxPagesElite = 999999;

  /// Flip to true after RevenueCat is live.
  static const billingEnabled = false;

  static const _prefPlan = 'nibras_plan_tier';

  static Future<PlanTier> currentTier() async {
    if (!billingEnabled) return PlanTier.elite;
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString(_prefPlan);
      if (local == 'elite') return PlanTier.elite;
      if (local == 'pro') return PlanTier.pro;

      final svc = SupabaseService.instance;
      if (svc.isReady && svc.isAuthenticated) {
        final user = svc.currentUser;
        if (user != null) {
          final row = await svc.client
              .from('profiles')
              .select('is_premium, premium_until')
              .eq('id', user.id)
              .maybeSingle();
          if (row != null) {
            final until = row['premium_until'] as String?;
            if (until != null) {
              final d = DateTime.tryParse(until);
              if (d != null && d.isBefore(DateTime.now())) {
                return PlanTier.free;
              }
            }
            if (row['is_premium'] == true) {
              return PlanTier.pro;
            }
          }
        }
      }
    } catch (_) {}
    return PlanTier.free;
  }

  static Future<void> setLocalTier(PlanTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefPlan,
      tier == PlanTier.elite
          ? 'elite'
          : tier == PlanTier.pro
              ? 'pro'
              : 'free',
    );
  }

  static Future<bool> isPremium() async {
    final t = await currentTier();
    return t != PlanTier.free;
  }

  static Future<int> maxDocuments() async {
    final t = await currentTier();
    if (t == PlanTier.free) return maxDocsFree;
    return 999999;
  }

  static Future<int> maxPages() async {
    final t = await currentTier();
    switch (t) {
      case PlanTier.free:
        return maxPagesFree;
      case PlanTier.pro:
        return maxPagesPro;
      case PlanTier.elite:
        return maxPagesElite;
    }
  }

  static Future<bool> canCreateDocument(int currentCount) async {
    if (!billingEnabled) return true;
    final max = await maxDocuments();
    return currentCount < max;
  }

  static Future<bool> canUsePageCount(int pages) async {
    if (!billingEnabled) return true;
    final max = await maxPages();
    return pages <= max;
  }

  static Future<bool> isNearPageLimit(int pages) async {
    if (!billingEnabled) return false;
    final max = await maxPages();
    if (max >= maxPagesElite) return false;
    return pages >= (max * 0.8).floor();
  }

  static const premiumFeatures = <String>{};
}
