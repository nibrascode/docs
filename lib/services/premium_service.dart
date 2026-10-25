import 'package:shared_preferences/shared_preferences.dart';
import 'billing_service.dart';

/// Plan model (Maher, Oct 2026):
/// - Free:  3 new documents per day, 20 pages per document.
/// - Pro:   unlimited writing; premium book covers stay locked.
/// - Ultra: everything unlocked (writing + premium covers).
enum PlanTier { free, pro, ultra }

class PremiumService {
  // Confirmed by Maher: Free = 3 new documents/day, 20 pages per document.
  static const freeDocsPerDay = 3;
  static const maxPagesFree = 20; // per document on Free
  static const unlimited = 999999;

  /// Back-compat names used by older UI/tests.
  static const maxDocsFree = freeDocsPerDay;
  static const maxPagesPro = unlimited;

  /// True only after RevenueCat SDK init succeeded (key present, Android).
  static bool get billingEnabled => BillingService.instance.available;

  static const _prefDay = 'nibras_usage_day';
  static const _prefDocs = 'nibras_usage_docs';

  static PlanTier tierFromString(String? s) {
    switch (s) {
      case 'ultra':
      case 'elite': // legacy
        return PlanTier.ultra;
      case 'pro':
        return PlanTier.pro;
      default:
        return PlanTier.free;
    }
  }

  static String tierToString(PlanTier t) => t.name;

  // ── Pure rules (unit-tested) ──
  static bool writingUnlimited(PlanTier t) => t != PlanTier.free;
  static bool premiumCoversUnlocked(PlanTier t) => t == PlanTier.ultra;
  static int docsPerDay(PlanTier t) => t == PlanTier.free ? freeDocsPerDay : unlimited;
  static int pagesPerDoc(PlanTier t) => t == PlanTier.free ? maxPagesFree : unlimited;

  /// Premium covers = the Nibras art covers (template ids of art covers).
  static bool isPremiumCoverLayout(String layout) => layout == 'nibrasart';

  static Future<PlanTier> currentTier() async {
    if (!billingEnabled) return PlanTier.ultra;
    return BillingService.instance.tier;
  }

  static Future<bool> isPremium() async => (await currentTier()) != PlanTier.free;

  static Future<int> maxDocuments() async => docsPerDay(await currentTier());
  static Future<int> maxPages() async => pagesPerDoc(await currentTier());

  // ── Daily usage counters ──
  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static Future<SharedPreferences> _usagePrefs() async {
    final p = await SharedPreferences.getInstance();
    if (p.getString(_prefDay) != _today()) {
      await p.setString(_prefDay, _today());
      await p.setInt(_prefDocs, 0);
    }
    return p;
  }

  static Future<int> docsCreatedToday() async => (await _usagePrefs()).getInt(_prefDocs) ?? 0;

  static Future<void> recordDocCreated() async {
    final p = await _usagePrefs();
    await p.setInt(_prefDocs, (p.getInt(_prefDocs) ?? 0) + 1);
  }

  /// [currentCount] kept for API compat; Free limit is per day.
  static Future<bool> canCreateDocument(int currentCount) async {
    if (!billingEnabled) return true;
    final t = await currentTier();
    return await docsCreatedToday() < docsPerDay(t);
  }

  static Future<bool> canUsePremiumCover() async {
    if (!billingEnabled) return true;
    return premiumCoversUnlocked(await currentTier());
  }

  static Future<bool> canUsePageCount(int pages) async {
    if (!billingEnabled) return true;
    return pages <= await maxPages();
  }

  static Future<bool> isNearPageLimit(int pages) async {
    if (!billingEnabled) return false;
    final max = await maxPages();
    if (max >= unlimited) return false;
    return pages >= (max * 0.8).floor();
  }

  static const premiumFeatures = <String>{};
}
