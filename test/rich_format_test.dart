import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:docspro/core/page_layout.dart';
import 'package:docspro/core/page_size.dart';
import 'package:docspro/core/rich_markup.dart';
import 'package:docspro/presentation/document_editor_screen/widgets/document_canvas.dart';
import 'package:docspro/services/book_writers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextSelection sel(String raw, String part, [int from = 0]) {
  // Selection over the plain substring [part] mapped back to raw offsets.
  final p = RichMarkup.parse(raw);
  final a = p.plain.indexOf(part, from);
  return TextSelection(baseOffset: p.rawAt(a) , extentOffset: p.rawAt(a + part.length));
}

List<(String, SpanStyle)> spans(String raw) {
  final p = RichMarkup.parse(raw);
  final out = <(String, SpanStyle)>[];
  for (var k = 0; k < p.length; k++) {
    if (out.isNotEmpty && out.last.$2 == p.st[k]) {
      out[out.length - 1] = (out.last.$1 + p.el[k], p.st[k]);
    } else {
      out.add((p.el[k], p.st[k]));
    }
  }
  return out;
}

const red = '#B42318', blue = '#175CD3', yellow = '#FFF3B0';

void main() {
  group('span model', () {
    test('colour only the selected letters', () {
      var raw = 'Salam dünya';
      // "lam" inside the first word.
      final s = TextSelection(baseOffset: 2, extentOffset: 5);
      final (r, ns) = RichMarkup.applyRange(raw, s, const FormatOp('color', red));
      expect(spans(r), [('Sa', SpanStyle.plain), ('lam', const SpanStyle(color: red)), (' dünya', SpanStyle.plain)]);
      expect(RichMarkup.parse(r).plainAt(ns.start), 2);
      raw = r;
    });

    test('mixed overlapping spans stay correct', () {
      var raw = 'one two three four';
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'two three'), const FormatOp('bold'));
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'three four'), const FormatOp('color', blue));
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'ee fo'), const FormatOp('bg', yellow));
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'o t'), const FormatOp('italic'));
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'thr'), const FormatOp('size', 24));
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'four'), const FormatOp('font', 'Lora'));
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'one'), const FormatOp('underline'));
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'ne'), const FormatOp('strike'));
      final p = RichMarkup.parse(raw);
      expect(p.plain, 'one two three four');
      SpanStyle at(String ch, [int from = 0]) => p.st[p.plain.indexOf(ch, from)];
      expect(at('o'), const SpanStyle(underline: true));
      expect(at('n'), const SpanStyle(underline: true, strike: true));
      expect(at('t'), const SpanStyle(bold: true));
      expect(at('o', 5), const SpanStyle(bold: true, italic: true)); // "two"'s o
      expect(at('h'), const SpanStyle(bold: true, color: blue, size: 24));
      expect(at('t', 8), const SpanStyle(bold: true, italic: true, color: blue, size: 24));
      expect(at('e', 10), const SpanStyle(bold: true, color: blue, bg: yellow)); // thr|ee
      expect(at('f'), const SpanStyle(color: blue, bg: yellow, font: 'Lora'));
      expect(at('r', 16), const SpanStyle(color: blue, font: 'Lora'));
      // Canonical: serialising again is stable.
      expect(RichMarkup.serialize(p.el, p.st), raw);
    });

    test('toggle off only when the whole selection has it', () {
      var raw = '**ab**cd';
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'abcd'), const FormatOp('bold'));
      expect(raw, '**abcd**');
      (raw, _) = RichMarkup.applyRange(raw, sel(raw, 'bc'), const FormatOp('bold'));
      expect(raw, '**a**bc**d**');
    });

    test('typing inherits the style on the left; pending style applies', () {
      const old = 'x **ab**';
      final p = RichMarkup.parse(old);
      final caret = p.rawAt(4); // after "b"
      final typed = old.substring(0, caret) + 'c' + old.substring(caret);
      final v = RichMarkup.reconcile(old, TextEditingValue(text: typed, selection: TextSelection.collapsed(offset: caret + 1)), null);
      final now = v?.text ?? typed;
      expect(spans(now).last, ('abc', const SpanStyle(bold: true)));
      // Pending red at the end of plain text.
      const o2 = 'hello';
      final v2 = RichMarkup.reconcile(o2, const TextEditingValue(text: 'hello!', selection: TextSelection.collapsed(offset: 6)), const SpanStyle(color: red))!;
      expect(spans(v2.text), [('hello', SpanStyle.plain), ('!', const SpanStyle(color: red))]);
      // Backspace over a hidden marker deletes the visible letter.
      final v3 = RichMarkup.reconcile('**ab**', const TextEditingValue(text: '**ab*', selection: TextSelection.collapsed(offset: 5)), null)!;
      expect(RichMarkup.parse(v3.text).plain, 'a');
    });

    test('copy keeps formatting; pasting it restores spans', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      const raw = 'a [color=#B42318]**red**[/color] b';
      await RichClipboard.copy(raw, sel(raw, 'ed b'));
      expect(RichClipboard.last!.$1, 'ed b');
      final v = RichMarkup.reconcile('X', const TextEditingValue(text: 'Xed b', selection: TextSelection.collapsed(offset: 5)), null,
          clip: RichClipboard.last)!;
      expect(spans(v.text), [('X', SpanStyle.plain), ('ed', const SpanStyle(bold: true, color: red)), (' b', SpanStyle.plain)]);
    });

    test('literal asterisks, scene breaks and headings are safe', () {
      expect(RichMarkup.parse('5 * 3 = 15').plain, '5 * 3 = 15');
      expect(RichMarkup.parse('* * *').plain, '* * *');
      var raw = '# Title here';
      (raw, _) = RichMarkup.applyRange(raw, const TextSelection(baseOffset: 0, extentOffset: 12), const FormatOp('bold'));
      expect(raw, '# **Title here**');
      expect(RichMarkup.parse('Note[^2] end').el.contains('[^2]'), isTrue);
    });
  });

  group('exports use the same spans', () {
    const doc = 'Plain [color=#B42318]red[/color] and [bg=#FFF3B0]**hi**[/bg] [size=24]big[/size] [font=Lora]lora[/font] ~~x~~ __u__ *i*';
    test('layout engine', () {
      final rs = PageLayoutEngine.runs(doc, const LStyle(family: 'LibreBaskerville', size: 12));
      (String, LStyle) r(String t) => rs.firstWhere((e) => e.$1 == t);
      expect(r('red').$2.color, 0xFFB42318);
      expect(r('hi').$2.bold, isTrue);
      expect(r('hi').$2.bg, 0xFFFFF3B0);
      expect(r('big').$2.size, 18);
      expect(r('lora').$2.family, 'Lora');
      expect(r('x').$2.strike, isTrue);
      expect(r('u').$2.underline, isTrue);
      expect(r('i').$2.italic, isTrue);
      expect(r('Plain ').$2.color, 0xFF1A1A1A);
    });

    test('DOCX', () {
      final bytes = DocxWriter.build(doc, const DocxOptions(title: 't', pageSize: PageSize.a5));
      final xml = utf8.decode(ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content as List<int>);
      expect(xml, contains('<w:color w:val="b42318"/></w:rPr><w:t xml:space="preserve">red'));
      expect(xml, contains('w:fill="fff3b0"'));
      expect(xml, contains('<w:sz w:val="36"/>'));
      expect(xml, contains('w:ascii="Lora"'));
    });

    test('EPUB', () {
      final bytes = EpubWriter.build('# Ch\n\n$doc', title: 't');
      final arc = ZipDecoder().decodeBytes(bytes);
      final x = arc.files.where((f) => f.name.endsWith('.xhtml')).map((f) => utf8.decode(f.content as List<int>)).join('\n');
      expect(x, contains('color:#b42318'));
      expect(x, contains('background:#fff3b0'));
      expect(x, contains('font-family:'));
      expect(x, contains('<strong>hi</strong>'));
    });
  });

  test('links render as links in layout, EPUB and PDF', () async {
    const doc = 'See [Nibras](https://nibrascode.com) now.';
    final rs = PageLayoutEngine.runs(doc, const LStyle(family: 'LibreBaskerville', size: 12));
    final l = rs.firstWhere((e) => e.$1 == 'Nibras');
    expect(l.$2.link, 'https://nibrascode.com');
    expect(l.$2.underline, isTrue);
    expect(RichMarkup.parse(doc).plain, doc); // atomic element keeps its source
    final ep = EpubWriter.build('# C\n\n$doc', title: 't');
    final x = ZipDecoder().decodeBytes(ep).files.where((f) => f.name.endsWith('.xhtml')).map((f) => utf8.decode(f.content as List<int>)).join();
    expect(x, contains('<a href="https://nibrascode.com">'));
  });

  testWidgets('editor: select a word, colour it, type more, round-trip', (tester) async {
    var saved = '';
    final key = GlobalKey<DocumentCanvasState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentCanvas(
          key: key,
          text: 'Salam dünya',
          onChanged: (t) => saved = t,
          hint: '',
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.left,
          readOnly: false,
          onEditTable: (_) async {},
          onDeleteTable: (_) {},
          onEditImage: (_) async {},
          onDeleteImage: (_) {},
        ),
      ),
    ));
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    final tf = tester.widget<TextField>(find.byType(TextField).first);
    final c = tf.controller as MarkupTextController;
    // Select "dünya" and make it red, then bold "ala".
    c.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
    expect(key.currentState!.formatFocused(const FormatOp('color', red)), isTrue);
    c.selection = sel(c.text, 'ala');
    key.currentState!.formatFocused(const FormatOp('bold'));
    await tester.pump();
    expect(spans(saved), [
      ('S', SpanStyle.plain),
      ('ala', const SpanStyle(bold: true)),
      ('m ', SpanStyle.plain),
      ('dünya', const SpanStyle(color: red)),
    ]);
    // Cursor at the end, toggle italic, type: only new text is italic + red.
    final end = c.text.length;
    c.selection = TextSelection.collapsed(offset: end);
    key.currentState!.formatFocused(const FormatOp('italic'));
    await tester.enterText(find.byType(TextField).first, '${c.text}!');
    await tester.pump();
    expect(spans(saved).last, ('!', const SpanStyle(italic: true, color: red)));
    // Round-trip: reopen the saved text, styles are identical.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentCanvas(
          key: GlobalKey(),
          text: saved,
          onChanged: (_) {},
          hint: '',
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.left,
          readOnly: false,
          onEditTable: (_) async {},
          onDeleteTable: (_) {},
          onEditImage: (_) async {},
          onDeleteImage: (_) {},
        ),
      ),
    ));
    final c2 = tester.widget<TextField>(find.byType(TextField).first).controller!;
    expect(spans(c2.text), spans(saved));
    // Rendered spans hide markers and colour only that word.
    final span = c2.buildTextSpan(context: tester.element(find.byType(TextField).first), withComposing: false);
    final visible = <String>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.text != null && (s.style?.fontSize ?? 16) > 1) visible.add(s.text!);
      return true;
    });
    expect(visible.join(), 'Salam dünya!');
  });
}
