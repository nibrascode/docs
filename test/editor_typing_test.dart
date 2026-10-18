// Simulates real phone typing: Gboard-style composing updates char by char,
// Enter as an inserted "\n", backspace, autocorrect replacement, toggled
// styles at a bare caret, then save / reopen.
import 'package:docspro/core/rich_controller.dart';
import 'package:docspro/core/rich_doc.dart';
import 'package:docspro/core/rich_markup.dart';
import 'package:docspro/core/page_layout.dart';
import 'package:docspro/l10n/app_localizations.dart';
import 'package:docspro/presentation/document_editor_screen/widgets/document_canvas.dart';
import 'package:docspro/presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const red = '#B42318';

class Harness {
  final WidgetTester t;
  final key = GlobalKey<DocumentCanvasState>();
  String saved = '';
  Harness(this.t);

  Future<void> pump(String text) async {
    saved = text;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    await t.pumpWidget(LocalizationsProvider(child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DocumentCanvas(
            key: key,
            text: text,
            onChanged: (s) => saved = s,
            hint: 'Yazın…',
            style: const TextStyle(fontSize: 16, color: Colors.black),
            textAlign: TextAlign.left,
            readOnly: false,
            onEditTable: (_) async {},
            onDeleteTable: (_) {},
            onEditImage: (_) async {},
            onDeleteImage: (_) {},
          ),
        ),
      ),
    )));
    await t.pump();
  }

  DocumentCanvasState get canvas => key.currentState!;
  Iterable<TextField> get fields => t.widgetList<TextField>(find.byType(TextField));

  RichController get focused {
    for (final f in fields) {
      if (f.focusNode?.hasFocus ?? false) return f.controller! as RichController;
    }
    throw StateError('no focused field');
  }

  Future<void> tapField(int i, {int? offset}) async {
    await t.tap(find.byType(TextField).at(i));
    await t.pump();
    final c = fields.elementAt(i).controller! as RichController;
    c.selection = TextSelection.collapsed(offset: offset ?? c.text.length);
    await t.pump();
  }

  TextEditingValue get v => focused.value;

  Future<void> _send(TextEditingValue nv) async {
    t.testTextInput.updateEditingValue(nv);
    await t.pump();
  }

  /// Gboard: each letter extends a composing region over the current word.
  Future<void> typeWord(String w, {void Function(int)? after}) async {
    var start = v.selection.extentOffset;
    for (var i = 0; i < w.length; i++) {
      final cur = v;
      final c = cur.selection.extentOffset;
      final text = cur.text.replaceRange(c, c, w[i]);
      await _send(TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: c + 1),
        composing: TextRange(start: start, end: c + 1),
      ));
      after?.call(i);
    }
    // Commit (composing ends, text unchanged).
    await _send(v.copyWith(composing: TextRange.empty));
  }

  Future<void> commit(String s) async {
    final c = v.selection.extentOffset;
    await _send(TextEditingValue(
        text: v.text.replaceRange(c, c, s), selection: TextSelection.collapsed(offset: c + s.length)));
  }

  Future<void> enter() => commit('\n');

  Future<void> backspace() async {
    final c = v.selection.extentOffset;
    if (c == 0) {
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      await t.pump();
      await t.pump();
      return;
    }
    await _send(TextEditingValue(text: v.text.replaceRange(c - 1, c, ''), selection: TextSelection.collapsed(offset: c - 1)));
  }

  Future<void> select(int a, int b) async {
    focused.selection = TextSelection(baseOffset: a, extentOffset: b);
    await t.pump();
  }

  Future<void> fmt(FormatOp op) async {
    expect(canvas.formatFocused(op), isTrue);
    await t.pump();
  }
}

/// Visible (rendered) runs of a controller.
List<(String, TextStyle?)> rendered(WidgetTester t, RichController c) {
  final span = c.buildTextSpan(context: t.element(find.byType(TextField).first), withComposing: true);
  final out = <(String, TextStyle?)>[];
  span.visitChildren((s) {
    if (s is TextSpan && s.text != null) out.add((s.text!, s.style));
    return true;
  });
  return out;
}

