enum PageSize {
  a4,
  a3,
  a5,
  letter,
  legal;

  String get label {
    switch (this) {
      case PageSize.a4:
        return 'A4';
      case PageSize.a3:
        return 'A3';
      case PageSize.a5:
        return 'A5';
      case PageSize.letter:
        return 'Letter';
      case PageSize.legal:
        return 'Legal';
    }
  }

  double get widthPx {
    switch (this) {
      case PageSize.a4:
        return 794.0;
      case PageSize.a3:
        return 1123.0;
      case PageSize.a5:
        return 559.0;
      case PageSize.letter:
        return 816.0;
      case PageSize.legal:
        return 816.0;
    }
  }

  double get heightPx {
    switch (this) {
      case PageSize.a4:
        return 1123.0;
      case PageSize.a3:
        return 1587.0;
      case PageSize.a5:
        return 794.0;
      case PageSize.letter:
        return 1056.0;
      case PageSize.legal:
        return 1344.0;
    }
  }
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
