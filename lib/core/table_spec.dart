/// Single source of truth for how a table looks. Used by the layout engine
/// (page view + PDF) and by the editable table in the editor, so the three
/// can't drift apart. All sizes are in points; the editor multiplies by its
/// pixels-per-point factor.
class TableSpec {
  static const int borderColor = 0xFF555555;
  static const double borderWidth = 0.6;
  static const int headerFill = 0xFFF1ECE0;
  static const double fontScale = 0.85; // of body text size
  static const double lineScale = 1.35; // line height / font size
  static const double pad = 4.0; // cell padding
  static const double marginTop = 4.0;
  static const double marginBottom = 6.0;
  static const double captionScale = 0.8;
  static const double minRel = 0.3, maxRel = 3.0;

  /// Absolute column widths for a table [width] points wide.
  static List<double> columnWidths(List<double> rel, int cols, double width) {
    if (cols <= 0) return const [];
    final r = List<double>.generate(
        cols, (i) => i < rel.length ? rel[i].clamp(minRel, maxRel).toDouble() : 1.0);
    final sum = r.fold(0.0, (a, c) => a + c);
    return [for (final v in r) width * v / sum];
  }

  /// Column alignment code -> 'left' | 'center' | 'right'.
  static String align(List<String> aligns, int col) {
    final a = col < aligns.length ? aligns[col] : 'l';
    return switch (a) { 'c' => 'center', 'r' => 'right', _ => 'left' };
  }
}

/// Per-cell attributes stored as a prefix in the cell text:
/// `{bg=#RRGGBB;span=2}text`. span = columns merged to the right.
class CellAttr {
  static final _re = RegExp(r'^\{((?:bg=#[0-9A-Fa-f]{6}|span=\d{1,2})(?:;(?:bg=#[0-9A-Fa-f]{6}|span=\d{1,2}))*)\}');

  static (int? bg, int span, String text) parse(String raw) {
    final m = _re.firstMatch(raw);
    if (m == null) return (null, 1, raw);
    int? bg;
    var span = 1;
    for (final part in m.group(1)!.split(';')) {
      if (part.startsWith('bg=#')) bg = 0xFF000000 | int.parse(part.substring(4), radix: 16);
      if (part.startsWith('span=')) span = int.parse(part.substring(5)).clamp(1, 16);
    }
    return (bg, span, raw.substring(m.end));
  }

  static String make(int? bg, int span, String text) {
    final parts = [
      if (bg != null) 'bg=#${(bg & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      if (span > 1) 'span=$span',
    ];
    return parts.isEmpty ? text : '{${parts.join(';')}}$text';
  }

  /// For row [row] of a table with [cols] columns: list of (col, span) for
  /// the visible cells (cells covered by a merge are skipped).
  static List<(int, int)> visible(List<String> row, int cols) {
    final out = <(int, int)>[];
    var c = 0;
    while (c < cols) {
      final span = c < row.length ? parse(row[c]).$2.clamp(1, cols - c) : 1;
      out.add((c, span));
      c += span;
    }
    return out;
  }
}
