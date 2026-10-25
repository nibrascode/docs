import 'package:docspro/services/billing_service.dart';
import 'package:docspro/services/premium_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_harness.dart';

Finder _fields() => find.descendant(
      of: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'DocumentCanvas'),
      matching: find.byType(EditableText),
    );

void main() {
  for (final live in [false, true]) {
    for (final content in ['', 'Salam dünya\nİkinci sətir']) {
      final name = 'billing=$live, ${content.isEmpty ? 'empty' : 'text'}';
      testWidgets('tap on a text line focuses the editor ($name)', (tester) async {
        BillingService.instance.available = live;
        BillingService.instance.tier = PlanTier.free;
        addTearDown(() => BillingService.instance.available = false);
        await pumpEditor(tester, content: content);
        await tester.pump(const Duration(seconds: 1));
        final ed = tester.widget<EditableText>(_fields().first);
        expect(ed.readOnly, isFalse);
        await tester.tap(_fields().first);
        await tester.pump(const Duration(milliseconds: 300));
        expect(ed.focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        tester.testTextInput.enterText('${content}x');
        await tester.pump();
        expect(ed.controller.text.contains('x'), isTrue);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('tap on empty page space below the text focuses the editor ($name)', (tester) async {
        BillingService.instance.available = live;
        BillingService.instance.tier = PlanTier.free;
        addTearDown(() => BillingService.instance.available = false);
        await pumpEditor(tester, content: content);
        await tester.pump(const Duration(seconds: 1));
        final last = _fields().last;
        final ed = tester.widget<EditableText>(last);
        final r = tester.getRect(last);
        // Well below the last line but still on the first page sheet.
        await tester.tapAt(Offset(r.center.dx, r.bottom + 150));
        await tester.pump(const Duration(milliseconds: 300));
        expect(ed.focusNode.hasFocus, isTrue, reason: 'blank page area must open the editor');
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }
}
