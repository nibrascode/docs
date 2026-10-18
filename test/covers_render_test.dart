import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:docspro/presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

Future<void> _icons() async {
  final f = File('/home/box/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!f.existsSync()) return;
  final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await l.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  for (final variant in ['short', 'long']) {
    testWidgets('all cover templates render without overflow ($variant titles)', (tester) async {
      await tester.runAsync(() async {
        await loadAppFonts();
        await _icons();
      });
      final data = variant == 'short'
          ? const CoverData(templateId: '', title: 'Səhər işığı', subtitle: 'Roman', author: 'Aysel Məmmədova', year: '2026')
          : const CoverData(
              templateId: '',
              title: 'Dağların arxasında qalan şəhərin unudulmuş hekayələri',
              subtitle: 'Azərbaycan nağılları və əfsanələri toplusu, ikinci nəşr',
              author: 'Məhəmmədəli Əbdülrəhmanzadə',
              year: '2026');
      for (final group in [
        ('nibras', coverTemplates.where((t) => t.layout == 'nibrascode').toList()),
        ('all', coverTemplates),
      ]) {
        final list = group.$2;
        const w = 150.0, h = 225.0, cols = 6;
        final rows = (list.length / cols).ceil();
        tester.view.physicalSize = Size(cols * (w + 12) + 12, rows * (h + 30) + 12);
        tester.view.devicePixelRatio = 1;
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFE9E6E0),
            body: RepaintBoundary(
              key: key,
              child: Container(
                color: const Color(0xFFE9E6E0),
                padding: const EdgeInsets.all(6),
                child: Wrap(children: [
                  for (final t in list)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(children: [
                        CoverPagePreview(template: t, data: data, width: w, height: h),
                        SizedBox(height: 18, child: Text(t.name, style: const TextStyle(fontFamily: 'DMSans', fontSize: 11))),
                      ]),
                    ),
                ]),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'overflow in ${group.$1}/$variant');
        await _shot(tester, key, '/workspace/docs-shots/covers-${group.$1}-$variant.png');
      }
      addTearDown(tester.view.reset);
    });
  }
}
