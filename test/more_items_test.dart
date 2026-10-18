// "More" menu items: the editor canvas must lay each element out exactly
// like the page engine that also produces the PDF (WYSIWYG), and the PDF
// must never show raw markup.
import 'package:docspro/core/page_layout.dart';
import 'package:docspro/core/page_size.dart';
import 'package:docspro/core/rich_controller.dart';
import 'package:docspro/core/rich_markup.dart';
import 'package:archive/archive.dart';
import 'package:docspro/core/table_spec.dart';
import 'package:docspro/core/toc.dart';
import 'package:docspro/l10n/app_localizations.dart';
import 'package:docspro/presentation/document_editor_screen/widgets/document_canvas.dart';
import 'package:docspro/services/book_writers.dart';
import 'package:docspro/services/layout_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

const settings = LayoutSettings(pageSize: PageSize.a5, marginMm: 18, fontSize: 16, lineHeight: 1.5, showPageNumbers: true);
// Editor at 1.5 px per point: body 12pt -> 18px.
const k = 1.5;
final textW = (settings.pageW - settings.margin * 2) * k;
final style = TextStyle(fontFamily: 'LibreBaskerville', fontSize: settings.bodyPt * k, height: 1.5, color: const Color(0xFF1A1A1A));

const table = '''[TABLE]
[W] 1.00 2.00 1.00
[A] l c r
| Ad | Təsvir | İl |
| --- | --- | --- |
| Aysel | Bakı şəhərində yaşayan və kitab yazan bir müəllif | 2024 |
| Murad | Gəncə | 2025 |
[/TABLE]''';

String saved = '';
final canvasKey = GlobalKey<DocumentCanvasState>();

