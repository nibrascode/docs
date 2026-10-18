import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'rich_doc.dart';
import 'rich_markup.dart';

/// Rich text editing controller in the attributed-string style used by
/// production editors (Quill/Docs): the text the keyboard (IME) sees is only
/// the visible characters, and formatting lives in a parallel per-character
/// style list plus per-line kinds. Every edit, including Android composing
/// updates, is diffed against the previous value so new characters take the
/// caret style immediately; formatting a selection never changes the text,
/// so the keyboard's composing state is never disturbed.
class RichController extends TextEditingController {
  RichController({List<RLine>? lines}) {
    setLines(lines ?? [RLine.empty()]);
  }

  /// Style at the caret of the focused editor (drives toolbar state).
  static final caret = ValueNotifier<SpanStyle>(SpanStyle.plain);

  /// Last rich copy: (plain text, per-char styles).
  static (String, List<SpanStyle>)? clip;

  List<SpanStyle> _st = [];
  List<String> _kinds = [''];

  /// Style for the next typed text (toggled with a bare caret). Kept while
  /// the user keeps typing; dropped when the caret is moved elsewhere.
  SpanStyle? pending;

  bool _silent = false;

  List<SpanStyle> get styles => List.unmodifiable(_st);
  List<String> get kinds => List.unmodifiable(_kinds);

  // ---------------------------------------------------------------- model

