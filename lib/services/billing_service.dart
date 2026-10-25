import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'premium_service.dart';

/// RevenueCat billing (project "Nibras Docs").
/// Entitlements: `pro`, `ultra` (Ultra products also grant `pro`).
/// Offering `default`, packages `$rc_custom_{pro,ultra}_{monthly,annual}`.
class BillingService {
  BillingService._();
  static final instance = BillingService._();

  static const entitlementPro = 'pro';
  static const entitlementUltra = 'ultra';

  /// True only after Purchases.configure succeeded with a real key.
  bool available = false;
  PlanTier tier = PlanTier.free;

  /// ultra → Ultra; pro only → Pro; else Free.
  static PlanTier tierFromEntitlements(Iterable<String> active) {
    final s = active.toSet();
    if (s.contains(entitlementUltra)) return PlanTier.ultra;
    if (s.contains(entitlementPro)) return PlanTier.pro;
    return PlanTier.free;
  }

  static String packageId(String plan, {bool annual = false}) =>
      '\$rc_custom_${plan}_${annual ? 'annual' : 'monthly'}';

  static Future<String> _loadKey() async {
    const define = String.fromEnvironment('REVENUECAT_GOOGLE_API_KEY');
    if (define.isNotEmpty) return define;
    try {
      final m = jsonDecode(await rootBundle.loadString('assets/env.json'))
          as Map<String, dynamic>;
      return (m['REVENUECAT_GOOGLE_API_KEY'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  void _apply(CustomerInfo info) {
    tier = tierFromEntitlements(info.entitlements.active.keys);
  }

  Future<void> init({String? appUserId}) async {
    if (available) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final key = await _loadKey();
    if (key.isEmpty) return;
    try {
      final cfg = PurchasesConfiguration(key);
      if (appUserId != null && appUserId.isNotEmpty) cfg.appUserID = appUserId;
      await Purchases.configure(cfg);
      available = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
    } catch (e) {
      debugPrint('RevenueCat init failed: $e');
      available = false;
    }
  }

  /// Call after Supabase sign-in so purchases follow the account.
  Future<void> logIn(String supabaseUserId) async {
    if (!available) return;
    try {
      _apply((await Purchases.logIn(supabaseUserId)).customerInfo);
    } catch (_) {}
  }

  Future<void> logOut() async {
    if (!available) return;
    try {
      _apply(await Purchases.logOut());
    } catch (_) {}
  }

  Future<Package?> package(String plan, {bool annual = false}) async {
    if (!available) return null;
    final offering = (await Purchases.getOfferings()).current;
    return offering?.getPackage(packageId(plan, annual: annual));
  }

  /// Returns true if the purchase granted a paid tier; false on cancel/failure.
  Future<bool> buy(String plan, {bool annual = false}) async {
    final pkg = await package(plan, annual: annual);
    if (pkg == null) return false;
    try {
      final res = await Purchases.purchase(PurchaseParams.package(pkg));
      _apply(res.customerInfo);
      return tier != PlanTier.free;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  Future<PlanTier> restore() async {
    if (!available) return tier;
    _apply(await Purchases.restorePurchases());
    return tier;
  }

  void dispose() {}
}
