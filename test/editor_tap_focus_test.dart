import 'package:docspro/services/billing_service.dart';
import 'package:docspro/services/premium_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_harness.dart';

Finder _fields() => find.descendant(
      of: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'DocumentCanvas'),
      matching: find.byType(EditableText),
    );

bool _anyFocused(WidgetTester tester) =>
    tester.widgetList<EditableText>(_fields()).any((e) => e.focusNode.hasFocus);

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

      testWidgets('tap on the grey area below the page focuses the editor ($name)', (tester) async {
        BillingService.instance.available = live;
        BillingService.instance.tier = PlanTier.free;
        addTearDown(() => BillingService.instance.available = false);
        await pumpEditor(tester, content: content);
        await tester.pump(const Duration(seconds: 1));
        final area = tester.getRect(find.byKey(const ValueKey('editor-tap-area')));
        final ed = tester.widget<EditableText>(_fields().last);
        // Bottom-left corner of the writing area: outside the page sheet.
        await tester.tapAt(Offset(area.left + 2, area.bottom - 4));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_anyFocused(tester), isTrue, reason: 'grey area around the page must open the editor');
        expect(ed.focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('keyboard opening (view insets) keeps the editor focused ($name)', (tester) async {
        BillingService.instance.available = live;
        BillingService.instance.tier = PlanTier.free;
        addTearDown(() => BillingService.instance.available = false);
        await pumpEditor(tester, content: content);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(_fields().first);
        await tester.pump(const Duration(milliseconds: 300));
        tester.view.viewInsets = const FakeViewPadding(bottom: 900);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(_anyFocused(tester), isTrue);
        tester.testTextInput.enterText('${content}y');
        await tester.pump();
        expect(tester.widgetList<EditableText>(_fields()).any((e) => e.controller.text.contains('y')), isTrue);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('leaving reading mode (toolbar or any tap on the page) focuses the editor ($name)', (tester) async {
        BillingService.instance.available = live;
        BillingService.instance.tier = PlanTier.free;
        addTearDown(() => BillingService.instance.available = false);
        await pumpEditor(tester, content: content);
        await tester.pump(const Duration(seconds: 1));
        // Toolbar toggle: reading → editing.
        await tester.tap(find.byIcon(Icons.menu_book_rounded));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const ValueKey('reading-mode-tap')), findsOneWidget);
        await tester.tap(find.byIcon(Icons.edit_rounded));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.widget<EditableText>(_fields().first).readOnly, isFalse);
        expect(_anyFocused(tester), isTrue, reason: 'toolbar edit button must open the keyboard');
        expect(tester.testTextInput.isVisible, isTrue);
        // Blank tap in reading mode (corner of the view, not on a line).
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.byIcon(Icons.menu_book_rounded));
        await tester.pump(const Duration(seconds: 1));
        final r = tester.getRect(find.byKey(const ValueKey('reading-mode-tap')));
        await tester.tapAt(Offset(r.left + 3, r.bottom - 3));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('reading-mode-tap')), findsNothing);
        expect(_anyFocused(tester), isTrue, reason: 'any tap in reading mode must go back to writing');
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }
}
