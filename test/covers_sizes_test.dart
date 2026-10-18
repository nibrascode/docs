import 'dart:io';

import 'package:docspro/core/cover_art.dart';
import 'package:docspro/presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import 'package:docspro/services/mobile_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'test_fonts.dart';

const _sizes = <String, Size>{
  'A3': Size(841.89, 1190.55),
  'A4': Size(595.28, 841.89),
  'A5': Size(419.53, 595.28),
  'A6': Size(297.64, 419.53),
  'Letter': Size(612, 792),
  'Legal': Size(612, 1008),
  'A4-landscape': Size(841.89, 595.28),
};

const _long = CoverData(
    templateId: '',
    title: 'Dağların arxasında qalan şəhərin unudulmuş hekayələri və xatirələri',
    subtitle: 'Azərbaycan nağılları və əfsanələri toplusu, ikinci nəşr',
    author: 'Məhəmmədəli Əbdülrəhmanzadə Qarabağlı',
    year: '2026');

CoverData _with(CoverData d, String id) => CoverData(
    templateId: id, title: d.title, subtitle: d.subtitle, author: d.author, year: d.year, titleScale: 1.8);

void main() {
  test('${artCovers.length} art covers: every element inside the safe area, in order, at all page sizes', () {
    expect(artCovers.length, greaterThanOrEqualTo(40));
    final bad = <String>[];
    for (final c in artCovers) {
      for (final e in _sizes.entries) {
        final w = e.value.width, h = e.value.height;
        final g = ArtCoverGeometry.of(c.style, w, h, titleScale: 1.8, title: _long.title, subtitle: _long.subtitle);
        for (final b in g.boxes) {
          if (b.x < w * 0.06 - 0.01 || b.right > w * 0.94 + 0.01 || b.y < h * 0.04 - 0.01 || b.bottom > h * 0.96 + 0.01 || b.w <= 0 || b.h <= 0) {
            bad.add('${c.id}@${e.key}: $b');
          }
        }
        if (e.key.contains('landscape')) continue;
        final order = g.boxes;
        for (var i = 1; i < order.length; i++) {
          if (order[i].y < order[i - 1].bottom - 0.5) bad.add('${c.id}@${e.key}: overlap ${i - 1}/$i');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.take(20).join('\n'));
  });

  for (final name in ['A3', 'A4', 'A5']) {
    testWidgets('every cover renders at $name without overflow', (tester) async {
      await tester.runAsync(loadAppFonts);
      final s = _sizes[name]!;
      tester.view.physicalSize = Size(s.width + 40, s.height + 40);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bad = <String>[];
      for (final t in coverTemplates) {
        await tester.pumpWidget(MaterialApp(
          home: Center(child: CoverPagePreview(template: t, data: _with(_long, t.id), width: s.width, height: s.height)),
        ));
        final e = tester.takeException();
        if (e != null) bad.add('${t.id}: $e');
        if (t.layout == 'nibrasart') {
          // Every text stays inside the page.
          final page = tester.getRect(find.byType(ArtCoverView));
          for (final el in find.byType(Text).evaluate()) {
            final r = tester.getRect(find.byWidget(el.widget));
            if (r.left < page.left - 0.5 || r.right > page.right + 0.5 || r.top < page.top - 0.5 || r.bottom > page.bottom + 0.5) {
              bad.add('${t.id}: text outside page $r');
            }
          }
        }
      }
      expect(bad, isEmpty, reason: bad.take(20).join('\n'));
    });
  }

  test('every art cover exports to PDF at A3, A4 and A5', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PdfFace.warm();
    await ArtCoverCache.warm(artCovers.map((c) => c.templateId));
    expect(ArtCoverCache.jpeg.length, artCovers.length);
    final pdf = pw.Document();
    for (final c in artCovers) {
      for (final name in ['A3', 'A4', 'A5']) {
        final s = _sizes[name]!;
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat(s.width, s.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => MobileExportService.pdfCoverPage(_with(_long, c.templateId), s.width, s.height),
        ));
      }
    }
    final bytes = await pdf.save();
    Directory('/tmp/arx').createSync(recursive: true);
    File('/tmp/arx/art_covers.pdf').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(10000));
  });
}
