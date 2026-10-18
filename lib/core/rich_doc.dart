import 'rich_markup.dart';

/// One editor line: plain characters with per-character styles, plus the
/// line's alignment and kind ('' normal, h1, h2, h3, quote).
class RLine {
  String align;
  String kind;
  String text;
  List<SpanStyle> st;
  RLine(this.text, this.st, {this.align = 'left', this.kind = ''});
  RLine.empty({this.align = 'left', this.kind = ''})
      : text = '',
        st = [];
}

/// Converts a text block's markup (the storage format used by layout, PDF,
/// DOCX and EPUB) to editor lines and back. Old documents (paragraph-level
/// [align=x] that lasts until a blank line) decode exactly as before.
class RichDoc {
  static final alignRe = RegExp(r'^\[align=(left|center|right|justify)\]');
  static const kindPrefix = {'h1': '# ', 'h2': '## ', 'h3': '### ', 'quote': '> '};

  static List<RLine> decode(String raw) {
    final out = <RLine>[];
    String? chunk;
    for (final src in raw.split('\n')) {
      var body = src;
      String align;
      final m = alignRe.firstMatch(body);
      if (m != null) {
        align = m.group(1)!;
        body = body.substring(m.end);
        chunk = align;
      } else {
        align = body.trim().isEmpty ? 'left' : (chunk ?? 'left');
      }
      if (body.trim().isEmpty) chunk = null;
      var kind = '';
      for (final e in const [('h3', '### '), ('h2', '## '), ('h1', '# '), ('quote', '> ')]) {
        if (body.startsWith(e.$2)) {
          kind = e.$1;
          body = body.substring(e.$2.length);
          break;
        }
      }
      if (kind == '' && RegExp(r'^#{4,6} ').hasMatch(body)) {
        kind = 'h3';
        body = body.replaceFirst(RegExp(r'^#{4,6} '), '');
      }
      final p = RichMarkup.parse(body);
      final t = StringBuffer();
      final st = <SpanStyle>[];
      for (var k = 0; k < p.length; k++) {
        final e = p.el[k];
        if (p.isLink(k)) {
          final (lt, url) = ParsedMarkup.linkParts(e);
          t.write(lt);
          st.addAll(List.filled(lt.length, p.st[k].copyWith(link: url)));
        } else {
          t.write(e);
          st.addAll(List.filled(e.length, p.st[k]));
        }
      }
      out.add(RLine(t.toString(), st, align: align, kind: kind));
    }
    return out;
  }

  /// Elements (single chars, or whole "[text](url)" link runs) of a line.
  static (List<String>, List<SpanStyle>, List<int>) elements(RLine l) {
    final el = <String>[], st = <SpanStyle>[], start = <int>[];
    var k = 0;
    while (k < l.text.length) {
      final s = k < l.st.length ? l.st[k] : SpanStyle.plain;
      if (s.link != null) {
        var j = k;
        while (j < l.text.length && j < l.st.length && l.st[j].link == s.link) {
          j++;
        }
        final lt = l.text.substring(k, j).replaceAll(RegExp(r'[\[\]\n]'), '');
        if (lt.isEmpty) {
          k = j;
          continue;
        }
        start.add(k);
        el.add('[$lt](${s.link})');
        st.add(s.noLink);
        k = j;
        continue;
      }
      start.add(k);
      el.add(l.text[k]);
      st.add(s);
      k++;
    }
    return (el, st, start);
  }

  static String _body(RLine l) {
    final (el, st, _) = elements(l);
    return RichMarkup.serializeLine(el, st, literalPrefix: l.kind == '');
  }

  /// Raw (storage) lines; [rawCol] maps a line char offset to its raw offset.
  static List<String> encodeLines(List<RLine> lines) {
    final out = <String>[];
    String? chunk;
    for (final l in lines) {
      final blank = l.text.trim().isEmpty && l.kind == '';
      var prefix = '';
      if (l.align != 'left') {
        prefix = '[align=${l.align}]';
        chunk = l.align;
      } else if (!blank && chunk != null && chunk != 'left') {
        prefix = '[align=left]';
        chunk = 'left';
      }
      if (blank) chunk = null;
      out.add(prefix + (kindPrefix[l.kind] ?? '') + _body(l));
    }
    return out;
  }

  static String encode(List<RLine> lines) => encodeLines(lines).join('\n');

  /// Offset in the encoded block of char [col] of line [li].
  static int rawOffset(List<RLine> lines, int li, int col) {
    final raw = encodeLines(lines);
    var off = 0;
    for (var k = 0; k < li && k < raw.length; k++) {
      off += raw[k].length + 1;
    }
    if (li >= lines.length) return off > 0 ? off - 1 : 0;
    final line = raw[li];
    final pm = alignRe.firstMatch(line);
    var pre = pm?.end ?? 0;
    pre += (kindPrefix[lines[li].kind] ?? '').length;
    final (_, _, start) = elements(lines[li]);
    var k = 0;
    while (k < start.length && start[k] < col) {
      k++;
    }
    final p = RichMarkup.parse(line.substring(pre));
    return off + pre + p.rawAt(k);
  }
}
