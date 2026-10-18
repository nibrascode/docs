// Shared page layout engine.
//
// The editor's page view and the PDF export both consume the output of
// [PageLayoutEngine.layout]. Every word gets an absolute position (in PDF
// points) here, so the screen and the PDF break lines and pages at exactly
// the same places.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import '../presentation/document_editor_screen/widgets/document_canvas.dart';
import 'book_chrome.dart';
import 'page_size.dart';
import 'rich_markup.dart';

const double kPtPerMm = 72 / 25.4;

/// Maps the user's font choice to a bundled family (same TTF in app and PDF).
String layoutFamily(String userFamily) => switch (userFamily) {
      'Lora' => 'Lora',
      'NotoNaskhArabic' || 'Naskh' => 'NotoNaskhArabic',
      'Roboto' || 'Arial' || 'DMSans' || 'Sans' => 'DMSans',
      _ => 'LibreBaskerville',
    };

class LStyle {
  final String family;
  final double size;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final int color;
  final int bg; // 0 = none
  final bool sup;
  final String? link;

  const LStyle({
    required this.family,
    required this.size,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color = 0xFF1A1A1A,
    this.bg = 0,
    this.sup = false,
    this.link,
  });

  LStyle copyWith({
    double? size,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    int? color,
    int? bg,
    bool? sup,
    String? link,
  }) =>
      LStyle(
        family: family,
        size: size ?? this.size,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        strike: strike ?? this.strike,
        color: color ?? this.color,
        bg: bg ?? this.bg,
        sup: sup ?? this.sup,
        link: link ?? this.link,
      );

  /// Bundled fonts have Regular, Bold and Italic only (no BoldItalic):
  /// bold wins, exactly like the PDF face picker.
  TextStyle toTextStyle() => TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: (italic && !bold) ? FontStyle.italic : FontStyle.normal,
        color: Color(color),
        height: 1.0,
        letterSpacing: 0,
        wordSpacing: 0,
      );

  LStyle withFamily(String f) => LStyle(
      family: f, size: size, bold: bold, italic: italic, underline: underline,
      strike: strike, color: color, bg: bg, sup: sup, link: link);

  String get key => '$family|$size|$bold|$italic';
}

/// One positioned piece of text (usually a single word).
class LWord {
  final String text;
  final LStyle style;
  double x; // left edge, points from page left
  final double width;
  LWord(this.text, this.style, this.x, this.width);
}

class LLine {
  final List<LWord> words;
  final double y; // baseline, points from page top
  final double top;
  final double height;
  final bool rtl;
  final int sourceOffset; // char offset into the document (for tap-to-edit)
  LLine(this.words, this.y, this.top, this.height, this.rtl, this.sourceOffset);
}

class LRect {
  final double x, y, w, h;
  final int stroke; // 0 = none
  final int fill; // 0 = none
  final double lineWidth;
  const LRect(this.x, this.y, this.w, this.h,
      {this.stroke = 0, this.fill = 0, this.lineWidth = 0.6});
}

class LImage {
  final String path;
  final double x, y, w, h;
  const LImage(this.path, this.x, this.y, this.w, this.h);
}

class LPage {
  final List<LLine> lines = [];
  final List<LRect> rects = [];
  final List<LImage> images = [];
  CoverData? cover;
  bool plain = false; // no header / page number (title page)
  String header = '';
  String pageLabel = '';
  int physical = 0;
}

class LayoutSettings {
  final PageSize pageSize;
  final bool landscape;
  final double marginMm;
  final String fontFamily;
  final double fontSize; // editor px @96dpi, as stored in settings
  final double lineHeight;
  final bool firstLineIndent;
  final bool chapterNewPage;
  final bool showPageNumbers;
  final String pageNumberPos;
  final String pageNumberStyle;
  final int pageNumberStartPage;
  final int pageNumberStartAt;
  final String headerText;
  final String footerText;
  final String title;
  final String author;
  final String subtitle;
  final int pageBgColor;
  final bool pageFrame;
  final String textAlign; // left, center, right, justify

