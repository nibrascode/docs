// Renders a [DocLayout] into a PDF. Each word is drawn at the exact position
// the shared layout engine computed, so the PDF matches the on-screen page.
import 'dart:io';
import 'dart:typed_data';


import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/page_layout.dart';
// ignore: implementation_imports
import 'package:pdf/src/pdf/font/arabic.dart' as arabic;
import 'mobile_export_service.dart';

PdfColor _c(int argb) => PdfColor.fromInt(argb);

class _PageCanvas extends pw.Widget {
  final DocLayout doc;
  final LPage page;
  final Map<String, Uint8List> images;
  _PageCanvas(this.doc, this.page, this.images);

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    box = PdfRect(0, 0, doc.settings.pageW, doc.settings.pageH);
  }

  pw.Font _font(LStyle st) {
    final f = PdfFace.pick(st.family);
    if (st.bold) return f.bold;
    if (st.italic) return f.italic;
    return f.regular;
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final s = doc.settings;
    final g = context.canvas;
    final h = s.pageH;
    double fy(double top) => h - top; // top-based -> PDF bottom-based

    g
      ..setFillColor(_c(s.pageBgColor | 0xFF000000))
      ..drawRect(0, 0, s.pageW, h)
      ..fillPath();

    if (s.pageFrame) {
      g
        ..setStrokeColor(_c(0xFF1A1A1A))
        ..setLineWidth(1.1)
        ..drawRect(14, 14, s.pageW - 28, h - 28)
        ..strokePath()
        ..setLineWidth(0.4)
        ..drawRect(18, 18, s.pageW - 36, h - 36)
        ..strokePath();
    }

    for (final r in page.rects) {
      if (r.fill != 0) {
        g
          ..setFillColor(_c(r.fill))
          ..drawRect(r.x, fy(r.y + r.h), r.w, r.h)
          ..fillPath();
      }
      if (r.stroke != 0) {
        g
          ..setStrokeColor(_c(r.stroke))
          ..setLineWidth(r.lineWidth);
        if (r.h == 0 || r.w == 0) {
          g.drawLine(r.x, fy(r.y), r.x + r.w, fy(r.y + r.h));
        } else {
          g.drawRect(r.x, fy(r.y + r.h), r.w, r.h);
        }
        g.strokePath();
      }
    }

    for (final im in page.images) {
      final bytes = images[im.path];
      if (bytes == null) continue;
      try {
        final img = PdfImage.file(context.document, bytes: bytes);
        g.drawImage(img, im.x, fy(im.y + im.h), im.w, im.h);
      } catch (_) {}
    }

    for (final line in page.lines) {
      for (final w in line.words) {
        final st = w.style;
        final font = _font(st).getFont(context);
        final base = st.sup ? line.y - st.size * 0.7 : line.y;
        g
          ..setFillColor(_c(st.color))
          ..drawString(font, st.size, _visual(w.text), w.x, fy(base));
        if (st.underline || st.strike) {
          final uy = st.underline ? base + st.size * 0.12 : base - st.size * 0.28;
          g
            ..setStrokeColor(_c(st.color))
            ..setLineWidth(st.size * 0.06)
            ..drawLine(w.x, fy(uy), w.x + w.width, fy(uy))
            ..strokePath();
        }
      }
    }

    // Header and page number (same geometry as the preview painter).
    final chrome = PageChrome.of(doc, page);
    for (final t in chrome) {
      final font = PdfFace.pick(layoutFamily(s.fontFamily)).regular.getFont(context);
      g
        ..setFillColor(_c(t.color))
        ..drawString(font, t.size, t.text, t.x, fy(t.baseline));
      if (t.ruleY != null) {
        g
          ..setStrokeColor(_c(0xFF444444))
          ..setLineWidth(0.4)
          ..drawLine(s.margin, fy(t.ruleY!), s.pageW - s.margin, fy(t.ruleY!))
          ..strokePath();
      }
    }
  }
}

final _ar = RegExp(r'[\u0600-\u06FF]');

/// drawString paints glyphs left to right without shaping: shape Arabic into
/// presentation forms and reverse to visual order.
String _visual(String word) {
  if (!_ar.hasMatch(word)) return word;
  final shaped = arabic.convert(word);
  return shaped;
}

class LayoutPdf {
  static Future<Uint8List> build(DocLayout doc, {String title = ''}) async {
    await PdfFace.warm();
    final pdf = pw.Document(title: title);
    final images = <String, Uint8List>{};
    for (final p in doc.pages) {
      for (final im in p.images) {
        try {
          images[im.path] ??= await File(im.path).readAsBytes();
        } catch (_) {}
      }
    }
    final fmt = PdfPageFormat(doc.settings.pageW, doc.settings.pageH);
    for (final p in doc.pages) {
      if (p.cover != null) {
        pdf.addPage(pw.Page(
          pageFormat: fmt,
          margin: pw.EdgeInsets.zero,
          build: (_) => MobileExportService.pdfCoverPage(p.cover!, fmt.width, fmt.height),
        ));
        continue;
      }
      pdf.addPage(pw.Page(
        pageFormat: fmt,
        margin: pw.EdgeInsets.zero,
        build: (_) => _PageCanvas(doc, p, images),
      ));
    }
    return pdf.save();
  }
}

/// A text item in the page margins (header text, page number).
class ChromeText {
  final String text;
  final double x, baseline, size;
  final int color;
  final double? ruleY;
  ChromeText(this.text, this.x, this.baseline, this.size, this.color, [this.ruleY]);
}

class PageChrome {
  static List<ChromeText> of(DocLayout doc, LPage page) {
    final s = doc.settings;
    final out = <ChromeText>[];
    final eng = PageLayoutEngine(s);
    final st = LStyle(family: layoutFamily(s.fontFamily), size: 8.5, color: 0xFF555555);
    final m = s.margin;
    if (page.header.isNotEmpty) {
      final w = eng.measure(page.header, st);
      final base = m + 8.5;
      out.add(ChromeText(page.header, (s.pageW - w) / 2, base, 8.5, st.color, base + 5));
    }
    if (page.pageLabel.isNotEmpty) {
      final ns = st.copyWith(size: 9.5, color: 0xFF333333);
      final w = eng.measure(page.pageLabel, ns);
      final top = s.pageNumberPos.startsWith('top');
      final base = top ? m * 0.6 : s.pageH - m + 4 + 9.5;
      double x;
      if (s.pageNumberPos.endsWith('left')) {
        x = m;
      } else if (s.pageNumberPos.endsWith('right')) {
        x = s.pageW - m - w;
      } else {
        x = (s.pageW - w) / 2;
      }
      out.add(ChromeText(page.pageLabel, x, base, 9.5, ns.color));
    }
    if (s.footerText.trim().isNotEmpty) {
      final fs = st.copyWith(size: 8.5);
      final base = s.pageH - m + 4 + 9.5;
      final left = s.pageNumberPos.endsWith('left');
      final w = eng.measure(s.footerText.trim(), fs);
      out.add(ChromeText(s.footerText.trim(), left ? s.pageW - m - w : m, base, 8.5, fs.color));
    }
    return out;
  }
}

