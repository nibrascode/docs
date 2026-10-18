import 'package:docspro/l10n/app_localizations.dart';
import 'package:docspro/presentation/document_editor_screen/document_editor_screen.dart';
import 'package:docspro/presentation/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:docspro/services/premium_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizer/sizer.dart';

void main() {
  test('all features free while billing is off', () async {
    expect(PremiumService.billingEnabled, isFalse);
    expect(await PremiumService.canCreateDocument(1000), isTrue);
    expect(await PremiumService.canUsePageCount(100000), isTrue);
  });

  test('footnotes renumber in reading order', () {
    const t = 'A[^3] B[^1]\n\n[^1]: bir\n[^3]: üç';
    expect(renumberFootnotes(t), 'A[^1] B[^2]\n\n[^2]: bir\n[^1]: üç');
  });

  testWidgets('premium screen shows Tezliklə', (t) async {
    await t.pumpWidget(LocalizationsProvider(
        child: Sizer(builder: (c, o, s) => const MaterialApp(home: SubscriptionPlanScreen()))));
    await t.pump();
    expect(find.byKey(const ValueKey('premium-coming-soon')), findsOneWidget);
    expect(find.textContaining(RegExp('Tezliklə|Coming soon')), findsOneWidget);
  });
}
