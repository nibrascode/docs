import 'package:docspro/l10n/app_localizations.dart';
import 'package:docspro/presentation/document_editor_screen/document_editor_screen.dart';
import 'package:docspro/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'test_fonts.dart';

Future<void> pumpEditor(WidgetTester tester, {String content = '', String title = 'Test'}) async {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.runAsync(loadAppFonts);
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(LocalizationsProvider(
    child: Sizer(
      builder: (context, o, s) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: DocumentEditorScreen(documentData: {'id': 'local_test', 'title': title, 'content': content}),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 500));
}
