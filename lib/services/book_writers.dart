// DOCX and EPUB writers built on the same markup parser as the page layout.
import '../core/table_spec.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../core/page_layout.dart';
import '../core/page_size.dart';
import '../presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import '../presentation/document_editor_screen/widgets/document_canvas.dart';

String _x(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final _alignRe = RegExp(r'^\[align=(left|center|right|justify)\]');
final _rtlRe = RegExp(r'[\u0590-\u08FF]');
final _firstStrongRe = RegExp(r'[A-Za-z\u00C0-\u024F\u0259\u018F\u0400-\u04FF\u0590-\u08FF\uFB50-\uFEFF]');

/// Human font name for a bundled family (DOCX/EPUB).
String cssFamily(String f) => switch (f) {
      'LibreBaskerville' => 'Libre Baskerville',
      'DMSans' => 'DM Sans',
      'NotoNaskhArabic' => 'Noto Naskh Arabic',
      _ => f,
    };

/// Paragraph direction from its first strong letter (Unicode rule P2).
bool isRtlText(String s) {
  final m = _firstStrongRe.firstMatch(s);
  return m != null && _rtlRe.hasMatch(m.group(0)!);
}

/// Splits text into (segment, isArabic) pieces; spaces/marks between two
/// Arabic words stay inside the Arabic segment.
final _arSegRe = RegExp(r'[\u0590-\u08FF\uFB50-\uFEFF]+(?:[\s\u060C\u061B\u061F.,:;!?]+[\u0590-\u08FF\uFB50-\uFEFF]+)*[\u060C\u061B\u061F]?');
List<(String, bool)> scriptSegments(String t) {
  final out = <(String, bool)>[];
  var i = 0;
  for (final m in _arSegRe.allMatches(t)) {
    if (m.start > i) out.add((t.substring(i, m.start), false));
    out.add((m.group(0)!, true));
    i = m.end;
  }
  if (i < t.length) out.add((t.substring(i), false));
  return out;
}

const _base = LStyle(family: 'serif', size: 12);

class DocxOptions {
  final String title, author, subtitle, fontFamily, language;
  final PageSize pageSize;
  final bool landscape, chapterNewPage, firstLineIndent;
  final double marginMm, fontSize, lineHeight;
  final String textAlign;
  const DocxOptions({
    this.title = '',
    this.author = '',
    this.subtitle = '',
    this.fontFamily = 'Georgia',
    this.language = 'az',
    this.pageSize = PageSize.a4,
    this.landscape = false,
    this.chapterNewPage = false,
    this.firstLineIndent = false,
    this.marginMm = 20,
    this.fontSize = 16,
    this.lineHeight = 1.7,
    this.textAlign = 'left',
  });
}

String _wordFont(String f) => switch (layoutFamily(f)) {
      'Lora' => 'Lora',
      'DMSans' => 'DM Sans',
      _ => 'Libre Baskerville',
    };

class DocxWriter {
  static Uint8List build(String content, DocxOptions o) {
    final body = StringBuffer();
    final media = <String, List<int>>{};
    final rels = <String>[];
    var imgN = 0;
    var firstChapter = true;
    // Real Word footnotes: [^n] -> footnoteReference, "[^n]: text" -> footnotes.xml.
    final fnDefs = <String, String>{
      for (final mm in RegExp(r'^\[\^(\d+)\]:[ \t]*(.*)$', multiLine: true).allMatches(content))
        mm.group(1)!: mm.group(2)!.trim()
    };

    String runsXml(String text, {bool raw = false}) {
      final b = StringBuffer();
      for (final (t, st) in raw ? [(text, _base)] : PageLayoutEngine.runs(text, _base)) {
        if (t.isEmpty) continue;
        if (st.sup && fnDefs.containsKey(t)) {
          b.write('<w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr><w:footnoteReference w:id="$t"/></w:r>');
          continue;
        }
        final hex = (int c) => (c & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
        for (final (seg, ar) in scriptSegments(t)) {
          // Child order follows the OOXML schema (CT_RPr sequence).
          final rp = StringBuffer();
          final fam = st.family != _base.family ? cssFamily(st.family) : null;
          if (ar || fam != null) {
            rp.write('<w:rFonts${fam != null ? ' w:ascii="$fam" w:hAnsi="$fam"' : ''}${ar ? ' w:cs="Noto Naskh Arabic"' : ''}/>');
          }
          if (st.bold) rp.write(ar ? '<w:b/><w:bCs/>' : '<w:b/>');
          if (st.italic) rp.write(ar ? '<w:i/><w:iCs/>' : '<w:i/>');
          if (st.strike) rp.write('<w:strike/>');
          if (st.color != _base.color) rp.write('<w:color w:val="${hex(st.color)}"/>');
          if (st.size != _base.size && !st.sup) {
            final v = (st.size * 2).round();
            rp.write(ar ? '<w:sz w:val="$v"/><w:szCs w:val="$v"/>' : '<w:sz w:val="$v"/>');
          }
          if (st.underline) rp.write('<w:u w:val="single"/>');
          if (st.bg != 0) rp.write('<w:shd w:val="clear" w:color="auto" w:fill="${hex(st.bg)}"/>');
          if (st.sup) rp.write('<w:vertAlign w:val="superscript"/>');
          if (ar) rp.write('<w:rtl/><w:lang w:bidi="ar-SA"/>');
          b.write('<w:r>${rp.isEmpty ? '' : '<w:rPr>$rp</w:rPr>'}<w:t xml:space="preserve">${_x(seg)}</w:t></w:r>');
        }
      }
      return b.toString();
    }

    void para(String text, {String? style, String? align, bool pageBreakBefore = false, bool raw = false}) {
      final pr = StringBuffer();
      if (style != null) pr.write('<w:pStyle w:val="$style"/>');
      if (pageBreakBefore) pr.write('<w:pageBreakBefore/>');
      final rtl = isRtlText(text);
      if (rtl) pr.write('<w:bidi/>');
      final a = align ?? (style == null ? o.textAlign : null);
      if (a != null && a != 'left') pr.write('<w:jc w:val="${a == 'justify' ? 'both' : a}"/>');
      body.write('<w:p>${pr.isEmpty ? '' : '<w:pPr>$pr</w:pPr>'}${runsXml(text, raw: raw)}</w:p>');
    }

    // Title page.
    if (!content.contains('[COVER')) {
      para(o.title, style: 'Title');
      if (o.subtitle.isNotEmpty) para(o.subtitle, style: 'Subtitle');
      if (o.author.isNotEmpty) para(o.author, align: 'center');
      body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
    }

    final allBlocks = DocumentBlocks.parse(content);
    for (var bi = 0; bi < allBlocks.length; bi++) {
      final blk = allBlocks[bi];
      switch (blk.kind) {
        case DocBlockKind.cover:
          final c = CoverData.parse(blk.text);
          if (c != null) {
            para(c.title, style: 'Title');
            if (c.subtitle.isNotEmpty) para(c.subtitle, style: 'Subtitle');
            if (c.author.isNotEmpty) para(c.author, align: 'center');
            body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
          }
          break;
        case DocBlockKind.pageBreak:
          body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
          break;
        case DocBlockKind.toc:
          // Real Word TOC field (Word fills page numbers on open).
          para('**${blk.text}**', align: 'center');
          final es = PageLayoutEngine.scanHeadings(content).where((e) => e.level <= blk.tocLevels).toList();
          final instr = '<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>'
              '<w:r><w:instrText xml:space="preserve"> TOC \\o "1-${blk.tocLevels}" \\h \\z \\u </w:instrText></w:r>'
              '<w:r><w:fldChar w:fldCharType="separate"/></w:r>';
          const end = '<w:r><w:fldChar w:fldCharType="end"/></w:r>';
          if (es.isEmpty) {
            body.write('<w:p>$instr$end</w:p>');
          }
          for (var i = 0; i < es.length; i++) {
            final e = es[i];
            body.write('<w:p><w:pPr><w:tabs><w:tab w:val="right" w:leader="dot" w:pos="9000"/></w:tabs>'
                '<w:ind w:left="${(e.level - 1) * 280}"/></w:pPr>${i == 0 ? instr : ''}'
                '<w:r><w:t xml:space="preserve">${_x(e.title)}</w:t></w:r>${i == es.length - 1 ? end : ''}</w:p>');
          }
          break;
        case DocBlockKind.sceneBreak:
          para('*   *   *', align: 'center', raw: true);
          break;
        case DocBlockKind.hr:
          body.write('<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="888888"/></w:pBdr></w:pPr></w:p>');
          break;
        case DocBlockKind.note:
          para(blk.text, style: 'Quote');
          break;
        case DocBlockKind.image:
          final f = File(blk.imagePath);
          if (!f.existsSync()) break;
          final bytes = f.readAsBytesSync();
          final ext = blk.imagePath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
          imgN++;
          final name = 'image$imgN.$ext';
          media[name] = bytes;
          final rid = 'rIdImg$imgN';
          rels.add('<Relationship Id="$rid" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$name"/>');
          final pageW = (o.landscape ? o.pageSize.heightPt : o.pageSize.widthPt) - o.marginMm * kPtPerMm * 2;
          final (iw, ih) = _imageSize(bytes) ?? (4, 3);
          final wPt = pageW * blk.imageWidth.clamp(0.2, 1.0);
          final hPt = wPt * ih / iw;
          final cx = (wPt * 12700).round(), cy = (hPt * 12700).round();
          final jc = blk.imageAlign == 'left' ? '' : '<w:jc w:val="${blk.imageAlign}"/>';
          body.write('<w:p><w:pPr>$jc</w:pPr><w:r><w:drawing>'
              '<wp:inline><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$imgN" name="$name"/>'
              '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
              '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
              '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
              '<pic:nvPicPr><pic:cNvPr id="$imgN" name="$name"/><pic:cNvPicPr/></pic:nvPicPr>'
              '<pic:blipFill><a:blip r:embed="$rid"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
              '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
              '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>');
          if (blk.imageCaption.isNotEmpty) para(blk.imageCaption, style: 'Caption');
          break;
        case DocBlockKind.table:
          final cols = blk.cells.fold<int>(0, (a, r) => r.length > a ? r.length : a);
          body.write('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="5000" w:type="pct"/>'
              '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="555555"/><w:left w:val="single" w:sz="4" w:color="555555"/>'
              '<w:bottom w:val="single" w:sz="4" w:color="555555"/><w:right w:val="single" w:sz="4" w:color="555555"/>'
              '<w:insideH w:val="single" w:sz="4" w:color="555555"/><w:insideV w:val="single" w:sz="4" w:color="555555"/>'
              '</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr>');
          final cw = TableSpec.columnWidths(blk.widths, cols, 5000);
          body.write('<w:tblGrid>${cw.map((w) => '<w:gridCol w:w="${w.round()}"/>').join()}</w:tblGrid>');
          for (var r = 0; r < blk.cells.length; r++) {
            final head = r == 0 && blk.tableHeader;
            body.write(head ? '<w:tr><w:trPr><w:tblHeader/></w:trPr>' : '<w:tr>');
            for (var c = 0; c < cols; c++) {
              final t = c < blk.cells[r].length ? blk.cells[r][c] : '';
              final shd = head ? '<w:shd w:val="clear" w:color="auto" w:fill="F1ECE0"/>' : '';
              final jc = switch (TableSpec.align(blk.tableAligns, c)) { 'center' => 'center', 'right' => 'right', _ => '' };
              final ppr = jc.isEmpty ? '' : '<w:pPr><w:jc w:val="$jc"/></w:pPr>';
              body.write('<w:tc><w:tcPr><w:tcW w:w="${cw[c].round()}" w:type="pct"/>$shd</w:tcPr><w:p>$ppr${runsXml(head ? '**$t**' : t)}</w:p></w:tc>');
            }
            body.write('</w:tr>');
          }
          body.write('</w:tbl>');
          if (blk.tableCaption.isNotEmpty) para(blk.tableCaption, style: 'Caption');
          break;
        case DocBlockKind.text:
          String? chunkAlign;
          final lines = blk.text.split('\n');
          for (var li = 0; li < lines.length; li++) {
            var line = lines[li];
            if (line.trim().isEmpty && ((li == 0 && bi > 0) || (li == lines.length - 1 && bi < allBlocks.length - 1))) {
              chunkAlign = null;
              continue;
            }
            final am = _alignRe.firstMatch(line);
            if (am != null) {
              chunkAlign = am.group(1);
              line = line.substring(am.end);
            }
            final t = line.trimRight();
            final fm = RegExp(r'^\[\^(\d+)\]:').firstMatch(t);
            if (fm != null && fnDefs.containsKey(fm.group(1))) continue; // in footnotes.xml
            if (t.trim().isEmpty) {
              chunkAlign = null;
              body.write('<w:p/>'); // empty line, as in the editor
              continue;
            }
            if (t.startsWith('# ')) {
              final pb = o.chapterNewPage && !firstChapter;
              firstChapter = false;
              para(t.substring(2), style: 'Heading1', pageBreakBefore: pb);
            } else if (t.startsWith('## ')) {
              para(t.substring(3), style: 'Heading2');
            } else if (t.startsWith('### ')) {
              para(t.substring(4), style: 'Heading3');
            } else if (t.startsWith('> ')) {
              para(t.substring(2), style: 'Quote', align: chunkAlign == 'left' ? null : chunkAlign);
            } else if (RegExp(r'^\[\^\d+\]:').hasMatch(t)) {
              para(t, style: 'FootnoteText');
            } else {
              para(t, align: chunkAlign == 'left' ? null : chunkAlign);
            }
          }
          break;
      }
    }

    final w = ((o.landscape ? o.pageSize.heightPt : o.pageSize.widthPt) * 20).round();
    final h = ((o.landscape ? o.pageSize.widthPt : o.pageSize.heightPt) * 20).round();
    final m = (o.marginMm * kPtPerMm * 20).round();
    final doc = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        '<w:body>$body<w:sectPr><w:pgSz w:w="$w" w:h="$h"${o.landscape ? ' w:orient="landscape"' : ''}/>'
        '<w:pgMar w:top="$m" w:right="$m" w:bottom="$m" w:left="$m" w:header="400" w:footer="400" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';

    final font = _wordFont(o.fontFamily);
    final sz = (o.fontSize * 0.75 * 2).round();
    final line = (o.lineHeight * 240).round();
    final ind = o.firstLineIndent ? '<w:ind w:firstLine="425"/>' : '';
    String hs(String id, String name, int size, {bool center = false}) =>
        '<w:style w:type="paragraph" w:styleId="$id"><w:name w:val="$name"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>'
        '<w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="360" w:after="160"/><w:ind w:firstLine="0"/>${center ? '<w:jc w:val="center"/>' : ''}'
        '<w:outlineLvl w:val="${int.parse(id.substring(id.length - 1)) - 1}"/></w:pPr><w:rPr><w:b/><w:sz w:val="$size"/></w:rPr></w:style>';
    final styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="$font" w:hAnsi="$font" w:cs="$font" w:eastAsia="$font"/>'
        '<w:sz w:val="$sz"/><w:szCs w:val="$sz"/><w:lang w:val="${o.language}"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="$line" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/><w:pPr>$ind</w:pPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:spacing w:before="2400" w:after="240"/><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr><w:rPr><w:b/><w:sz w:val="${sz * 2}"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:basedOn w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr><w:rPr><w:i/><w:color w:val="555555"/><w:sz w:val="${(sz * 1.2).round()}"/></w:rPr></w:style>'
        '${hs('Heading1', 'heading 1', (sz * 1.55).round(), center: true)}'
        '${hs('Heading2', 'heading 2', (sz * 1.22).round())}'
        '${hs('Heading3', 'heading 3', (sz * 1.05).round())}'
        '<w:style w:type="paragraph" w:styleId="Quote"><w:name w:val="Quote"/><w:basedOn w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:ind w:left="567" w:firstLine="0"/></w:pPr><w:rPr><w:i/><w:color w:val="424242"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Caption"><w:name w:val="caption"/><w:basedOn w:val="Normal"/>'
        '<w:pPr><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr><w:rPr><w:i/><w:sz w:val="${(sz * 0.8).round()}"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="FootnoteText"><w:name w:val="footnote text"/><w:basedOn w:val="Normal"/>'
        '<w:pPr><w:ind w:firstLine="0"/></w:pPr><w:rPr><w:sz w:val="${(sz * 0.72).round()}"/></w:rPr></w:style>'
        '<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblCellMar>'
        '<w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>'
        '</w:styles>';

    final core = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>${_x(o.title)}</dc:title>'
        '<dc:creator>${_x(o.author.isEmpty ? 'Nibras Docs' : o.author)}</dc:creator></cp:coreProperties>';

    final arc = Archive();
    void add(String n, List<int> d) => arc.addFile(ArchiveFile(n, d.length, d));
    add('[Content_Types].xml', utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Default Extension="png" ContentType="image/png"/><Default Extension="jpeg" ContentType="image/jpeg"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/word/footnotes.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '</Types>'));
    add('_rels/.rels', utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        '</Relationships>'));
    add('word/_rels/document.xml.rels', utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '<Relationship Id="rIdFootnotes" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes" Target="footnotes.xml"/>'
        '${rels.join()}</Relationships>'));
    add('word/document.xml', utf8.encode(doc));
    add('word/styles.xml', utf8.encode(styles));
    final fn = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:footnote>'
        '<w:footnote w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>');
    fnDefs.forEach((n, t) => fn.write('<w:footnote w:id="$n"><w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr>'
        '<w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr><w:footnoteRef/></w:r>'
        '<w:r><w:t xml:space="preserve"> </w:t></w:r>${runsXml(t)}</w:p></w:footnote>'));
    fn.write('</w:footnotes>');
    add('word/footnotes.xml', utf8.encode(fn.toString()));
    add('docProps/core.xml', utf8.encode(core));
    media.forEach((n, d) => add('word/media/$n', d));
    return Uint8List.fromList(ZipEncoder().encode(arc)!);
  }
}