Future<void> pumpCanvas(WidgetTester t, String text, {List<TocEntry> toc = const []}) async {
  saved = text;
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  await t.pumpWidget(LocalizationsProvider(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: textW,
              child: DocumentCanvas(
                key: canvasKey,
                text: text,
                onChanged: (s) => saved = s,
                hint: '',
                style: style,
                textAlign: TextAlign.left,
                readOnly: false,
                pxPerPt: k,
                tocEntries: toc,
                onEditTable: (_) async {},
                onDeleteTable: (_) {},
                onEditImage: (_) async {},
                onDeleteImage: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await t.pump();
}

Future<DocLayout> layout(WidgetTester t, String text) async =>
    (await t.runAsync(() => PageLayoutEngine(settings, imageSizer: (_) async => null).layout(text)))!;

List<LRect> tableRects(LPage p) => p.rects.where((r) => r.stroke == TableSpec.borderColor).toList();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  testWidgets('table: editor grid == page/PDF grid (cols, widths, rows, header, alignment)', (t) async {
    final doc = await layout(t, table);
    final rects = tableRects(doc.pages.first);
    expect(rects.length, 9); // 3 rows x 3 cols
    await pumpCanvas(t, table);
    final tableBox = t.getRect(find.byKey(const ValueKey('visual-table')));
    final x0 = rects.first.x, y0 = rects.first.y;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final e = rects[r * 3 + c];
        final cell = t.getRect(find.byKey(ValueKey('cell-$r-$c')));
        expect(cell.left - tableBox.left, closeTo((e.x - x0) * k, 0.6), reason: 'x r$r c$c');
        expect(cell.width, closeTo(e.w * k, 0.6), reason: 'w r$r c$c');
        expect(cell.top - tableBox.top, closeTo((e.y - y0) * k, 2.0), reason: 'y r$r');
      }
      // Row height (the tallest cell defines it, same line breaks).
      final rowH = [for (var c = 0; c < 3; c++) t.getRect(find.byKey(ValueKey('cell-$r-$c'))).height].reduce((a, b) => a > b ? a : b);
      expect(rowH, closeTo(rects[r * 3].h * k, 2.0), reason: 'row height r$r');
    }
    // Wrapped cell is 2+ lines in both.
    expect(rects[3].h, greaterThan(rects[6].h * 1.5));
    // Header shading only on row 0, same colour.
    expect(rects.take(3).every((r) => r.fill == TableSpec.headerFill), isTrue);
    expect(rects.skip(3).every((r) => r.fill == 0), isTrue);
    // Column alignment: centre column text centred, right column flush right.
    final lines = doc.pages.first.lines;
    final yearLine = lines.firstWhere((l) => l.words.any((w) => w.text == '2025'));
    final yw = yearLine.words.first;
    expect(yw.x + yw.width, closeTo(rects[8].x + rects[8].w - TableSpec.pad, 0.5));
    final gl = lines.firstWhere((l) => l.words.any((w) => w.text == 'Gəncə')).words.first;
    expect(gl.x + gl.width / 2, closeTo(rects[7].x + rects[7].w / 2, 0.5));
    final tf = t.widget<TextField>(find.descendant(of: find.byKey(const ValueKey('cell-2-2')), matching: find.byType(TextField)));
    expect(tf.textAlign, TextAlign.right);
  });

  testWidgets('table: typing in a cell, Enter moves to next cell, header toggle persists', (t) async {
    await pumpCanvas(t, table);
    final cell = find.descendant(of: find.byKey(const ValueKey('cell-2-1')), matching: find.byType(TextField));
    await t.tap(cell);
    await t.pump();
    final c = t.widget<TextField>(cell).controller! as RichController;
    c.selection = TextSelection.collapsed(offset: c.text.length);
    await t.pump();
    var start = c.text.length;
    for (final ch in ' və Şəki'.split('')) {
      final v = c.value;
      final o = v.selection.extentOffset;
      t.testTextInput.updateEditingValue(TextEditingValue(
          text: v.text.replaceRange(o, o, ch), selection: TextSelection.collapsed(offset: o + 1),
          composing: ch == ' ' ? TextRange.empty : TextRange(start: start, end: o + 1)));
      if (ch == ' ') start = o + 1;
      await t.pump();
    }
    expect(saved, contains('| Murad | Gəncə və Şəki | 2025 |'));
    // Bold via the toolbar path works on the focused cell.
    c.selection = TextSelection(baseOffset: c.text.length - 4, extentOffset: c.text.length);
    expect(canvasKey.currentState!.formatFocused(const FormatOp('bold')), isTrue);
    await t.pump();
    expect(saved, contains('Gəncə və **Şəki**'));
    // Enter = next cell, never a broken row.
    final v = c.value;
    t.testTextInput.updateEditingValue(TextEditingValue(text: '${v.text}\n', selection: TextSelection.collapsed(offset: v.text.length + 1)));
    await t.pump();
    expect(saved.split('\n').where((l) => l.startsWith('| Murad')).single, contains('| 2025 |'));
    // Header row off -> serialized and honoured by the engine.
    final s2 = saved.replaceFirst('[TABLE]\n', '[TABLE]\n[H] 0\n');
    final blocks = DocumentBlocks.parse(s2);
    expect(blocks.first.tableHeader, isFalse);
    expect(DocumentBlocks.serialize(blocks), contains('[H] 0'));
    final doc = await layout(t, s2);
    expect(tableRects(doc.pages.first).every((r) => r.fill == 0), isTrue);
  });

  testWidgets('table: DOCX/EPUB keep widths, header and alignment', (t) async {
    final zip = ZipDecoder().decodeBytes(DocxWriter.build(table, const DocxOptions()));
    final docx = String.fromCharCodes(zip.findFile('word/document.xml')!.content as List<int>);
    final epubZip = ZipDecoder().decodeBytes(EpubWriter.build(table, title: 'T'));
    final html = [for (final f in epubZip.files) if (f.name.endsWith('.xhtml')) String.fromCharCodes(f.content as List<int>)].join();
    expect(html, contains('<col style="width:50.0%"/>'));
    expect(html, contains('text-align:right'));
    expect(docx, contains('<w:gridCol w:w="1250"/><w:gridCol w:w="2500"/>'));
    expect(docx, contains('<w:jc w:val="center"/>'));
    expect(docx, contains('<w:tblHeader/>'));
  });

  testWidgets('TOC: real block, page numbers from the engine, same entries in editor, no raw markup in PDF', (t) async {
    const text = '${'[TOC title="Mündəricat" levels=2][/TOC]'}\n\n# Birinci fəsil\n\nMətn.\n\n--- Page Break ---\n\n## Alt bölmə\n\nMətn.\n\n--- Page Break ---\n\n# İkinci fəsil\n\n### Dərin\n\nSon.';
    final doc = await layout(t, text);
    expect(doc.toc.map((e) => (e.level, e.title, e.page)).toList(), [
      (1, 'Birinci fəsil', '1'),
      (2, 'Alt bölmə', '2'),
      (1, 'İkinci fəsil', '3'),
      (3, 'Dərin', '3'),
    ]);
    final all = [for (final p in doc.pages) for (final l in p.lines) for (final w in l.words) w.text].join(' ');
    expect(all, isNot(contains('[TOC')));
    expect(all, contains('Mündəricat'));
    // Entries (levels<=2) with right-aligned page numbers at the text edge.
    final p1 = doc.pages.first;
    final entry = p1.lines.firstWhere((l) => l.words.first.text == 'Alt bölmə');
    expect(entry.words.last.text, '2');
    expect(entry.words.last.x + entry.words.last.width, closeTo(settings.pageW - settings.margin, 0.5));
    expect(entry.words.first.x, closeTo(settings.margin + TocSpec.indentPerLevel, 0.5));
    expect(p1.lines.any((l) => l.words.first.text == 'Dərin'), isFalse);
    // PDF builds from the same layout.
    final bytes = await t.runAsync(() => LayoutPdf.build(doc));
    expect(bytes!.length, greaterThan(1000));
    // Editor shows the same entries, same pages, same indent.
    await pumpCanvas(t, text, toc: doc.toc);
    expect(find.text('Mündəricat'), findsOneWidget);
    expect(find.byKey(const ValueKey('toc-2-Alt bölmə')), findsOneWidget);
    expect(find.byKey(const ValueKey('toc-3-Dərin')), findsNothing);
    final ed = t.getRect(find.byKey(const ValueKey('toc-2-Alt bölmə')));
    final ed1 = t.getRect(find.byKey(const ValueKey('toc-1-Birinci fəsil')));
    final tit = t.getRect(find.descendant(of: find.byKey(const ValueKey('toc-2-Alt bölmə')), matching: find.text('Alt bölmə')));
    expect(tit.left - ed1.left, closeTo(TocSpec.indentPerLevel * k, 0.6));
    expect(ed.right, closeTo(ed1.right, 0.1));
    // Saved as a marker, not as typed text.
    expect(DocumentBlocks.serialize(DocumentBlocks.parse(text)), startsWith('[TOC title="Mündəricat" levels=2][/TOC]'));
    // Old documents: legacy TOC text block is understood and regenerated.
    final legacy = DocumentBlocks.parse('\n[TOC]\n# Table of Contents\n\n1. X\n[/TOC]\n# X\n');
    expect(legacy.any((b) => b.kind == DocBlockKind.toc), isTrue);
  });

  testWidgets('rule, scene break and note: same size and indent as the PDF', (t) async {
    const text = 'Bir.\n--------------------\nİki.\n\n* * *\n\nÜç.\n[note]Haşiyə mətni[/note]\nDörd.';
    final doc = await layout(t, text);
    final p = doc.pages.first;
    final rule = p.rects.firstWhere((r) => r.h == 0 && r.w > 0);
    expect(rule.w, closeTo(settings.pageW - settings.margin * 2, 0.01));
    expect(rule.lineWidth, 0.6);
    final noteLine = p.lines.firstWhere((l) => l.words.first.text == 'Haşiyə');
    expect(noteLine.words.first.x, closeTo(settings.margin + 10, 0.5));
    expect(noteLine.words.first.style.italic, isTrue);
    expect(p.lines.any((l) => l.words.any((w) => w.text.contains('[note]') || w.text.contains('---'))), isFalse);
    await pumpCanvas(t, text);
    final hr = t.getRect(find.byKey(ValueKey('hr-${DocumentBlocks.parse(text).indexWhere((b) => b.kind == DocBlockKind.hr)}')));
    expect(hr.height, closeTo((12 + 0.6) * k, 0.1));
    expect(hr.width, closeTo(textW, 0.5));
    final ni = DocumentBlocks.parse(text).indexWhere((b) => b.kind == DocBlockKind.note);
    final noteBox = t.getRect(find.byKey(ValueKey('note-$ni')));
    final noteField = t.getRect(find.descendant(of: find.byKey(ValueKey('note-$ni')), matching: find.byType(EditableText)));
    expect(noteField.left - noteBox.left, closeTo(10 * k, 0.6));
    expect(noteBox.width, closeTo(textW, 0.5));
    expect(find.text('*   *   *'), findsOneWidget);
  });
}
