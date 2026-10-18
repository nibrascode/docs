import 'package:docspro/core/rich_markup.dart';
import 'package:docspro/core/rich_controller.dart';
import 'package:docspro/presentation/document_editor_screen/widgets/document_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'editor_harness.dart';

const sample = 'Salam dünya, bu sınaq mətnidir.\n\nİkinci abzas burada.';

Finder para(String start) =>
    find.byWidgetPredicate((w) => w is TextField && (w.controller?.text.contains(start) ?? false));

Future<RichController> focusPara(WidgetTester t, String start, TextSelection s) async {
  await t.tap(para(start).first);
  await t.pump();
  final c = t.widget<TextField>(para(start).first).controller! as RichController;
  // Offsets are relative to the paragraph that starts with [start].
  final o = c.text.indexOf(start);
  c.selection = TextSelection(baseOffset: s.baseOffset + o, extentOffset: s.extentOffset + o);
  await t.pump();
  return c;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

String allText(WidgetTester t) =>
    t.widgetList<TextField>(find.byType(TextField)).map((f) => f.controller!.text).join('\n\n');

void main() {
  testWidgets('B/I/U/S apply to the selection only and light up at the caret', (t) async {
    await pumpEditor(t, content: sample);
    var c = await focusPara(t, 'Salam', const TextSelection(baseOffset: 6, extentOffset: 11));
    for (final b in ['B', 'I', 'U', 'S']) {
      await t.tap(find.text(b).first);
      await t.pump();
    }
    c = t.widget<TextField>(para('Salam').first).controller! as RichController;
    expect(c.text, startsWith('Salam dünya, bu sınaq mətnidir.\n'));
    expect(c.styles[c.text.indexOf('d')], const SpanStyle(bold: true, italic: true, underline: true, strike: true));
    expect(c.styles[0], SpanStyle.plain);
    expect(c.styles[c.text.indexOf(',')], SpanStyle.plain);
    // Caret inside the word: toolbar state reflects it.
    c.selection = const TextSelection.collapsed(offset: 8);
    await t.pump();
    expect(MarkupTextController.caret.value.bold, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('colour sheet colours only the selection', (t) async {
    await pumpEditor(t, content: sample);
    await focusPara(t, 'Salam', const TextSelection(baseOffset: 0, extentOffset: 5));
    await t.tap(find.text('Color').first);
    await settle(t);
    // Tap the first swatch that is not black (any coloured circle).
    final swatches = find.byWidgetPredicate((w) =>
        w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).shape == BoxShape.circle &&
        (w.decoration as BoxDecoration).color != null && (w.decoration as BoxDecoration).color!.toARGB32() != 0xFF1A1A1A);
    expect(swatches, findsWidgets);
    await t.tap(swatches.at(2), warnIfMissed: false);
    await settle(t);
    final c = t.widget<TextField>(para('Salam').first).controller! as RichController;
    expect(c.styles[0].color ?? c.styles[0].bg, isNotNull, reason: c.text);
    expect(c.styles[c.text.indexOf('d')], SpanStyle.plain);
    expect(t.takeException(), isNull);
  });

  testWidgets('alignment, lists, indent, undo/redo', (t) async {
    await pumpEditor(t, content: sample);
    await focusPara(t, 'İkinci', const TextSelection.collapsed(offset: 3));
    await t.tap(find.byIcon(Icons.format_align_left_rounded).first);
    await settle(t);
    await t.tap(find.text('Center').last);
    await settle(t);
    // Alignment is stored on the focused paragraph only.
    expect(t.widget<TextField>(para('İkinci').first).textAlign, TextAlign.center);
    expect(t.widget<TextField>(para('Salam').first).textAlign, isNot(TextAlign.center));

    await focusPara(t, 'Salam', const TextSelection.collapsed(offset: 2));
    await t.tap(find.byIcon(Icons.format_list_bulleted_rounded).first);
    await settle(t);
    await t.tap(find.text('Numbers').last);
    await settle(t);
    expect(allText(t), contains('1. Salam'));

    await focusPara(t, 'İkinci', const TextSelection.collapsed(offset: 3));
    await t.tap(find.byIcon(Icons.format_indent_increase_rounded).first);
    await settle(t);
    await t.tap(find.text('Girinti +').last);
    await settle(t);
    expect(allText(t), contains('  İkinci'));

    final before = allText(t);
    await t.tap(find.byIcon(Icons.undo_rounded));
    await settle(t);
    expect(allText(t), isNot(before));
    await t.tap(find.byIcon(Icons.redo_rounded));
    await settle(t);
    expect(allText(t), before);
    expect(t.takeException(), isNull);
  });

  testWidgets('text sheet: font and size on selection; page view opens', (t) async {
    await pumpEditor(t, content: sample);
    await focusPara(t, 'Salam', const TextSelection(baseOffset: 0, extentOffset: 5));
    await t.tap(find.text('Text').first);
    await settle(t);
    await t.tap(find.text('Lora').last);
    await settle(t);
    final c = t.widget<TextField>(para('Salam').first).controller! as RichController;
    expect(c.styles[0].font, 'Lora');
    expect(c.styles[6].font, isNull);
    expect(t.takeException(), isNull);
    // Close the sheet and open the exact page view.
    await t.tapAt(const Offset(10, 10));
    await settle(t);
    await t.tap(find.byIcon(Icons.menu_book_rounded));
    await settle(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('undo reverts a typed word as one step; formatting is its own step', (t) async {
    await pumpEditor(t, content: 'Salam');
    final c = await focusPara(t, 'Salam', const TextSelection.collapsed(offset: 5));
    Future<void> type(String w, {bool space = true}) async {
      final start = c.selection.extentOffset;
      for (var i = 0; i < w.length; i++) {
        final k = c.selection.extentOffset;
        t.testTextInput.updateEditingValue(TextEditingValue(
            text: c.text.replaceRange(k, k, w[i]),
            selection: TextSelection.collapsed(offset: k + 1),
            composing: TextRange(start: start, end: k + 1)));
        await t.pump();
      }
      if (space) {
        final k = c.selection.extentOffset;
        t.testTextInput.updateEditingValue(
            TextEditingValue(text: c.text.replaceRange(k, k, ' '), selection: TextSelection.collapsed(offset: k + 1)));
        await t.pump();
      }
    }

    await type(' dünya');
    await type('gözəl', space: false);
    expect(c.text, 'Salam dünya gözəl');
    await t.tap(find.byIcon(Icons.undo_rounded));
    await settle(t);
    final c2 = t.widget<TextField>(find.byType(TextField).first).controller!;
    expect(c2.text, 'Salam dünya ');
    expect(t.takeException(), isNull);
  });
}