  void setLines(List<RLine> lines, {TextSelection? selection}) {
    final t = StringBuffer();
    final st = <SpanStyle>[];
    final kinds = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      t.write(l.text);
      for (var k = 0; k < l.text.length; k++) {
        st.add(k < l.st.length ? l.st[k] : SpanStyle.plain);
      }
      kinds.add(l.kind);
      if (i < lines.length - 1) {
        t.write('\n');
        st.add(SpanStyle.plain);
      }
    }
    if (kinds.isEmpty) kinds.add('');
    _st = st;
    _kinds = kinds;
    pending = null;
    final s = t.toString();
    _silent = true;
    super.value = TextEditingValue(
      text: s,
      selection: selection == null
          ? const TextSelection.collapsed(offset: -1)
          : TextSelection(
              baseOffset: selection.baseOffset.clamp(0, s.length),
              extentOffset: selection.extentOffset.clamp(0, s.length)),
    );
    _silent = false;
  }

  /// Lines with [align] (the caller owns alignment).
  List<RLine> lines(String align) {
    final out = <RLine>[];
    var start = 0;
    final t = text;
    var li = 0;
    for (var k = 0; k <= t.length; k++) {
      if (k == t.length || t.codeUnitAt(k) == 10) {
        out.add(RLine(t.substring(start, k), _st.sublist(start, k),
            align: align, kind: li < _kinds.length ? _kinds[li] : ''));
        li++;
        start = k + 1;
      }
    }
    return out;
  }

  int lineOf(int offset) {
    var n = 0;
    final t = text;
    for (var k = 0; k < offset && k < t.length; k++) {
      if (t.codeUnitAt(k) == 10) n++;
    }
    return n;
  }

  int lineStart(int offset) {
    if (offset <= 0) return 0;
    final i = text.lastIndexOf('\n', offset - 1);
    return i < 0 ? 0 : i + 1;
  }

  int lineEnd(int offset) {
    final i = text.indexOf('\n', offset);
    return i < 0 ? text.length : i;
  }

  /// Style that text typed at [k] takes when nothing is pending:
  /// the character on the left; at a line start the first character of the
  /// line; on an empty line the end of the line above (like Word).
  SpanStyle styleAt(int k) {
    final t = text;
    if (t.isEmpty) return SpanStyle.plain;
    SpanStyle s;
    if (k > 0 && t.codeUnitAt(k - 1) != 10) {
      s = _st[k - 1];
      // Typing right after a link does not extend it.
      if (s.link != null && (k >= t.length || _st[k].link != s.link)) s = s.noLink;
      return s;
    }
    if (k < t.length && t.codeUnitAt(k) != 10) return _st[k].noLink;
    if (k >= 2 && t.codeUnitAt(k - 2) != 10) return _st[k - 2].noLink;
    return SpanStyle.plain;
  }

  SpanStyle caretStyle() {
    if (pending != null) return pending!;
    final sel = selection;
    if (!sel.isValid) return SpanStyle.plain;
    if (sel.isCollapsed) return styleAt(sel.extentOffset.clamp(0, text.length));
    for (var k = sel.start; k < sel.end && k < _st.length; k++) {
      if (text.codeUnitAt(k) != 10) return _st[k];
    }
    return styleAt(sel.start);
  }

  void _publish() => caret.value = caretStyle();

  // ---------------------------------------------------------------- edits

  @override
  set value(TextEditingValue nv) {
    if (_silent) {
      super.value = nv;
      return;
    }
    final old = value;
    if (nv.text == old.text) {
      if (nv.selection.isValid &&
          old.selection.isValid &&
          (nv.selection.baseOffset != old.selection.baseOffset ||
              nv.selection.extentOffset != old.selection.extentOffset)) {
        pending = null;
      }
      super.value = nv;
      _publish();
      return;
    }
    final (a, del, ins) = _diff(old.text, nv.text, nv.selection);
    final out = _apply(old.text, a, del, ins, nv);
    _silent = true;
    super.value = out;
    _silent = false;
    _publish();
  }

  /// (start, deleted length, inserted text), aligned with the caret.
  static (int, int, String) _diff(String o, String n, TextSelection sel) {
    var pre = 0;
    final minLen = o.length < n.length ? o.length : n.length;
    while (pre < minLen && o.codeUnitAt(pre) == n.codeUnitAt(pre)) {
      pre++;
    }
    var suf = 0;
    while (suf < minLen - pre && o.codeUnitAt(o.length - 1 - suf) == n.codeUnitAt(n.length - 1 - suf)) {
      suf++;
    }
    if (sel.isValid && sel.isCollapsed) {
      final c = sel.extentOffset;
      final d = n.length - o.length;
      if (d > 0 && c - d >= 0 && c <= n.length) {
        final s = c - d;
        if (o.substring(0, s) == n.substring(0, s) && o.substring(s) == n.substring(c)) {
          return (s, 0, n.substring(s, c));
        }
      } else if (d < 0 && c >= 0 && c <= n.length && c - d <= o.length) {
        if (o.substring(0, c) == n.substring(0, c) && o.substring(c - d) == n.substring(c)) {
          return (c, -d, '');
        }
      }
    }
    return (pre, o.length - suf - pre, n.substring(pre, n.length - suf));
  }

  static final _listRe = RegExp(r'^(\s*)(• |- |(\d+)([.)]) )');

  TextEditingValue _apply(String o, int a, int del, String ins, TextEditingValue nv) {
    // Styles for the inserted characters.
    SpanStyle base;
    if (del > 0 && ins.isNotEmpty && o.codeUnitAt(a) != 10) {
      base = _st[a]; // autocorrect / replacement keeps the word's style
    } else if (pending != null) {
      base = pending!;
    } else {
      base = styleAt(a);
    }
    List<SpanStyle> insSt;
    final cl = clip;
    if (cl != null && ins.length > 1 && ins == cl.$1) {
      insSt = List.of(cl.$2);
    } else {
      insSt = [for (var k = 0; k < ins.length; k++) ins.codeUnitAt(k) == 10 ? SpanStyle.plain : base];
    }
    // Line kinds.
    final line = lineOf(a);
    final delNl = '\n'.allMatches(o.substring(a, a + del)).length;
    final insNl = '\n'.allMatches(ins).length;
    if (delNl > 0) {
      final upper = _kinds[line];
      final lower = line + delNl < _kinds.length ? _kinds[line + delNl] : '';
      final upperEmpty = lineEnd(lineStart(a)) == lineStart(a) && a == lineStart(a);
      _kinds.removeRange(line + 1, (line + 1 + delNl).clamp(line + 1, _kinds.length));
      _kinds[line] = upperEmpty ? lower : upper;
    }
    if (insNl > 0) {
      final k = _kinds[line];
      final atEnd = a + del >= o.length || o.codeUnitAt(a + del) == 10;
      final next = (k.startsWith('h') && atEnd) ? '' : k;
      _kinds.insertAll(line + 1, List.filled(insNl, next));
    }
    _st.replaceRange(a, a + del, insSt);
    var result = nv;
    // Lists: Enter continues the list; Enter on an empty item ends it.
    if (ins == '\n' && del == 0) {
      final ls = lineStart(a > o.length ? o.length : a);
      final lineText = o.substring(ls, a);
      final restOfLine = o.substring(a, o.indexOf('\n', a) < 0 ? o.length : o.indexOf('\n', a));
      final m = _listRe.firstMatch(lineText);
      if (m != null) {
        final n = nv.text;
        if (lineText.substring(m.end).trim().isEmpty && restOfLine.trim().isEmpty) {
          // Remove the marker and the new line.
          final t = n.substring(0, ls) + n.substring(a + 1);
          _st.removeRange(ls, a + 1);
          _kinds.removeAt(line + 1);
          result = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: ls));
        } else {
          final num = m.group(3);
          final marker = m.group(1)! + (num != null ? '${int.parse(num) + 1}${m.group(4)} ' : m.group(2)!);
          final t = n.substring(0, a + 1) + marker + n.substring(a + 1);
          _st.insertAll(a + 1, List.filled(marker.length, SpanStyle.plain));
          result = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: a + 1 + marker.length));
        }
      }
    }
    // Backspace right after a list marker removes the whole marker.
    if (ins.isEmpty && del == 1 && o.codeUnitAt(a) == 32) {
      final ls = lineStart(a);
      final m = _listRe.firstMatch(o.substring(ls, a + 1));
      if (m != null && m.end == a + 1 - ls) {
        final n = result.text;
        _st.removeRange(ls, a);
        result = TextEditingValue(text: n.substring(0, ls) + n.substring(a), selection: TextSelection.collapsed(offset: ls));
      }
    }
    assert(_st.length == result.text.length);
    if (_st.length != result.text.length) {
      // Never let the model drift from the text.
      _st = [..._st.take(result.text.length), ...List.filled((result.text.length - _st.length).clamp(0, 1 << 30), base)];
    }
    final nl = '\n'.allMatches(result.text).length + 1;
    while (_kinds.length < nl) {
      _kinds.add('');
    }
    if (_kinds.length > nl) _kinds.removeRange(nl, _kinds.length);
    return result;
  }

  /// Replaces the whole value with a programmatic edit (styles follow the
  /// same diff rules).
  void edit(TextEditingValue v) => value = v;

  // ------------------------------------------------------------ formatting

  /// Applies [op] to the selection, or to the text typed next at a bare caret.
  bool format(FormatOp op) {
    final sel = selection;
    if (!sel.isValid) return false;
    if (sel.isCollapsed) {
      final cur = caretStyle();
      pending = op.readsToggle() && op.value == null ? op.apply(cur, on: !op.has(cur)) : op.apply(cur);
      caret.value = pending!;
      notifyListeners();
      return true;
    }
    final a = sel.start, z = sel.end;
    bool? on;
    if (op.readsToggle() && op.value == null) {
      var all = true, any = false;
      for (var k = a; k < z; k++) {
        final ch = text[k];
        if (ch == '\n' || ch.trim().isEmpty) continue;
        any = true;
        if (!op.has(_st[k])) all = false;
      }
      on = !(all && any);
    }
    for (var k = a; k < z; k++) {
      if (text.codeUnitAt(k) == 10) continue;
      final link = _st[k].link;
      _st[k] = op.apply(_st[k], on: on);
      if (op.kind == 'clear' && link != null) _st[k] = _st[k].copyWith(link: link);
    }
    pending = null;
    notifyListeners();
    _publish();
    return true;
  }

  /// Sets a link on the selection (null removes it).
  bool setLink(String? url) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return false;
    for (var k = sel.start; k < sel.end; k++) {
      if (text.codeUnitAt(k) != 10) _st[k] = _st[k].copyWith(link: url);
    }
    notifyListeners();
    return true;
  }

  (int, int) _selLines() {
    final sel = selection;
    final s = sel.isValid ? sel.start : 0;
    final e = sel.isValid ? sel.end : 0;
    return (lineOf(s), lineOf(e));
  }

  /// Heading / quote / normal for the selected lines. Text is unchanged.
  void setKind(String kind) {
    final (l0, l1) = _selLines();
    final all = [for (var i = l0; i <= l1; i++) _kinds[i] == kind].every((e) => e);
    for (var i = l0; i <= l1; i++) {
      _kinds[i] = all && kind != '' ? '' : kind;
    }
    notifyListeners();
  }

  /// Rewrites the start of each selected line through [fn].
  void _mapLineStarts(String Function(String line, int index) fn) {
    final (l0, l1) = _selLines();
    final ls = lines('left');
    final sel = selection;
    var delta = 0, i0 = 0;
    for (var i = 0; i < ls.length; i++) {
      if (i >= l0 && i <= l1) {
        final before = ls[i].text;
        final after = fn(before, i - l0);
        if (after != before) {
          // Only the prefix changes: keep styles of the remaining text.
          var common = 0;
          while (common < before.length && common < after.length &&
              before[before.length - 1 - common] == after[after.length - 1 - common]) {
            common++;
          }
          final keep = ls[i].st.sublist(before.length - common);
          ls[i].text = after;
          ls[i].st = [...List.filled(after.length - common, SpanStyle.plain), ...keep];
          if (i == l0) i0 = after.length - before.length;
          delta += after.length - before.length;
        }
      }
    }
    final kinds = _kinds;
    final nsel = sel.isValid
        ? TextSelection(
            baseOffset: (sel.baseOffset + (sel.baseOffset <= sel.extentOffset ? i0 : delta)).clamp(0, 1 << 30),
            extentOffset: (sel.extentOffset + (sel.baseOffset <= sel.extentOffset ? delta : i0)).clamp(0, 1 << 30))
        : null;
    final p = pending;
    setLines(ls, selection: nsel);
    _kinds = kinds;
    pending = p;
    notifyListeners();
  }

  static final _markerRe = RegExp(r'^(\s*)(• |- |\d+[.)] )');

  void toggleList(bool numbered) {
    final (l0, l1) = _selLines();
    final ls = lines('left');
    final allHave = [
      for (var i = l0; i <= l1; i++)
        numbered ? RegExp(r'^\s*\d+[.)] ').hasMatch(ls[i].text) : RegExp(r'^\s*[•-] ').hasMatch(ls[i].text)
    ].every((e) => e);
    var start = 1;
    if (numbered && l0 > 0) {
      final m = RegExp(r'^\s*(\d+)[.)] ').firstMatch(ls[l0 - 1].text);
      if (m != null) start = int.parse(m.group(1)!) + 1;
    }
    for (var i = l0; i <= l1; i++) {
      _kinds[i] = _kinds[i] == 'quote' ? 'quote' : '';
    }
    _mapLineStarts((line, idx) {
      final m = _markerRe.firstMatch(line);
      final lead = m?.group(1) ?? RegExp(r'^\s*').firstMatch(line)!.group(0)!;
      final body = line.substring(m?.end ?? lead.length);
      if (allHave) return lead + body;
      return lead + (numbered ? '${start + idx}. ' : '• ') + body;
    });
  }

  void removeListMarkers() => _mapLineStarts((line, _) {
        final m = _markerRe.firstMatch(line);
        return m == null ? line : m.group(1)! + line.substring(m.end);
      });

  void indent(int delta) => _mapLineStarts((line, _) {
        final lead = RegExp(r'^ *').firstMatch(line)!.group(0)!.length;
        final level = (lead ~/ 2 + delta).clamp(0, 8);
        return ('  ' * level) + line.substring(lead);
      });

  /// Rich copy of the selection (system clipboard gets plain text).
  Future<void> copySelection() async {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final t = text.substring(sel.start, sel.end);
    clip = (t, _st.sublist(sel.start, sel.end));
    await Clipboard.setData(ClipboardData(text: t));
  }

  // -------------------------------------------------------------- display

  static Color? hex(String? s) {
    if (s == null || s.isEmpty) return null;
    var h = s.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  static String? fontFamilyFor(String? f) => switch (f) {
        null => null,
        'DMSans' || 'Sans' => 'DMSans',
        'NotoNaskhArabic' || 'Naskh' => 'NotoNaskhArabic',
        _ => f,
      };

  static TextStyle lineStyle(String kind, TextStyle base) {
    final fs = base.fontSize ?? 16;
    return switch (kind) {
      'h1' => base.copyWith(fontSize: fs * 1.55, fontWeight: FontWeight.w700, height: 1.2),
      'h2' => base.copyWith(fontSize: fs * 1.22, fontWeight: FontWeight.w700, height: 1.25),
      'h3' => base.copyWith(fontSize: fs * 1.05, fontWeight: FontWeight.w700, height: 1.25),
      'quote' => base.copyWith(fontStyle: FontStyle.italic, color: const Color(0xFF424242)),
      _ => base,
    };
  }

  static TextStyle spanStyle(SpanStyle sp, TextStyle ls, {bool composing = false}) {
    final deco = <TextDecoration>[
      if (sp.underline || sp.link != null || composing) TextDecoration.underline,
      if (sp.strike) TextDecoration.lineThrough,
    ];
    return ls.copyWith(
      fontWeight: sp.bold ? FontWeight.w700 : null,
      fontStyle: sp.italic ? FontStyle.italic : null,
      decoration: deco.isEmpty ? null : TextDecoration.combine(deco),
      color: sp.link != null ? const Color(0xFF175CD3) : hex(sp.color),
      backgroundColor: hex(sp.bg),
      fontSize: sp.size?.toDouble(),
      fontFamily: fontFamilyFor(sp.font),
    );
  }

  static final _fnRe = RegExp(r'\[\^\d+\]');
  static const _hidden = TextStyle(fontSize: 0.01, height: 0.01, color: Colors.transparent);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A));
    final fs = base.fontSize ?? 16;
    final t = text;
    final comp = withComposing && value.composing.isValid && !value.composing.isCollapsed ? value.composing : null;
    final children = <InlineSpan>[];
    final buf = StringBuffer();
    TextStyle? cur;
    void flush() {
      if (buf.isNotEmpty) children.add(TextSpan(text: buf.toString(), style: cur));
      buf.clear();
    }

    void put(String s, TextStyle ts) {
      if (cur != ts) {
        flush();
        cur = ts;
      }
      buf.write(s);
    }

    var li = 0;
    var ls = lineStyle(_kinds.isEmpty ? '' : _kinds[0], base);
    // Footnote references: show only the number, small and raised.
    final fn = <int, int>{}; // start -> end
    for (final m in _fnRe.allMatches(t)) {
      fn[m.start] = m.end;
    }
    var k = 0;
    while (k < t.length) {
      final ch = t.codeUnitAt(k);
      if (ch == 10) {
        put('\n', ls);
        li++;
        ls = lineStyle(li < _kinds.length ? _kinds[li] : '', base);
        k++;
        continue;
      }
      final fe = fn[k];
      if (fe != null) {
        put('[^', _hidden);
        put(t.substring(k + 2, fe - 1),
            ls.copyWith(fontSize: fs * 0.62, fontWeight: FontWeight.w700, color: const Color(0xFF8C1C13), height: 1));
        put(']', _hidden);
        k = fe;
        continue;
      }
      final inComp = comp != null && k >= comp.start && k < comp.end;
      put(t[k], spanStyle(k < _st.length ? _st[k] : SpanStyle.plain, ls, composing: inComp));
      k++;
    }
    flush();
    return TextSpan(style: base, children: children);
  }
}
