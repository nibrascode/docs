import 'package:flutter/services.dart';

/// Inline style of one character.
class SpanStyle {
  final bool bold, italic, underline, strike;
  final String? color, bg, font; // '#RRGGBB' / family name
  final int? size; // px, like [size=N]
  const SpanStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color,
    this.bg,
    this.font,
    this.size,
  });
  static const plain = SpanStyle();

  SpanStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    Object? color = _keep,
    Object? bg = _keep,
    Object? font = _keep,
    Object? size = _keep,
  }) =>
      SpanStyle(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        strike: strike ?? this.strike,
        color: identical(color, _keep) ? this.color : color as String?,
        bg: identical(bg, _keep) ? this.bg : bg as String?,
        font: identical(font, _keep) ? this.font : font as String?,
        size: identical(size, _keep) ? this.size : size as int?,
      );

  SpanStyle withToggles(SpanStyle o) =>
      copyWith(bold: o.bold, italic: o.italic, underline: o.underline, strike: o.strike);

  @override
  bool operator ==(Object o) =>
      o is SpanStyle &&
      o.bold == bold &&
      o.italic == italic &&
      o.underline == underline &&
      o.strike == strike &&
      o.color == color &&
      o.bg == bg &&
      o.font == font &&
      o.size == size;
  @override
  int get hashCode => Object.hash(bold, italic, underline, strike, color, bg, font, size);
  @override
  String toString() =>
      'S(${bold ? 'b' : ''}${italic ? 'i' : ''}${underline ? 'u' : ''}${strike ? 's' : ''}'
      '${color ?? ''}${bg != null ? ' bg$bg' : ''}${size != null ? ' $size' : ''}${font != null ? ' $font' : ''})';
}

const _keep = Object();

/// One formatting change, applied to a range or kept pending at the cursor.
class FormatOp {
  final String kind; // bold italic underline strike color bg size font clear
  final Object? value; // for toggles: bool (null = toggle); else the value
  const FormatOp(this.kind, [this.value]);

  bool readsToggle() => const {'bold', 'italic', 'underline', 'strike'}.contains(kind);

  bool has(SpanStyle s) => switch (kind) {
        'bold' => s.bold,
        'italic' => s.italic,
        'underline' => s.underline,
        'strike' => s.strike,
        _ => false,
      };

  SpanStyle apply(SpanStyle s, {bool? on}) {
    final v = on ?? (value is bool ? value as bool : true);
    return switch (kind) {
      'bold' => s.copyWith(bold: v),
      'italic' => s.copyWith(italic: v),
      'underline' => s.copyWith(underline: v),
      'strike' => s.copyWith(strike: v),
      'color' => s.copyWith(color: value),
      'bg' => s.copyWith(bg: value),
      'size' => s.copyWith(size: value),
      'font' => s.copyWith(font: value),
      'clear' => SpanStyle.plain,
      _ => s,
    };
  }
}

/// Parsed paragraph: elements are single characters, or a whole footnote
/// reference like "[^3]". [rs]/[re] are raw start/end offsets.
class ParsedMarkup {
  final List<String> el;
  final List<SpanStyle> st;
  final List<int> rs, re;
  final int rawLength;
  ParsedMarkup(this.el, this.st, this.rs, this.re, this.rawLength);

  int get length => el.length;
  String get plain => el.join();
  bool isFootnote(int i) => el[i].length > 1;

  /// Number of elements fully before a raw caret offset.
  int plainAt(int raw) {
    var k = 0;
    while (k < el.length && rs[k] < raw) {
      k++;
    }
    return k;
  }

  /// Raw caret offset for a plain caret (after element k-1).
  int rawAt(int k) {
    if (el.isEmpty) return rawLength;
    if (k <= 0) return rs[0];
    if (k >= el.length) return re.last;
    return re[k - 1];
  }

  /// Style typed text should take at plain caret k (inherit from the left).
  SpanStyle styleAt(int k) {
    if (el.isEmpty) return SpanStyle.plain;
    var i = k - 1;
    while (i >= 0 && el[i] == '\n') {
      i = -1;
    }
    if (i >= 0) return st[i];
    return k < el.length && el[k] != '\n' ? st[k] : SpanStyle.plain;
  }
}

