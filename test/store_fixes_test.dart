import 'dart:io';
import 'dart:typed_data';

import 'package:docspro/core/cover_art.dart';
import 'package:docspro/core/toc.dart';
import 'package:docspro/l10n/app_localizations.dart';
import 'package:docspro/l10n/ui_strings.dart';
import 'package:docspro/presentation/document_editor_screen/doc_title.dart';
import 'package:docspro/presentation/document_editor_screen/widgets/book_cover_sheet.dart';
import 'package:docspro/presentation/legal/legal_texts.dart';
import 'package:docspro/services/book_structure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'editor_harness.dart';

/// Letters that only occur in Azerbaijani text (not in English UI strings).
final _az = RegExp('[əğıışçöüİƏĞŞÇÖÜ]');
final _lit = RegExp(r"""(r?)'((?:[^'\\\n]|\\.)*)'""");

/// Files that legitimately hold Azerbaijani literals: translation tables,
/// detection of text typed in any language, and screens hidden while
/// billing is off / unused code.
const _allowFiles = [
  'lib/l10n/',
  'lib/core/text_case.dart',
  'lib/presentation/legal/legal_texts.dart',
  'lib/services/book_structure.dart',
  'lib/services/doc_import_service.dart',
  'lib/services/mobile_export_service.dart',
  'lib/services/template_service.dart', // unused
  'lib/presentation/subscription_plan_screen/', // hidden while billingEnabled == false
];
const _allowLiterals = {'[HAŞİYƏ]', '[/HAŞİYƏ]', '[HAŞİYƏ', 'adsız sənəd', 'adsız', 'Fəsil', 'Hissə'};

Iterable<(String, int, String, String)> _literals() sync* {
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final lines = f.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      for (final m in _lit.allMatches(line)) {
        if (m.group(1) == 'r') continue;
        yield (f.path, i + 1, m.group(2)!, line.substring(0, m.start));
      }
    }
  }
}

