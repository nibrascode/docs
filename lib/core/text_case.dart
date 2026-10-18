/// Case conversion that respects Azerbaijani/Turkish dotted and dotless i
/// and keeps markup markers untouched.
class TextCase {
  static String upper(String s, {bool turkic = false}) =>
      (turkic ? s.replaceAll('i', 'İ').replaceAll('ı', 'I') : s).toUpperCase();

  static String lower(String s, {bool turkic = false}) =>
      (turkic ? s.replaceAll('I', 'ı').replaceAll('İ', 'i') : s.replaceAll('İ', 'i')).toLowerCase();

  static String apply(String s, String mode, {bool turkic = false}) {
    switch (mode) {
      case 'upper':
        return upper(s, turkic: turkic);
      case 'lower':
        return lower(s, turkic: turkic);
      case 'title':
        return s.splitMapJoin(RegExp(r'[^\s]+'), onMatch: (m) {
          final w = m.group(0)!;
          final i = w.indexOf(RegExp(r'[^\W\d_]', unicode: true));
          if (i < 0) return w;
          return w.substring(0, i) +
              upper(w[i], turkic: turkic) +
              lower(w.substring(i + 1), turkic: turkic);
        }, onNonMatch: (n) => n);
      default:
        return s;
    }
  }
}