class RichMarkup {
  static final _tok = RegExp(
    r'\[(color|bg)=(#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?)\]'
    r'|\[size=(\d{1,3})\]'
    r'|\[font=([A-Za-z][A-Za-z0-9 ]{0,40})\]'
    r'|\[/(color|bg|size|font)\]'
    r'|\[\^\d+\]'
    r'|\*\*|__|~~|\*',
  );
  static final _ws = RegExp(r'\s');

  static ParsedMarkup parse(String raw) {
    final el = <String>[], rs = <int>[], re = <int>[];
    final st = <SpanStyle>[];
    var base = 0;
    final lines = raw.split('\n');
    for (var li = 0; li < lines.length; li++) {
      _parseLine(lines[li], base, el, st, rs, re);
      base += lines[li].length;
      if (li < lines.length - 1) {
        el.add('\n');
        st.add(SpanStyle.plain);
        rs.add(base);
        re.add(base + 1);
        base += 1;
      }
    }
    return ParsedMarkup(el, st, rs, re, raw.length);
  }

  static void _parseLine(String line, int base, List<String> el, List<SpanStyle> st, List<int> rs, List<int> re) {
    // 1) tokens
    final toks = <(int, int, String, String?)>[]; // start, end, kind, value
    var i = 0;
    while (i < line.length) {
      final m = _tok.matchAsPrefix(line, i);
      if (m == null) {
        i++;
        continue;
      }
      final t = m.group(0)!;
      String kind;
      String? val;
      if (m.group(1) != null) {
        kind = '+${m.group(1)}';
        val = m.group(2)!.toUpperCase();
      } else if (m.group(3) != null) {
        kind = '+size';
        val = m.group(3);
      } else if (m.group(4) != null) {
        kind = '+font';
        val = m.group(4);
      } else if (m.group(5) != null) {
        kind = '-${m.group(5)}';
      } else if (t.startsWith('[^')) {
        kind = 'fn';
      } else {
        kind = t;
      }
      toks.add((i, m.end, kind, val));
      i = m.end;
    }
    // 2) pairing; unpaired markers are literal text
    final active = List<bool>.filled(toks.length, false);
    final openToggle = <String, int>{};
    final stacks = <String, List<int>>{};
    for (var k = 0; k < toks.length; k++) {
      final (s, e, kind, _) = toks[k];
      if (kind == 'fn') continue;
      if (kind.startsWith('+')) {
        (stacks[kind.substring(1)] ??= []).add(k);
      } else if (kind.startsWith('-')) {
        final stk = stacks[kind.substring(1)];
        if (stk != null && stk.isNotEmpty) {
          active[stk.removeLast()] = true;
          active[k] = true;
        }
      } else {
        final canOpen = e < line.length && !_ws.hasMatch(line[e]);
        final canClose = s > 0 && !_ws.hasMatch(line[s - 1]);
        final o = openToggle[kind];
        if (o != null && canClose) {
          active[o] = true;
          active[k] = true;
          openToggle.remove(kind);
        } else if (canOpen) {
          openToggle[kind] = k;
        }
      }
    }
    // 3) walk
    var b = 0, it = 0, u = 0, sk = 0;
    final vals = <String, List<String>>{'color': [], 'bg': [], 'size': [], 'font': []};
    SpanStyle cur() => SpanStyle(
          bold: b.isOdd,
          italic: it.isOdd,
          underline: u.isOdd,
          strike: sk.isOdd,
          color: vals['color']!.isEmpty ? null : vals['color']!.last,
          bg: vals['bg']!.isEmpty ? null : vals['bg']!.last,
          size: vals['size']!.isEmpty ? null : int.tryParse(vals['size']!.last),
          font: vals['font']!.isEmpty ? null : vals['font']!.last,
        );
    var pos = 0;
    void text(int upto) {
      final s = cur();
      for (var p = pos; p < upto; p++) {
        el.add(line[p]);
        st.add(s);
        rs.add(base + p);
        re.add(base + p + 1);
      }
      pos = upto;
    }

    for (var k = 0; k < toks.length; k++) {
      final (s, e, kind, val) = toks[k];
      if (kind == 'fn') {
        text(s);
        el.add(line.substring(s, e));
        st.add(cur());
        rs.add(base + s);
        re.add(base + e);
        pos = e;
        continue;
      }
      if (!active[k]) continue;
      text(s);
      switch (kind) {
        case '**':
          b++;
        case '*':
          it++;
        case '__':
          u++;
        case '~~':
          sk++;
        default:
          if (kind.startsWith('+')) {
            vals[kind.substring(1)]!.add(val!);
          } else {
            final l = vals[kind.substring(1)]!;
            if (l.isNotEmpty) l.removeLast();
          }
      }
      pos = e;
    }
    text(line.length);
  }

