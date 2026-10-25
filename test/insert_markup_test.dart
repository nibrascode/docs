import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docspro/presentation/document_editor_screen/document_editor_screen.dart';
import 'editor_harness.dart';

const sample = '# Birinci fəsil\n\nSalam dünya, bu sınaq mətnidir.\n\nİkinci abzas burada.';

dynamic _st(WidgetTester t) => t.state(find.byType(DocumentEditorScreen));

Future<String> _run(WidgetTester t, String key, TextSelection sel) async {
  await pumpEditor(t, content: sample);
  final s = _st(t);
  s.runInsertForTest(key, selection: sel);
  for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 100)); }
  return s.bodyMarkupForTest as String;
}

void main() {
  final para = sample.indexOf('Salam');
  testWidgets('hline inserts a rule into markup', (t) async {
    final out = await _run(t, 'hline', TextSelection.collapsed(offset: para + 5));
    expect(out, contains('--------------------'));
  });
  testWidgets('h1 turns the paragraph into a heading', (t) async {
    final out = await _run(t, 'h1', TextSelection.collapsed(offset: para + 2));
    expect(out, contains('# Salam dünya'));
  });
  testWidgets('quote turns the paragraph into a quote', (t) async {
    final out = await _run(t, 'quote', TextSelection.collapsed(offset: para + 2));
    expect(out, contains('> Salam dünya'));
  });
  testWidgets('wrapQuotes wraps only the selection', (t) async {
    final out = await _run(t, 'wrapQuotes', TextSelection(baseOffset: para, extentOffset: para + 5));
    expect(out, contains('«Salam» dünya'));
    expect(out, contains('İkinci abzas burada.'));
  });
}
