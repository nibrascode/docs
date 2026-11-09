import 'package:docspro/l10n/app_localizations.dart';
import 'package:docspro/presentation/document_editor_screen/document_editor_screen.dart';
import 'package:docspro/presentation/documents_list_screen/documents_list_screen.dart';
import 'package:docspro/routes/app_routes.dart';
import 'package:docspro/services/billing_service.dart';
import 'package:docspro/services/local_docs_cache.dart';
import 'package:docspro/services/premium_service.dart';
import 'package:docspro/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'test_fonts.dart';

Finder _editorFields() => find.descendant(
      of: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'DocumentCanvas'),
      matching: find.byType(EditableText),
    );

bool _anyFocused(WidgetTester tester) =>
    tester.widgetList<EditableText>(_editorFields()).any((e) => e.focusNode.hasFocus);

Finder _docTitleOnHome() => find.descendant(
      of: find.byType(DocumentsListScreen),
      matching: find.text('Ev sənədi'),
    );

void _ignoreHomeCardOverflow() {
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
    old?.call(details);
  };
}

Future<void> _pumpHome(WidgetTester tester) async {
  _ignoreHomeCardOverflow();
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.runAsync(loadAppFonts);
  // Wide enough that the two home action cards do not overflow in tests.
  tester.view.physicalSize = const Size(1440, 3120);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  BillingService.instance.available = false;
  BillingService.instance.tier = PlanTier.free;
  addTearDown(() => BillingService.instance.available = false);

  await LocalDocsCache.saveDoc(
    id: 'local_home_open',
    title: 'Ev sənədi',
    content: 'Salam dünya',
  );

  final router = GoRouter(
    initialLocation: AppRoutes.documentsListScreen,
    routes: [
      GoRoute(
        path: AppRoutes.documentsListScreen,
        builder: (context, state) => const DocumentsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.documentEditorScreen,
        builder: (context, state) {
          final doc = state.extra as Map<String, dynamic>?;
          return DocumentEditorScreen(documentData: doc);
        },
      ),
      GoRoute(
        path: AppRoutes.subscriptionPlanScreen,
        builder: (context, state) => const Scaffold(body: Text('plans')),
      ),
      GoRoute(
        path: AppRoutes.templatesScreen,
        builder: (context, state) => const Scaffold(body: Text('templates')),
      ),
      GoRoute(
        path: AppRoutes.settingsScreen,
        builder: (context, state) => const Scaffold(body: Text('settings')),
      ),
    ],
  );

  await tester.pumpWidget(LocalizationsProvider(
    child: Sizer(
      builder: (context, o, s) => MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openDocFromHome(WidgetTester tester) async {
  expect(_docTitleOnHome(), findsWidgets);
  await tester.tap(_docTitleOnHome().first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _popEditor(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(DocumentEditorScreen), findsNothing);
}

void main() {
  testWidgets('home → open document → editor focused & keyboard', (tester) async {
    await _pumpHome(tester);
    await _openDocFromHome(tester);

    expect(find.byType(DocumentEditorScreen), findsOneWidget);
    expect(_editorFields(), findsWidgets);
    expect(_anyFocused(tester), isTrue,
        reason: 'opening from home must focus the writing area');
    expect(tester.testTextInput.isVisible, isTrue,
        reason: 'keyboard must open when a document is opened from home');
  });

  testWidgets('home → open → back → open again still focuses', (tester) async {
    await _pumpHome(tester);
    await _openDocFromHome(tester);
    expect(find.byType(DocumentEditorScreen), findsOneWidget);
    expect(_anyFocused(tester), isTrue);

    await _popEditor(tester);

    // Silent refresh: list stays visible, not a spinner
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_docTitleOnHome(), findsWidgets);

    await _openDocFromHome(tester);
    expect(find.byType(DocumentEditorScreen), findsOneWidget);
    expect(_anyFocused(tester), isTrue,
        reason: 'reopening from home after back must focus again');
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('after editor return, home list stays tappable (no spinner flash)',
      (tester) async {
    await _pumpHome(tester);
    await _openDocFromHome(tester);
    expect(find.byType(DocumentEditorScreen), findsOneWidget);

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_docTitleOnHome(), findsWidgets);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