  static final _prefix = RegExp(r'^(#{1,3} |> |[-•] |\d+[.)] )');

  /// Canonical markup for elements+styles. Whitespace takes the toggles
  /// shared by its neighbours so markers always flank real characters.
  static String serialize(List<String> el, List<SpanStyle> st) {
    final out = StringBuffer();
    var start = 0;
    for (var k = 0; k <= el.length; k++) {
      if (k == el.length || el[k] == '\n') {
        out.write(_serializeLine(el.sublist(start, k), st.sublist(start, k)));
        if (k < el.length) out.write('\n');
        start = k + 1;
      }
    }
    return out.toString();
  }

  static String _serializeLine(List<String> el, List<SpanStyle> st0) {
    if (el.isEmpty) return '';
    final st = List<SpanStyle>.of(st0);
    // Line prefixes (headings, quotes, list markers) stay unstyled.
    final pm = _prefix.firstMatch(el.join());
    var skip = 0;
    if (pm != null) {
      var n = 0;
      while (skip < el.length && n < pm.end) {
        n += el[skip].length;
        st[skip] = SpanStyle.plain;
        skip++;
      }
    }
    bool isWs(int k) => el[k].length == 1 && _ws.hasMatch(el[k]);
    for (var k = skip; k < el.length; k++) {
      if (!isWs(k)) continue;
      var p = k - 1;
      while (p >= skip && isWs(p)) {
        p--;
      }
      var n = k + 1;
      while (n < el.length && isWs(n)) {
        n++;
      }
      final a = p >= skip ? st[p] : null;
      final c = n < el.length ? st[n] : null;
      final t = SpanStyle(
        bold: (a?.bold ?? false) && (c?.bold ?? false),
        italic: (a?.italic ?? false) && (c?.italic ?? false),
        underline: (a?.underline ?? false) && (c?.underline ?? false),
        strike: (a?.strike ?? false) && (c?.strike ?? false),
      );
      st[k] = st[k].withToggles(t);
    }
    final b = StringBuffer();
    var prev = SpanStyle.plain;
    void transition(SpanStyle from, SpanStyle to) {
      // Close first (toggles, then brackets), then open (brackets, toggles).
      if (from.strike && !to.strike) b.write('~~');
      if (from.underline && !to.underline) b.write('__');
      if (from.italic && !to.italic) b.write('*');
      if (from.bold && !to.bold) b.write('**');
      if (from.bg != null && from.bg != to.bg) b.write('[/bg]');
      if (from.color != null && from.color != to.color) b.write('[/color]');
      if (from.size != null && from.size != to.size) b.write('[/size]');
      if (from.font != null && from.font != to.font) b.write('[/font]');
      if (to.font != null && from.font != to.font) b.write('[font=${to.font}]');
      if (to.size != null && from.size != to.size) b.write('[size=${to.size}]');
      if (to.color != null && from.color != to.color) b.write('[color=${to.color}]');
      if (to.bg != null && from.bg != to.bg) b.write('[bg=${to.bg}]');
      if (to.bold && !from.bold) b.write('**');
      if (to.italic && !from.italic) b.write('*');
      if (to.underline && !from.underline) b.write('__');
      if (to.strike && !from.strike) b.write('~~');
    }

    for (var k = 0; k < el.length; k++) {
      if (st[k] != prev) {
        transition(prev, st[k]);
        prev = st[k];
      }
      b.write(el[k]);
    }
    transition(prev, SpanStyle.plain);
    return b.toString();
  }

  /// Applies [op] to the raw range; toggles switch off only when every
  /// selected character already has them. Returns new raw + selection.
  static (String, TextSelection) applyRange(String raw, TextSelection sel, FormatOp op) {
    final p = parse(raw);
    final a = p.plainAt(sel.start), z = p.plainAt(sel.end);
    bool? on;
    if (op.readsToggle() && op.value == null) {
      var all = z > a;
      for (var k = a; k < z; k++) {
        if (p.el[k] != '\n' && !_ws.hasMatch(p.el[k]) && !op.has(p.st[k])) all = false;
      }
      on = !all;
    }
    final st = List<SpanStyle>.of(p.st);
    for (var k = a; k < z; k++) {
      if (p.el[k] == '\n') continue;
      st[k] = op.apply(st[k], on: on);
    }
    final out = serialize(p.el, st);
    final q = parse(out);
    return (out, TextSelection(baseOffset: q.rawAt(a), extentOffset: q.rawAt(z)));
  }