/// Width/height of a PNG or JPEG from its header.
(int, int)? _imageSize(List<int> b) {
  if (b.length > 24 && b[0] == 0x89 && b[1] == 0x50) {
    int u32(int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
    return (u32(16), u32(20));
  }
  if (b.length > 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      final len = (b[i + 2] << 8) | b[i + 3];
      if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
        return ((b[i + 7] << 8) | b[i + 8], (b[i + 5] << 8) | b[i + 6]);
      }
      i += 2 + len;
    }
  }
  return null;
}

class EpubWriter {
  /// EPUB 3: one XHTML file per chapter (split at "# " headings), nav TOC,
  /// stylesheet, embedded images, tables, inline formatting, RTL aware.
  static Uint8List build(String content,
      {required String title, String author = '', String subtitle = '', String language = 'az'}) {
    String inline(String s) {
      final b = StringBuffer();
      for (final (t, st) in PageLayoutEngine.runs(s, _base)) {
        var h = _x(t);
        if (st.sup) h = '<sup>$h</sup>';
        if (st.bold) h = '<strong>$h</strong>';
        if (st.italic) h = '<em>$h</em>';
        if (st.underline) h = '<u>$h</u>';
        if (st.strike) h = '<s>$h</s>';
        final css = <String>[
          if (st.color != _base.color) 'color:#${(st.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
          if (st.bg != 0) 'background:#${(st.bg & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
          if (st.size != _base.size && !st.sup) 'font-size:${(st.size / _base.size).toStringAsFixed(2)}em',
          if (st.family != _base.family) "font-family:'${cssFamily(st.family)}'",
        ];
        if (css.isNotEmpty) h = '<span style="${css.join(';')}">$h</span>';
        if (st.link != null) h = '<a href="${_x(st.link!)}">$h</a>';
        b.write(h);
      }
      return b.toString();
    }

    final chapters = <(String, StringBuffer)>[];
    var cur = StringBuffer();
    var curTitle = title;
    final images = <String, List<int>>{};
    var n = 0;

    void startChapter(String t) {
      if (cur.isNotEmpty) chapters.add((curTitle, cur));
      cur = StringBuffer();
      curTitle = t;
    }

    String dir(String s) => isRtlText(s) ? ' dir="rtl"' : (_rtlRe.hasMatch(s) ? ' dir="ltr"' : '');

    final allBlocks = DocumentBlocks.parse(content);
    for (var bi = 0; bi < allBlocks.length; bi++) {
      final blk = allBlocks[bi];
      switch (blk.kind) {
        case DocBlockKind.cover:
          final c = CoverData.parse(blk.text);
          if (c != null) {
            final t = coverById(c.templateId);
            String hex(int v) => (v & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
            cur.write('<section class="cover" style="background:#${hex(t.bg.toARGB32())};color:#${hex(t.fg.toARGB32())}">'
                '<p class="brand">NIBRAS CODE</p><h1 class="ctitle">${_x(c.title)}</h1>'
                '${c.subtitle.isEmpty ? '' : '<p class="csub">${_x(c.subtitle)}</p>'}'
                '${c.author.isEmpty ? '' : '<p class="cauthor">${_x(c.author)}</p>'}<p class="site">NibrasCode.com</p></section>');
          }
          break;
        case DocBlockKind.pageBreak:
          cur.write('<div class="pb"></div>');
          break;
        case DocBlockKind.toc:
          cur.write('<nav class="toc"><p class="toctitle"><b>${_x(blk.text)}</b></p><ul style="list-style:none;padding:0">');
          for (final e in PageLayoutEngine.scanHeadings(content).where((e) => e.level <= blk.tocLevels)) {
            cur.write('<li style="margin-left:${(e.level - 1) * 1.2}em"${dir(e.title)}>${_x(e.title)}</li>');
          }
          cur.write('</ul></nav>');
          break;
        case DocBlockKind.sceneBreak:
          cur.write('<p class="scene">*&#160;&#160;*&#160;&#160;*</p>');
          break;
        case DocBlockKind.hr:
          cur.write('<hr/>');
          break;
        case DocBlockKind.note:
          cur.write('<aside class="note"${dir(blk.text)}>${inline(blk.text)}</aside>');
          break;
        case DocBlockKind.image:
          final f = File(blk.imagePath);
          if (!f.existsSync()) break;
          n++;
          final ext = blk.imagePath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
          final name = 'img$n.$ext';
          images[name] = f.readAsBytesSync();
          cur.write('<figure style="text-align:${blk.imageAlign}"><img src="images/$name" alt="" style="width:${(blk.imageWidth * 100).round()}%"/>'
              '${blk.imageCaption.isEmpty ? '' : '<figcaption>${inline(blk.imageCaption)}</figcaption>'}</figure>');
          break;
        case DocBlockKind.table:
          final ncols = blk.cells.fold<int>(0, (a, r) => r.length > a ? r.length : a);
          final pw = TableSpec.columnWidths(blk.widths, ncols, 100);
          cur.write('<table style="table-layout:fixed;width:100%"><colgroup>${pw.map((w) => '<col style="width:${w.toStringAsFixed(1)}%"/>').join()}</colgroup>');
          for (var r = 0; r < blk.cells.length; r++) {
            final tag = r == 0 && blk.tableHeader ? 'th' : 'td';
            final row = blk.cells[r];
            cur.write('<tr>${[for (var c = 0; c < row.length; c++) '<$tag${dir(row[c])} style="text-align:${TableSpec.align(blk.tableAligns, c)}">${inline(row[c])}</$tag>'].join()}</tr>');
          }
          cur.write('</table>');
          if (blk.tableCaption.isNotEmpty) cur.write('<p class="caption">${inline(blk.tableCaption)}</p>');
          break;
        case DocBlockKind.text:
          String? chunkAlign;
          final lines = blk.text.split('\n');
          for (var li = 0; li < lines.length; li++) {
            var line = lines[li];
            if (line.trim().isEmpty && ((li == 0 && bi > 0) || (li == lines.length - 1 && bi < allBlocks.length - 1))) {
              chunkAlign = null;
              continue;
            }
            final am = _alignRe.firstMatch(line);
            if (am != null) {
              chunkAlign = am.group(1);
              line = line.substring(am.end);
            }
            final t = line.trimRight();
            if (t.trim().isEmpty) {
              chunkAlign = null;
              cur.write('<p class="blank">&#160;</p>');
              continue;
            }
            if (t.startsWith('# ')) {
              startChapter(t.substring(2).replaceAll(RegExp(r'[*_~]'), ''));
              cur.write('<h1${dir(t)}>${inline(t.substring(2))}</h1>');
            } else if (t.startsWith('## ')) {
              cur.write('<h2${dir(t)}>${inline(t.substring(3))}</h2>');
            } else if (t.startsWith('### ')) {
              cur.write('<h3${dir(t)}>${inline(t.substring(4))}</h3>');
            } else if (t.startsWith('> ')) {
              cur.write('<blockquote${dir(t)}>${inline(t.substring(2))}</blockquote>');
            } else if (RegExp(r'^\[\^\d+\]:').hasMatch(t)) {
              cur.write('<p class="fn"${dir(t)}>${inline(t)}</p>');
            } else {
              final st = chunkAlign == null || chunkAlign == 'left' ? '' : ' style="text-align:$chunkAlign"';
              cur.write('<p$st${dir(t)}>${inline(t)}</p>');
            }
          }
          break;
      }
    }
    if (cur.isNotEmpty || chapters.isEmpty) chapters.add((curTitle, cur));

    final rnd = Random.secure();
    final hexs = List.generate(16, (i) {
      var v = rnd.nextInt(256);
      if (i == 6) v = (v & 0x0F) | 0x40;
      if (i == 8) v = (v & 0x3F) | 0x80;
      return v.toRadixString(16).padLeft(2, '0');
    }).join();
    final id = 'urn:uuid:${hexs.substring(0, 8)}-${hexs.substring(8, 12)}-${hexs.substring(12, 16)}-${hexs.substring(16, 20)}-${hexs.substring(20)}';
    final modified = DateTime.now().toUtc().toIso8601String().split('.').first;
    String xhtml(String t, String body) => '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE html>\n<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="$language" lang="$language">'
        '<head><meta charset="utf-8"/><title>${_x(t)}</title><link rel="stylesheet" type="text/css" href="style.css"/></head>'
        '<body>$body</body></html>';

    final arc = Archive();
    final mt = utf8.encode('application/epub+zip');
    // The mimetype entry must come first and be stored uncompressed.
    arc.addFile(ArchiveFile.noCompress('mimetype', mt.length, mt));
    void add(String name, List<int> d) => arc.addFile(ArchiveFile(name, d.length, d));
    add('META-INF/container.xml', utf8.encode('<?xml version="1.0" encoding="UTF-8"?>'
        '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'));
    add('OEBPS/style.css', utf8.encode('body{font-family:serif;line-height:1.6;margin:0 5%}'
        'h1{text-align:center;margin:2em 0 1em;page-break-before:always}h2,h3{margin:1.4em 0 .6em}'
        'p{margin:0 0 .6em;text-align:justify}blockquote{font-style:italic;margin:1em 2em;color:#444}'
        '.scene{text-align:center;margin:1.2em 0}.pb{page-break-after:always}.fn{font-size:.8em}'
        'table{border-collapse:collapse;width:100%;margin:1em 0}th,td{border:1px solid #555;padding:.3em .5em;text-align:left}'
        'th{background:#f1ece0}.caption,figcaption{text-align:center;font-style:italic;font-size:.85em}'
        'figure{margin:1em 0}img{max-width:100%}aside.note{border-left:3px solid #c9a84c;padding-left:.8em;font-style:italic}'
        '.title{text-align:center;margin-top:30%}.title h1{page-break-before:avoid}'
        '.cover{text-align:center;padding:12% 8%;min-height:90vh;box-sizing:border-box}.cover .brand{letter-spacing:.3em;font-size:.8em}'
        '.cover .ctitle{page-break-before:avoid;margin-top:35%}.cover .site{margin-top:30%;font-size:.8em}'
        '[dir=rtl]{text-align:right;font-family:"Amiri","Noto Naskh Arabic","Traditional Arabic",serif}'));
    final titleBody = '<section class="title"><h1>${_x(title)}</h1>'
        '${subtitle.isEmpty ? '' : '<p style="text-align:center"><em>${_x(subtitle)}</em></p>'}'
        '${author.isEmpty ? '' : '<p style="text-align:center">${_x(author)}</p>'}</section>';
    add('OEBPS/title.xhtml', utf8.encode(xhtml(title, titleBody)));
    final manifest = StringBuffer()
      ..write('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>')
      ..write('<item id="css" href="style.css" media-type="text/css"/>')
      ..write('<item id="title" href="title.xhtml" media-type="application/xhtml+xml"/>');
    final spine = StringBuffer('<itemref idref="title"/>');
    final nav = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      final (t, b) = chapters[i];
      add('OEBPS/ch${i + 1}.xhtml', utf8.encode(xhtml(t, b.toString())));
      manifest.write('<item id="ch${i + 1}" href="ch${i + 1}.xhtml" media-type="application/xhtml+xml"/>');
      spine.write('<itemref idref="ch${i + 1}"/>');
      nav.write('<li><a href="ch${i + 1}.xhtml">${_x(t)}</a></li>');
    }
    images.forEach((name, d) {
      add('OEBPS/images/$name', d);
      manifest.write('<item id="${name.replaceAll('.', '_')}" href="images/$name" media-type="image/${name.endsWith('png') ? 'png' : 'jpeg'}"/>');
    });
    add('OEBPS/nav.xhtml', utf8.encode(xhtml('Contents', '<nav epub:type="toc" id="toc"><h1>${_x(title)}</h1><ol>$nav</ol></nav>')));
    add('OEBPS/content.opf', utf8.encode('<?xml version="1.0" encoding="UTF-8"?>'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="BookId" xml:lang="$language">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="BookId">$id</dc:identifier><dc:title>${_x(title)}</dc:title>'
        '<dc:language>$language</dc:language>${author.isEmpty ? '' : '<dc:creator>${_x(author)}</dc:creator>'}'
        '<meta property="dcterms:modified">${modified}Z</meta></metadata>'
        '<manifest>$manifest</manifest><spine>$spine</spine></package>'));
    return Uint8List.fromList(ZipEncoder().encode(arc)!);
  }
}
