import '../l10n/ui_strings.dart';

/// Chapter / heading ranges for a manuscript (H1–H6).
class BookSection {
  final int index;
  final int level;
  final int start;
  final int end;
  final String title;
  final String headingRaw;

  const BookSection({
    required this.index,
    required this.level,
    required this.start,
    required this.end,
    required this.title,
    required this.headingRaw,
  });
}

/// Book-writer operations on markdown-ish document text.
class BookStructure {
  static final _headingRe = RegExp(r'^(#{1,6}) (.+)$', multiLine: true);
  static final _chapterNumRe = RegExp(
    r'^(#{1,6}) (Chapter|Fəsil|Глава|فصل)\s+\d+(\s*[—–:\-].*)?$',
    multiLine: true,
  );
  static final _partNumRe = RegExp(
    r'^(#{1,6}) (Part|Hissə|Часть)\s+\d+(\s*[—–:\-].*)?$',
    multiLine: true,
  );

  static const planningCaptions = {
    'personajlar',
    'məkanlar',
    'mekanlar',
    'xronologiya',
    'səhnə siyahısı',
    'sehne siyahisi',
    'fəsil planı',
    'fasil plani',
    'tədqiqat',
    'tedqiqat',
    'outline',
    'cast',
    'places',
    'timeline',
    'scene list',
    'research',
    'characters',
  };

