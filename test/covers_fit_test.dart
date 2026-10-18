import 'package:docspro/presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

void main() {
  const data = CoverData(
      templateId: '',
      title: 'Dağların arxasında qalan şəhərin unudulmuş hekayələri',
      subtitle: 'Azərbaycan nağılları və əfsanələri toplusu, ikinci nəşr',
      author: 'Məhəmmədəli Əbdülrəhmanzadə',
      year: '2026',
      publisher: 'Nibras Code');
  for (final size in [const Size(150, 225), const Size(90, 135), const Size(320, 480)]) {
    testWidgets('every cover fits long text at ${size.width.toInt()}px', (tester) async {
      await tester.runAsync(loadAppFonts);
      final bad = <String>[];
      for (final t in coverTemplates) {
        await tester.pumpWidget(MaterialApp(
          home: Center(child: CoverPagePreview(template: t, data: data, width: size.width, height: size.height)),
        ));
        final e = tester.takeException();
        if (e != null) bad.add('${t.id}(${t.layout})');
      }
      expect(bad, isEmpty, reason: bad.join(', '));
    });
  }
}
