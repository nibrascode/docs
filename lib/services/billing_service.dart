/// Placeholder until RevenueCat (`purchases_flutter`) is wired.
/// Do not call Play Billing from here.
class BillingService {
  BillingService._();
  static final instance = BillingService._();

  bool available = false;

  Future<void> init() async {
    available = false;
  }

  Future<bool> buy(String planId) async => false;

  Future<void> restore() async {}

  void dispose() {}
}
