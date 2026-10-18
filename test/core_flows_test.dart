import 'dart:io';

import 'package:archive/archive.dart';
import 'package:docspro/core/page_layout.dart';
import 'package:docspro/core/page_size.dart';
import 'package:docspro/services/book_writers.dart';
import 'package:docspro/services/doc_import_service.dart';
import 'package:docspro/services/local_docs_cache.dart';
import 'package:docspro/services/mobile_export_service.dart';
import 'package:docspro/presentation/document_editor_screen/widgets/document_canvas.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fonts.dart';

const book = '''[COVER id=nc_emerald title="Səhər işığı" sub="Roman" author="Aysel Məmmədova" year="2026" publisher="" ts=1.00 tp=middle]

# Birinci fəsil

Bu **qalın**, *kursiv* və __altxətli__ mətndir.[^1]

[align=center]Mərkəzə düzlənmiş abzas.

> Sitat sətri.

[TABLE]
| Ad | Rol |
| --- | --- |
| Murad | Qəhrəman |
[/TABLE]

* * *

# İkinci fəsil

Русский абзац. النص العربي هنا.

[^1]: Dipqeyd.
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('local documents', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('save, star survives re-save, rename, duplicate, delete', () async {
      await LocalDocsCache.saveDoc(id: 'a', title: 'Kitab', content: 'Mətn bir iki üç');
      await LocalDocsCache.setStarred('a', true);
      await LocalDocsCache.saveDoc(id: 'a', title: 'Kitab', content: 'Yeni mətn');
      var docs = await LocalDocsCache.load();
      expect(docs.single['isStarred'], isTrue, reason: 'saving must not unstar');
      expect(docs.single['wordCount'], 2);
      await LocalDocsCache.rename('a', 'Yeni ad');
      final copy = await LocalDocsCache.duplicate('a', suffix: ' (surət)');
      docs = await LocalDocsCache.load();
      expect(docs.length, 2);
      expect(docs.map((d) => d['title']), containsAll(['Yeni ad', 'Yeni ad (surət)']));
      await LocalDocsCache.delete(copy!);
      expect((await LocalDocsCache.load()).length, 1);
    });

    test('backup and restore', () async {
      await LocalDocsCache.saveDoc(id: 'a', title: 'A', content: 'x', settings: {'fontSize': 18});
      final json = await LocalDocsCache.exportAll();
      SharedPreferences.setMockInitialValues({});
      expect(await LocalDocsCache.load(), isEmpty);
      expect(await LocalDocsCache.importAll(json), 1);
      final d = (await LocalDocsCache.load()).single;
      expect(d['title'], 'A');
      expect((d['settings'] as Map)['fontSize'], 18);
      expect(await LocalDocsCache.importAll(json), 0, reason: 'same backup twice adds nothing');
      expect(() => LocalDocsCache.importAll('{"x":1}'), throwsFormatException);
    });
  });

  test('blocks parse/serialize round trip keeps content', () {
    final blocks = DocumentBlocks.parse(book);
    final kinds = blocks.map((b) => b.kind).toSet();
    expect(kinds, containsAll([DocBlockKind.cover, DocBlockKind.text, DocBlockKind.table, DocBlockKind.sceneBreak]));
    final once = DocumentBlocks.serialize(blocks);
    expect(once, book, reason: 'opening + saving must not change the text');
    expect(DocumentBlocks.serialize(DocumentBlocks.parse(once)), once);
  });

  test('plain text export strips all markup', () {
    final t = MobileExportService.plainText(book);
    for (final bad in ['**', '[COVER', '[TABLE]', '[align=', '# ', '| ---']) {
      expect(t.contains(bad), isFalse, reason: bad);
    }
    expect(t, contains('Birinci fəsil'));
    expect(t, contains('qalın'));
  });

  testWidgets('layout engine: cover page, chapters, page breaks, offsets', (tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      final long = List.filled(60, 'Uzun abzas sözləri səhifələri doldurmaq üçün təkrarlanır.').join(' ');
      final doc = await PageLayoutEngine(
        const LayoutSettings(pageSize: PageSize.a5, chapterNewPage: true),
        imageSizer: _noImage,
      ).layout('$book\n\n$long\n\n--- Page Break ---\n\nSon.');
      expect(doc.pages.first.cover, isNotNull, reason: 'cover is its own first page');
      expect(doc.pages.first.pageLabel, isEmpty);
      // Second chapter starts on a new page.
      final ch2 = doc.pages.indexWhere((p) => p.lines.any((l) => l.words.any((w) => w.text == 'İkinci')));
      final firstWordOnPage = doc.pages[ch2].lines.first.words.first.text;
      expect(firstWordOnPage, 'İkinci');
      // Last line "Son." alone on its own page after the page break.
      expect(doc.pages.last.lines.single.words.single.text, 'Son.');
      // No markup leaks into the laid-out text.
      for (final p in doc.pages) {
        for (final l in p.lines) {
          for (final w in l.words) {
            expect(w.text.contains('**') || w.text.contains('[align'), isFalse, reason: w.text);
          }
        }
      }
      // Page numbers continue.
      expect(doc.pages[1].pageLabel, '2');
    });
  });

  test('DOCX: styles, page size, formatting, table; import reads it back', () async {
    final bytes = DocxWriter.build(book, const DocxOptions(title: 'Səhər işığı', pageSize: PageSize.book6x9, chapterNewPage: true));
    File('/workspace/docs-shots/exports/sample.docx').writeAsBytesSync(bytes);
    final arc = ZipDecoder().decodeBytes(bytes);
    final xml = String.fromCharCodes(arc.findFile('word/document.xml')!.content as List<int>);
    expect(xml, contains('w:pgSz w:w="8640" w:h="12960"'));
    expect(xml, contains('<w:pStyle w:val="Heading1"/>'));
    expect(xml, contains('<w:b/>'));
    expect(xml, contains('<w:tbl>'));
    expect(xml, contains('<w:pageBreakBefore/>'));
    expect(arc.findFile('word/styles.xml'), isNotNull);
    final back = DocImportService.docxToMarkup(bytes);
    expect(back, contains('# Birinci fəsil'));
    expect(back, contains('**qalın**'));
    expect(back, contains('[TABLE]'));
  });

  test('EPUB 3: mimetype first & stored, one file per chapter, nav', () async {
    final bytes = EpubWriter.build(book, title: 'Səhər işığı', author: 'Aysel');
    File('/workspace/docs-shots/exports/sample.epub').writeAsBytesSync(bytes);
    final arc = ZipDecoder().decodeBytes(bytes);
    expect(arc.files.first.name, 'mimetype');
    expect(arc.findFile('OEBPS/nav.xhtml'), isNotNull);
    expect(arc.findFile('OEBPS/ch2.xhtml'), isNotNull);
    expect(arc.findFile('OEBPS/ch3.xhtml'), isNotNull);
  });

  testWidgets('PDF export from layout produces all pages', (tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      final bytes = await MobileExportService.buildLayoutPdf(
        content: book,
        settings: const LayoutSettings(pageSize: PageSize.book55x85, headerText: 'Səhər işığı'),
      );
      File('/workspace/docs-shots/exports/sample.pdf').writeAsBytesSync(bytes);
      final s = String.fromCharCodes(bytes);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(s).length, greaterThanOrEqualTo(2));
    });
  });
}

Future<Size?> _noImage(String _) async => null;
