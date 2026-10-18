import '../l10n/ui_strings.dart';
import 'rich_markup.dart';

/// One table-of-contents entry: heading level (1-3), plain title, printed
/// page label (filled in by the page engine).
class TocEntry {
  final int level;
  final String title;
  final String page;
  const TocEntry(this.level, this.title, this.page);
  @override
  bool operator ==(Object o) => o is TocEntry && o.level == level && o.title == title && o.page == page;
  @override
  int get hashCode => Object.hash(level, title, page);
}

/// Shared TOC look (engine/PDF + editor).
class TocSpec {
  static const double titleScale = 1.3;
  static const double indentPerLevel = 14.0; // pt
  static const double entryGap = 2.0; // pt extra below each entry
  static String get defaultTitle => tr('Mündəricat');

  static int levelOf(String line) {
    if (line.startsWith('### ')) return 3;
    if (line.startsWith('## ')) return 2;
    if (line.startsWith('# ')) return 1;
    return 0;
  }

  static String plain(String markup) => RichMarkup.parse(markup).el.join().trim();

  /// `[TOC title="…" levels=N][/TOC]`; old documents had `[TOC]\n# Title\n…[/TOC]`.
  static (String, int) parseMarker(String s) {
    final t = RegExp(r'title="([^"]*)"').firstMatch(s)?.group(1);
    final lv = int.tryParse(RegExp(r'levels=(\d)').firstMatch(s)?.group(1) ?? '') ?? 3;
    var title = t ?? RegExp(r'^# (.+)$', multiLine: true).firstMatch(s)?.group(1)?.trim() ?? defaultTitle;
    if (title.toLowerCase() == 'table of contents' && t == null) title = defaultTitle;
    return (title, lv.clamp(1, 3));
  }

  static String marker(String title, int levels) =>
      '[TOC title="${title.replaceAll('"', "'")}" levels=$levels][/TOC]';
}