  const LayoutSettings({
    this.pageSize = PageSize.a4,
    this.landscape = false,
    this.marginMm = 20,
    this.fontFamily = 'Georgia',
    this.fontSize = 16,
    this.lineHeight = 1.7,
    this.firstLineIndent = false,
    this.chapterNewPage = false,
    this.showPageNumbers = true,
    this.pageNumberPos = 'bottom-center',
    this.pageNumberStyle = 'plain',
    this.pageNumberStartPage = 1,
    this.pageNumberStartAt = 1,
    this.headerText = '',
    this.footerText = '',
    this.title = '',
    this.author = '',
    this.subtitle = '',
    this.pageBgColor = 0xFFFFFFFF,
    this.pageFrame = false,
    this.textAlign = 'left',
  });

  double get pageW => landscape ? pageSize.heightPt : pageSize.widthPt;
  double get pageH => landscape ? pageSize.widthPt : pageSize.heightPt;
  double get margin => marginMm.clamp(8, 40) * kPtPerMm;
  double get bodyPt => (fontSize * 0.75).clamp(7.0, 28.0);
  int get ink => Color(pageBgColor | 0xFF000000).computeLuminance() < 0.4
      ? 0xFFF5F0E6
      : 0xFF1A1A1A;
  bool get hasHeader => headerText.trim().isNotEmpty;
  bool get hasFooter => showPageNumbers || footerText.trim().isNotEmpty;
}

class DocLayout {
  final LayoutSettings settings;
  final List<LPage> pages;
  DocLayout(this.settings, this.pages);
}

typedef ImageSizer = Future<Size?> Function(String path);

Future<Size?> defaultImageSizer(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return null;
    final codec = await ui.instantiateImageCodec(await f.readAsBytes());
    final frame = await codec.getNextFrame();
    return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  } catch (_) {
    return null;
  }
}

class _Para {
  final List<LWord> tokens; // words with x = 0, width measured
  final LStyle base;
  final String align;
  final bool indentFirst;
  final double leftIndent;
  final double spaceBefore;
  final double spaceAfter;
  final bool rtl;
  final int offset;
  final List<int> tokenOffsets;
  final bool newPage;
  _Para(this.tokens, this.base, this.align, this.indentFirst, this.leftIndent,
      this.spaceBefore, this.spaceAfter, this.rtl, this.offset,
      this.tokenOffsets, {this.newPage = false});
}

class PageLayoutEngine {
  final LayoutSettings s;
  final ImageSizer imageSizer;
  final Map<String, double> _cache = {};

  PageLayoutEngine(this.s, {this.imageSizer = defaultImageSizer});

  static final _punctEdges = RegExp(r'^([\(\[«"\u201C]*)(.*?)([\.,;:!\?\)\]»"\u201D\u060C\u061B\u061F]*)$', dotAll: true);
  static final _digits = RegExp(r'[0-9\u0660-\u0669]');
  static const _mirror = {0x28: 0x29, 0x29: 0x28, 0x5B: 0x5D, 0x5D: 0x5B, 0xAB: 0xBB, 0xBB: 0xAB};
  static final _strongLtr = RegExp(r'[A-Za-z\u00C0-\u024F\u0259\u018F\u0400-\u04FF]');
  static final _firstStrong = RegExp(r'[A-Za-z\u00C0-\u024F\u0259\u018F\u0400-\u04FF\u0590-\u08FF]');
  static final _alignRe = RegExp(r'^\[align=(left|center|right|justify)\]');
  static final _arabic = RegExp(r'[\u0590-\u08FF\uFB1D-\uFEFC]');

  static final _cyr = RegExp(r'[\u0400-\u04FF]');

  /// Arabic words use Noto Naskh Arabic; Cyrillic falls back to Lora
  /// (the only bundled Latin family with Cyrillic glyphs).
  static LStyle scriptStyle(String w, LStyle st) {
    if (_arabic.hasMatch(w)) return st.withFamily('NotoNaskhArabic');
    if (_cyr.hasMatch(w) && st.family != 'Lora') return st.withFamily('Lora');
    return st;
  }

