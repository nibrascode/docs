import 'dart:io';

import 'package:docspro/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'editor_harness.dart';

const sample = '# Birinci fəsil\n\nSalam dünya, bu sınaq mətnidir.\n\nİkinci abzas burada.';

List<(String, String)> insertItems() {
  final src = File('lib/presentation/document_editor_screen/document_editor_screen.dart').readAsStringSync();
  final l = AppLocalizations();
  final out = <(String, String)>[];
  for (final m in RegExp(r"item\(Icons\.\w+, (?:l10n\.t\(az: '(?:[^']+)', en: '((?:[^'\\]|\\.)+)'[^)]*\)|l10n\.(\w+)), '(\w+)'\)").allMatches(src)) {
    final label = m.group(1) ??
        switch (m.group(2)) { 'link' => l.link, 'pageBreak' => l.pageBreak, 'horizontalLine' => l.horizontalLine, _ => m.group(2)! };
    out.add((m.group(3)!, label.replaceAll("\\'", "'")));
  }
  return out;
}

String editorText(WidgetTester t) => tester_text(t);
String tester_text(WidgetTester t) =>
    t.widgetList<TextField>(find.byType(TextField)).map((f) => f.controller?.text ?? '').join('|');

void main() {
  final items = insertItems();
  test('found insert items', () => expect(items.length, greaterThan(40)));

  for (final (key, label) in items) {
    testWidgets('insert sheet: $key ($label)', (tester) async {
      await pumpEditor(tester, content: sample);
      // Put the caret into the body paragraph.
      final body = find.byWidgetPredicate((w) => w is TextField && (w.controller?.text.startsWith('Salam') ?? false));
      if (body.evaluate().isNotEmpty) {
        await tester.tap(body.first);
        await tester.pump();
        final c = tester.widget<TextField>(body.first).controller!;
        c.selection = const TextSelection.collapsed(offset: 5);
        await tester.pump();
      }
      final before = tester_text(tester);
      final routesBefore = find.byType(ModalBarrier).evaluate().length;
      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final f = find.text(label);
      final sc = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
      for (final g in ['Insert', 'Book', 'Book parts', "Writer's plan", 'Text', 'Page']) {
        if (f.evaluate().isNotEmpty) break;
        final gf = find.descendant(of: find.byType(BottomSheet), matching: find.text(g));
        try {
          await tester.scrollUntilVisible(gf, 200, scrollable: sc, maxScrolls: 40);
        } catch (_) {}
        if (gf.evaluate().isEmpty) continue;
        await tester.tap(gf.first, warnIfMissed: false);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        try {
          await tester.scrollUntilVisible(f, 150, scrollable: sc, maxScrolls: 40);
        } catch (_) {}
        if (f.evaluate().isNotEmpty) break;
        try {
          await tester.scrollUntilVisible(gf, -200, scrollable: sc, maxScrolls: 60);
          await tester.tap(gf.first, warnIfMissed: false); // collapse again
          for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        } catch (_) {}
      }
      expect(f, findsWidgets, reason: 'menu item not found');
      await tester.ensureVisible(f.last);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(f.last);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      final after = tester_text(tester);
      final barriers = find.byType(ModalBarrier).evaluate().length;
      final snack = find.byType(SnackBar).evaluate().isNotEmpty;
      final moreOpen = find.text('Find and replace').evaluate().isNotEmpty && find.text("Writer's plan").evaluate().isNotEmpty;
      final outcome = moreOpen ? 'MISSED' : after != before
          ? 'CHANGED'
          : barriers > routesBefore + 0
              ? 'OPENED'
              : snack
                  ? 'SNACK'
                  : 'NOTHING';
      final ex = tester.takeException();
      // ignore: avoid_print
      print('QA|$key|$label|$outcome|${ex.toString().split('\n').first}');
      expect(ex, isNull);
    });
  }
}
