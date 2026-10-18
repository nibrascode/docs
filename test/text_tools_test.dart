import 'package:docspro/core/page_layout.dart';
import 'package:docspro/core/page_size.dart';
import 'package:docspro/core/text_case.dart';
import 'package:docspro/services/book_writers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

Future<List<String>> lineWords(String text) async {
  final d = await PageLayoutEngine(const LayoutSettings(pageSize: PageSize.a4), imageSizer: (_) async => null).layout(text);
  // Visual order = left-to-right by x.
  return [
    for (final l in d.pages.first.lines)
      ([...l.words]..sort((a, b) => a.x.compareTo(b.x))).map((w) => w.text).join(' ')
  ];
}

void main() {
  test('Azerbaijani case transforms', () {
    expect(TextCase.apply('işıq və ilham', 'upper', turkic: true), 'İŞIQ VƏ İLHAM');
    expect(TextCase.apply('İLHAM IŞIQ', 'lower', turkic: true), 'ilham ışıq');
    expect(TextCase.apply('səhər işığı «bakı»', 'title', turkic: true), 'Səhər İşığı «Bakı»');
    expect(TextCase.apply('hello world', 'upper'), 'HELLO WORLD');
  });

  test('paragraph direction from first strong letter', () {
    expect(isRtlText('النص PDF'), isTrue);
    expect(isRtlText('2026 النص'), isTrue);
    expect(isRtlText('Nibras Docs يدعم'), isFalse);
    expect(scriptSegments('Kitab النص العربي, PDF'), [('Kitab ', false), ('النص العربي', true), (', PDF', false)]);
  });

  testWidgets('bidi: visual order of mixed lines', (t) async {
    await t.runAsync(() async {
      await loadAppFonts();
      // RTL paragraph ending in a Latin word: the period goes to the far left.
      expect((await lineWords('النص في ملف PDF.')).single, '. PDF ملف في النص');
      // Brackets mirror inside RTL; numbers stay left-to-right.
      expect((await lineWords('وهو EPUB (الإصدار 1.1.0).')).single, '.( 1.1.0 الإصدار ) EPUB وهو');
      // LTR paragraph with an Arabic phrase: phrase reversed as a unit.
      expect((await lineWords('Nibras Docs يدعم العربية today.')).single, 'Nibras Docs العربية يدعم today .');
      // Arabic heading and tashkeel survive as whole words.
      final h = await lineWords('# الفصل الأول\n\nبِسْمِ اللَّهِ');
      expect(h.first, 'الأول الفصل');
      expect(h.last, 'اللَّهِ بِسْمِ');
    });
  });
}
