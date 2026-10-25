import '../core/cover_art.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/book_chrome.dart';
import '../core/page_layout.dart';
import '../core/page_size.dart';
import 'layout_pdf.dart';
import 'book_writers.dart';
import '../presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import '../presentation/document_editor_screen/widgets/table_editor_dialog.dart';

class PdfFace {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font? _boldItalic;
  const PdfFace(this.regular, this.bold, this.italic, [this._boldItalic]);
  pw.Font get boldItalic => _boldItalic ?? bold;

  static PdfFace? _bask;
  static PdfFace? _lora;
  static PdfFace? _sans;
  static PdfFace? _naskh;

  static Future<pw.Font> _load(String name) async {
    final data = await rootBundle.load('assets/fonts/$name');
    return pw.Font.ttf(data);
  }

  static Future<void> warm() async {
    if (_bask != null) return;
    _bask = PdfFace(
      await _load('LibreBaskerville-Regular.ttf'),
      await _load('LibreBaskerville-Bold.ttf'),
      await _load('LibreBaskerville-Italic.ttf'),
      await _load('LibreBaskerville-BoldItalic.ttf'),
    );
    _lora = PdfFace(
      await _load('Lora-Regular.ttf'),
      await _load('Lora-Bold.ttf'),
      await _load('Lora-Italic.ttf'),
      await _load('Lora-BoldItalic.ttf'),
    );
    final nr = await _load('NotoNaskhArabic-Regular.ttf');
    _naskh = PdfFace(nr, await _load('NotoNaskhArabic-Bold.ttf'), nr);
    _sans = PdfFace(
      await _load('DMSans-Regular.ttf'),
      await _load('DMSans-Bold.ttf'),
      await _load('DMSans-Italic.ttf'),
      await _load('DMSans-BoldItalic.ttf'),
    );
  }

  static PdfFace pick(String family) {
    if (family == 'Lora') return _lora ?? _bask!;
    if (family == 'NotoNaskhArabic') return _naskh ?? _bask!;
    if (family == 'Roboto' || family == 'Arial' || family == 'DMSans') {
      return _sans ?? _bask!;
    }
    return _bask!;
  }
}


void paintCoverMarks(PdfGraphics canvas, PdfPoint size, PdfColor accent, String layout) {
  final w = size.x;
  final h = size.y;
    PdfColor fade(double a) => PdfColor(accent.red, accent.green, accent.blue, a);

    void strokeRect(double x, double y, double rw, double rh, PdfColor c, double width) {
      canvas
        ..setStrokeColor(c)
        ..setLineWidth(width)
        ..drawRect(x, y, rw, rh)
        ..strokePath();
    }

    void frame(double m) {
      strokeRect(m, m, w - m * 2, h - m * 2, fade(0.85), 1.2);
      strokeRect(m + 4, m + 4, w - (m + 4) * 2, h - (m + 4) * 2, fade(0.35), 0.7);
    }

    void corners() {
      const s = 16.0;
      canvas
        ..setStrokeColor(accent)
        ..setLineWidth(1.4);
      void corner(double x, double y, double dx, double dy) {
        canvas.drawLine(x, y, x + dx * s, y);
        canvas.drawLine(x, y, x, y + dy * s);
      }
      final top = h - 14;
      corner(14, top, 1, -1);
      corner(w - 14, top, -1, -1);
      corner(14, 14, 1, 1);
      corner(w - 14, 14, -1, 1);
      canvas.strokePath();
    }

    switch (layout) {
      case 'geometric':
        frame(10);
        canvas.setFillColor(fade(0.22));
        for (var top = 28.0; top < h - 24; top += 28) {
          for (var x = 22.0; x < w - 16; x += 28) {
            canvas.drawEllipse(x, h - top, 1.6, 1.6);
          }
        }
        canvas.fillPath();
        break;
      case 'ornate':
      case 'navy':
      case 'night':
      case 'emerald':
      case 'crimson':
      case 'royal':
        frame(11);
        corners();
        canvas
          ..setFillColor(fade(0.12))
          ..drawEllipse(w / 2, h - h * 0.22, w * 0.21, 5)
          ..fillPath();
        break;
      case 'manuscript':
        canvas
          ..setFillColor(fade(0.15))
          ..drawRect(0, h - 36, w, 36)
          ..fillPath();
        corners();
        break;
      case 'marble':
        frame(12);
        canvas
          ..setStrokeColor(fade(0.25))
          ..setLineWidth(0.6);
        for (var i = 0; i < 6; i++) {
          canvas.drawLine(w * 0.2, h * (0.2 + i * 0.12), w * 0.85, h * (0.05 + i * 0.12));
        }
        canvas.strokePath();
        break;
      case 'ocean':
        frame(10);
        canvas
          ..setStrokeColor(fade(0.35))
          ..setLineWidth(1.1);
        for (var i = 0; i < 6; i++) {
          final y = h * 0.38 - i * 10;
          canvas.moveTo(12, y);
          canvas.curveTo(w * 0.25, y + 8, w * 0.5, y, w * 0.5, y);
          canvas.curveTo(w * 0.75, y - 8, w - 12, y, w - 12, y);
        }
        canvas.strokePath();
        break;
      case 'botanical':
        frame(10);
        canvas.setFillColor(fade(0.35));
        for (var i = 0; i < 12; i++) {
          final x = 18.0 + (i % 4) * (w / 5);
          final top = 22.0 + (i ~/ 4) * (h / 5);
          canvas.drawEllipse(x, h - top, 5, 9);
        }
        canvas.fillPath();
        break;
      case 'leather':
        frame(12);
        corners();
        canvas
          ..setFillColor(fade(0.5))
          ..drawRect(w * 0.18, h * 0.56, w * 0.64, 2)
          ..fillPath();
        break;
      case 'nibras':
        frame(10);
        corners();
        final cy = h - h * 0.22;
        canvas
          ..setStrokeColor(fade(0.7))
          ..setLineWidth(1.1)
          ..drawEllipse(w / 2, cy, 16, 16)
          ..strokePath()
          ..setStrokeColor(accent)
          ..drawEllipse(w / 2, cy, 8, 8)
          ..strokePath();
        break;
      case 'classic':
      case 'linen':
      case 'poetry':
        frame(10);
        corners();
        break;
      default:
        corners();
    }
}