TextStyle? styleOfChar(WidgetTester t, RichController c, int index) {
  var k = 0;
  for (final (s, st) in rendered(t, c)) {
    if (index < k + s.length) return st;
    k += s.length;
  }
  return null;
}

void main() {
  testWidgets('Enter many times gives many empty lines in the same field', (t) async {
    final h = Harness(t);
    await h.pump('');
    await h.tapField(0);
    await h.typeWord('Salam');
    for (var i = 0; i < 5; i++) {
      await h.enter();
    }
    await h.typeWord('dünya');
    expect(h.fields.length, 1);
    expect(h.focused.text, 'Salam\n\n\n\n\ndünya');
    expect(h.v.selection.extentOffset, h.focused.text.length);
    expect(h.saved, 'Salam\n\n\n\n\ndünya');
    // Enter at the start and in the middle, and empty lines survive reopening.
    await h.select(0, 0);
    await h.enter();
    await h.enter();
    expect(h.focused.text, '\n\nSalam\n\n\n\n\ndünya');
    await h.pump(h.saved);
    expect((h.fields.first.controller! as RichController).text, '\n\nSalam\n\n\n\n\ndünya');
    // Backspace removes exactly one empty line each time.
    await h.tapField(0, offset: 8);
    await h.backspace();
    expect(h.focused.text, '\n\nSalam\n\n\n\ndünya');
    expect(t.takeException(), isNull);
  });

  testWidgets('bold toggled at a bare caret shows on every letter while composing', (t) async {
    final h = Harness(t);
    await h.pump('Bu ');
    await h.tapField(0);
    await h.fmt(const FormatOp('bold'));
    expect(RichController.caret.value.bold, isTrue);
    await h.typeWord('qalın', after: (i) {
      // Every composing update is already bold, letter by letter.
      final c = h.focused;
      for (var k = 3; k <= 3 + i; k++) {
        expect(c.styles[k].bold, isTrue, reason: 'letter $k after ${i + 1} letters');
        expect(styleOfChar(t, c, k)?.fontWeight, FontWeight.w700);
      }
    });
    // Style persists across space and Enter until toggled off.
    await h.commit(' ');
    await h.typeWord('söz');
    await h.enter();
    await h.typeWord('yeni');
    final c = h.focused;
    expect(c.text, 'Bu qalın söz\nyeni');
    for (var k = 3; k < c.text.length; k++) {
      if (c.text[k] != '\n') expect(c.styles[k].bold, isTrue, reason: 'char $k ${c.text[k]}');
    }
    // Toggle off: next letters are plain immediately.
    await h.fmt(const FormatOp('bold'));
    await h.commit(' ');
    await h.typeWord('adi', after: (i) => expect(h.focused.styles.last.bold, isFalse));
    expect(h.saved, 'Bu **qalın söz**\n**yeni** adi');
    expect(t.takeException(), isNull);
  });

  testWidgets('colour, size, font, italic, underline pending while typing', (t) async {
    final h = Harness(t);
    await h.pump('');
    await h.tapField(0);
    await h.fmt(const FormatOp('color', red));
    await h.fmt(const FormatOp('size', 24));
    await h.fmt(const FormatOp('font', 'Lora'));
    await h.fmt(const FormatOp('italic'));
    await h.fmt(const FormatOp('underline'));
    await h.typeWord('Rəng', after: (i) {
      final st = styleOfChar(t, h.focused, i)!;
      expect(st.color, const Color(0xFFB42318));
      expect(st.fontSize, 24);
      expect(st.fontFamily, 'Lora');
      expect(st.fontStyle, FontStyle.italic);
    });
    final s = h.focused.styles.first;
    expect(s, const SpanStyle(italic: true, underline: true, color: red, size: 24, font: 'Lora'));
    // Moving the caret elsewhere drops the pending style.
    await h.fmt(const FormatOp('bold'));
    await h.select(0, 0);
    await h.select(4, 4);
    expect(h.focused.pending, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('selection: each style applies only to the selected part and combines', (t) async {
    final h = Harness(t);
    await h.pump('Salam dünya, bu sınaq mətnidir.');
    await h.tapField(0);
    final c = h.focused;
    final before = c.text;
    await h.select(6, 11); // dünya
    await h.fmt(const FormatOp('bold'));
    await h.fmt(const FormatOp('italic'));
    await h.fmt(const FormatOp('color', red));
    await h.select(8, 15); // nya, b
    await h.fmt(const FormatOp('underline'));
    await h.fmt(const FormatOp('bg', '#FFF3B0'));
    expect(c.text, before, reason: 'formatting never changes the text the keyboard sees');
    expect(c.styles[6], const SpanStyle(bold: true, italic: true, color: red));
    expect(c.styles[9], const SpanStyle(bold: true, italic: true, underline: true, color: red, bg: '#FFF3B0'));
    expect(c.styles[13], const SpanStyle(underline: true, bg: '#FFF3B0'));
    expect(c.styles[0], SpanStyle.plain);
    expect(c.styles[16], SpanStyle.plain);
    // Rendered immediately.
    expect(styleOfChar(t, c, 9)!.fontWeight, FontWeight.w700);
    expect(styleOfChar(t, c, 9)!.backgroundColor, const Color(0xFFFFF3B0));
    // Toggle off only where all selected have it.
    await h.select(6, 11);
    await h.fmt(const FormatOp('bold'));
    expect(c.styles[6].bold, isFalse);
    expect(c.styles[6].italic, isTrue);
    // Reopen: identical.
    final styles = List.of(c.styles);
    await h.pump(h.saved);
    expect((h.fields.first.controller! as RichController).styles, styles);
    // Copy a part and paste it: formatting comes along.
    await h.tapField(0);
    await h.select(6, 11);
    await h.focused.copySelection();
    await h.select(h.focused.text.length, h.focused.text.length);
    await h.commit('dünya');
    expect(h.focused.styles.last, const SpanStyle(italic: true, underline: true, color: red, bg: '#FFF3B0'));
    expect(t.takeException(), isNull);
  });

  testWidgets('autocorrect replacing a word keeps its style; literal markup chars survive', (t) async {
    final h = Harness(t);
    await h.pump('');
    await h.tapField(0);
    await h.fmt(const FormatOp('bold'));
    await h.typeWord('teh');
    await h.fmt(const FormatOp('bold'));
    // Gboard replaces the word "teh" -> "the".
    await h._send(const TextEditingValue(text: 'the', selection: TextSelection.collapsed(offset: 3)));
    expect(h.focused.styles.every((s) => s.bold), isTrue);
    await h.commit(' 2*3*4 = a_b __x__ ~~y~~ [color=#000000]z [^1] #tag');
    final txt = h.focused.text;
    await h.pump(h.saved);
    expect((h.fields.first.controller! as RichController).text, txt);
    expect(RichMarkup.parse(h.saved).plain, contains('2*3*4 = a_b __x__ ~~y~~ [color=#000000]z'));
    expect(t.takeException(), isNull);
  });

  testWidgets('lists continue on Enter, empty item ends the list; headings keep text', (t) async {
    final h = Harness(t);
    await h.pump('• bir');
    await h.tapField(0);
    await h.enter();
    expect(h.focused.text, '• bir\n• ');
    await h.typeWord('iki');
    await h.enter();
    await h.enter(); // empty item: list ends
    expect(h.focused.text, '• bir\n• iki\n');
    await h.pump('1. bir');
    await h.tapField(0);
    await h.enter();
    expect(h.focused.text, '1. bir\n2. ');
    // Backspace right after "• " removes the bullet.
    await h.pump('• ');
    await h.tapField(0);
    await h.backspace();
    expect(h.focused.text, '');
    // Heading on a line: text unchanged, stored as '# '.
    await h.pump('Başlıq\nmətn');
    await h.tapField(0, offset: 2);
    expect(h.canvas.lineStyleFocused('h1'), isTrue);
    await t.pump();
    expect(h.focused.text, 'Başlıq\nmətn');
    expect(h.saved, '# Başlıq\nmətn');
    await h.select(6, 6);
    await h.enter(); // Enter at the end of a heading: next line is normal
    await h.typeWord('x');
    expect(h.saved, '# Başlıq\nx\nmətn');
    expect(t.takeException(), isNull);
  });

  testWidgets('alignment per line; Enter keeps typing in the same centred field', (t) async {
    final h = Harness(t);
    await h.pump('bir\niki\nüç');
    await h.tapField(0, offset: 5);
    expect(h.canvas.alignFocused('center'), isTrue);
    await t.pump();
    await t.pump();
    expect(h.fields.length, 3);
    expect(h.fields.elementAt(1).textAlign, TextAlign.center);
    expect(h.saved, 'bir\n[align=center]iki\n[align=left]üç');
    // Typing in the centred field with Enter twice.
    expect(h.focused.text, 'iki');
    await h.select(3, 3);
    await h.enter();
    await h.enter();
    await h.typeWord('dörd');
    expect(h.fields.length, 3);
    expect(h.focused.text, 'iki\n\ndörd');
    final saved = h.saved;
    await h.pump(saved);
    expect(h.fields.length, 3);
    expect((h.fields.elementAt(1).controller! as RichController).text, 'iki\n\ndörd');
    // Backspace at the very start of the last field joins it with the line above.
    await h.tapField(2, offset: 0);
    await h.backspace();
    await t.pump();
    expect(h.fields.length, 2);
    expect(h.focused.text, 'iki\n\ndördüç');
    // Old documents: paragraph [align] lasts until the blank line.
    final lines = RichDoc.decode('[align=center]a\nb\n\nc');
    expect(lines.map((l) => l.align).toList(), ['center', 'center', 'left', 'left']);
    expect(t.takeException(), isNull);
  });

  testWidgets('Arabic typing: field switches to RTL', (t) async {
    final h = Harness(t);
    await h.pump('');
    await h.tapField(0);
    await h.typeWord('بِسْمِ');
    await h.commit(' ');
    await h.fmt(const FormatOp('bold'));
    await h.typeWord('اللَّهِ');
    await t.pump();
    expect(h.fields.first.textDirection, TextDirection.rtl);
    final c = h.focused;
    expect(c.text, 'بِسْمِ اللَّهِ');
    expect(c.styles.sublist(0, 7).any((s) => s.bold), isFalse);
    expect(c.styles.sublist(7).every((s) => s.bold), isTrue);
    await h.pump(h.saved);
    expect((h.fields.first.controller! as RichController).styles, c.styles);
    expect(t.takeException(), isNull);
  });

  testWidgets('Samsung-style composing flaps do not change text or drop pending style', (t) async {
    final h = Harness(t);
    await h.pump('abc');
    await h.tapField(0);
    await h.fmt(const FormatOp('italic'));
    for (var i = 0; i < 4; i++) {
      await h._send(h.v.copyWith(composing: const TextRange(start: 0, end: 3)));
      await h._send(h.v.copyWith(composing: TextRange.empty));
    }
    expect(h.focused.pending?.italic, isTrue);
    await h.typeWord('d');
    expect(h.focused.styles.last.italic, isTrue);
    expect(h.saved, 'abc*d*');
  });

  test('cover titles are clean: default Nibras Code, no markup from old versions', () {
    expect(CoverData.cleanTitle(''), 'Nibras Code');
    expect(CoverData.cleanTitle('Untitled Document'), 'Nibras Code');
    expect(CoverData.cleanTitle('[align=center]# **Salam** [color=#B42318]dünya[/color][^1]'), 'Salam dünya');
    expect(CoverData.cleanTitle('[COVER id=classic title="x"]'), 'Nibras Code');
    expect(CoverData.parse('[COVER id=classic title="**Kitab**" sub="" author="# Ali" year="" publisher=""]')!.author, 'Ali');
  });

  test('layout: every empty line takes a full line (WYSIWYG)', () {
    expect(RichDoc.encode(RichDoc.decode('a\n\n\n\nb')), 'a\n\n\n\nb');
    expect(PageLayoutEngine.runs('**x**', const LStyle(family: 'Lora', size: 12)).first.$2.bold, isTrue);
  });
}