  /// Formatted copy of a raw selection (balanced markup).
  static String extract(String raw, TextSelection sel) {
    final p = parse(raw);
    final a = p.plainAt(sel.start), z = p.plainAt(sel.end);
    return serialize(p.el.sublist(a, z), p.st.sublist(a, z));
  }

  /// Removes the selected characters (and any markers between them).
  static (String, int) deleteRange(String raw, TextSelection sel) {
    final p = parse(raw);
    final a = p.plainAt(sel.start), z = p.plainAt(sel.end);
    final el = [...p.el]..removeRange(a, z);
    final st = [...p.st]..removeRange(a, z);
    final out = serialize(el, st);
    return (out, parse(out).rawAt(a));
  }

  /// Reconciles a user edit (typing, paste, IME commit, backspace) with the
  /// span model: typed text inherits the style on its left, or [pending];
  /// pasted markup keeps its own styles; markers are never half-deleted.
  static TextEditingValue? reconcile(String oldRaw, TextEditingValue nv, SpanStyle? pending,
      {(String, String)? clip}) {
    final newRaw = nv.text;
    if (newRaw == oldRaw) return null;
    var pre = 0;
    final minLen = oldRaw.length < newRaw.length ? oldRaw.length : newRaw.length;
    while (pre < minLen && oldRaw.codeUnitAt(pre) == newRaw.codeUnitAt(pre)) {
      pre++;
    }
    var suf = 0;
    while (suf < minLen - pre &&
        oldRaw.codeUnitAt(oldRaw.length - 1 - suf) == newRaw.codeUnitAt(newRaw.length - 1 - suf)) {
      suf++;
    }
    // The caret tells us where the edit ended; align the diff with it.
    if (nv.selection.isValid && nv.selection.isCollapsed) {
      final c = nv.selection.extentOffset;
      final insLen = newRaw.length - oldRaw.length;
      if (insLen >= 0 && c - insLen >= 0 && c <= newRaw.length) {
        final s = c - insLen;
        if (oldRaw.substring(0, s) == newRaw.substring(0, s) &&
            oldRaw.substring(s) == newRaw.substring(c)) {
          pre = s;
          suf = oldRaw.length - s;
        }
      }
    }
    final p = parse(oldRaw);
    var a = p.plainAt(pre);
    final oldEnd = oldRaw.length - suf;
    var z = p.plainAt(oldEnd);
    var inserted = newRaw.substring(pre, newRaw.length - suf);
    // Pasting our own copy: restore its formatting.
    if (clip != null && inserted.isNotEmpty && inserted == clip.$1) inserted = clip.$2;
    if (z < a) z = a;
    // Backspace that only removed hidden markers: delete the char before.
    if (inserted.isEmpty && z == a) {
      if (a > 0) {
        a -= 1;
      } else if (z < p.length) {
        z += 1;
      }
    }
    final ins = parse(inserted);
    final hasMarkup = ins.rawLength != ins.plain.length ||
        ins.st.any((s) => s != SpanStyle.plain);
    final List<SpanStyle> insSt;
    if (hasMarkup) {
      insSt = ins.st;
    } else {
      final s = pending ?? p.styleAt(a);
      insSt = [for (final e in ins.el) e == '\n' ? SpanStyle.plain : s];
    }
    final el = [...p.el]..replaceRange(a, z, ins.el);
    final st = [...p.st]..replaceRange(a, z, insSt);
    final out = serialize(el, st);
    final caret = parse(out).rawAt(a + ins.length);
    if (out == newRaw && nv.selection.isCollapsed && nv.selection.extentOffset == caret) return null;
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: caret));
  }
}

/// Formatted copy buffer (system clipboard gets plain text).
class RichClipboard {
  static (String, String)? last; // plain, markup
  static Future<void> copy(String raw, TextSelection sel) async {
    final rich = RichMarkup.extract(raw, sel);
    final plain = RichMarkup.parse(rich).plain;
    last = (plain, rich);
    await Clipboard.setData(ClipboardData(text: plain));
  }
}