class MobileExportService {
  static final _blockRe = RegExp(
    r'(\[TABLE\][\s\S]*?\[/TABLE\])'
    r'|(\[img path="[^"]*"[^\]]*\])'
    r'|(--- Page Break ---)'
    r'|(\n[ \t]*\* \* \*[ \t]*\n)'
    r'|(\n-{12,}\n)'
    r'|(\[note\][\s\S]*?\[/note\])'
    r'|(\[HAŞİYƏ\][\s\S]*?\[/HAŞİYƏ\])'
    r'|(\[COVER[^\]]*\])',
  );

  static String? imageDir;

  static File resolveImage(String path) {
    final direct = File(path);
    if (direct.existsSync()) return direct;
    final name = path.split(RegExp(r'[/\\]')).last;
    if (imageDir != null) {
      final alt = File('$imageDir/$name');
      if (alt.existsSync()) return alt;
    }
    return direct;
  }

  static List<pw.TextSpan> _pdfSpans(String src, [double fontSize = 11.5, Color? ink, PdfFace? face]) {
    final re = RegExp(
      r'\[color=(#[0-9A-Fa-f]{6,8})\]([\s\S]*?)\[/color\]'
      r'|\[bg=(#[0-9A-Fa-f]{6,8})\]([\s\S]*?)\[/bg\]'
      r'|\*\*(.+?)\*\*'
      r'|__(.+?)__'
      r'|~~(.+?)~~'
      r'|\*(.+?)\*'
      r'|\[\^(\d+)\]',
    );
    pw.TextStyle paint(String? hex, {bool bold = false, bool italic = false, bool under = false, bool strike = false}) {
      PdfColor? c;
      if (hex != null) {
        var h = hex.replaceAll('#', '');
        if (h.length == 6) h = 'FF$h';
        final v = int.parse(h, radix: 16);
        c = PdfColor(((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255);
      }
      return pw.TextStyle(
        font: bold
            ? face?.bold
            : italic
                ? face?.italic
                : face?.regular,
        fontSize: fontSize,
        color: c ?? (ink == null ? null : _pdfC(ink)),
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
        decoration: under
            ? pw.TextDecoration.underline
            : strike
                ? pw.TextDecoration.lineThrough
                : null,
      );
    }

    if (!re.hasMatch(src)) {
      return [pw.TextSpan(text: src)];
    }
    final out = <pw.TextSpan>[];
    var cursor = 0;
    for (final m in re.allMatches(src)) {
      if (m.start > cursor) {
        out.add(pw.TextSpan(text: src.substring(cursor, m.start)));
      }
      if (m.group(1) != null) {
        out.add(pw.TextSpan(text: m.group(2) ?? '', style: paint(m.group(1))));
      } else if (m.group(3) != null) {
        out.add(pw.TextSpan(text: m.group(4) ?? '', style: paint(m.group(3))));
      } else if (m.group(5) != null) {
        out.add(pw.TextSpan(text: m.group(5), style: paint(null, bold: true)));
      } else if (m.group(6) != null) {
        out.add(pw.TextSpan(text: m.group(6), style: paint(null, under: true)));
      } else if (m.group(7) != null) {
        out.add(pw.TextSpan(text: m.group(7), style: paint(null, strike: true)));
      } else if (m.group(8) != null) {
        out.add(pw.TextSpan(text: m.group(8), style: paint(null, italic: true)));
      } else if (m.group(9) != null) {
        out.add(pw.TextSpan(
          text: easternDigits(m.group(9)!),
          style: pw.TextStyle(
            font: face?.bold,
            fontSize: fontSize * 0.62,
            color: PdfColors.red900,
          ),
        ));
      }
      cursor = m.end;
    }
    if (cursor < src.length) out.add(pw.TextSpan(text: src.substring(cursor)));
    return out;
  }

  static String _stripInline(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/color]', '');
    s = s.replaceAll(RegExp(r'\[bg=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/bg]', '');
    s = s.replaceAll(RegExp(r'\[align=(left|center|right|justify)\]'), '');
    s = s.replaceAll('[/size]', '');
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(
      RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'),
      (m) => m.group(1) ?? '',
    );
    return s;
  }

  static String _safeFileName(String title, String ext) {
    var base = title.trim().isEmpty ? 'Nibras_Document' : title.trim();
    base = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    base = base.replaceAll(RegExp(r'\s+'), '_');
    if (base.length > 60) base = base.substring(0, 60);
    return '$base.$ext';
  }

  static Future<void> exportPdf({
    required String title,
    required String content,
    required PageSize pageSize,
    bool showPageNumbers = true,
    String pageNumberPos = 'bottom-center',
    String headerText = '',
    String footerText = '',
    String author = '',
    String subtitle = '',
    bool firstLineIndent = false,
    bool chapterNewPage = false,
    double marginMm = 20,
    bool landscape = false,
    int pageNumberStartPage = 1,
    int pageNumberStartAt = 1,
    double fontSize = 16,
    double lineHeight = 1.7,
    int pageBgColor = 0xFFFFFFFF,
    String fontFamily = 'Georgia',
    bool pageFrame = false,
    String pageNumberStyle = 'plain',
    bool bookHeader = false,
    String textAlign = 'left',
  }) async {
    if (kIsWeb) return;
    final bytes = await buildLayoutPdf(
      content: content,
      settings: LayoutSettings(
        pageSize: pageSize,
        landscape: landscape,
        marginMm: marginMm,
        fontFamily: fontFamily,
        fontSize: fontSize,
        lineHeight: lineHeight,
        firstLineIndent: firstLineIndent,
        chapterNewPage: chapterNewPage,
        showPageNumbers: showPageNumbers,
        pageNumberPos: pageNumberPos,
        pageNumberStyle: pageNumberStyle,
        pageNumberStartPage: pageNumberStartPage,
        pageNumberStartAt: pageNumberStartAt,
        headerText: headerText,
        footerText: footerText,
        title: title,
        author: author,
        subtitle: subtitle,
        pageBgColor: pageBgColor,
        pageFrame: pageFrame,
        textAlign: textAlign,
      ),
    );
    final safe = title.trim().isEmpty ? 'Untitled Document' : title.trim();
    await _shareBytes(bytes, _safeFileName(safe, 'pdf'), 'application/pdf');
  }

  /// PDF from the shared page layout (identical to the editor's page view).
  static Future<Uint8List> buildLayoutPdf({
    required String content,
    required LayoutSettings settings,
  }) async {
    final doc = await PageLayoutEngine(settings).layout(content);
    return LayoutPdf.build(doc, title: settings.title);
  }

  // Previous flow-based exporter, kept for reference; not used.
  // ignore: unused_element
  static Future<void> _legacyExportPdf({
    required String title,
    required String content,
    required PageSize pageSize,
    bool showPageNumbers = true,
    String pageNumberPos = 'bottom-center',
    String headerText = '',
    String footerText = '',
    String author = '',
    String subtitle = '',
    bool firstLineIndent = false,
    bool chapterNewPage = false,
    double marginMm = 20,
    bool landscape = false,
    int pageNumberStartPage = 1,
    int pageNumberStartAt = 1,
    double fontSize = 16,
    double lineHeight = 1.7,
    int pageBgColor = 0xFFFFFFFF,
    String fontFamily = 'Georgia',
    bool pageFrame = false,
    String pageNumberStyle = 'plain',
    bool bookHeader = false,
  }) async {
    var pageFormat = switch (pageSize) {
      PageSize.a3 => PdfPageFormat.a3,
      PageSize.a5 => PdfPageFormat.a5,
      PageSize.letter => PdfPageFormat.letter,
      PageSize.legal => PdfPageFormat.legal,
      _ => PdfPageFormat.a4,
    };
    if (landscape) pageFormat = pageFormat.landscape;
    final margin = (marginMm.clamp(8, 40)) * PdfPageFormat.mm;
    final bodyPt = (fontSize * 0.75).clamp(9.0, 28.0);
    final bg = Color(pageBgColor | 0xFF000000);
    final ink = bg.computeLuminance() < 0.4 ? const Color(0xFFF5F0E6) : const Color(0xFF1A1A1A);
    await PdfFace.warm();
    final face = PdfFace.pick(fontFamily);
    final innerW = pageFormat.width - margin * 2;

    final safeTitle = title.trim().isEmpty ? 'Untitled Document' : title.trim();
    final doc = pw.Document();
    final children = await _pdfChildren(
      content: content,
      title: safeTitle,
      author: author,
      subtitle: subtitle,
      firstLineIndent: firstLineIndent,
      chapterNewPage: chapterNewPage,
      bodyPt: bodyPt,
      lineHeight: lineHeight,
      ink: ink,
      face: face,
      innerW: innerW,
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(margin),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
            color: _pdfC(bg),
            padding: pageFrame ? const pw.EdgeInsets.all(14) : pw.EdgeInsets.zero,
            child: pageFrame
                ? pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey900, width: 1.1),
                    ),
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey900, width: 0.4),
                      ),
                    ),
                  )
                : pw.SizedBox(),
          ),
          ),
        ),
        header: (context) {
          final shown = _displayPageNo(
            context.pageNumber,
            showPageNumbers,
            pageNumberStartPage,
            pageNumberStartAt,
            pageNumberPos.startsWith('top'),
          );
          if (context.pageNumber == 1 && author.isNotEmpty) {
            return pw.SizedBox();
          }
          final h = headerText.trim().isNotEmpty ? headerText.trim() : safeTitle;
          final label = shown == null ? '' : formatPageNumber(shown, pageNumberStyle);
          final arabic = RegExp(r'[\u0600-\u06FF]').hasMatch(h);
          pw.Widget numBox() {
            if (label.isEmpty) return pw.SizedBox();
            if (bookHeader || pageNumberInOval(pageNumberStyle)) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey900, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(label, style: pw.TextStyle(font: face.regular, fontSize: 9)),
              );
            }
            return pw.Text(label, style: pw.TextStyle(font: face.regular, fontSize: 9, color: PdfColors.grey700));
          }

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              children: [
                pw.Row(
                  children: [
                    if (!arabic && (bookHeader || pageNumberPos.startsWith('top'))) numBox(),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(
                        h,
                        textAlign: arabic ? pw.TextAlign.right : pw.TextAlign.center,
                        style: pw.TextStyle(font: face.regular, fontSize: 9, color: PdfColors.grey800),
                      ),
                    ),
                    if (arabic && (bookHeader || pageNumberPos.startsWith('top'))) numBox(),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Container(height: bookHeader ? 1.1 : 0.4, color: PdfColors.grey800),
                if (bookHeader) ...[
                  pw.SizedBox(height: 1.5),
                  pw.Container(height: 0.4, color: PdfColors.grey800),
                ],
              ],
            ),
          );
        },
        footer: (context) {
          final shown = _displayPageNo(
            context.pageNumber,
            showPageNumbers,
            pageNumberStartPage,
            pageNumberStartAt,
            !pageNumberPos.startsWith('top'),
          );
          pw.MainAxisAlignment align = pw.MainAxisAlignment.spaceBetween;
          if (pageNumberPos.endsWith('center')) {
            align = pw.MainAxisAlignment.center;
          } else if (pageNumberPos.endsWith('right')) {
            align = pw.MainAxisAlignment.end;
          } else if (pageNumberPos.endsWith('left')) {
            align = pw.MainAxisAlignment.start;
          }
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: align,
              children: [
                if (footerText.trim().isNotEmpty &&
                    !pageNumberPos.endsWith('center'))
                  pw.Text(
                    footerText.trim(),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                if (shown != null && !bookHeader)
                  pw.Text(
                    formatPageNumber(shown, pageNumberStyle),
                    style: pw.TextStyle(font: face.regular, fontSize: 10, color: PdfColors.grey800),
                  ),
              ],
            ),
          );
        },
        build: (context) => children,
      ),
    );

    final bytes = await doc.save();
    await _shareBytes(bytes, _safeFileName(safeTitle, 'pdf'), 'application/pdf');
  }

  static Future<List<pw.Widget>> _pdfChildren({
    required String content,
    required String title,
    required String author,
    required String subtitle,
    required bool firstLineIndent,
    required bool chapterNewPage,
    required double bodyPt,
    required double lineHeight,
    required Color ink,
    required PdfFace face,
    required double innerW,
  }) async {
    final out = <pw.Widget>[];
    if (!content.contains('[COVER') &&
        (author.isNotEmpty || subtitle.isNotEmpty)) {
      out.add(pw.SizedBox(height: 80));
      out.add(pw.Center(
        child: pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
      ));
      if (subtitle.isNotEmpty) {
        out.add(pw.SizedBox(height: 10));
        out.add(pw.Center(
          child: pw.Text(
            subtitle,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ),
        ));
      }
      if (author.isNotEmpty) {
        out.add(pw.SizedBox(height: 28));
        out.add(pw.Center(
          child: pw.Text(author, style: const pw.TextStyle(fontSize: 13)),
        ));
      }
      out.add(pw.NewPage());
    }

    var cursor = 0;
    var firstHeading = true;
    final matches = _blockRe.allMatches(content).toList();
    Future<void> flushText(String raw) async {
      if (raw.trim().isEmpty && raw.isEmpty) return;
      final paras = raw.split('\n\n');
      for (final para in paras) {
        var body = para;
        var align = pw.TextAlign.left;
        final am = RegExp(r'^\[align=(left|center|right|justify)\]')
            .firstMatch(body.trimLeft());
        if (am != null) {
          align = switch (am.group(1)) {
            'center' => pw.TextAlign.center,
            'right' => pw.TextAlign.right,
            'justify' => pw.TextAlign.justify,
            _ => pw.TextAlign.left,
          };
          body = body.trimLeft().substring(am.end);
        }
        var seenFn = false;
        for (final line in body.split('\n')) {
          if (RegExp(r'^\[\^\d+\]:').hasMatch(line.trim())) {
            if (!seenFn) {
              out.add(pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(width: 90, height: 0.7, color: PdfColors.grey800),
              ));
              out.add(pw.SizedBox(height: 3));
            }
            seenFn = true;
            out.add(pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.RichText(
                textAlign: pw.TextAlign.right,
                textDirection: pw.TextDirection.rtl,
                text: pw.TextSpan(
                  style: pw.TextStyle(font: face.regular, fontSize: bodyPt * 0.72, color: _pdfC(ink)),
                  children: _pdfSpans(line.trim(), bodyPt * 0.72, ink, face),
                ),
              ),
            ));
            continue;
          }
          if (line.trim().isNotEmpty) seenFn = false;
          final t = _stripInline(line);
          final trimmed = t.trim();
          if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
            if (chapterNewPage && !firstHeading) out.add(pw.NewPage());
            firstHeading = false;
            out.add(pw.Padding(
              padding: pw.EdgeInsets.only(top: bodyPt, bottom: bodyPt * 0.45),
              child: pw.Text(
                trimmed.substring(2).trim(),
                textAlign: align,
                style: pw.TextStyle(
                  font: face.bold,
                  fontSize: bodyPt * 1.55,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfC(ink),
                ),
              ),
            ));
          } else if (trimmed.startsWith('## ') && !trimmed.startsWith('### ')) {
            out.add(pw.Padding(
              padding: pw.EdgeInsets.only(top: bodyPt * 0.7, bottom: bodyPt * 0.3),
              child: pw.Text(
                trimmed.substring(3).trim(),
                textAlign: align,
                style: pw.TextStyle(
                  font: face.bold,
                  fontSize: bodyPt * 1.22,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfC(ink),
                ),
              ),
            ));
          } else if (trimmed.startsWith('### ')) {
            out.add(pw.Padding(
              padding: pw.EdgeInsets.only(top: bodyPt * 0.4, bottom: bodyPt * 0.2),
              child: pw.Text(
                trimmed.substring(4).trim(),
                textAlign: align,
                style: pw.TextStyle(
                  font: face.bold,
                  fontSize: bodyPt * 1.05,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfC(ink),
                ),
              ),
            ));
          } else if (trimmed.startsWith('> ')) {
            out.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: pw.Text(
                trimmed.substring(2),
                textAlign: align,
                style: pw.TextStyle(
                  font: face.italic,
                  fontSize: bodyPt * 0.95,
                  fontStyle: pw.FontStyle.italic,
                  color: _pdfC(ink),
                ),
              ),
            ));
          } else {
            final indent = firstLineIndent && trimmed.isNotEmpty;
            out.add(pw.Padding(
              padding: pw.EdgeInsets.only(left: indent ? bodyPt : 0),
              child: pw.RichText(
                textAlign: align,
                textDirection:
                    _detectRtl(t) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                text: pw.TextSpan(
                  style: pw.TextStyle(
                    font: face.regular,
                    fontSize: bodyPt,
                    color: _pdfC(ink),
                    lineSpacing: bodyPt * (lineHeight - 1).clamp(0.0, 1.5),
                  ),
                  children: _pdfSpans(line.isEmpty ? ' ' : line, bodyPt, ink, face),
                ),
              ),
            ));
          }
        }
        out.add(pw.SizedBox(height: bodyPt * 0.45));
      }
    }

    for (final m in matches) {
      if (m.start > cursor) {
        await flushText(content.substring(cursor, m.start));
      }
      final s = m.group(0)!;
      if (s.contains('[TABLE]')) {
        final tables = TableBlock.allIn(s);
        if (tables.isNotEmpty) {
          out.add(_pdfTable(tables.first));
          out.add(pw.SizedBox(height: 10));
        }
      } else if (s.startsWith('[img')) {
        final path = RegExp(r'path="([^"]+)"').firstMatch(s)?.group(1);
        if (path != null) {
          try {
            final f = resolveImage(path);
            if (f.existsSync()) {
              final bytes = await f.readAsBytes();
              out.add(pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Center(
                  child: pw.Image(pw.MemoryImage(bytes), height: 220, fit: pw.BoxFit.contain),
                ),
              ));
            }
          } catch (_) {}
        }
      } else if (s.contains('Page Break')) {
        out.add(pw.NewPage());
      } else if (s.contains('* * *')) {
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 16),
          child: pw.Center(
            child: pw.Text('*   *   *', style: const pw.TextStyle(fontSize: 14, letterSpacing: 4)),
          ),
        ));
      } else if (s.contains('[COVER')) {
        final cover = CoverData.parse(s);
        if (cover != null) {
          out.add(_pdfCover(cover, innerW, face));
        }
      } else if (s.contains('[note]') || s.contains('[HAŞİYƏ]')) {
        final inner = s
            .replaceAll('[note]', '')
            .replaceAll('[/note]', '')
            .replaceAll('[HAŞİYƏ]', '')
            .replaceAll('[/HAŞİYƏ]', '')
            .trim();
        out.add(pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 110,
            margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
            padding: const pw.EdgeInsets.only(left: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.amber800, width: 1),
              ),
            ),
            child: pw.Text(
              inner,
              style: pw.TextStyle(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ));
      } else {
        out.add(pw.Divider());
      }
      cursor = m.end;
    }
    if (cursor < content.length) {
      await flushText(content.substring(cursor));
    }
    if (out.isEmpty) {
      out.add(pw.Text(title));
    }
    return out;
  }

  static pw.Widget _pdfTable(TableBlock table) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey800, width: 0.6),
          children: [
            for (var r = 0; r < table.cells.length; r++)
              pw.TableRow(
                decoration: r == 0
                    ? const pw.BoxDecoration(color: PdfColors.blueGrey800)
                    : (r.isOdd ? const pw.BoxDecoration(color: PdfColors.grey200) : null),
                children: [
                  for (final cell in table.cells[r])
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        cell,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: r == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: r == 0 ? PdfColors.amber200 : PdfColors.black,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (table.caption.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Center(
              child: pw.Text(
                table.caption.trim(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Future<void> exportDocx({
    required String title,
    required String content,
    String author = '',
    String subtitle = '',
    DocxOptions? options,
  }) async {
    if (kIsWeb) return;
    final safeTitle = title.trim().isEmpty ? 'Untitled_Document' : title.trim();
    final bytes = DocxWriter.build(
      content,
      options ?? DocxOptions(title: safeTitle, author: author, subtitle: subtitle),
    );
    await _shareBytes(
      bytes,
      _safeFileName(safeTitle, 'docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }

  /// Document markup -> readable plain text (for TXT export and sharing).
  static String plainText(String content) {
    var s = content;
    s = s.replaceAll(RegExp(r'\[COVER[^\]]*\]'), '');
    s = s.replaceAll('[TABLE]', '').replaceAll('[/TABLE]', '');
    s = s.replaceAll(RegExp(r'^\[W\][^\n]*\n?', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\|[ \-|]+\|\s*$\n?', multiLine: true), '');
    s = s.replaceAll('[TOC]', '').replaceAll('[/TOC]', '');
    s = s.replaceAll(RegExp(r'\[/?(note|HAŞİYƏ)\]'), '');
    s = s.replaceAll(RegExp(r'\[align=(left|center|right|justify)\]'), '');
    s = s.replaceAll(RegExp(r'\[size=\d+\]'), '').replaceAll('[/size]', '');
    s = s.replaceAll(RegExp(r'\[img path="[^"]*"[^\]]*\]'), '[Image]');
    s = s.replaceAll('--- Page Break ---', '\n\n');
    s = s.replaceAll(RegExp(r'^#{1,3} ', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^> ', multiLine: true), '');
    return _stripInline(s).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static Future<void> exportTxt({
    required String title,
    required String content,
  }) async {
    if (kIsWeb) return;
    final safeTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final bytes = Uint8List.fromList(utf8.encode(plainText(content)));
    await _shareBytes(bytes, _safeFileName(safeTitle, 'txt'), 'text/plain');
  }

  static Future<void> exportEpub({
    required String title,
    required String content,
    String author = '',
    String subtitle = '',
    String language = 'az',
  }) async {
    if (kIsWeb) return;
    final safeTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final bytes = EpubWriter.build(content,
        title: safeTitle, author: author, subtitle: subtitle, language: language);
    await _shareBytes(bytes, _safeFileName(safeTitle, 'epub'), 'application/epub+zip');
  }


  static bool _detectRtl(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  static Future<String> shareFile(Uint8List bytes, String name, String mime) =>
      _shareBytes(bytes, name, mime);

  static Future<String> _shareBytes(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final durable = File('${docs.path}/exports/$filename');
      await durable.parent.create(recursive: true);
      await durable.writeAsBytes(bytes, flush: true);
    } catch (_) {}
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mime, name: filename)],
      subject: filename,
      text: 'Exported from Nibras Docs',
    );
    return file.path;
  }


  static int? _displayPageNo(
    int physical,
    bool show,
    int startPage,
    int startAt,
    bool thisEdge,
  ) {
    if (!show || !thisEdge) return null;
    if (physical < startPage) return null;
    return startAt + (physical - startPage);
  }

  static PdfColor _pdfC(Color color) {
    final v = color.toARGB32();
    return PdfColor(
      ((v >> 16) & 0xFF) / 255.0,
      ((v >> 8) & 0xFF) / 255.0,
      (v & 0xFF) / 255.0,
    );
  }

  static PdfColor _pdfCA(Color color, double alpha) {
    final c = _pdfC(color);
    return PdfColor(c.red, c.green, c.blue, alpha);
  }

  static pw.Widget _pdfArtCover(ArtCover art, CoverData data, double w, double h) {
    final g = ArtCoverGeometry.of(art.style, w, h,
        titleScale: data.titleScale <= 0 ? 1 : data.titleScale, title: data.title.trim(), subtitle: data.subtitle.trim());
    final serif = PdfFace.pick('LibreBaskerville');
    final sans = PdfFace.pick('DMSans');
    final title = data.title.trim().isEmpty ? CoverData.brandTitle : data.title.trim();
    final author = data.author.trim();
    final sub = data.subtitle.trim();
    final ink = _pdfC(data.titleColor == 0 ? art.ink : Color(data.titleColor | 0xFF000000));
    final a = _pdfC(art.accent);
    final bytes = ArtCoverCache.jpeg[art.id];
    pw.Widget at(ArtBox b, pw.Widget c) => pw.Positioned(left: b.x, top: b.y, child: pw.SizedBox(width: b.w, height: b.h, child: c));
    pw.Widget line(ArtBox b, String s, pw.TextStyle st) =>
        at(b, pw.Center(child: pw.FittedBox(fit: pw.BoxFit.scaleDown, child: pw.Text(s, maxLines: 1, softWrap: false, style: st))));
    return pw.SizedBox(
      width: w,
      height: h,
      child: pw.Stack(children: [
        pw.Positioned.fill(
          child: pw.Container(
            color: _pdfC(art.bg),
            child: bytes == null ? null : pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover, alignment: pw.Alignment.center),
          ),
        ),
        if (art.plaque) ...[
          for (final b in [g.pill(g.brand, 11 * 1.3, g.brandSize), g.pill(g.url, 14, g.urlSize)])
            at(
                b,
                pw.Container(
                    decoration: pw.BoxDecoration(
                        color: _pdfCA(art.bg, 0.72),
                        borderRadius: pw.BorderRadius.circular(b.h / 2),
                        border: pw.Border.all(color: _pdfCA(art.accent, 0.7), width: g.brandSize * 0.06)))),
          at(
              g.plaqueBox,
              pw.Container(
                  decoration: pw.BoxDecoration(
                      color: _pdfCA(art.bg, 0.80),
                      borderRadius: pw.BorderRadius.circular(g.plaqueBox.w * 0.03),
                      border: pw.Border.all(color: _pdfCA(art.accent, 0.85), width: g.brandSize * 0.08)))),
        ],
        line(g.brand, 'NIBRAS CODE', pw.TextStyle(font: sans.bold, fontSize: g.brandSize, letterSpacing: g.brandSize * 0.3, color: a)),
        at(
          g.emblem,
          pw.Container(
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: _pdfC(art.bg.withValues(alpha: 0.55)),
              border: pw.Border.all(color: a, width: g.emblem.w * 0.025),
            ),
            child: pw.Text('NC', style: pw.TextStyle(font: serif.bold, fontSize: g.emblem.w * 0.3, letterSpacing: g.emblem.w * 0.02, color: a)),
          ),
        ),
        at(
          g.title,
          pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.SizedBox(
                width: g.title.w,
                child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
                  pw.Text(title, textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: serif.bold, fontSize: g.titleSize, lineSpacing: g.titleSize * 0.25, color: ink)),
                  if (sub.isNotEmpty) ...[
                    pw.SizedBox(height: g.titleSize * 0.4),
                    pw.Text(sub, textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: serif.italic, fontSize: g.titleSize * 0.45, lineSpacing: g.titleSize * 0.13, color: ink)),
                  ],
                  pw.SizedBox(height: g.titleSize * 0.5),
                  pw.Container(width: g.ruleW, height: g.titleSize * 0.03 + 0.4, color: a),
                ]),
              ),
            ),
          ),
        ),
        if (author.isNotEmpty)
          line(g.author, author, pw.TextStyle(font: sans.regular, fontSize: g.authorSize, letterSpacing: g.authorSize * 0.08, color: ink)),
        line(g.url, 'NibrasCode.com', pw.TextStyle(font: sans.regular, fontSize: g.urlSize, letterSpacing: g.urlSize * 0.06, color: a)),
      ]),
    );
  }

  static pw.Widget pdfCoverPage(CoverData data, double width, double height) =>
      _pdfCover(data, width, PdfFace.pick('LibreBaskerville'), height: height);

  static pw.Widget _pdfCover(CoverData data, double width, PdfFace face, {double height = 500}) {
    final art = artCoverFor(data.templateId);
    if (art != null) return _pdfArtCover(art, data, width, height);
    final t = coverById(data.templateId);
    final title = data.title.trim().isEmpty ? CoverData.brandTitle : data.title.trim();
    final author = data.author.trim().isEmpty ? '' : data.author.trim();
    final sub = data.subtitle.trim();
    final fg = _pdfC(t.fg);
    final bg = _pdfC(t.bg);
    final accent = _pdfC(t.accent);

    pw.Widget titleBlock({pw.TextAlign align = pw.TextAlign.center, PdfColor? color}) {
      return pw.Column(
        crossAxisAlignment: align == pw.TextAlign.left
            ? pw.CrossAxisAlignment.start
            : pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title,
            textAlign: align,
            style: pw.TextStyle(
              font: face.bold,
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: color ?? fg,
            ),
          ),
          if (sub.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              sub,
              textAlign: align,
              style: pw.TextStyle(font: face.italic, fontSize: 12, fontStyle: pw.FontStyle.italic, color: color ?? fg),
            ),
          ],
        ],
      );
    }

    pw.Widget authorLine(PdfColor color) => author.isEmpty
        ? pw.SizedBox()
        : pw.Text(
            author.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: face.regular, fontSize: 11, letterSpacing: 1.6, color: color),
          );

    pw.Widget inner;
    final titleInk = data.titleColor == 0 ? fg : _pdfC(Color(data.titleColor | 0xFF000000));
    switch (t.layout) {
      case 'medallion':
        inner = pw.Column(
          children: [
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Container(
                width: 72,
                height: 72,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: accent, width: 2),
                ),
              ),
            ),
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              color: accent,
              padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: pw.Text(title, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: face.bold, fontSize: 22, color: titleInk)),
            ),
            pw.Spacer(),
            authorLine(titleInk),
            pw.SizedBox(height: 18),
          ],
        );
        break;
      case 'literary':
        inner = pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            children: [
              pw.Spacer(),
              titleBlock(color: titleInk),
              pw.Spacer(),
              authorLine(titleInk),
              pw.SizedBox(height: 12),
            ],
          ),
        );
        break;
      case 'curve':
      case 'diagonal':
        inner = pw.Column(
          children: [
            pw.Container(height: 180, color: t.layout == 'curve' ? accent : bg),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(18),
                child: titleBlock(color: titleInk),
              ),
            ),
            authorLine(fg),
            pw.SizedBox(height: 16),
          ],
        );
        break;
      case 'nibrascode':
        inner = pw.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: accent, width: 0.8)),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: pw.Column(
            children: [
              pw.Text('NIBRAS CODE',
                  style: pw.TextStyle(font: face.bold, fontSize: 10, letterSpacing: 2.4, color: accent)),
              pw.SizedBox(height: 18),
              pw.Container(
                width: 52,
                height: 52,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: accent, width: 0.8),
                ),
                child: pw.Text('NC', style: pw.TextStyle(font: face.bold, fontSize: 15, letterSpacing: 1, color: accent)),
              ),
              pw.Spacer(),
              titleBlock(color: titleInk),
              pw.SizedBox(height: 14),
              pw.Container(width: 60, height: 0.6, color: accent),
              pw.SizedBox(height: 10),
              authorLine(fg),
              pw.Spacer(),
              pw.Text('NibrasCode.com',
                  style: pw.TextStyle(font: face.regular, fontSize: 9, letterSpacing: 0.8, color: accent)),
            ],
          ),
        );
        break;
      case 'banner':
        inner = pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              color: accent,
              padding: const pw.EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: titleBlock(color: PdfColors.white),
            ),
            pw.Spacer(),
            authorLine(fg),
            pw.SizedBox(height: 24),
          ],
        );
        break;
      case 'band':
        inner = pw.Column(
          children: [
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              color: accent,
              padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: titleBlock(color: PdfColors.white),
            ),
            pw.Spacer(),
            authorLine(fg),
            pw.SizedBox(height: 28),
          ],
        );
        break;
      case 'split':
        inner = pw.Row(
          children: [
            pw.Container(
              width: 78,
              color: accent,
              alignment: pw.Alignment.center,
              child: pw.Text(
                author.isEmpty ? '' : author.toUpperCase(),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white, letterSpacing: 1.2),
              ),
            ),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(22),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Spacer(),
                    titleBlock(align: pw.TextAlign.left),
                    pw.Spacer(),
                  ],
                ),
              ),
            ),
          ],
        );
        break;
      case 'academic':
        inner = pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            children: [
              pw.SizedBox(height: 12),
              pw.Container(
                width: 42,
                height: 42,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: accent, width: 1.2),
                ),
              ),
              pw.SizedBox(height: 16),
              titleBlock(),
              pw.SizedBox(height: 10),
              pw.Container(width: 56, height: 1, color: accent),
              pw.Spacer(),
              authorLine(accent),
              pw.SizedBox(height: 16),
            ],
          ),
        );
        break;
      default:
        inner = pw.Container(
          margin: const pw.EdgeInsets.all(16),
          padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: accent, width: 1.4),
          ),
          child: pw.Column(
            children: [
              pw.Container(width: 64, height: 1, color: accent),
              pw.Spacer(),
              titleBlock(),
              pw.SizedBox(height: 14),
              pw.Container(width: 64, height: 1, color: accent),
              pw.Spacer(),
              authorLine(accent),
              if (data.publisher.isNotEmpty || data.year.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text(
                    [data.publisher, data.year].where((e) => e.trim().isNotEmpty).join(' · '),
                    style: pw.TextStyle(fontSize: 9, color: fg),
                  ),
                ),
              pw.SizedBox(height: 8),
            ],
          ),
        );
    }

    return pw.Container(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
            child: pw.Container(color: bg),
          ),
          pw.Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
            child: pw.CustomPaint(
              size: PdfPoint(width, height),
              painter: (canvas, size) => paintCoverMarks(canvas, size, accent, t.layout),
            ),
          ),
          pw.Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: pw.Container(width: 7, color: PdfColors.black),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: inner,
          ),
        ],
      ),
    );
  }

}
