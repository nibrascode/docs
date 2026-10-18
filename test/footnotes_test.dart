import 'package:archive/archive.dart';
import 'package:docspro/core/page_layout.dart';
import 'package:docspro/core/page_size.dart';
import 'package:docspro/services/book_writers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

void main() {
  testWidgets('footnotes print at the foot of the page that references them', (t) async {
    await t.runAsync(loadAppFonts);
    const s = LayoutSettings(pageSize: PageSize.a5, marginMm: 18, fontSize: 16, lineHeight: 1.5);
    final para = List.filled(12, 'Bu cümlə səhifəni doldurmaq üçün yazılıb və bir az uzundur.').join(' ');
    final text = 'Birinci qeyd burada.[^1]\n\n$para\n\n$para\n\nİkinci qeyd isə sonda.[^2]\n\n[^1]: Birinci izah.\n[^2]: İkinci izah, bir az uzun yazılıb ki, sətrə sığsın.';
    final doc = (await t.runAsync(() => PageLayoutEngine(s, imageSizer: (_) async => null).layout(text)))!;
    expect(doc.pages.length, greaterThan(1));
    final bottom = s.pageH - s.margin - (s.bodyPt * 1.6 + 6);
    int pageOfRef(String n) => doc.pages.indexWhere((p) => p.lines.any((l) => l.sourceOffset >= 0 && l.words.any((w) => w.style.sup && w.text == n)));
    for (final n in ['1', '2']) {
      final pi = pageOfRef(n);
      expect(pi, greaterThanOrEqualTo(0));
      final p = doc.pages[pi];
      expect(p.notes, contains(n));
      final noteLines = p.lines.where((l) => l.sourceOffset == -1).toList();
      expect(noteLines, isNotEmpty);
      final bodyLines = p.lines.where((l) => l.sourceOffset >= 0);
      final noteTop = noteLines.map((l) => l.top).reduce((a, b) => a < b ? a : b);
      for (final l in bodyLines) {
        expect(l.top + l.height, lessThanOrEqualTo(noteTop + 0.01), reason: 'body overlaps notes');
      }
      final last = noteLines.last;
      expect(last.top + last.height, closeTo(bottom, 0.5));
      expect(p.rects.any((r) => r.h == 0 && (r.w - (s.pageW - s.margin * 2) * 0.3).abs() < 0.1), isTrue);
    }
    // Definitions are not printed in the body.
    expect(doc.pages.expand((p) => p.lines).where((l) => l.sourceOffset >= 0).any((l) => l.words.any((w) => w.text == 'izah.')), isFalse);
    // DOCX: real Word footnotes.
    final zip = ZipDecoder().decodeBytes(DocxWriter.build(text, const DocxOptions()));
    final d = String.fromCharCodes(zip.findFile('word/document.xml')!.content as List<int>);
    final f = String.fromCharCodes(zip.findFile('word/footnotes.xml')!.content as List<int>);
    expect(d, contains('<w:footnoteReference w:id="1"/>'));
    expect(d, isNot(contains('İkinci izah')));
    expect(f, contains('<w:footnote w:id="2">'));
  });
}