int _weightClass(Uint8List b) {
  final d = ByteData.sublistView(b);
  final n = d.getUint16(4);
  for (var i = 0; i < n; i++) {
    final o = 12 + i * 16;
    if (String.fromCharCodes(b.sublist(o, o + 4)) == 'OS/2') return d.getUint16(d.getUint32(o + 8) + 4);
  }
  return -1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppLocalizations().setLanguage(AppLanguage.en));

  group('l10n audit', () {
    test('every tr()/trf() key has az, en, ru, ar with the same placeholders', () {
      final call = RegExp(r"""\btrf?\(\s*'((?:[^'\\]|\\.)*)'""");
      final missing = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.endsWith('ui_strings.dart')) continue;
        for (final m in call.allMatches(f.readAsStringSync())) {
          final key = m.group(1)!.replaceAll(r'\n', '\n').replaceAll(r"\'", "'").replaceAll(r'\$', r'$');
          if (!uiStrings.containsKey(key)) missing.add('${f.path}: $key');
        }
      }
      expect(missing, isEmpty);
      final ph = RegExp(r'\{(\w+)\}');
      uiStrings.forEach((k, v) {
        expect(v.length, 4, reason: k);
        final want = ph.allMatches(k).map((m) => m.group(1)).toSet();
        for (final s in v) {
          expect(s.trim(), isNotEmpty, reason: k);
          expect(ph.allMatches(s).map((m) => m.group(1)).toSet(), want, reason: '$k -> $s');
        }
        expect(v[1], isNot(matches(_az)), reason: 'English text with Azerbaijani letters: $k');
      });
    });

    test('no hard-coded Azerbaijani UI text outside translations', () {
      final bad = <String>[];
      for (final (path, line, s, before) in _literals()) {
        if (!_az.hasMatch(s) || _allowFiles.any(path.startsWith) || _allowLiterals.contains(s)) continue;
        if (RegExp(r'\b(az|en|ru|ar):\s*$').hasMatch(before)) continue; // l10n.t(az: …)
        if (RegExp(r'\b(_l|t|_t|tr|trf|trAll)\(\s*$').hasMatch(before)) continue; // positional az / key
        if (RegExp(r"\bconst \[[^\]]*$").hasMatch(before) && path.endsWith('book_structure.dart')) continue;
        // cover names are table data shown through tr(name)
        if ((path.endsWith('cover_art.dart') || path.endsWith('book_cover_sheet.dart')) && uiStrings.containsKey(s)) continue;
        bad.add('$path:$line  $s');
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
    });

    test('cover names are translated', () {
      for (final t in coverTemplates) {
        expect(uiStrings.containsKey(t.name), isTrue, reason: t.name);
      }
      for (final c in artCovers) {
        expect(uiStrings.containsKey(c.name), isTrue, reason: c.name);
      }
    });

    test('tr() follows the UI language', () {
      AppLocalizations().setLanguage(AppLanguage.en);
      expect(tr('Üz qabığı'), 'Cover');
      expect(tr('Fəsil'), 'Chapter');
      expect(tr('Yalnız əlyazma'), 'Manuscript only');
      expect(TocSpec.defaultTitle, 'Contents');
      expect(trf('Fəsillər ({n})', {'n': 3}), 'Chapters (3)');
      AppLocalizations().setLanguage(AppLanguage.ru);
      expect(tr('Üz qabığı'), 'Обложка');
      AppLocalizations().setLanguage(AppLanguage.ar);
      expect(tr('Mündəricat'), 'الفهرس');
      AppLocalizations().setLanguage(AppLanguage.az);
      expect(tr('Üz qabığı'), 'Üz qabığı');
      expect(tr('Find'), 'Tap');
    });

    test('legal pages exist in every language and match the app', () {
      for (final l in AppLanguage.values) {
        for (final d in [LegalTexts.privacy(l), LegalTexts.terms(l)]) {
          expect(d.sections, isNotEmpty);
          final all = d.sections.map((s) => s.body).join(' ');
          expect(all, contains('nibrascode@gmail.com'));
          expect(all, isNot(contains('Lemon Squeezy')));
        }
      }
      expect(LegalTexts.privacy(AppLanguage.en).sections.map((s) => s.body).join(), contains('photo picker'));
    });

    test('manuscript export strips planning tables written in any UI language', () {
      for (final lang in AppLanguage.values) {
        AppLocalizations().setLanguage(lang);
        final cast = '[TABLE]\n| ${tr('Ad')} | ${tr('Rol')} | ${tr('İstək')} | ${tr('Qüsur')} |\n| --- | --- | --- | --- |\n| a | b | c | d |\n[CAP]${tr('Personajlar')}\n[/TABLE]';
        final scene = '## ${tr('Səhnə')}\n\n**POV:** x\n**${tr('Nəticə')}:** y\n\n';
        final out = BookStructure.toManuscript('# One\n\nBody.\n\n$cast\n\n$scene# Two\n');
        expect(out, isNot(contains(tr('Qüsur'))), reason: lang.name);
        expect(out, isNot(contains('POV')), reason: lang.name);
        expect(out, contains('Body.'));
      }
    });
  });

  group('title bar', () {
    test('DocTitle strips markup', () {
      expect(DocTitle.display(typed: '', body: '# Chapter One\n\nText', untitled: 'U'), 'Chapter One');
      expect(DocTitle.display(typed: '## **Bold** title', body: '', untitled: 'U'), 'Bold title');
      expect(DocTitle.display(typed: '', body: '[TOC title="Contents" levels=2][/TOC]\n\n> *Quote*', untitled: 'U'), 'Quote');
      expect(DocTitle.display(typed: '', body: '', untitled: 'U'), 'U');
    });

    testWidgets('editor bar shows the plain title', (tester) async {
      await pumpEditor(tester, title: '', content: '# Chapter One\n\nIt was a bright cold day.');
      expect(find.text('Chapter One'), findsWidgets);
      expect(find.text('# Chapter One'), findsNothing);
    });
  });

  group('export format picker', () {
    for (final (name, size, dpr) in [
      ('1080x2340 phone', const Size(1080, 2340), 2.75),
      ('7-inch tablet portrait', const Size(1200, 1920), 2.0),
      ('7-inch tablet landscape', const Size(1920, 1200), 2.0),
      ('small phone landscape', const Size(1280, 720), 2.0),
    ]) {
      testWidgets('fits and scrolls on $name', (tester) async {
        await pumpEditor(tester, content: 'Hello');
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpr;
        await tester.pump();
        final st = tester.state(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'DocumentEditorScreen'));
        final picked = (st as dynamic).showFormatPickerForTest() as Future;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('export-format-sheet')), findsOneWidget);
        await tester.scrollUntilVisible(find.text('EPUB'), 80, scrollable: find.descendant(of: find.byKey(const Key('export-format-sheet')), matching: find.byType(Scrollable)));
        await tester.tap(find.text('EPUB'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect((await picked).toString(), contains('epub'));
      });
    }
  });

  group('fonts', () {
    test('DM Sans Medium and SemiBold are bundled for google_fonts and the family', () {
      final pub = File('pubspec.yaml').readAsStringSync();
      for (final (file, w) in [('DMSans-Medium', 500), ('DMSans-SemiBold', 600)]) {
        final f = File('assets/fonts/$file.ttf');
        expect(f.existsSync(), isTrue, reason: file);
        expect(_weightClass(f.readAsBytesSync()), w, reason: file);
        expect(pub, contains('- asset: assets/fonts/$file.ttf\n          weight: $w'));
      }
    });
  });

  group('android permissions', () {
    test('manifest strips media/storage permissions merged from plugins', () {
      final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      for (final p in [
        'READ_MEDIA_IMAGES',
        'READ_MEDIA_VIDEO',
        'READ_MEDIA_VISUAL_USER_SELECTED',
        'READ_EXTERNAL_STORAGE',
        'WRITE_EXTERNAL_STORAGE',
        'MANAGE_EXTERNAL_STORAGE',
      ]) {
        expect(m, contains('<uses-permission android:name="android.permission.$p" tools:node="remove"/>'), reason: p);
        expect(RegExp('android.permission.$p"(?! tools:node="remove")').hasMatch(m), isFalse, reason: p);
      }
      expect(m, isNot(contains('requestLegacyExternalStorage')));
      final lib = Directory('lib').listSync(recursive: true).whereType<File>().map((f) => f.readAsStringSync()).join();
      expect(lib, isNot(contains('permission_handler')));
    });

    test('single-ABI APK drops other ABIs\' plugin libraries', () {
      final g = File('android/app/build.gradle.kts').readAsStringSync();
      expect(g, contains('findProperty("target-platform")'));
      expect(g, contains('excludes += "lib/\$abi/**"'));
    });
  });
}
