import 'widgets/book_cover_sheet.dart';

/// Plain document title for bars and lists: never raw markup such as
/// `# Chapter One`, `**bold**` or block tokens.
class DocTitle {
  static const int maxLen = 80;

  static String _cut(String c) => c.length > maxLen ? '${c.substring(0, maxLen).trimRight()}…' : c;

  /// Markup-free version of a stored/typed title ('' when nothing is left).
  static String clean(String title) => _cut(CoverData.cleanText(title));

  /// Title taken from the body: cover title, else the first real text line.
  static String fromBody(String text) {
    final cover = CoverData.parse(text);
    if (cover != null && cover.title.isNotEmpty && cover.title != CoverData.brandTitle) {
      return clean(cover.title);
    }
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('[COVER') || t.startsWith('[img') || t.startsWith('[TABLE') ||
          t.startsWith('[/TABLE') || t.startsWith('[TOC') || t.startsWith('[/TOC') || t.startsWith('[CAP') ||
          t.startsWith('|') || t.contains('Page Break') || t.startsWith('[note') ||
          t.startsWith('[HAŞİYƏ') || RegExp(r'^[-*\s]+$').hasMatch(t)) {
        continue;
      }
      final c = clean(t);
      if (c.isNotEmpty) return c;
    }
    return '';
  }

  /// What the editor bar / list shows.
  static String display({required String typed, required String body, required String untitled}) {
    final a = clean(typed);
    if (a.isNotEmpty) return a;
    final b = fromBody(body);
    return b.isNotEmpty ? b : untitled;
  }
}
