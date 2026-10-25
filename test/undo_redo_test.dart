import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docspro/presentation/document_editor_screen/document_editor_screen.dart';
import 'editor_harness.dart';

const sample = '# Birinci fəsil\n\nSalam dünya, bu sınaq mətnidir.\n\nİkinci abzas burada.';

dynamic _st(WidgetTester t) => t.state(find.byType(DocumentEditorScreen));

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, IconData icon) async {
  await t.tap(find.byIcon(icon).first);
  await _settle(t);
}

void main() {
  final para = sample.indexOf('Salam');

  testWidgets('undo restores prior markup, redo brings it back', (t) async {
    await pumpEditor(t, content: sample);
    final s = _st(t);
    final original = s.bodyMarkupForTest as String;

    s.runInsertForTest('h1', selection: TextSelection.collapsed(offset: para + 2));
    await _settle(t);
    final afterH1 = s.bodyMarkupForTest as String;
    expect(afterH1, contains('# Salam dünya'));

    s.runInsertForTest('wrapQuotes', selection: TextSelection(baseOffset: afterH1.indexOf('İkinci'), extentOffset: afterH1.indexOf('İkinci') + 6));
    await _settle(t);
    final afterQuote = s.bodyMarkupForTest as String;
    expect(afterQuote, contains('«İkinci»'));

    await _tap(t, Icons.undo_rounded);
    expect(s.bodyMarkupForTest, afterH1);
    await _tap(t, Icons.undo_rounded);
    expect(s.bodyMarkupForTest, original);
    // Extra undo at the bottom of the stack is a no-op.
    await _tap(t, Icons.undo_rounded);
    expect(s.bodyMarkupForTest, original);

    await _tap(t, Icons.redo_rounded);
    expect(s.bodyMarkupForTest, afterH1);
    await _tap(t, Icons.redo_rounded);
    expect(s.bodyMarkupForTest, afterQuote);
    await _tap(t, Icons.redo_rounded);
    expect(s.bodyMarkupForTest, afterQuote);
  });

  testWidgets('a new edit after undo clears the redo stack', (t) async {
    await pumpEditor(t, content: sample);
    final s = _st(t);
    final original = s.bodyMarkupForTest as String;
    s.runInsertForTest('h1', selection: TextSelection.collapsed(offset: para + 2));
    await _settle(t);
    await _tap(t, Icons.undo_rounded);
    expect(s.bodyMarkupForTest, original);
    s.runInsertForTest('quote', selection: TextSelection.collapsed(offset: para + 2));
    await _settle(t);
    final afterQuote = s.bodyMarkupForTest as String;
    expect(afterQuote, contains('> Salam dünya'));
    await _tap(t, Icons.redo_rounded);
    expect(s.bodyMarkupForTest, afterQuote);
  });
}
