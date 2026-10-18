// On-screen pages drawn from the shared layout engine (exactly like the PDF).
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/page_layout.dart';
import '../presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import '../services/layout_pdf.dart';

class LayoutPagePainter extends CustomPainter {
  final DocLayout doc;
  final LPage page;
  final Map<String, ImageProvider> images;
  LayoutPagePainter(this.doc, this.page, {this.images = const {}});

  @override
  void paint(Canvas canvas, Size size) {
    final s = doc.settings;
    final k = size.width / s.pageW; // points -> logical pixels
    canvas.save();
    canvas.scale(k);
    canvas.drawRect(Rect.fromLTWH(0, 0, s.pageW, s.pageH), Paint()..color = Color(s.pageBgColor | 0xFF000000));
    if (s.pageFrame) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF1A1A1A);
      canvas.drawRect(Rect.fromLTWH(14, 14, s.pageW - 28, s.pageH - 28), p..strokeWidth = 1.1);
      canvas.drawRect(Rect.fromLTWH(18, 18, s.pageW - 36, s.pageH - 36), p..strokeWidth = 0.4);
    }
    for (final r in page.rects) {
      final rect = Rect.fromLTWH(r.x, r.y, r.w, r.h);
      if (r.fill != 0) canvas.drawRect(rect, Paint()..color = Color(r.fill));
      if (r.stroke != 0) {
        final p = Paint()
          ..color = Color(r.stroke)
          ..strokeWidth = r.lineWidth
          ..style = PaintingStyle.stroke;
        if (r.w == 0 || r.h == 0) {
          canvas.drawLine(Offset(r.x, r.y), Offset(r.x + r.w, r.y + r.h), p);
        } else {
          canvas.drawRect(rect, p);
        }
      }
    }
    for (final line in page.lines) {
      for (final w in line.words) {
        final st = w.style;
        final tp = TextPainter(
          text: TextSpan(text: w.text, style: st.toTextStyle()),
          textDirection: _arabicRe.hasMatch(w.text) ? TextDirection.rtl : TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        final base = st.sup ? line.y - st.size * 0.7 : line.y;
        tp.paint(canvas, Offset(w.x, base - ascent));
        tp.dispose();
        if (st.underline || st.strike) {
          final uy = st.underline ? base + st.size * 0.12 : base - st.size * 0.28;
          canvas.drawLine(Offset(w.x, uy), Offset(w.x + w.width, uy),
              Paint()
                ..color = Color(st.color)
                ..strokeWidth = st.size * 0.06);
        }
      }
    }
    for (final t in PageChrome.of(doc, page)) {
      final tp = TextPainter(
        text: TextSpan(
            text: t.text,
            style: LStyle(family: layoutFamily(s.fontFamily), size: t.size, color: t.color).toTextStyle()),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(t.x, t.baseline - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
      tp.dispose();
      if (t.ruleY != null) {
        canvas.drawLine(Offset(s.margin, t.ruleY!), Offset(s.pageW - s.margin, t.ruleY!),
            Paint()
              ..color = const Color(0xFF444444)
              ..strokeWidth = 0.4);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LayoutPagePainter old) => old.page != page || old.doc != doc;
}

/// One page at a given on-screen width.
class LayoutPage extends StatelessWidget {
  final DocLayout doc;
  final LPage page;
  final double width;
  final void Function(int offset)? onTapLine;
  const LayoutPage({super.key, required this.doc, required this.page, required this.width, this.onTapLine});

  @override
  Widget build(BuildContext context) {
    final s = doc.settings;
    final k = width / s.pageW;
    final h = s.pageH * k;
    if (page.cover != null) {
      final t = coverById(page.cover!.templateId);
      return CoverPagePreview(template: t, data: page.cover!, width: width, height: h);
    }
    return GestureDetector(
      onTapUp: onTapLine == null
          ? null
          : (d) {
              final yPt = d.localPosition.dy / k;
              for (final l in page.lines) {
                if (yPt >= l.top && yPt <= l.top + l.height) {
                  onTapLine!(l.sourceOffset);
                  return;
                }
              }
            },
      child: SizedBox(
        width: width,
        height: h,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: LayoutPagePainter(doc, page))),
          for (final im in page.images)
            Positioned(
              left: im.x * k,
              top: im.y * k,
              width: im.w * k,
              height: im.h * k,
              child: Image.file(File(im.path), fit: BoxFit.fill, errorBuilder: (_, __, ___) => const SizedBox()),
            ),
        ]),
      ),
    );
  }
}

/// All pages, each fitted to the screen width, pinch-zoomable.
class LayoutPagesView extends StatelessWidget {
  final DocLayout doc;
  final void Function(int offset)? onTapLine;
  const LayoutPagesView({super.key, required this.doc, this.onTapLine});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = doc.settings;
      // Fit the whole page: width-limited, but never taller than the viewport.
      var w = c.maxWidth - 24;
      final maxH = c.maxHeight - 24;
      if (maxH.isFinite && w * s.pageH / s.pageW > maxH && c.maxWidth > c.maxHeight) {
        w = maxH * s.pageW / s.pageH;
      }
      return InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        constrained: true,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: doc.pages.length,
          separatorBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('— ${i + 1} / ${doc.pages.length} —',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8A))),
          ),
          itemBuilder: (_, i) => Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
              ]),
              child: LayoutPage(doc: doc, page: doc.pages[i], width: w, onTapLine: onTapLine),
            ),
          ),
        ),
      );
    });
  }
}

final _arabicRe = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
