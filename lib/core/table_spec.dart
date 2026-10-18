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