  double measure(String text, LStyle st) {
    final k = '${st.key}|$text';
    final hit = _cache[k];
    if (hit != null) return hit;
    final tp = TextPainter(
      text: TextSpan(text: text, style: st.toTextStyle()),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return _cache[k] = w;
  }

  static int? _hex(String? h) {
    if (h == null) return null;
    var v = h.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return int.tryParse(v, radix: 16);
  }

  /// Splits a line into styled runs (markup removed).
  /// Shared inline parser (same model as the editor: rich_markup.dart).
  static List<(String, LStyle)> runs(String src, LStyle st) {
    final p = RichMarkup.parse(src);
    final out = <(String, LStyle)>[];
    final buf = StringBuffer();
    LStyle? cur;
    void flush() {
      if (buf.isNotEmpty && cur != null) out.add((buf.toString(), cur!));
      buf.clear();
    }

    for (var k = 0; k < p.length; k++) {
      final sp = p.st[k];
      LStyle ls;
      String text = p.el[k];
      if (p.isLink(k)) {
        final (lt, url) = ParsedMarkup.linkParts(text);
        text = lt;
        ls = st.copyWith(
          bold: st.bold || sp.bold,
          italic: st.italic || sp.italic,
          underline: true,
          color: 0xFF175CD3,
          link: url,
        );
      } else if (p.isFootnote(k)) {
        text = text.substring(2, text.length - 1);
        ls = st.copyWith(size: st.size * 0.62, bold: true, sup: true, color: 0xFF8C1C13);
      } else {
        ls = st.copyWith(
          bold: st.bold || sp.bold,
          italic: st.italic || sp.italic,
          underline: st.underline || sp.underline,
          strike: st.strike || sp.strike,
          color: _hex(sp.color),
          bg: _hex(sp.bg),
          size: sp.size == null ? null : (sp.size! * 0.75).clamp(6.0, 60.0),
        );
        if (sp.font != null) ls = ls.withFamily(layoutFamily(sp.font!));
      }
      if (cur != null && _same(cur, ls)) {
        buf.write(text);
      } else {
        flush();
        cur = ls;
        buf.write(text);
      }
    }
    flush();
    return out;
  }

  static bool _same(LStyle a, LStyle b) =>
      a.family == b.family && a.size == b.size && a.bold == b.bold && a.italic == b.italic &&
      a.underline == b.underline && a.strike == b.strike && a.color == b.color && a.bg == b.bg && a.sup == b.sup && a.link == b.link;

  /// Tokenises runs into words (spaces are separators, not tokens).
  /// Words glued to the previous one (style change mid-word) are kept as
  /// separate tokens with `glue` semantics: width added without a space.
  (List<LWord>, List<bool>) _tokens(List<(String, LStyle)> rs) {
    final words = <LWord>[];
    final glue = <bool>[];
    var prevEndedWithSpace = true;
    for (final (text, st) in rs) {
      final parts = text.split(RegExp(r'(?<= )|(?= )'));
      for (final p in parts) {
        if (p.isEmpty) continue;
        if (p == ' ') {
          prevEndedWithSpace = true;
          continue;
        }
        for (final w in p.split(' ').where((e) => e.isNotEmpty)) {
          final ws = scriptStyle(w, st);
          words.add(LWord(w, ws, 0, measure(w, ws)));
          glue.add(!prevEndedWithSpace && words.length > 1);
          prevEndedWithSpace = false;
        }
      }
    }
    return (words, glue);
  }

  Future<DocLayout> layout(String content) async {
    final pages = <LPage>[];
    final m = s.margin;
    final headerH = s.hasHeader ? s.bodyPt * 1.6 + 6 : 0.0;
    final footerH = s.hasFooter ? s.bodyPt * 1.6 + 6 : 0.0;
    final top = m + headerH;
    final bottom = s.pageH - m - footerH;
    final left = m;
    final width = s.pageW - m * 2;
    final body = LStyle(family: layoutFamily(s.fontFamily), size: s.bodyPt, color: s.ink);

    LPage page = LPage();
    pages.add(page);
    var y = top;
    var pageHasContent = false;

    void newPage() {
      page = LPage();
      pages.add(page);
      y = top;
      pageHasContent = false;
    }

    double lineH(LStyle st) => st.size * s.lineHeight;

    void placePara(_Para p) {
      if (p.newPage && pageHasContent) newPage();
      if (pageHasContent) y += p.spaceBefore;
      final lh = lineH(p.base);
      final space = measure(' ', p.base);
      final indent = p.indentFirst ? p.base.size * 1.5 : 0.0;
      var i = 0;
      var firstLine = true;
      final (toks, glue) = (p.tokens, p.tokenOffsets.map((e) => e < 0).toList());
      if (toks.isEmpty) {
        if (y + lh > bottom) newPage();
        y += lh;
        pageHasContent = true;
        y += p.spaceAfter;
        return;
      }
      while (i < toks.length) {
        final avail = width - p.leftIndent - (firstLine ? indent : 0);
        final line = <LWord>[];
        final lineGlue = <bool>[];
        var w = 0.0;
        while (i < toks.length) {
          final t = toks[i];
          final g = glue[i] && line.isNotEmpty;
          final add = (line.isEmpty || g ? 0 : space) + t.width;
          if (line.isNotEmpty && w + add > avail) break;
          if (line.isEmpty && t.width > avail) {
            // Hard-break a word longer than the line.
            var cut = t.text.length;
            while (cut > 1 && measure(t.text.substring(0, cut), t.style) > avail) {
              cut--;
            }
            final head = t.text.substring(0, cut);
            final rest = t.text.substring(cut);
            line.add(LWord(head, t.style, 0, measure(head, t.style)));
            lineGlue.add(false);
            toks[i] = LWord(rest, t.style, 0, measure(rest, t.style));
            w = line.first.width;
            break;
          }
          line.add(t);
          lineGlue.add(g);
          w += add;
          i++;
        }
        if (y + lh > bottom && pageHasContent) newPage();
        final isLast = i >= toks.length;
        // Horizontal placement.
        // RTL paragraphs take their indents on the right-hand side.
        final x0 = p.rtl ? left : left + p.leftIndent + (firstLine ? indent : 0);
        var gap = space;
        var start = x0;
        final spaces = lineGlue.where((g) => !g).length - 1;
        switch (p.align) {
          case 'center':
            start = x0 + (avail - w) / 2;
            break;
          case 'right':
            start = x0 + avail - w;
            break;
          case 'justify':
            if (!isLast && spaces > 0) gap = space + (avail - w) / spaces;
            if (isLast && p.rtl) start = x0 + avail - w;
            break;
          default:
            if (p.rtl) start = x0 + avail - w;
        }
        // Bidi placement: words of the other direction keep their own order
        // inside a run (e.g. a Latin phrase inside an Arabic paragraph).
        final placed = <LWord>[];
        final paraDir = p.rtl ? 1 : 0;
        // Split trailing/leading punctuation off words so it can take the
        // direction of its surroundings (Unicode bidi neutrals), e.g.
        // "ملف PDF." shows the period at the far left like the editor.
        final mixed = p.rtl || line.any((t) => _arabic.hasMatch(t.text));
        final items = <(String, LStyle, double, bool)>[]; // text, style, width, glued
        for (var k = 0; k < line.length; k++) {
          final t = line[k];
          final m = _punctEdges.firstMatch(t.text);
          final glue = k > 0 && lineGlue[k];
          if (!mixed || m == null || (m.group(1)!.isEmpty && m.group(3)!.isEmpty) || m.group(2)!.isEmpty) {
            items.add((t.text, t.style, t.width, glue));
            continue;
          }
          var first = true;
          for (final part in [m.group(1)!, m.group(2)!, m.group(3)!]) {
            if (part.isEmpty) continue;
            items.add((part, t.style, measure(part, t.style), first ? glue : true));
            first = false;
          }
        }
        // Resolve directions: 1 rtl, 0 ltr, -1 neutral.
        final dirs = [
          for (final it in items) _arabic.hasMatch(it.$1) ? 1 : (_strongLtr.hasMatch(it.$1) ? 0 : -1)
        ];
        final neutral = [for (final d in dirs) d == -1];
        for (var k = 0; k < dirs.length; k++) {
          if (dirs[k] != -1) continue;
          var before = paraDir, after = paraDir;
          for (var j = k - 1; j >= 0; j--) {
            if (dirs[j] >= 0) { before = dirs[j]; break; }
          }
          for (var j = k + 1; j < dirs.length; j++) {
            if (dirs[j] >= 0) { after = dirs[j]; break; }
          }
          dirs[k] = before == after ? before : paraDir;
        }
        // Ensure resolved neutrals never feed back as strong for later ones.
        final runsIdx = <(int, List<int>)>[];
        for (var k = 0; k < items.length; k++) {
          final d = dirs[k];
          if (runsIdx.isNotEmpty && runsIdx.last.$1 == d) {
            runsIdx.last.$2.add(k);
          } else {
            runsIdx.add((d, [k]));
          }
        }
        final visualRuns = p.rtl ? runsIdx.reversed.toList() : runsIdx;
        final order = <int>[
          for (final r in visualRuns) ...(r.$1 == 1 ? r.$2.reversed : r.$2),
        ];
        final vpos = List<int>.filled(order.length, 0);
        for (var v = 0; v < order.length; v++) {
          vpos[order[v]] = v;
        }
        // A glued item whose logical predecessor ended up elsewhere visually.
        bool hugs(int g) => items[g].$4 && g > 0 && (vpos[g] - vpos[g - 1]).abs() != 1;
        var x = (p.align == 'justify' && !isLast) ? x0 : start;
        for (var v = 0; v < order.length; v++) {
          final k = order[v];
          if (v > 0) {
            final prev = order[v - 1];
            // Logical neighbours: use their own glue. Visual-only neighbours
            // (at a direction-run boundary): a split-off punctuation mark
            // has no space before it, so it hugs the run edge.
            final glued = (k - prev).abs() == 1
                ? items[k > prev ? k : prev].$4
                : (hugs(k) || hugs(prev));
            if (!glued) x += gap;
          }
          final it = items[k];
          var text = it.$1;
          if (neutral[k] && dirs[k] == 1 && !_digits.hasMatch(text)) {
            // Neutral run inside RTL: visual order is reversed, brackets mirror.
            text = String.fromCharCodes(text.runes.toList().reversed.map((r) => _mirror[r] ?? r));
          }
          placed.add(LWord(text, it.$2, x, it.$3));
          x += it.$3;
        }
        // Baseline: centre the font box inside the line box (like CSS).
        final baseline = y + (lh - p.base.size) / 2 + p.base.size * 0.8;
        page.lines.add(LLine(placed, baseline, y, lh, p.rtl, p.offset));
        for (final wd in placed) {
          if (wd.style.bg != 0) {
            page.rects.add(LRect(wd.x, y + (lh - p.base.size * 1.2) / 2, wd.width,
                p.base.size * 1.2, fill: wd.style.bg));
          }
        }
        y += lh;
        pageHasContent = true;
        firstLine = false;
      }
      y += p.spaceAfter;
    }

    _Para para(String text, LStyle st, int offset,
        {String? align,
        bool indentFirst = false,
        double leftIndent = 0,
        double before = 0,
        double after = 0,
        bool newPage = false,
        bool raw = false}) {
      final strong = _firstStrong.firstMatch(text)?.group(0) ?? '';
      final rtl = _arabic.hasMatch(strong);
      final (toks, glue) = _tokens(raw ? [(text, st)] : runs(text, st));
      return _Para(
        toks,
        st,
        align ?? s.textAlign,
        indentFirst,
        leftIndent,
        before,
        after,
        rtl,
        offset,
        [for (final g in glue) g ? -1 : 0],
        newPage: newPage,
      );
    }

    // Title page (only when there is no designed cover).
    if (!content.contains('[COVER') && (s.author.trim().isNotEmpty || s.subtitle.trim().isNotEmpty)) {
      y = top + (bottom - top) * 0.28;
      placePara(para(s.title.trim().isEmpty ? ' ' : s.title.trim(),
          body.copyWith(size: body.size * 2, bold: true), 0, align: 'center', after: 10));
      if (s.subtitle.trim().isNotEmpty) {
        placePara(para(s.subtitle.trim(), body.copyWith(size: body.size * 1.1, italic: true, color: 0xFF555555), 0,
            align: 'center', after: 24));
      }
      if (s.author.trim().isNotEmpty) {
        placePara(para(s.author.trim(), body.copyWith(size: body.size * 1.05), 0, align: 'center'));
      }
      page.plain = true;
      newPage();
    }

    var offset = 0;
    var firstChapter = true;
    final allBlocks = DocumentBlocks.parse(content);
    for (var bi = 0; bi < allBlocks.length; bi++) {
      final b = allBlocks[bi];
      switch (b.kind) {
        case DocBlockKind.cover:
          final c = CoverData.parse(b.text);
          if (c != null) {
            if (pageHasContent) newPage();
            page.cover = c;
            newPage();
          }
          break;
        case DocBlockKind.pageBreak:
          if (pageHasContent) newPage();
          break;
        case DocBlockKind.sceneBreak:
          placePara(para('*   *   *', body, offset, raw: true, align: 'center', before: lineH(body) * 0.5, after: lineH(body) * 0.5));
          break;
        case DocBlockKind.hr:
          if (y + 12 > bottom) newPage();
          y += 6;
          page.rects.add(LRect(left, y, width, 0, stroke: s.ink, lineWidth: 0.6));
          y += 6;
          pageHasContent = true;
          break;
        case DocBlockKind.note:
          final st = body.copyWith(size: body.size * 0.9, italic: true);
          final startY = y;
          final startPage = page;
          placePara(para(b.text, st, offset, leftIndent: 10, before: 4, after: 4));
          if (identical(startPage, page)) {
            page.rects.add(LRect(left + 2, startY + 4, 0, y - startY - 8, stroke: 0xFFC9A84C, lineWidth: 2));
          }
          break;
        case DocBlockKind.image:
          final size = await imageSizer(b.imagePath);
          if (size == null || size.width <= 0) break;
          var w = width * b.imageWidth.clamp(0.2, 1.0);
          var h = w * size.height / size.width;
          final maxH = bottom - top;
          if (h > maxH) {
            h = maxH;
            w = h * size.width / size.height;
          }
          if (y + h > bottom && pageHasContent) newPage();
          final x = switch (b.imageAlign) {
            'left' => left,
            'right' => left + width - w,
            _ => left + (width - w) / 2,
          };
          page.images.add(LImage(b.imagePath, x, y, w, h));
          y += h + 6;
          pageHasContent = true;
          if (b.imageCaption.isNotEmpty) {
            placePara(para(b.imageCaption, body.copyWith(size: body.size * 0.8, italic: true), offset, align: 'center', after: 6));
          }
          break;
        case DocBlockKind.table:
          _placeTable(b, body, left, width, bottom, () => y, (v) => y = v, () => page, newPage, () => pageHasContent = true);
          break;
        case DocBlockKind.text:
          var lineOffset = offset;
          final lines = b.text.split('\n');
          String? chunkAlign; // [align=x] applies until the next blank line
          for (var li = 0; li < lines.length; li++) {
            final raw = lines[li];
            var t = raw.trimRight();
            final here = lineOffset;
            lineOffset += raw.length + 1;
            final am = _alignRe.firstMatch(t);
            if (am != null) {
              chunkAlign = am.group(1);
              t = t.substring(am.end);
            }
            if (t.trim().isEmpty && ((li == 0 && bi > 0) || (li == lines.length - 1 && bi < allBlocks.length - 1))) {
              chunkAlign = null; // line break that only separates this block from a table/image
              continue;
            }
            if (t.trim().isEmpty) {
              chunkAlign = null;
              // Every empty line is one full line, exactly as in the editor
              // (never at the top of a page).
              if (pageHasContent) y += lineH(body);
              continue;
            }
            if (t.startsWith('# ')) {
              final np = s.chapterNewPage && !firstChapter;
              firstChapter = false;
              placePara(para(t.substring(2), body.copyWith(size: body.size * 1.55, bold: true), here,
                  align: 'center', before: lineH(body), after: lineH(body) * 0.6, newPage: np));
            } else if (t.startsWith('## ')) {
              placePara(para(t.substring(3), body.copyWith(size: body.size * 1.22, bold: true), here,
                  before: lineH(body) * 0.7, after: lineH(body) * 0.3));
            } else if (t.startsWith('### ')) {
              placePara(para(t.substring(4), body.copyWith(size: body.size * 1.05, bold: true), here,
                  before: lineH(body) * 0.5, after: lineH(body) * 0.2));
            } else if (t.startsWith('> ')) {
              placePara(para(t.substring(2), body.copyWith(size: body.size * 0.95, italic: true, color: 0xFF424242), here,
                  align: chunkAlign, leftIndent: 18, before: 2, after: 2));
            } else if (RegExp(r'^\[\^\d+\]:').hasMatch(t)) {
              placePara(para(t, body.copyWith(size: body.size * 0.72), here));
            } else {
              // Leading spaces = indent level (2 per level); lists never get a
              // first-line indent.
              final lead = RegExp(r'^ +').firstMatch(t)?.group(0)?.length ?? 0;
              final tt = t.substring(lead);
              final isList = RegExp(r'^(•|-|\d+[.)]) ').hasMatch(tt);
              final a = chunkAlign == 'left' ? null : chunkAlign;
              placePara(para(tt, body, here,
                  align: a,
                  leftIndent: (lead ~/ 2) * 14.0,
                  indentFirst: s.firstLineIndent && lead == 0 && !isList && (a == null || a == 'justify')));
            }
          }
          break;
      }
      offset += _blockLen(b);
    }

    // Drop a trailing empty page.
    if (pages.length > 1 && _empty(pages.last)) pages.removeLast();

    // Header, page numbers.
    var physical = 0;
    for (final p in pages) {
      physical++;
      p.physical = physical;
      if (p.cover != null || p.plain) continue;
      p.header = s.hasHeader ? s.headerText.trim() : '';
      if (s.showPageNumbers && physical >= s.pageNumberStartPage) {
        p.pageLabel = formatPageNumber(
            s.pageNumberStartAt + (physical - s.pageNumberStartPage), s.pageNumberStyle);
      }
    }
    return DocLayout(s, pages);
  }

  static bool _empty(LPage p) =>
      p.lines.isEmpty && p.rects.isEmpty && p.images.isEmpty && p.cover == null;

  int _blockLen(DocBlock b) => b.kind == DocBlockKind.text ? b.text.length : 0;

  void _placeTable(
    DocBlock b,
    LStyle body,
    double left,
    double width,
    double bottom,
    double Function() getY,
    void Function(double) setY,
    LPage Function() getPage,
    void Function() newPage,
    void Function() mark,
  ) {
    if (b.cells.isEmpty) return;
    final cols = b.cells.map((r) => r.length).fold(0, math.max);
    if (cols == 0) return;
    final rel = List<double>.generate(cols, (i) => i < b.widths.length ? b.widths[i].clamp(0.3, 3.0) : 1.0);
    final sum = rel.fold(0.0, (a, c) => a + c);
    final colW = rel.map((r) => width * r / sum).toList();
    final st = body.copyWith(size: body.size * 0.85);
    final lh = st.size * 1.35;
    const pad = 4.0;
    var y = getY() + 4;
    for (var r = 0; r < b.cells.length; r++) {
      final rowStyle = r == 0 ? st.copyWith(bold: true) : st;
      // Wrap every cell first to know the row height.
      final cellLines = <List<List<LWord>>>[];
      var maxLines = 1;
      for (var c = 0; c < cols; c++) {
        final text = c < b.cells[r].length ? b.cells[r][c] : '';
        final (toks, _) = _tokens(runs(text, rowStyle));
        final avail = colW[c] - pad * 2;
        final lines = <List<LWord>>[];
        var cur = <LWord>[];
        var w = 0.0;
        final sp = measure(' ', rowStyle);
        for (final t in toks) {
          final add = (cur.isEmpty ? 0 : sp) + t.width;
          if (cur.isNotEmpty && w + add > avail) {
            lines.add(cur);
            cur = [];
            w = 0;
          }
          cur.add(t);
          w += cur.length == 1 ? t.width : add;
        }
        if (cur.isNotEmpty) lines.add(cur);
        cellLines.add(lines);
        maxLines = math.max(maxLines, lines.length);
      }
      final rowH = maxLines * lh + pad * 2;
      if (y + rowH > bottom) {
        newPage();
        y = getY();
      }
      final page = getPage();
      var x = left;
      for (var c = 0; c < cols; c++) {
        page.rects.add(LRect(x, y, colW[c], rowH,
            stroke: 0xFF555555, fill: r == 0 ? 0xFFF1ECE0 : 0, lineWidth: 0.6));
        var ly = y + pad;
        for (final ln in cellLines[c]) {
          var wx = x + pad;
          final sp = measure(' ', rowStyle);
          final placed = <LWord>[];
          for (final t in ln) {
            placed.add(LWord(t.text, t.style, wx, t.width));
            wx += t.width + sp;
          }
          final base = ly + (lh - rowStyle.size) / 2 + rowStyle.size * 0.8;
          page.lines.add(LLine(placed, base, ly, lh, false, 0));
          ly += lh;
        }
        x += colW[c];
      }
      y += rowH;
      mark();
    }
    if (b.tableCaption.isNotEmpty) {
      final page = getPage();
      final cs = body.copyWith(size: body.size * 0.8, italic: true);
      final w = measure(b.tableCaption, cs);
      page.lines.add(LLine([LWord(b.tableCaption, cs, left + (width - w) / 2, w)],
          y + cs.size * 1.2, y, cs.size * 1.5, false, 0));
      y += cs.size * 1.6;
    }
    setY(y + 6);
  }
}
