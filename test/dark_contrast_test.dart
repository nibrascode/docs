import 'test_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:docspro/theme/app_theme.dart';
import 'package:docspro/widgets/dark_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double _lum(Color c) => c.computeLuminance();
double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05));
}

Color _textColor(WidgetTester t, String s) {
  final rt = t.renderObject<RenderParagraph>(find.text(s).last);
  return rt.text.style!.color!;
}


void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final entry in <String, ThemeData Function()>{
    'dark': () => AppTheme.darkTheme,
    'sheet': () => AppTheme.sheetTheme,
    'light': () => AppTheme.lightTheme,
  }.entries) {
    testWidgets('${entry.key}: input text, label and selected chip contrast',
        (t) async {
      await t.runAsync(loadAppFonts);
      final theme = entry.value();
      final ctrl = TextEditingController(text: 'Yazı');
      await t.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(children: [
            TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Kitabın adı')),
            ChoiceChip(label: const Text('Orta'), selected: true, onSelected: (_) {}),
            ChoiceChip(label: const Text('Alt'), selected: false, onSelected: (_) {}),
          ]),
        ),
      ));
      final fill = theme.inputDecorationTheme.fillColor!;
      final editable = t.widget<EditableText>(find.byType(EditableText));
      expect(contrast(editable.style.color!, fill), greaterThan(4.5));
      expect(contrast(_textColor(t, 'Kitabın adı'), fill), greaterThan(3.0));
      final selBg = theme.chipTheme.selectedColor!;
      expect(contrast(_textColor(t, 'Orta'), selBg), greaterThan(4.5));
      final bg = theme.chipTheme.backgroundColor!;
      expect(contrast(_textColor(t, 'Alt'), bg), greaterThan(4.5));
    });
  }

  testWidgets('showDarkSheet applies dark theme in a light app', (t) async {
    await t.runAsync(loadAppFonts);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => showDarkSheet(
              context: ctx,
              builder: (_) => const TextField(
                  decoration: InputDecoration(labelText: 'Müəllif'))),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final ctx = t.element(find.byType(TextField));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    final fill = Theme.of(ctx).inputDecorationTheme.fillColor!;
    final editable = t.widget<EditableText>(find.byType(EditableText));
    expect(contrast(editable.style.color!, fill), greaterThan(4.5));
  });
}