  static List<BookSection> parse(String text) {
    final matches = _headingRe.allMatches(text).toList();
    final sections = <BookSection>[];
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final level = m.group(1)!.length;
      final title = m.group(2)!.trim();
      var end = text.length;
      for (var j = i + 1; j < matches.length; j++) {
        if (matches[j].group(1)!.length <= level) {
          end = matches[j].start;
          break;
        }
      }
      sections.add(BookSection(
        index: i,
        level: level,
        start: m.start,
        end: end,
        title: title.isEmpty ? tr('Başlıqsız') : title,
        headingRaw: m.group(0)!,
      ));
    }
    return sections;
  }

  static int? parentIndex(List<BookSection> all, int i) {
    final level = all[i].level;
    for (var j = i - 1; j >= 0; j--) {
      if (all[j].level < level) return j;
    }
    return null;
  }

  static List<int> siblingIndices(List<BookSection> all, int i) {
    final parent = parentIndex(all, i);
    final level = all[i].level;
    final out = <int>[];
    for (var k = 0; k < all.length; k++) {
      if (all[k].level != level) continue;
      if (parentIndex(all, k) != parent) continue;
      out.add(k);
    }
    return out;
  }

  static String _swap(
    String text,
    int aStart,
    int aEnd,
    int bStart,
    int bEnd,
  ) {
    if (aStart > bStart) return _swap(text, bStart, bEnd, aStart, aEnd);
    final a = text.substring(aStart, aEnd);
    final mid = text.substring(aEnd, bStart);
    final b = text.substring(bStart, bEnd);
    return '${text.substring(0, aStart)}$b$mid$a${text.substring(bEnd)}';
  }

  /// Move a heading AND its body among same-level siblings.
  static String move(String text, int sectionIndex, int dir) {
    final all = parse(text);
    if (sectionIndex < 0 || sectionIndex >= all.length) return text;
    final sibs = siblingIndices(all, sectionIndex);
    final pos = sibs.indexOf(sectionIndex);
    final swapWith = pos + dir;
    if (pos < 0 || swapWith < 0 || swapWith >= sibs.length) return text;
    final aIdx = dir < 0 ? sibs[swapWith] : sectionIndex;
    final bIdx = dir < 0 ? sectionIndex : sibs[swapWith];
    return _swap(
      text,
      all[aIdx].start,
      all[aIdx].end,
      all[bIdx].start,
      all[bIdx].end,
    );
  }

  static String duplicate(String text, int sectionIndex) {
    final all = parse(text);
    if (sectionIndex < 0 || sectionIndex >= all.length) return text;
    final s = all[sectionIndex];
    var block = text.substring(s.start, s.end);
    if (!block.endsWith('\n')) block = '$block\n';
    return text.substring(0, s.end) + block + text.substring(s.end);
  }

  static String delete(String text, int sectionIndex) {
    final all = parse(text);
    if (sectionIndex < 0 || sectionIndex >= all.length) return text;
    final s = all[sectionIndex];
    return text.replaceRange(s.start, s.end, '');
  }

  static String rename(String text, int sectionIndex, String newTitle) {
    final all = parse(text);
    if (sectionIndex < 0 || sectionIndex >= all.length) return text;
    final s = all[sectionIndex];
    final hashes = '#' * s.level;
    final title = newTitle.trim().isEmpty ? tr('Başlıqsız') : newTitle.trim();
    return text.replaceRange(
      s.start,
      s.start + s.headingRaw.length,
      '$hashes $title',
    );
  }

  static String changeLevel(String text, int sectionIndex, int delta) {
    final all = parse(text);
    if (sectionIndex < 0 || sectionIndex >= all.length) return text;
    final s = all[sectionIndex];
    final newLevel = (s.level + delta).clamp(1, 6);
    if (newLevel == s.level) return text;
    final hashes = '#' * newLevel;
    return text.replaceRange(
      s.start,
      s.start + s.headingRaw.length,
      '$hashes ${s.title}',
    );
  }

  static String renumber(String text) {
    var ch = 0;
    var out = text.replaceAllMapped(_chapterNumRe, (m) {
      ch++;
      final rest = m.group(3) ?? '';
      return '${m.group(1)} ${m.group(2)} $ch$rest';
    });
    var part = 0;
    out = out.replaceAllMapped(_partNumRe, (m) {
      part++;
      final rest = m.group(3) ?? '';
      return '${m.group(1)} ${m.group(2)} $part$rest';
    });
    return out;
  }

  static String splitAt(String text, int cursor, {String label = 'Fəsil'}) {
    final n = RegExp(
          r'^# (Chapter|Fəsil|Глава|فصل) ',
          multiLine: true,
        ).allMatches(text).length +
        1;
    final snippet = '\n\n# $label $n — \n\n';
    final at = cursor.clamp(0, text.length);
    return renumber(text.substring(0, at) + snippet + text.substring(at));
  }

  /// Planning-table captions in every UI language (inserted via tr()).
  static final Set<String> _localCaptions = {
    for (final k in const ['Personajlar', 'Məkanlar', 'Xronologiya', 'Səhnə siyahısı', 'Fəsil planı', 'Tədqiqat'])
      ...trAll(k).map((v) => v.toLowerCase()),
  };

  static bool _isPlanningTable(String block) {
    final cap = RegExp(r'\[CAP\](.*)$', multiLine: true)
            .firstMatch(block)
            ?.group(1)
            ?.trim()
            .toLowerCase() ??
        '';
    if (planningCaptions.contains(cap) || _localCaptions.contains(cap)) return true;
    bool has(String k) => trAll(k).any((v) => block.contains('| $v |'));
    if (has('İstək') || has('Qüsur') || block.contains('| POV |') && has('Konflikt')) {
      return true;
    }
    return false;
  }

  /// Strip writer-planning tables / outline so export is the book itself.
  static String toManuscript(String text) {
    var s = text.replaceAllMapped(
      RegExp(r'\[TABLE\][\s\S]*?\[/TABLE\]'),
      (m) => _isPlanningTable(m.group(0)!) ? '' : m.group(0)!,
    );
    s = s.replaceAll(
      RegExp(
        '## (?:${trAll('Səhnə').map(RegExp.escape).join('|')})\\n+\\*\\*POV:\\*\\*[\\s\\S]*?'
        '\\*\\*(?:${trAll('Nəticə').map(RegExp.escape).join('|')}):\\*\\*[^\\n]*\\n*',
      ),
      '\n',
    );
    final cuts = <BookSection>[];
    for (final sec in parse(s)) {
      final t = sec.title.toLowerCase();
      if (t == 'outline' ||
          t.startsWith('outline ') ||
          t.startsWith('yazıçı dəftəri') ||
          t.startsWith('yaziçi defteri') ||
          t == 'akt planı' ||
          t.startsWith('writer bible') ||
          t.startsWith('writer notebook')) {
        cuts.add(sec);
      }
    }
    cuts.sort((a, b) => b.start.compareTo(a.start));
    for (final c in cuts) {
      s = s.replaceRange(c.start, c.end, '');
    }
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  static Map<String, int> nameIndex(String text) {
    final names = <String, int>{};
    for (final m in RegExp(r'\[TABLE\]([\s\S]*?)\[/TABLE\]').allMatches(text)) {
      final body = m.group(1) ?? '';
      final cap = RegExp(r'\[CAP\](.*)$', multiLine: true)
              .firstMatch(body)
              ?.group(1)
              ?.trim()
              .toLowerCase() ??
          '';
      final lines = body
          .split('\n')
          .where((l) => l.startsWith('|') && !l.contains('---'))
          .toList();
      if (lines.isEmpty) continue;
      final header = lines.first.toLowerCase();
      final isCast = cap.contains('personaj') ||
          cap.contains('cast') ||
          cap.contains('character') ||
          header.contains('| ad |') ||
          header.contains('| name |');
      if (!isCast) continue;
      for (var i = 1; i < lines.length; i++) {
        var parts = lines[i].split('|');
        if (parts.isNotEmpty && parts.first.trim().isEmpty) {
          parts = parts.sublist(1);
        }
        if (parts.isEmpty) continue;
        final name = parts.first.trim();
        if (name.length < 2) continue;
        names.putIfAbsent(name, () => 0);
      }
    }
    final body =
        text.replaceAll(RegExp(r'\[TABLE\][\s\S]*?\[/TABLE\]'), ' ');
    for (final n in names.keys.toList()) {
      names[n] = RegExp(
        r'(^|[^\p{L}])' + RegExp.escape(n) + r'($|[^\p{L}])',
        caseSensitive: false,
        unicode: true,
      ).allMatches(body).length;
    }
    const skip = {
      'the',
      'and',
      'for',
      'this',
      'that',
      'with',
      'from',
      'chapter',
      'fəsil',
      'fasil',
      'prologue',
      'epilogue',
      'copyright',
      'dedication',
      'table',
      'contents',
      'about',
      'author',
      'part',
      'hissə',
      'preface',
      'glossary',
      'bibliography',
      'introduction',
      'conclusion',
      'notes',
      'acknowledgements',
      'afterword',
    };
    final extra = <String, int>{};
    final tokenRe = RegExp(r"\b[\p{Lu}][\p{L}'’\-]{2,}\b", unicode: true);
    for (final m in tokenRe.allMatches(body)) {
      final w = m.group(0)!;
      if (skip.contains(w.toLowerCase())) continue;
      extra[w] = (extra[w] ?? 0) + 1;
    }
    extra.forEach((k, v) {
      if (v >= 2 && !names.containsKey(k)) names[k] = v;
    });
    return names;
  }

  static int firstIndexOfName(String text, String name) {
    final m = RegExp(
      RegExp.escape(name),
      caseSensitive: false,
    ).firstMatch(text);
    return m?.start ?? 0;
  }
}
