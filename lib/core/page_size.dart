enum PageSize {
  a4('A4', 595.28, 841.89),
  a3('A3', 841.89, 1190.55),
  a5('A5', 419.53, 595.28),
  b5('B5', 498.90, 708.66),
  letter('Letter', 612, 792),
  legal('Legal', 612, 1008),
  book5x8('5 × 8 in', 360, 576),
  book55x85('5.5 × 8.5 in', 396, 612),
  book6x9('6 × 9 in', 432, 648);

  const PageSize(this.label, this.widthPt, this.heightPt);

  final String label;

  /// Size in PDF points (1/72 inch). The single source of truth.
  final double widthPt;
  final double heightPt;

  /// Legacy screen units (96 dpi).
  double get widthPx => widthPt * 96 / 72;
  double get heightPx => heightPt * 96 / 72;

  String get mm =>
      '${(widthPt / 72 * 25.4).round()} × ${(heightPt / 72 * 25.4).round()} mm';
}

enum PageMargin {
  narrow,
  normal,
  wide;

  String get label {
    switch (this) {
      case PageMargin.narrow:
        return 'Narrow';
      case PageMargin.normal:
        return 'Normal';
      case PageMargin.wide:
        return 'Wide';
    }
  }

  double get px {
    switch (this) {
      case PageMargin.narrow:
        return 36.0;
      case PageMargin.normal:
        return 56.0;
      case PageMargin.wide:
        return 80.0;
    }
  }
}
