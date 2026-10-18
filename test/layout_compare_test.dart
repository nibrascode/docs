import 'dart:io';
import 'dart:ui' as ui;

import 'package:docspro/core/page_layout.dart';
import 'package:docspro/core/page_size.dart';
import 'package:docspro/services/layout_pdf.dart';
import 'package:docspro/widgets/layout_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

const sample = '''# Birinci fəsil

Bu sənəd Nibras Docs-un səhifə mühərrikini yoxlamaq üçündür. Ekranda gördüyünüz hər sətir PDF-də də **eyni yerdə** bitməlidir: eyni kənarlar, eyni şrift, eyni ölçü və eyni sətir sonları.

İkinci abzas *kursiv* və __altxətli__ sözlər, həmçinin ~~pozulmuş~~ mətn ehtiva edir. Uzun abzaslar səhifə boyunca axır, səhifə dolanda isə növbəti səhifəyə keçir. Bu cümlə sadəcə mətnin uzunluğunu artırmaq üçün yazılıb ki, bir neçə sətir alınsın.

## Cədvəl

[TABLE]
| Ad | Şəhər | İl |
| Aysel | Bakı | 2024 |
| Murad | Gəncə | 2025 |
[/TABLE]

> Bu, sitat bloku üçün nümunə mətndir və bir az uzun yazılıb ki, iki sətrə keçsin.

Русский текст: документ должен выглядеть одинаково на экране и в PDF.

النص العربي يجب أن يظهر بنفس الشكل على الشاشة وفي ملف PDF.

Son abzas.[^1]

[^1]: Dipqeyd nümunəsi.
''';

void main() {
  testWidgets('page view and PDF use the same layout', (tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      for (final size in [PageSize.a5, PageSize.book6x9]) {
        final settings = LayoutSettings(
          pageSize: size,
          marginMm: 18,
          fontSize: 14,
          lineHeight: 1.5,
          textAlign: 'justify',
          firstLineIndent: true,
          headerText: 'Nibras Docs',
        );
        final doc = await PageLayoutEngine(settings, imageSizer: (_) async => null).layout(sample);
        expect(doc.pages, isNotEmpty);
        // Every word must stay inside the text area.
        for (final p in doc.pages) {
          for (final l in p.lines) {
            for (final w in l.words) {
              expect(w.x, greaterThanOrEqualTo(settings.margin - 0.01));
              expect(w.x + w.width, lessThanOrEqualTo(settings.pageW - settings.margin + 0.5));
            }
            expect(l.top + l.height, lessThanOrEqualTo(settings.pageH - settings.margin + 0.5));
          }
        }
        // Screen render of page 1 at 2 px per point.
        const k = 2.0;
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        LayoutPagePainter(doc, doc.pages.first).paint(canvas, Size(settings.pageW * k, settings.pageH * k));
        final img = await rec.endRecording().toImage((settings.pageW * k).round(), (settings.pageH * k).round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('/workspace/docs-shots/compare-${size.name}-screen.png').writeAsBytesSync(png!.buffer.asUint8List());
        final pdf = await LayoutPdf.build(doc);
        File('/workspace/docs-shots/compare-${size.name}.pdf').writeAsBytesSync(pdf);
      }
    });
  });
}
