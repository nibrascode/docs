import 'dart:io';

import 'package:docspro/core/cover_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every art cover has an asset and a known category', () {
    final ids = coverCategories.map((c) => c.id).toSet();
    for (final c in artCovers) {
      expect(File(c.asset).existsSync(), isTrue, reason: c.asset);
      expect(ids.contains(c.category), isTrue, reason: c.id);
      expect(artCoverFor(c.templateId), same(c));
    }
    expect(artCovers.where((c) => c.id.startsWith('lib_')).length, 54);
  });

  test('category search works in every language', () {
    final leather = coverCategoryById('leather')!;
    for (final q in ['dəri', 'Leather', 'кожа', 'جلد']) {
      expect(leather.matches(q), isTrue, reason: q);
    }
    expect(coverCategoryById('nature')!.matches('meşə'), isTrue);
    expect(coverCategoryById('marble')!.matches('ulduz'), isFalse);
  });
}
