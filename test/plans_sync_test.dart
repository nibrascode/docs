import 'package:docspro/services/billing_service.dart';
import 'package:docspro/services/cloud_sync.dart';
import 'package:docspro/services/premium_service.dart';
import 'package:docspro/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DocumentModel _r(String id, DateTime u) => DocumentModel(
    id: id, userId: 'u', title: 't', content: 'c', isStarred: false,
    wordCount: 1, createdAt: u, updatedAt: u);

void main() {
  group('Plan rules', () {
    test('Free: 3 docs/day, 20 pages, covers locked', () {
      expect(PremiumService.docsPerDay(PlanTier.free), 3);
      expect(PremiumService.pagesPerDoc(PlanTier.free), 20);
      expect(PremiumService.premiumCoversUnlocked(PlanTier.free), isFalse);
      expect(PremiumService.writingUnlimited(PlanTier.free), isFalse);
    });
    test('Pro: unlimited writing, covers locked', () {
      expect(PremiumService.writingUnlimited(PlanTier.pro), isTrue);
      expect(PremiumService.pagesPerDoc(PlanTier.pro), PremiumService.unlimited);
      expect(PremiumService.premiumCoversUnlocked(PlanTier.pro), isFalse);
    });
    test('Ultra: everything', () {
      expect(PremiumService.writingUnlimited(PlanTier.ultra), isTrue);
      expect(PremiumService.premiumCoversUnlocked(PlanTier.ultra), isTrue);
    });
    test('legacy elite maps to ultra', () {
      expect(PremiumService.tierFromString('elite'), PlanTier.ultra);
      expect(PremiumService.tierFromString(null), PlanTier.free);
    });
    test('art covers are premium', () {
      expect(PremiumService.isPremiumCoverLayout('nibrasart'), isTrue);
      expect(PremiumService.isPremiumCoverLayout('classic'), isFalse);
    });
    test('daily doc counter', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await PremiumService.docsCreatedToday(), 0);
      await PremiumService.recordDocCreated();
      await PremiumService.recordDocCreated();
      expect(await PremiumService.docsCreatedToday(), 2);
      SharedPreferences.setMockInitialValues({'nibras_usage_day': '2000-1-1', 'nibras_usage_docs': 9});
      expect(await PremiumService.docsCreatedToday(), 0);
    });
    test('billing off never blocks', () async {
      expect(await PremiumService.canUsePremiumCover(), isTrue);
      expect(await PremiumService.currentTier(), PlanTier.ultra);
    });
  });

  group('RevenueCat mapping', () {
    test('ultra > pro > free', () {
      expect(BillingService.tierFromEntitlements(['pro', 'ultra']), PlanTier.ultra);
      expect(BillingService.tierFromEntitlements(['pro']), PlanTier.pro);
      expect(BillingService.tierFromEntitlements([]), PlanTier.free);
    });
    test('package ids', () {
      expect(BillingService.packageId('pro'), r'$rc_custom_pro_monthly');
      expect(BillingService.packageId('ultra', annual: true), r'$rc_custom_ultra_annual');
    });
    test('billing disabled without SDK init', () {
      expect(PremiumService.billingEnabled, isFalse);
    });
  });

  group('Supabase config', () {
    test('defaults to Nibrascode project with publishable key', () {
      final c = SupabaseService.resolveConfig({}, {});
      expect(c['url'], contains('qvwqqpxrvnrnwvyckwlo'));
      expect(c['key'], startsWith('sb_publishable_'));
      expect(c['googleWebClientId'], '');
    });
    test('publishable preferred over anon; defines over env', () {
      final c = SupabaseService.resolveConfig(
          {'GOOGLE_WEB_CLIENT_ID': 'web.apps'},
          {'SUPABASE_URL': 'https://x.supabase.co', 'SUPABASE_ANON_KEY': 'anon', 'SUPABASE_PUBLISHABLE_KEY': 'pub'});
      expect(c['url'], 'https://x.supabase.co');
      expect(c['key'], 'pub');
      expect(c['googleWebClientId'], 'web.apps');
    });
  });

  group('CloudSync.plan', () {
    final t0 = DateTime.utc(2026, 1, 1);
    final t1 = DateTime.utc(2026, 1, 2);
    const a = '11111111-1111-1111-1111-111111111111';
    const b = '22222222-2222-2222-2222-222222222222';
    const c = '33333333-3333-3333-3333-333333333333';
    test('local-only creates, newer local pushes, newer remote pulls, remote-only pulls', () {
      final steps = CloudSync.plan([
        {'id': 'local_1', 'updatedAt': t0.toIso8601String()},
        {'id': a, 'updatedAt': t1.toIso8601String()},
        {'id': b, 'updatedAt': t0.toIso8601String()},
      ], [_r(a, t0), _r(b, t1), _r(c, t0)]);
      expect(steps.map((s) => s.toString()).toList(),
          ['create:local_1', 'push:$a', 'pull:$b', 'pull:$c']);
    });
    test('equal timestamps do nothing', () {
      final s = CloudSync.plan([{'id': a, 'updatedAt': t0.toIso8601String()}], [_r(a, t0)]);
      expect(s.single.action, SyncAction.none);
    });
    test('isCloudId', () {
      expect(CloudSync.isCloudId(a), isTrue);
      expect(CloudSync.isCloudId('local_9'), isFalse);
    });
  });
}
