import '../../core/toc.dart';
import 'package:docspro/widgets/dark_sheet.dart';
import '../../routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/table_editor_dialog.dart';
import 'widgets/document_settings_sheet.dart';
import 'widgets/book_cover_sheet.dart';
import 'dart:async';
import 'widgets/image_insert_dialog.dart';
import 'widgets/link_insert_dialog.dart';
import '../../services/premium_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/pdf_service.dart';
import '../../services/book_writers.dart';
import '../../core/text_case.dart';
import '../../core/rich_markup.dart';
import '../../services/mobile_export_service.dart';
import '../../services/local_docs_cache.dart';
import '../../services/template_service.dart';
import '../../services/book_structure.dart';
import 'widgets/document_canvas.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../core/page_size.dart';
import '../../core/book_chrome.dart';
import '../../core/page_layout.dart';
import '../../widgets/layout_page_view.dart';



enum ExportFormat { pdf, word, txt, epub }

class DocumentEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? documentData;
  const DocumentEditorScreen({this.documentData, super.key});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen>
    with SingleTickerProviderStateMixin {
  final _canvasKey = GlobalKey<DocumentCanvasState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isStrikethrough = false;
  String _alignment = 'left';
  bool _isSaved = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String? _documentId;
  final FocusNode _bodyFocusNode = FocusNode();

  // Page size state
  PageSize _pageSize = PageSize.a4;
  PageMargin _pageMargin = PageMargin.normal;

  // Typography / color
  double _fontSize = 16;
  Color _textColor = const Color(0xFF1A1A1A);
  Color _bgColor = Colors.white;
  String _fontFamily = 'Roboto';

  // Header / footer
  String _headerText = '';
  String _footerText = '';
  bool _showPageNumbers = true;

  // Reading mode
  bool _readingMode = false;
  bool _focusMode = false;
  bool _manuscriptExport = false;
  int _sessionStartWords = 0;

  // Undo / Redo
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _applyingHistory = false;
  static const int _maxHistory = 50;

  /// Images shown in the document (path + width 0.3-1.0)
  final List<Map<String, dynamic>> _embeddedImages = [];
  DocumentSettings _docSettings = DocumentSettings();
  Timer? _autoSaveTimer;

  // Exact page layout (same engine as the PDF export).
  DocLayout? _layout;
  Timer? _layoutTimer;
  String _layoutSig = '';
  int _layoutGen = 0;

  LayoutSettings _layoutSettings() => LayoutSettings(
        pageSize: _pageSize,
        landscape: _docSettings.landscape,
        marginMm: _docSettings.marginMm,
        fontFamily: _docSettings.fontFamily,
        fontSize: _docSettings.fontSize,
        lineHeight: _docSettings.lineHeight,
        firstLineIndent: _docSettings.firstLineIndent,
        chapterNewPage: _docSettings.chapterNewPage,
        showPageNumbers: _showPageNumbers,
        pageNumberPos: _docSettings.pageNumberPos,
        pageNumberStyle: _docSettings.pageNumberStyle,
        pageNumberStartPage: _docSettings.pageNumberStartPage,
        pageNumberStartAt: _docSettings.pageNumberStartAt,
        headerText: _headerText,
        footerText: _footerText,
        title: _extractTitle(),
        author: _docSettings.author,
        subtitle: _docSettings.subtitle,
        pageBgColor: _docSettings.pageBgColor,
        pageFrame: _docSettings.pageFrame,
        textAlign: _alignment,
      );

  String _sigOf(LayoutSettings l, String text) => [
        l.pageSize, l.landscape, l.marginMm, l.fontFamily, l.fontSize, l.lineHeight,
        l.firstLineIndent, l.chapterNewPage, l.showPageNumbers, l.pageNumberPos,
        l.pageNumberStyle, l.pageNumberStartPage, l.pageNumberStartAt, l.headerText,
        l.footerText, l.title, l.author, l.subtitle, l.pageBgColor, l.pageFrame,
        l.textAlign, text.hashCode, text.length,
      ].join('|');

  /// Re-runs the page layout shortly after the text or settings change.
  void _scheduleLayout({bool now = false}) {
    final settings = _layoutSettings();
    final text = _bodyCtrl.text;
    final sig = _sigOf(settings, text);
    if (sig == _layoutSig) return;
    _layoutSig = sig;
    _layoutTimer?.cancel();
    _layoutTimer = Timer(Duration(milliseconds: now ? 0 : 350), () async {
      final gen = ++_layoutGen;
      try {
        final doc = await PageLayoutEngine(settings).layout(text);
        if (!mounted || gen != _layoutGen) return;
        setState(() => _layout = doc);
      } catch (e) {
        debugPrint('layout failed: $e');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((d) {
      MobileExportService.imageDir = d.path;
    });
    final data = widget.documentData;
    _documentId = data?['id'] as String?;
    _titleCtrl = TextEditingController(
      text: data != null ? data['title'] as String? ?? '' : '',
    );
    // Title lives in _titleCtrl. Body is document content only.
    // Older builds prepended title onto content on every open, which
    // duplicated the first line after each save.
    final existingTitle = data != null ? data['title'] as String? ?? '' : '';
    var existingContent = data != null
        ? data['content'] as String? ?? ''
        : '';
    if (existingTitle.isNotEmpty) {
      final lines = existingContent.split('\n');
      while (lines.length >= 2 &&
          lines[0].trim() == existingTitle.trim() &&
          lines[1].trim() == existingTitle.trim()) {
        lines.removeAt(0);
      }
      existingContent = lines.join('\n');
    }
    if (data != null && data['settings'] is Map) {
      _applySettingsMap(Map<String, dynamic>.from(data['settings'] as Map));
    }
    _recoverImagesFromContent(existingContent);
    _bodyCtrl = TextEditingController(text: existingContent);
    _bodyCtrl.addListener(_onBodyChanged);
    _titleCtrl.addListener(_onBodyChanged);
    _sessionStartWords = existingContent.trim().isEmpty
        ? 0
        : existingContent.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _layoutTimer?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  void _onBodyChanged() {
    if (_applyingHistory) return;
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
    }
    _pushHistory();
    _checkPageLimit();
    _scheduleAutoSave();
    _scheduleLayout();
  }

  DateTime _lastHistory = DateTime(2000);
  bool _historyClosed = true;

  void _pushHistory() {
    final text = _bodyCtrl.text;
    if (_undoStack.isNotEmpty && _undoStack.last == text) return;
    // Group a typing burst (letters of a word) into one undo step, like
    // Word/Docs: a pause, a space/new line, or a formatting action starts a
    // new step.
    final now = DateTime.now();
    final brk = _canvasKey.currentState?.takeHistoryBreak() ?? true;
    final prev = _undoStack.isNotEmpty ? _undoStack.last : '';
    final d = (text.length - prev.length).abs();
    final typedBoundary = text.length > prev.length && RegExp(r'\s$').hasMatch(_commonInsert(prev, text));
    final merge = _undoStack.length > 1 && !brk && !_historyClosed && d <= 2 &&
        now.difference(_lastHistory).inMilliseconds < 1200;
    _historyClosed = typedBoundary;
    _lastHistory = now;
    if (merge) {
      _undoStack[_undoStack.length - 1] = text;
      _redoStack.clear();
      return;
    }
    _undoStack.add(text);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Text inserted between [a] and [b] (common prefix/suffix removed).
  static String _commonInsert(String a, String b) {
    var p = 0;
    while (p < a.length && p < b.length && a.codeUnitAt(p) == b.codeUnitAt(p)) {
      p++;
    }
    var q = 0;
    while (q < a.length - p && q < b.length - p && a.codeUnitAt(a.length - 1 - q) == b.codeUnitAt(b.length - 1 - q)) {
      q++;
    }
    return b.substring(p, b.length - q);
  }

  void _undo() {
    if (_undoStack.length < 2) return;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final prev = _undoStack.last;
    _applyingHistory = true;
    _bodyCtrl.value = TextEditingValue(
      text: prev,
      selection: TextSelection.collapsed(offset: prev.length),
    );
    _applyingHistory = false;
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    _applyingHistory = true;
    _bodyCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _applyingHistory = false;
    setState(() {});
  }



  Map<String, dynamic> _settingsToMap() {
    return {
      'language': _docSettings.language,
      'pageSize': _docSettings.pageSize.name,
      'landscape': _docSettings.landscape,
      'marginMm': _docSettings.marginMm,
      'fontFamily': _docSettings.fontFamily,
      'fontSize': _docSettings.fontSize,
      'lineHeight': _docSettings.lineHeight,
      'showPageNumbers': _docSettings.showPageNumbers,
      'pageNumberPos': _docSettings.pageNumberPos,
      'headerText': _docSettings.headerText,
      'footerText': _docSettings.footerText,
      'autoSave': _docSettings.autoSave,
      'alignment': _alignment,
      'author': _docSettings.author,
      'subtitle': _docSettings.subtitle,
      'firstLineIndent': _docSettings.firstLineIndent,
      'chapterNewPage': _docSettings.chapterNewPage,
      'bookNotes': _docSettings.bookNotes,
      'wordGoal': _docSettings.wordGoal,
      'dailyGoal': _docSettings.dailyGoal,
      'genre': _docSettings.genre,
      'series': _docSettings.series,
      'isbn': _docSettings.isbn,
      'publisher': _docSettings.publisher,
      'pageNumberStartPage': _docSettings.pageNumberStartPage,
      'pageNumberStartAt': _docSettings.pageNumberStartAt,
      'pageBgColor': _docSettings.pageBgColor,
      'pageFrame': _docSettings.pageFrame,
      'pageNumberStyle': _docSettings.pageNumberStyle,
      'bookHeader': _docSettings.bookHeader,
    };
  }

  void _applySettingsMap(Map<String, dynamic>? m) {
    if (m == null) return;
    try {
      final sizeName = m['pageSize']?.toString() ?? 'a4';
      final size = PageSize.values.firstWhere(
        (e) => e.name == sizeName,
        orElse: () => PageSize.a4,
      );
      _docSettings = DocumentSettings(
        language: m['language']?.toString() ?? 'en',
        pageSize: size,
        landscape: m['landscape'] == true,
        marginMm: (m['marginMm'] is num) ? (m['marginMm'] as num).toDouble() : 20,
        fontFamily: m['fontFamily']?.toString() ?? 'Roboto',
        fontSize: (m['fontSize'] is num) ? (m['fontSize'] as num).toDouble() : 16,
        lineHeight: (m['lineHeight'] is num) ? (m['lineHeight'] as num).toDouble() : 1.7,
        showPageNumbers: m['showPageNumbers'] != false,
        pageNumberPos: m['pageNumberPos']?.toString() ?? 'bottom-center',
        headerText: m['headerText']?.toString() ?? '',
        footerText: m['footerText']?.toString() ?? '',
        autoSave: m['autoSave'] != false,
        author: m['author']?.toString() ?? '',
        subtitle: m['subtitle']?.toString() ?? '',
        firstLineIndent: m['firstLineIndent'] == true,
        chapterNewPage: m['chapterNewPage'] == true,
        bookNotes: m['bookNotes']?.toString() ?? '',
        wordGoal: (m['wordGoal'] is num) ? (m['wordGoal'] as num).toInt() : 50000,
        dailyGoal: (m['dailyGoal'] is num) ? (m['dailyGoal'] as num).toInt() : 1000,
        genre: m['genre']?.toString() ?? '',
        series: m['series']?.toString() ?? '',
        isbn: m['isbn']?.toString() ?? '',
        publisher: m['publisher']?.toString() ?? '',
        pageNumberStartPage: (m['pageNumberStartPage'] is num)
            ? (m['pageNumberStartPage'] as num).toInt()
            : 1,
        pageNumberStartAt: (m['pageNumberStartAt'] is num)
            ? (m['pageNumberStartAt'] as num).toInt()
            : 1,
        pageBgColor: (m['pageBgColor'] is num)
            ? (m['pageBgColor'] as num).toInt()
            : 0xFFFFFFFF,
        pageFrame: m['pageFrame'] == true,
        pageNumberStyle: m['pageNumberStyle']?.toString() ?? 'plain',
        bookHeader: m['bookHeader'] == true,
      );
      _pageSize = size;
      _fontSize = _docSettings.fontSize;
      _fontFamily = _docSettings.fontFamily;
      _showPageNumbers = _docSettings.showPageNumbers;
      _headerText = _docSettings.headerText;
      _footerText = _docSettings.footerText;
      _bgColor = Color(_docSettings.pageBgColor | 0xFF000000);
      if (m['alignment'] is String) _alignment = m['alignment'] as String;
    } catch (_) {}
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    if (!_docSettings.autoSave) return;
    _autoSaveTimer = Timer(const Duration(seconds: 8), () {
      if (_hasUnsavedChanges && mounted) {
        _saveDocument();
      }
    });
  }

  Future<void> _openDocumentSettings() async {
    final result = await showDocumentSettingsSheet(
      context,
      _docSettings,
      onOpenCover: () {
        Navigator.pop(context);
        _openCoverGallery();
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _docSettings = result;
      _pageSize = result.pageSize;
      _fontSize = result.fontSize;
      _fontFamily = result.fontFamily;
      _showPageNumbers = result.showPageNumbers;
      _headerText = result.headerText;
      _footerText = result.footerText;
      _bgColor = Color(result.pageBgColor | 0xFF000000);
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    _scheduleAutoSave();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t(
            az: 'Kitab ayarları yeniləndi',
            en: 'Book settings updated',
            ru: 'Настройки обновлены',
            ar: 'تم تحديث الإعدادات',
          )),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  double get _marginPx => _docSettings.marginMm * 96 / 25.4;
  double get _pageW =>
      _docSettings.landscape ? _pageSize.heightPx : _pageSize.widthPx;
  double get _pageH =>
      _docSettings.landscape ? _pageSize.widthPx : _pageSize.heightPx;

  int? _printedNumber(int physical) {
    if (!_showPageNumbers) return null;
    final start = _docSettings.pageNumberStartPage.clamp(1, 999);
    if (physical < start) return null;
    return _docSettings.pageNumberStartAt + (physical - start);
  }

  Widget _pageNumWidget(int? n, double scale) {
    if (n == null) return const SizedBox.shrink();
    final label = formatPageNumber(n, _docSettings.pageNumberStyle);
    final text = Text(
      label,
      style: TextStyle(
        fontFamily: 'LibreBaskerville',
        fontSize: (10 * scale).clamp(8.0, 13.0),
        color: const Color(0xFF1A1A1A),
      ),
    );
    if (pageNumberInOval(_docSettings.pageNumberStyle) ||
        _docSettings.bookHeader) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1A1A1A)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: text,
      );
    }
    return text;
  }

  Widget _bookHead(String title, int? n, double scale) {
    final arabic = RegExp(r'[\u0600-\u06FF]').hasMatch(title);
    final titleWidget = Expanded(
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: arabic ? TextAlign.right : TextAlign.center,
        style: TextStyle(
          fontFamily: 'LibreBaskerville',
          fontSize: (11 * scale).clamp(8.0, 13.0),
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (!arabic) _pageNumWidget(_docSettings.bookHeader ? n : null, scale),
            titleWidget,
            if (arabic) _pageNumWidget(_docSettings.bookHeader ? n : null, scale),
          ],
        ),
        SizedBox(height: _docSettings.bookHeader ? 3 : 2),
        Container(
          height: _docSettings.bookHeader ? 1.3 : 0.6,
          color: const Color(0xFF1A1A1A),
        ),
        if (_docSettings.bookHeader) ...[
          const SizedBox(height: 2),
          Container(height: 0.5, color: const Color(0xFF1A1A1A)),
        ],
      ],
    );
  }


  void _showFindReplace() {
    final findCtrl = TextEditingController();
    final replaceCtrl = TextEditingController();
    int lastIndex = 0;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            int countMatches() {
              final f = findCtrl.text;
              if (f.isEmpty) return 0;
              return RegExp(RegExp.escape(f), caseSensitive: false)
                  .allMatches(_bodyCtrl.text)
                  .length;
            }
            return AlertDialog(
              title: const Text('Find & Replace'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: findCtrl,
                    decoration: const InputDecoration(labelText: 'Find'),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  TextField(
                    controller: replaceCtrl,
                    decoration: const InputDecoration(labelText: 'Replace with'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      findCtrl.text.isEmpty
                          ? 'Enter text to search'
                          : '${countMatches()} match(es)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    final f = findCtrl.text;
                    if (f.isEmpty) return;
                    final text = _bodyCtrl.text;
                    final lower = text.toLowerCase();
                    final q = f.toLowerCase();
                    var i = lower.indexOf(q, lastIndex);
                    if (i < 0) i = lower.indexOf(q);
                    if (i < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tapılmadı')),
                      );
                      return;
                    }
                    lastIndex = i + f.length;
                    _bodyCtrl.selection = TextSelection(
                      baseOffset: i,
                      extentOffset: i + f.length,
                    );
                    _bodyFocusNode.requestFocus();
                    setLocal(() {});
                  },
                  child: const Text('Find next'),
                ),
                TextButton(
                  onPressed: () {
                    final f = findCtrl.text;
                    if (f.isEmpty) return;
                    final sel = _bodyCtrl.selection;
                    if (!sel.isValid || sel.isCollapsed) return;
                    final selected = _bodyCtrl.text.substring(sel.start, sel.end);
                    if (selected.toLowerCase() != f.toLowerCase()) return;
                    final newText = _bodyCtrl.text.replaceRange(
                      sel.start,
                      sel.end,
                      replaceCtrl.text,
                    );
                    _bodyCtrl.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(
                        offset: sel.start + replaceCtrl.text.length,
                      ),
                    );
                    setState(() {
                      _hasUnsavedChanges = true;
                      _isSaved = false;
                    });
                    setLocal(() {});
                  },
                  child: const Text('Replace'),
                ),
                FilledButton(
                  onPressed: () {
                    final f = findCtrl.text;
                    if (f.isEmpty) return;
                    final re = RegExp(RegExp.escape(f), caseSensitive: false);
                    final newText = _bodyCtrl.text.replaceAll(re, replaceCtrl.text);
                    _bodyCtrl.text = newText;
                    setState(() {
                      _hasUnsavedChanges = true;
                      _isSaved = false;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hamısı əvəz olundu')),
                    );
                  },
                  child: const Text('Replace all'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Strip heading / quote / list prefixes from a paragraph line.
  String _stripStylePrefix(String line) {
    var s = line;
    s = s.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
    s = s.replaceFirst(RegExp(r'^>\s*(\*\*Note:\*\*\s*)?'), '');
    s = s.replaceFirst(RegExp(r'^[•\-\*]\s+'), '');
    s = s.replaceFirst(RegExp(r'^\d+\.\s+'), '');
    return s;
  }

  void _applyStyle(String style) {
    if (_canvasKey.currentState?.lineStyleFocused(style) == true) {
      setState(() {
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      return;
    }
    _syncCursorFromCanvas();
    final text = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final pos = sel.isValid ? sel.start : text.length;
    // Work on whole paragraph
    var lineStart = pos <= 0 ? 0 : text.lastIndexOf('\n', pos - 1) + 1;
    var lineEnd = text.indexOf('\n', pos);
    if (lineEnd < 0) lineEnd = text.length;
    var line = text.substring(lineStart, lineEnd);
    final am = RegExp(r'^\[align=\w+\]').firstMatch(line);
    final alignPrefix = am?.group(0) ?? '';
    line = line.substring(alignPrefix.length);
    final body = _stripStylePrefix(line);

    String next;
    switch (style) {
      case 'h1':
      case 'chapter':
        next = '# ${body.isEmpty ? 'Chapter' : body}';
        break;
      case 'h2':
      case 'subchapter':
        next = '## ${body.isEmpty ? 'Section' : body}';
        break;
      case 'h3':
        next = '### ${body.isEmpty ? 'Subsection' : body}';
        break;
      case 'h4':
        next = '### ${body.isEmpty ? 'Title' : body}';
        break;
      case 'quote':
        next = '> $body';
        break;
      case 'note':
        next = '> **Note:** $body';
        break;
      case 'bullet':
        // Toggle: applying a bullet to a bullet line removes it.
        next = line.trimLeft().startsWith('• ') ? body : '• $body';
        break;
      case 'number':
        if (RegExp(r'^\s*\d+[.)] ').hasMatch(line)) {
          next = body;
        } else {
          // Continue numbering from the line above.
          final prevEnd = lineStart > 0 ? lineStart - 1 : 0;
          final prevStart = prevEnd <= 0 ? 0 : text.lastIndexOf('\n', prevEnd - 1) + 1;
          final prev = lineStart > 0 ? text.substring(prevStart, prevEnd) : '';
          final n = int.tryParse(RegExp(r'^\s*(\d+)[.)] ').firstMatch(prev)?.group(1) ?? '') ?? 0;
          next = '${n + 1}. $body';
        }
        break;
      case 'caption':
        next = '[align=center]*${body.isEmpty ? 'Caption' : body}*';
        break;
      case 'normal':
        next = body;
        break;
      default:
        next = body;
    }

    // Headings are centred by the layout; drop alignment for them.
    if (!next.startsWith('#')) next = alignPrefix + next;
    final newText = text.replaceRange(lineStart, lineEnd, next);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + next.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    _bodyFocusNode.requestFocus();
  }

  void _showStylesSheet() {
    final items = <Map<String, String>>[
      {'id': 'h1', 'label': 'Heading 1', 'sample': '# Title'},
      {'id': 'h2', 'label': 'Heading 2', 'sample': '## Section'},
      {'id': 'h3', 'label': 'Heading 3', 'sample': '### Subsection'},
      {'id': 'h4', 'label': 'Heading 4', 'sample': '#### Minor'},
      {'id': 'normal', 'label': 'Normal text', 'sample': 'Paragraph'},
      {'id': 'quote', 'label': 'Quote', 'sample': '> Quoted text'},
      {'id': 'note', 'label': 'Note', 'sample': '> **Note:** …'},
      {'id': 'caption', 'label': 'Caption', 'sample': '_Figure caption_'},
      {'id': 'bullet', 'label': 'Bullet list', 'sample': '• Item'},
      {'id': 'number', 'label': 'Numbered list', 'sample': '1. Item'},
    ];
    showDarkSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Styles',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  return ListTile(
                    title: Text(
                      it['label']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      it['sample']!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _applyStyle(it['id']!);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }



  void _transformCase(String mode) {
    _syncCursorFromCanvas();
    final sel = _bodyCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Əvvəl mətni seçin')),
      );
      return;
    }
    final s = TextCase.apply(_bodyCtrl.text.substring(sel.start, sel.end), mode,
        turkic: AppLocalizations.of(context).locale.languageCode == 'az');
    final newText = _bodyCtrl.text.replaceRange(sel.start, sel.end, s);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + s.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _showChaptersPanel() {
    showDarkSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final full = _bodyCtrl.text;
            final chapters = BookStructure.parse(full);
            final totalWords = full
                .trim()
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length;
            final totalPages = (totalWords / 250).ceil().clamp(1, 999999);

            int wordsOf(BookSection sec) {
              final body = full.substring(sec.start, sec.end);
              return body
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .length;
            }

            void apply(String next) {
              _applyBookText(next);
              setLocal(() {});
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fəsillər (${chapters.length})',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '$totalWords söz · ~$totalPages səh · ~${(totalWords / 200).ceil()} dəq',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_list_numbered,
                                color: Colors.white),
                            tooltip: 'Nömrələ',
                            onPressed: () =>
                                apply(BookStructure.renumber(_bodyCtrl.text)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            tooltip: 'Fəsil əlavə et',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _insertChapterHeading();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: chapters.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Hələ fəsil yoxdur.\n+ və ya Insert → Fəsil.',
                                  textAlign: TextAlign.center,
                                  style:
                                      GoogleFonts.dmSans(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: chapters.length,
                              itemBuilder: (_, i) {
                                final c = chapters[i];
                                final level = c.level;
                                final pad = 8.0 + (level - 1) * 12.0;
                                final words = wordsOf(c);
                                return ListTile(
                                  contentPadding: EdgeInsets.only(
                                    left: pad,
                                    right: 8,
                                  ),
                                  leading: Icon(
                                    level == 1
                                        ? Icons.menu_book
                                        : level == 2
                                            ? Icons.subdirectory_arrow_right
                                            : Icons.circle,
                                    size: level >= 3 ? 10 : 22,
                                    color: const Color(0xFFD4A84B),
                                  ),
                                  title: Text(
                                    c.title,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontWeight: level == 1
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'H$level · $words söz · ~${(words / 250).toStringAsFixed(1)} s',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _bodyCtrl.selection =
                                        TextSelection.collapsed(offset: c.start);
                                    _bodyFocusNode.requestFocus();
                                  },
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.white54),
                                    color: const Color(0xFF1E1E1E),
                                    onSelected: (action) {
                                      if (action == 'rename') {
                                        final ctrl = TextEditingController(
                                          text: c.title,
                                        );
                                        showDialog(
                                          context: context,
                                          builder: (dctx) => AlertDialog(
                                            title: const Text('Adı dəyiş'),
                                            content:
                                                TextField(controller: ctrl),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dctx),
                                                child: const Text('Ləğv'),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  Navigator.pop(dctx);
                                                  apply(BookStructure.rename(
                                                    _bodyCtrl.text,
                                                    i,
                                                    ctrl.text,
                                                  ));
                                                },
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else if (action == 'delete') {
                                        apply(BookStructure.delete(
                                            _bodyCtrl.text, i));
                                      } else if (action == 'up') {
                                        apply(BookStructure.move(
                                            _bodyCtrl.text, i, -1));
                                      } else if (action == 'down') {
                                        apply(BookStructure.move(
                                            _bodyCtrl.text, i, 1));
                                      } else if (action == 'duplicate') {
                                        apply(BookStructure.duplicate(
                                            _bodyCtrl.text, i));
                                      } else if (action == 'sub') {
                                        apply(BookStructure.changeLevel(
                                            _bodyCtrl.text, i, 1));
                                      } else if (action == 'promote') {
                                        apply(BookStructure.changeLevel(
                                            _bodyCtrl.text, i, -1));
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'rename',
                                          child: Text('Adı dəyiş',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'duplicate',
                                          child: Text(
                                              'Fəsili köçür (mətn daxil)',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'promote',
                                          child: Text('Səviyyə qaldır (H−)',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'sub',
                                          child: Text('Səviyyə endir (H+)',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'up',
                                          child: Text('Yuxarı (bütün fəsil)',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'down',
                                          child: Text('Aşağı (bütün fəsil)',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                              'Fəsili sil (mətn daxil)',
                                              style: TextStyle(
                                                  color: Colors.redAccent))),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _insertTableOfContents();
                              },
                              icon: const Icon(Icons.list_alt),
                              label: const Text('Mündəricat'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _insertChapterHeading();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Fəsil'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2B5CE6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _recoverImagesFromContent(String content) {
    final re = RegExp(
      r'\[img path="([^"]+)" w=([0-9.]+)(?: align=(left|center|right))?(?: caption="([^"]*)")?\]',
    );
    for (final m in re.allMatches(content)) {
      final path = m.group(1)!;
      final w = double.tryParse(m.group(2) ?? '0.85') ?? 0.85;
      final align = m.group(3) ?? 'center';
      final caption = m.group(4) ?? '';
      if (_embeddedImages.any((e) => e['path'] == path)) continue;
      _embeddedImages.add({
        'path': path,
        'width': w,
        'align': align,
        'caption': caption,
      });
    }
  }

  String _imgMarkup(Map<String, dynamic> img) {
    final path = img['path'];
    final w = (img['width'] as num?)?.toDouble() ?? 0.85;
    final align = img['align']?.toString() ?? 'center';
    final caption = img['caption']?.toString() ?? '';
    var s = '[img path="$path" w=${w.toStringAsFixed(2)} align=$align';
    if (caption.isNotEmpty) {
      s += ' caption="${caption.replaceAll('"', "'")}"';
    }
    s += ']';
    return s;
  }

  Future<void> _editImageAt(int idx) async {
    if (idx < 0 || idx >= _embeddedImages.length) return;
    final img = _embeddedImages[idx];
    final path = img['path'] as String;
    final result = await ImageInsertDialog.show(
      context,
      path,
      width: (img['width'] as num?)?.toDouble() ?? 0.85,
      caption: img['caption']?.toString() ?? '',
      align: img['align']?.toString() ?? 'center',
      editing: true,
    );
    if (result == null) return;
    final oldMarkup = _imgMarkup(img);
    setState(() {
      _embeddedImages[idx] = {
        'path': result.path,
        'width': result.widthFactor,
        'align': result.align,
        'caption': result.caption,
      };
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    final newMarkup = _imgMarkup(_embeddedImages[idx]);
    if (_bodyCtrl.text.contains(oldMarkup)) {
      _bodyCtrl.text = _bodyCtrl.text.replaceFirst(oldMarkup, newMarkup);
    } else {
      // fuzzy: replace by path only
      final re = RegExp(r'\[img path="' + RegExp.escape(path) + r'"[^\]]*\]');
      _bodyCtrl.text = _bodyCtrl.text.replaceFirst(re, newMarkup);
    }
  }

  void _deleteImageAt(int idx) {
    if (idx < 0 || idx >= _embeddedImages.length) return;
    final img = _embeddedImages[idx];
    final path = img['path'] as String;
    final markup = _imgMarkup(img);
    var text = _bodyCtrl.text;
    if (text.contains(markup)) {
      text = text.replaceFirst(markup, '');
    } else {
      text = text.replaceFirst(
        RegExp(r'\[img path="' + RegExp.escape(path) + r'"[^\]]*\]'),
        '',
      );
    }
    _bodyCtrl.text = text;
    setState(() {
      _embeddedImages.removeAt(idx);
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  /// The canvas edits paragraphs in their own controllers; copy its cursor
  /// into [_bodyCtrl] so "insert at cursor" really inserts at the cursor.
  void _syncCursorFromCanvas() {
    final st = _canvasKey.currentState;
    if (st == null) return;
    final gs = st.globalSelection();
    if (gs == null) return;
    final ser = st.serialized();
    final sel = TextSelection(
      baseOffset: gs.baseOffset.clamp(0, ser.length),
      extentOffset: gs.extentOffset.clamp(0, ser.length),
    );
    _applyingHistory = true;
    if (ser != _bodyCtrl.text) {
      _bodyCtrl.value = TextEditingValue(text: ser, selection: sel);
    } else {
      _bodyCtrl.selection = sel;
    }
    _applyingHistory = false;
  }

  void _insertAtCursor(String snippet) {
    _syncCursorFromCanvas();
    final text = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, snippet);
    final newOffset = start + snippet.length;
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  /// Strip existing size/color/bg markers from a fragment (inner only).
  String _stripInlineMarkers(String s) {
    s = s.replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/color]', '');
    s = s.replaceAll(RegExp(r'\[bg=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/bg]', '');
    s = s.replaceAll(RegExp(r'\[size=\d+\]'), '');
    s = s.replaceAll('[/size]', '');
    return s;
  }

  /// Color on selection, or (if nothing selected) on the next typed text.
  void _applyColorToSelection(Color color, {required bool background}) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final open = background ? '[bg=$hex]' : '[color=$hex]';
    final close = background ? '[/bg]' : '[/color]';
    if (_canvasKey.currentState?.formatFocused(FormatOp(background ? 'bg' : 'color', hex)) == true) {
      setState(() {
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      return;
    }
    int start;
    int end;
    String inner;
    if (!sel.isValid) {
      start = text.length;
      end = text.length;
      inner = '';
    } else if (sel.isCollapsed) {
      start = sel.start.clamp(0, text.length);
      end = start;
      inner = '';
    } else {
      start = sel.start.clamp(0, text.length);
      end = sel.end.clamp(0, text.length);
      if (end < start) {
        final t = start;
        start = end;
        end = t;
      }
      inner = _stripInlineMarkers(text.substring(start, end));
    }

    final wrapped = '$open$inner$close';
    final newText = text.replaceRange(start, end, wrapped);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: inner.isEmpty
          ? TextSelection.collapsed(offset: start + open.length)
          : TextSelection(
              baseOffset: start,
              extentOffset: start + wrapped.length,
            ),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
      if (!background) _textColor = color;
    });
  }

  /// Font size only on selection: [size=18]text[/size]
  void _applySizeToSelection(double size) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final sz = size.round().clamp(10, 48);
    if (_canvasKey.currentState?.formatFocused(FormatOp('size', sz)) ?? false) {
      _markDirty();
      return;
    }
    if (!sel.isValid || sel.isCollapsed) {
      setState(() => _fontSize = size);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Editor default size: $sz. Select text to change only that part.',
            style: GoogleFonts.dmSans(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final start = sel.start;
    final end = sel.end;
    var selected = _stripInlineMarkers(text.substring(start, end));
    final wrapped = '[size=$sz]$selected[/size]';
    final newText = text.replaceRange(start, end, wrapped);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + wrapped.length,
      ),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ölçü $sz seçilənə tətbiq olundu', style: GoogleFonts.dmSans()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearSelectionFormat() {
    if (_canvasKey.currentState?.formatFocused(const FormatOp('clear')) ?? false) {
      _markDirty();
      return;
    }
    final sel = _bodyCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formatı silmək üçün mətni seçin')),
      );
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final cleaned = _stripInlineMarkers(_bodyCtrl.text.substring(start, end));
    // also light markdown
    var s = cleaned;
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m.group(1)!);
    final newText = _bodyCtrl.text.replaceRange(start, end, s);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: start, extentOffset: start + s.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }


  void _toggleReadingMode() {
    setState(() {
      _readingMode = !_readingMode;
      if (_readingMode) _focusMode = false;
    });
  }

  void _markDirty() {
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _toggleFocusMode() {
    setState(() {
      _focusMode = !_focusMode;
      if (_focusMode) _readingMode = false;
    });
  }

  bool _pageLimitDialogOpen = false;

  Future<void> _checkPageLimit() async {
    if (!PremiumService.billingEnabled) return; // no limits until billing is live
    // Estimate pages from text length vs page body (same idea as indicator)
    final text = _bodyCtrl.text.isEmpty ? ' ' : _bodyCtrl.text;
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32;
    final scale = availableWidth / _pageSize.widthPx;
    final pageDisplayHeight = _pageSize.heightPx * scale;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: _fontSize, height: _docSettings.lineHeight),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: availableWidth - 64);
    final contentHeight = tp.height + 56;
    final pages = (contentHeight / pageDisplayHeight).ceil().clamp(1, 999999);

    final maxP = await PremiumService.maxPages();
    final near = await PremiumService.isNearPageLimit(pages);
    final over = pages > maxP;

    if (!mounted) return;
    if (over && !_pageLimitDialogOpen) {
      _pageLimitDialogOpen = true;
      final tier = await PremiumService.currentTier();
      final msg = tier == PlanTier.free
          ? 'This document is over ${PremiumService.maxPagesFree} pages (Free limit). Pro (2.75 USD/mo): up to 150 pages. Elite (5.75 USD/mo): unlimited length. You can still read and export; upgrade to keep writing longer books.'
          : tier == PlanTier.pro
              ? 'Pro allows up to ${PremiumService.maxPagesPro} pages. Elite (5.75 USD/mo) removes the page limit for long books.'
              : 'Page limit reached.';
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Page limit'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.subscriptionPlanScreen);
              },
              child: const Text('View plans'),
            ),
          ],
        ),
      );
      _pageLimitDialogOpen = false;
    } else if (near && !over && mounted) {
      // Soft toast once in a while — use SnackBar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approaching page limit ($pages / $maxP). Consider Pro for longer books.',
            style: GoogleFonts.dmSans(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    _syncCursorFromCanvas();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(AppLocalizations.of(ctx).t(
                az: 'Qalereya',
                en: 'Gallery',
                ru: 'Галерея',
                ar: 'المعرض',
              )),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(AppLocalizations.of(ctx).t(
                az: 'Kamera',
                en: 'Camera',
                ru: 'Камера',
                ar: 'الكاميرا',
              )),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (file == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final name =
          'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(file.path).copy('${dir.path}/$name');

      if (!mounted) return;
      final result = await ImageInsertDialog.show(context, saved.path);
      if (result == null) return;

      final entry = {
        'path': result.path,
        'width': result.widthFactor,
        'align': result.align,
        'caption': result.caption,
      };
      setState(() {
        _embeddedImages.removeWhere((e) => e['path'] == result.path);
        _embeddedImages.add(entry);
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      _insertAtCursor('\n${_imgMarkup(entry)}\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image inserted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, st) {
      debugPrint("Error: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şəkil seçilmədi. Yenidən cəhd edin.')),
        );
      }
    }
  }

  Future<void> _insertLink() async {
    _syncCursorFromCanvas();
    final sel = _bodyCtrl.selection;
    var selected = '';
    if (sel.isValid && !sel.isCollapsed) {
      selected = _bodyCtrl.text.substring(sel.start, sel.end);
    }
    final md = await LinkInsertDialog.show(context, selected: selected);
    if (md == null || md.isEmpty) return;
    _insertAtCursor(md);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link inserted'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _insertTable({int rows = 3, int cols = 3}) async {
    _syncCursorFromCanvas();
    // If cursor is inside an existing [TABLE] block → edit it
    final cursor = _bodyCtrl.selection.isValid
        ? _bodyCtrl.selection.start
        : _bodyCtrl.text.length;
    final existing = TableBlock.findAt(_bodyCtrl.text, cursor);
    if (existing != null) {
      final md = await TableEditorDialog.show(
        context,
        data: existing.cells,
        widths: existing.colWidths,
        caption: existing.caption,
        aligns: existing.colAligns,
        header: existing.header,
        editing: true,
      );
      if (md == null || md.isEmpty) return;
      final newText = _bodyCtrl.text.replaceRange(existing.start, existing.end, md.trim());
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: existing.start + md.trim().length),
      );
      setState(() {
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Table updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final size = await showTableSizePicker(context);
    if (size == null) return;
    if (size.openCustomEditor) {
      final md = await TableEditorDialog.show(
        context,
        rows: size.rows,
        cols: size.cols,
      );
      if (md == null || md.isEmpty) return;
      _insertAtCursor(md.startsWith('\n') ? md : '\n$md\n');
      _toast('Cədvəl daxil edildi — xanalara birbaşa yazın');
      return;
    }
    _insertVisualTable(rows: size.rows, cols: size.cols);
  }


  static final RegExp _tocBlockRe = RegExp(
    r'\[TOC[^\]]*\][\s\S]*?\[/TOC\]',
    multiLine: true,
  );

  /// Build TOC body from headings (excludes existing TOC titles).
  String _buildTocBody({int maxLevel = 3}) {
    final lines = _bodyCtrl.text.split('\n');
    final buf = StringBuffer();
    var n = 0;
    for (final line in lines) {
      final tline = line.trim();
      if (tline.toLowerCase().contains('table of contents')) continue;
      if (tline == '[TOC]' || tline == '[/TOC]') continue;
      if (tline.startsWith('# ') && !tline.startsWith('## ')) {
        if (maxLevel >= 1) {
          n++;
          buf.writeln('$n. ${tline.substring(2).trim()}');
        }
      } else if (tline.startsWith('## ') && !tline.startsWith('### ')) {
        if (maxLevel >= 2) {
          buf.writeln('   - ${tline.substring(3).trim()}');
        }
      } else if (tline.startsWith('### ') && !tline.startsWith('#### ')) {
        if (maxLevel >= 3) {
          buf.writeln('      · ${tline.substring(4).trim()}');
        }
      } else if (tline.startsWith('#### ') && maxLevel >= 4) {
        buf.writeln('         · ${tline.substring(5).trim()}');
      }
    }
    if (n == 0 && buf.isEmpty) {
      buf.writeln('_No headings yet. Add Heading 1 chapters first._');
    }
    return buf.toString().trimRight();
  }

  String _wrapToc(String body) {
    return '\n[TOC]\n# Table of Contents\n\n$body\n[/TOC]\n';
  }

  void _insertTableOfContents({int maxLevel = 3, bool ask = true}) {
    _syncCursorFromCanvas();
    if (ask) {
      _showTocOptions();
      return;
    }
    final toc = '${TocSpec.marker(TocSpec.defaultTitle, maxLevel)}\n\n';
    var text = _bodyCtrl.text;
    final has = _tocBlockRe.hasMatch(text);
    // Also remove legacy "# Table of Contents" blocks without markers
    final legacy = RegExp(
      r'\n# Table of Contents\n(?:.*\n)*?(?=\n# |\n## |\Z)',
      multiLine: true,
    );
    text = text.replaceAll(_tocBlockRe, '');
    text = text.replaceFirst(legacy, '\n');
    final newText = toc + text.trimLeft();
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: toc.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(has ? 'Table of Contents updated' : 'Table of Contents inserted'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _refreshTableOfContents() {
    if (!_tocBlockRe.hasMatch(_bodyCtrl.text) &&
        !_bodyCtrl.text.contains('# Table of Contents')) {
      _insertTableOfContents(ask: false);
      return;
    }
    _insertTableOfContents(ask: false);
  }

  void _deleteTableOfContents() {
    var text = _bodyCtrl.text;
    text = text.replaceAll(_tocBlockRe, '');
    text = text.replaceFirst(
      RegExp(r'\n# Table of Contents\n(?:.*\n)*?(?=\n# |\n## |\Z)', multiLine: true),
      '\n',
    );
    _bodyCtrl.text = text;
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TOC removed'), duration: Duration(seconds: 1)),
    );
  }

  void _showTocOptions() {
    final has = _tocBlockRe.hasMatch(_bodyCtrl.text) ||
        _bodyCtrl.text.contains('# Table of Contents');
    showDarkSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Table of Contents',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white70),
              title: Text(
                has ? 'Refresh TOC' : 'Insert TOC',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                has ? 'Update from current headings' : 'H1–H3 at top of document',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _insertTableOfContents(maxLevel: 3, ask: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_1, color: Colors.white70),
              title: const Text('TOC — chapters only (H1)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _insertTableOfContents(maxLevel: 1, ask: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_2, color: Colors.white70),
              title: const Text('TOC — H1 + H2',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _insertTableOfContents(maxLevel: 2, ask: false);
              },
            ),
            if (has)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete TOC',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteTableOfContents();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }




  void _showHeaderFooterDialog() {
    final headerCtrl = TextEditingController(text: _headerText);
    final footerCtrl = TextEditingController(text: _footerText);
    showDarkSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Header & Footer',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quick fill',
                      style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Book title'),
                          onPressed: () {
                            final title = _titleCtrl.text.trim().isNotEmpty
                                ? _titleCtrl.text.trim()
                                : _extractTitle();
                            headerCtrl.text = title;
                            setLocal(() {});
                          },
                        ),
                        ActionChip(
                          label: const Text('Chapter'),
                          onPressed: () {
                            // nearest H1 above cursor
                            final pos = _bodyCtrl.selection.isValid
                                ? _bodyCtrl.selection.start
                                : 0;
                            final before = _bodyCtrl.text.substring(0, pos);
                            final lines = before.split('\n').reversed;
                            String ch = 'Chapter';
                            for (final line in lines) {
                              if (line.startsWith('# ')) {
                                ch = line.substring(2).trim();
                                break;
                              }
                            }
                            headerCtrl.text = ch;
                            setLocal(() {});
                          },
                        ),
                        ActionChip(
                          label: const Text('Author'),
                          onPressed: () {
                            headerCtrl.text = 'Author Name';
                            setLocal(() {});
                          },
                        ),
                        ActionChip(
                          label: const Text('Date'),
                          onPressed: () {
                            final d = DateTime.now();
                            footerCtrl.text =
                                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                            setLocal(() {});
                          },
                        ),
                        ActionChip(
                          label: const Text('Title · Chapter'),
                          onPressed: () {
                            final title = _titleCtrl.text.trim().isNotEmpty
                                ? _titleCtrl.text.trim()
                                : 'Nibras Docs';
                            final pos = _bodyCtrl.selection.isValid
                                ? _bodyCtrl.selection.start
                                : 0;
                            final before = _bodyCtrl.text.substring(0, pos);
                            String ch = '';
                            for (final line in before.split('\n').reversed) {
                              if (line.startsWith('# ')) {
                                ch = line.substring(2).trim();
                                break;
                              }
                            }
                            headerCtrl.text =
                                ch.isEmpty ? title : '$title · $ch';
                            setLocal(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: headerCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Header (top of page)',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'Book title / chapter / author',
                        hintStyle: TextStyle(color: Colors.white30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: footerCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Footer (bottom of page)',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'Author / date / custom',
                        hintStyle: TextStyle(color: Colors.white30),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Page numbers',
                          style: TextStyle(color: Colors.white)),
                      value: _showPageNumbers,
                      onChanged: (v) => setLocal(() {
                        _showPageNumbers = v;
                      }),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _headerText = headerCtrl.text.trim();
                            _footerText = footerCtrl.text.trim();
                            _docSettings.headerText = _headerText;
                            _docSettings.footerText = _footerText;
                            _docSettings.showPageNumbers = _showPageNumbers;
                            _hasUnsavedChanges = true;
                            _isSaved = false;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Üst və alt qeyd saxlanıldı'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2B5CE6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Apply',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _showMarginsPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Page margins')),
              ...PageMargin.values.map((m) {
                return ListTile(
                  title: Text(m.label),
                  trailing: _pageMargin == m
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() => _pageMargin = m);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }



  void _applyBookText(String next, {int? cursor}) {
    if (next == _bodyCtrl.text) return;
    final off = (cursor ?? 0).clamp(0, next.length);
    _bodyCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: off),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  String get _chapterWord {
    switch (_docSettings.language) {
      case 'az':
        return 'Fəsil';
      case 'ru':
        return 'Глава';
      case 'ar':
        return 'فصل';
      default:
        return 'Chapter';
    }
  }

  String get _partWord {
    switch (_docSettings.language) {
      case 'az':
        return 'Hissə';
      case 'ru':
        return 'Часть';
      default:
        return 'Part';
    }
  }

  String _exportSource() {
    if (!_manuscriptExport) return _bodyCtrl.text;
    return BookStructure.toManuscript(_bodyCtrl.text);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _replaceRange(int start, int end, String md) {
    final newText = _bodyCtrl.text.replaceRange(start, end, md);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + md.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _insertVisualTable({
    required int rows,
    required int cols,
    List<String>? headers,
    String caption = '',
  }) {
    final markup = TableBlock.markupFrom(
      rows: rows,
      cols: cols,
      headers: headers,
      caption: caption,
    );
    _insertAtCursor('\n$markup\n');
    _toast('Cədvəl daxil edildi — xanalara birbaşa yazın');
  }

  void _insertPresetTable({
    required List<String> headers,
    required String caption,
    int dataRows = 6,
  }) {
    _insertVisualTable(
      rows: dataRows + 1,
      cols: headers.length,
      headers: headers,
      caption: caption,
    );
  }

  void _deleteTableAt(int index) {
    final all = TableBlock.allIn(_bodyCtrl.text);
    if (index < 0 || index >= all.length) return;
    final t = all[index];
    _bodyCtrl.value = TextEditingValue(
      text: _bodyCtrl.text.replaceRange(t.start, t.end, ''),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  Future<void> _editTableAt(int index) async {
    final all = TableBlock.allIn(_bodyCtrl.text);
    if (index < 0 || index >= all.length) {
      await _insertTable();
      return;
    }
    final existing = all[index];
    final md = await TableEditorDialog.show(
      context,
      data: existing.cells,
      widths: existing.colWidths,
      caption: existing.caption,
      aligns: existing.colAligns,
      header: existing.header,
      editing: true,
    );
    if (md == null || md.isEmpty) return;
    _replaceRange(existing.start, existing.end, md.trim());
  }

  TextStyle _editorTextStyle() {
    final family = switch (_docSettings.fontFamily) {
      'Lora' => 'Lora',
      'Roboto' || 'Arial' => 'DMSans',
      _ => 'LibreBaskerville',
    };
    final ink = _bgColor.computeLuminance() < 0.4
        ? const Color(0xFFF5F0E6)
        : const Color(0xFF1A1A1A);
    return TextStyle(
      fontFamily: family,
      fontSize: _fontSize,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      color: ink,
      height: _docSettings.lineHeight,
    );
  }

  String _plainForPages(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/color]', '');
    s = s.replaceAll(RegExp(r'\[bg=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/bg]', '');
    s = s.replaceAll(RegExp(r'\[align=(?:left|center|right|justify)\]'), '');
    s = s.replaceAll(RegExp(r'\[TABLE\][\s\S]*?\[/TABLE\]'), '\n\n');
    s = s.replaceAll(RegExp(r'\[img[^\]]*\]'), '\n\n');
    s = s.replaceAll(RegExp(r'\[COVER[^\]]*\]'), '\n\n');
    s = s.replaceAll(RegExp(r'\[note\][\s\S]*?\[/note\]'), '\n');
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1) ?? '');
    return s;
  }

  void _insertSceneBreak() {
    _insertAtCursor('\n\n* * *\n\n');
  }

  Future<void> _insertMarginNote() async {
    _syncCursorFromCanvas();
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Haşiyə'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Kənar qeyd yazın…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ləğv'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Əlavə et'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty) return;
    _insertAtCursor('\n[note]$text[/note]\n');
  }

  void _insertTitlePage() {
    _openCoverGallery();
  }

  Future<void> _openCoverGallery() async {
    final existing = CoverData.parse(_bodyCtrl.text);
    final data = await showCoverGallery(
      context: context,
      pageSize: _pageSize,
      landscape: _docSettings.landscape,
      initial: existing ??
          CoverData(
            templateId: 'classic',
            title: CoverData.brandTitle,
            subtitle: CoverData.cleanText(_docSettings.subtitle),
            author: CoverData.cleanText(_docSettings.author),
            publisher: CoverData.cleanText(_docSettings.publisher),
          ),
    );
    if (data == null || !mounted) return;
    _applyCover(data);
  }

  void _applyCover(CoverData data) {
    _docSettings.author = data.author;
    _docSettings.subtitle = data.subtitle;
    _docSettings.publisher = data.publisher;
    var body = _bodyCtrl.text.replaceAll(RegExp(r'\[COVER[^\]]*\]\s*'), '');
    body = body.replaceFirst(RegExp(r'^\s*--- Page Break ---\s*'), '');
    final block = '${data.toMarkup()}\n\n--- Page Break ---\n\n';
    _bodyCtrl.value = TextEditingValue(
      text: block + body,
      selection: const TextSelection.collapsed(offset: 0),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _setPageBackground(Color color) {
    setState(() {
      _bgColor = color;
      _docSettings.pageBgColor = color.toARGB32();
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  String _l(String az, String en, String ru, String ar) =>
      AppLocalizations.of(context).t(az: az, en: en, ru: ru, ar: ar);

  /// Small two-field prompt (text + optional second line).
  Future<(String, String)?> _askTwo(String title, String hint1, String hint2) async {
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: a, autofocus: true, maxLines: 3, decoration: InputDecoration(hintText: hint1)),
          if (hint2.isNotEmpty) TextField(controller: b, decoration: InputDecoration(hintText: hint2)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_l('Ləğv', 'Cancel', 'Отмена', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_l('Əlavə et', 'Insert', 'Вставить', 'إدراج'))),
        ],
      ),
    );
    final r = (a.text.trim().replaceAll('\n', ' '), b.text.trim());
    a.dispose();
    b.dispose();
    return ok == true && r.$1.isNotEmpty ? r : null;
  }

  /// Dedication: centred italic text on its own page (no heading, like
  /// printed books).
  Future<void> _insertDedication() async {
    _syncCursorFromCanvas();
    final r = await _askTwo(_l('İthaf', 'Dedication', 'Посвящение', 'إهداء'),
        _l('Məsələn: Anama', 'e.g. For my mother', 'Например: Маме', 'مثال: إلى أمي'), '');
    if (r == null) return;
    _insertAtCursor('\n\n[align=center]*${r.$1}*\n\n--- Page Break ---\n\n');
  }

  /// Epigraph: right-aligned quotation with its source.
  Future<void> _insertEpigraph() async {
    _syncCursorFromCanvas();
    final r = await _askTwo(_l('Epiqraf', 'Epigraph', 'Эпиграф', 'تصدير'),
        _l('Sitat', 'Quotation', 'Цитата', 'الاقتباس'), _l('Müəllif, əsər', 'Author, work', 'Автор, произведение', 'المؤلف، العمل'));
    if (r == null) return;
    final src = r.$2.isEmpty ? '' : '\n[align=right]> — ${r.$2}';
    _insertAtCursor('\n\n[align=right]> “${r.$1}”$src\n\n--- Page Break ---\n\n');
  }

  void _insertPart() {
    _syncCursorFromCanvas();
    final n = RegExp(r'^# (Part|Hissə|Часть) ', multiLine: true)
            .allMatches(_bodyCtrl.text)
            .length +
        1;
    final prefix =
        _docSettings.chapterNewPage ? '\n\n--- Page Break ---\n\n' : '\n\n';
    _insertAtCursor('$prefix# $_partWord $n\n\n');
  }

  void _insertChapterHeading() {
    _syncCursorFromCanvas();
    final n = RegExp(r'^# (Chapter|Fəsil|Глава|فصل) ', multiLine: true)
            .allMatches(_bodyCtrl.text)
            .length +
        1;
    final prefix =
        _docSettings.chapterNewPage ? '\n\n--- Page Break ---\n\n' : '\n\n';
    _insertAtCursor('$prefix# $_chapterWord $n — \n\n');
  }

  void _renumberChapters() {
    _applyBookText(BookStructure.renumber(_bodyCtrl.text));
    _toast('Fəsillər nömrələndi');
  }

  void _splitChapterAtCursor() {
    _syncCursorFromCanvas();
    final cursor = _bodyCtrl.selection.isValid
        ? _bodyCtrl.selection.start
        : _bodyCtrl.text.length;
    _applyBookText(
      BookStructure.splitAt(_bodyCtrl.text, cursor, label: _chapterWord),
      cursor: cursor + 8,
    );
    _toast('Fəsil kursor yerindən bölündü');
  }

  Future<void> _insertFootnote() async {
    _syncCursorFromCanvas();
    // Next free number (each note appears twice: marker + definition).
    final n = RegExp(r'\[\^(\d+)\]')
            .allMatches(_bodyCtrl.text)
            .map((m) => int.parse(m.group(1)!))
            .fold<int>(0, (a, b) => b > a ? b : a) +
        1;
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Qeyd [^$n]'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'İzah / mənbə'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ləğv'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Daxil et'),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    _insertAtCursor('[^$n]');
    _bodyCtrl.text = '${_bodyCtrl.text}\n[^$n]: $note\n';
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _showBookNotes() {
    final ctrl = TextEditingController(
      text: _docSettings.bookNotes.isEmpty
          ? 'Personajlar:\n- \n\nMəkanlar:\n- \n\nSüjet:\n- \n'
          : _docSettings.bookNotes,
    );
    showDarkSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Kitab dəftəri',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _docSettings.bookNotes = ctrl.text;
                        Navigator.pop(ctx);
                        setState(() {
                          _hasUnsavedChanges = true;
                        });
                      },
                      child: const Text('Saxla'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Personaj, məkan, süjet — oxucuya görünmür.',
                  style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(color: Colors.white, height: 1.45),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF1A1A1A),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _insertCopyright() {
    final year = DateTime.now().year;
    final author = _docSettings.author.trim().isEmpty
        ? _l('Müəllif', 'The author', 'Автор', 'المؤلف')
        : _docSettings.author.trim();
    final pub = _docSettings.publisher.trim();
    final isbn = _docSettings.isbn.trim();
    final buf = StringBuffer()
      ..writeln()
      ..writeln('# ${_l('Müəllif hüquqları', 'Copyright', 'Авторские права', 'حقوق النشر')}')
      ..writeln()
      ..writeln('© $year $author. ${_l('Bütün hüquqlar qorunur.', 'All rights reserved.', 'Все права защищены.', 'جميع الحقوق محفوظة.')}')
      ..writeln()
      ..writeln(
        'Bu əsərin heç bir hissəsi müəllifin yazılı icazəsi olmadan çoxaldıla, yayıla və ya saxlana bilməz.',
      )
      ..writeln();
    if (pub.isNotEmpty) buf.writeln('Nəşriyyat: $pub\n');
    if (isbn.isNotEmpty) buf.writeln('ISBN: $isbn\n');
    buf.writeln('--- Page Break ---\n');
    _insertAtCursor(buf.toString());
  }

  /// A titled book section: real heading (in the TOC), an empty paragraph
  /// with the cursor in it, then a page break. No placeholder text that
  /// would end up printed.
  void _insertBookSection({
    required String heading,
    bool pageBreakAfter = true,
  }) {
    final pb = pageBreakAfter ? '\n\n--- Page Break ---\n\n' : '\n\n';
    final head = '\n# $heading\n\n';
    _insertAtCursor('$head$pb');
    final at = _bodyCtrl.selection.start - pb.length;
    _bodyCtrl.selection = TextSelection.collapsed(offset: at.clamp(0, _bodyCtrl.text.length));
  }

  void _insertPrologue() => _insertBookSection(heading: _l('Proloq', 'Prologue', 'Пролог', 'تمهيد'));
  void _insertEpilogue() => _insertBookSection(heading: _l('Epiloq', 'Epilogue', 'Эпилог', 'خاتمة'));
  void _insertPreface() => _insertBookSection(heading: _l('Ön söz', 'Preface', 'Предисловие', 'مقدمة'));
  void _insertAfterword() => _insertBookSection(heading: _l('Son söz', 'Afterword', 'Послесловие', 'كلمة ختامية'));
  void _insertAcknowledgements() =>
      _insertBookSection(heading: _l('Təşəkkür', 'Acknowledgements', 'Благодарности', 'شكر وتقدير'));
  void _insertAboutAuthor() =>
      _insertBookSection(heading: _l('Müəllif haqqında', 'About the Author', 'Об авторе', 'عن المؤلف'));

  void _insertGlossary() {
    _insertAtCursor(
      '\n# ${_l('Lüğət', 'Glossary', 'Глоссарий', 'مسرد')}\n\n'
      '${TableBlock.markupFrom(rows: 8, cols: 2, headers: ['Term', 'İzah'], caption: 'Lüğət')}\n'
      '--- Page Break ---\n\n',
    );
  }

  void _insertBibliography() {
    _insertAtCursor(
      '\n# ${_l('Ədəbiyyat', 'Bibliography', 'Библиография', 'المراجع')}\n\n'
      '${TableBlock.markupFrom(rows: 7, cols: 4, headers: ['Müəllif', 'Əsər', 'İl', 'Qeyd'], caption: 'Mənbələr')}\n'
      '--- Page Break ---\n\n',
    );
  }

  void _insertCastTable() {
    _insertPresetTable(
      headers: ['Ad', 'Rol', 'İstək', 'Qüsur', 'Qeyd'],
      caption: 'Personajlar',
    );
  }

  void _insertPlacesTable() {
    _insertPresetTable(
      headers: ['Məkan', 'Tip', 'Əhval', 'Kimlər', 'Qeyd'],
      caption: 'Məkanlar',
    );
  }

  void _insertTimelineTable() {
    _insertPresetTable(
      headers: ['Tarix / sıra', 'Hadisə', 'Kim', 'Nəticə'],
      caption: 'Xronologiya',
    );
  }

  void _insertSceneTable() {
    _insertPresetTable(
      headers: ['Fəsil', 'Səhnə', 'POV', 'Məqsəd', 'Konflikt', 'Nəticə'],
      caption: 'Səhnə siyahısı',
      dataRows: 8,
    );
  }

  void _insertOutlineTable() {
    _insertPresetTable(
      headers: ['Fəsil', 'Ad', 'Akt', 'Söz', 'Status'],
      caption: 'Fəsil planı',
      dataRows: 10,
    );
  }

  void _insertResearchTable() {
    _insertPresetTable(
      headers: ['Mövzu', 'Mənbə', 'Səh.', 'Fakt', 'Qeyd'],
      caption: 'Tədqiqat',
    );
  }

  void _insertSceneCard() {
    _insertAtCursor(
      '\n## Səhnə\n\n'
      '**POV:** \n'
      '**Yer / vaxt:** \n'
      '**Məqsəd:** \n'
      '**Konflikt:** \n'
      '**Dönüş:** \n'
      '**Nəticə:** \n\n',
    );
  }

  void _insertOutlineActs() {
    _insertAtCursor(
      '\n# Outline\n\n'
      '## Act I — Başlanğıc\n'
      '- \n\n'
      '## Act II — Yüksəliş\n'
      '- \n\n'
      '## Act III — Qovuşma\n'
      '- \n\n',
    );
  }

  Future<void> _shareDocument() async {
    final title = _extractTitle();
    try {
      await Share.share(_exportSource(), subject: title);
    } catch (e, st) {
      debugPrint("Error: $e\n$st");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşmaq alınmadı. Yenidən cəhd edin.')),
      );
    }
  }

  int _countWords(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int get _sessionWords {
    final n = _wordCount - _sessionStartWords;
    return n < 0 ? 0 : n;
  }

  String _fmtNum(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _showNameIndex() {
    final map = BookStructure.nameIndex(_bodyCtrl.text);
    final keys = map.keys.toList()
      ..sort((a, b) => map[b]!.compareTo(map[a]!));
    showDarkSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        'Ad indeksi',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Personaj cədvəlindən və mətndə təkrarlanan adlardan.',
                    style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: keys.isEmpty
                      ? const Center(
                          child: Text(
                            'Ad tapılmadı. Əvvəl personaj cədvəli əlavə edin.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: keys.length,
                          itemBuilder: (_, i) {
                            final name = keys[i];
                            return ListTile(
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              trailing: Text(
                                '${map[name]}',
                                style: const TextStyle(color: Color(0xFFC9A84C)),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                final off = BookStructure.firstIndexOfName(
                                  _bodyCtrl.text,
                                  name,
                                );
                                _bodyCtrl.selection =
                                    TextSelection.collapsed(offset: off);
                                _bodyFocusNode.requestFocus();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManuscriptStats() {
    final full = _bodyCtrl.text;
    final words = _countWords(full);
    final chars = full.replaceAll(RegExp(r'\s+'), '').length;
    final paras = full
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .length;
    final chapters = BookStructure.parse(full).where((s) => s.level == 1).length;
    final scenes = RegExp(r'\* \* \*').allMatches(full).length;
    final pages = (words / 250).ceil().clamp(1, 999999);
    final minRead = (words / 200).ceil().clamp(1, 999999);
    final novel = words >= 50000;
    final goal = _docSettings.wordGoal <= 0 ? 50000 : _docSettings.wordGoal;
    final pct = (words / goal * 100).clamp(0, 999);
    final remain = (goal - words).clamp(0, 9999999);
    final session = _sessionWords;
    final daily = _docSettings.dailyGoal <= 0 ? 1000 : _docSettings.dailyGoal;
    showDarkSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Əlyazma',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 14),
                _statRow('Söz', '$words'),
                _statRow('Bu seans', '+$session'),
                _statRow('Hədəf', '${_fmtNum(goal)}  ·  ${pct.toStringAsFixed(1)}%'),
                _statRow('Qalıq', remain == 0 ? 'Hədəf dolub' : '${_fmtNum(remain)} söz'),
                _statRow('Gündəlik hədəf', '$session / $daily'),
                _statRow('Simvol', '$chars'),
                _statRow('Paraqlıq', '$paras'),
                _statRow('Fəsil / hissə (H1)', '$chapters'),
                _statRow('Səhnə bölgüsü', '$scenes'),
                _statRow('Təxmini səhifə (~250 söz)', '$pages'),
                _statRow('Oxuma (~200 wpm)', '$minRead dəq'),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (words / goal).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFC9A84C),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  novel
                      ? 'Roman həcmi: 50 000+ söz — keçdiniz.'
                      : 'Roman həcmi adətən 50 000 sözdür. Qalıq: ${50000 - words}.',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFC9A84C),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: GoogleFonts.dmSans(color: Colors.white70)),
          ),
          Text(
            v,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  int get _wordCount {
    final text = _bodyCtrl.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  /// Visible title: hidden title field, otherwise first non-empty line.
  String _currentTitle() {
    final typed = _titleCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    return _extractTitle();
  }

  /// Full document body. Never strip the first line — that used to drop
  /// the title heading on cloud save and then duplicate it on the next open.
  String _currentContent() => _bodyCtrl.text;

  /// Extract title from first line of body text
  String _extractTitle() {
    final text = _bodyCtrl.text;
    final untitled = AppLocalizations.of(context).untitledDocument;
    final cover = CoverData.parse(text);
    if (cover != null && cover.title.isNotEmpty && cover.title != CoverData.brandTitle) return cover.title;
    // First real line of text, without markup or block tokens.
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('[COVER') || t.startsWith('[img') || t.startsWith('[TABLE') ||
          t.startsWith('[/TABLE') || t.startsWith('|') || t.contains('Page Break') || t.startsWith('[note') ||
          t.startsWith('[HAŞİYƏ') || RegExp(r'^[-*\s]+$').hasMatch(t)) {
        continue;
      }
      final c = CoverData.cleanText(t);
      if (c.isNotEmpty) return c.length > 80 ? '${c.substring(0, 80).trimRight()}…' : c;
    }
    return untitled;
  }

  Future<void> _saveDocument() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final title = _currentTitle();
      final content = _currentContent();
      // Ensure stable local id
      _documentId ??= 'local_${DateTime.now().millisecondsSinceEpoch}';
      await LocalDocsCache.saveDoc(
        id: _documentId!,
        title: title,
        content: content,
        settings: _settingsToMap(),
      );
      // Optional cloud
      try {
        if (SupabaseService.instance.isReady &&
            SupabaseService.instance.isAuthenticated) {
          await _saveToDatabase();
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isSaved = true;
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saxlanıldı',
              style: GoogleFonts.dmSans(),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e, st) {
      debugPrint("Error: $e\n$st");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sənəd saxlanılmadı. Yenidən cəhd edin.')),
        );
      }
    }
  }

  Future<void> _exportDocument() async {
    if (_isSaving) return;

    // Show format picker dialog
    final format = await _showFormatPicker();
    if (format == null) return; // user cancelled
    final source = _exportSource();

    // If PDF selected, generate and download PDF, then also save to DB
    if (format == ExportFormat.pdf) {
      final title = _extractTitle();
      await PdfService.generateAndDownload(
        title: title,
        content: source,
        pageSize: _pageSize,
        textAlign: _alignment,
        isBold: false, // inline formatting lives in the text itself
        isItalic: false,
        isUnderline: false,
        showPageNumbers: _showPageNumbers,
        pageNumberPos: _docSettings.pageNumberPos,
        headerText: _headerText,
        footerText: _footerText,
        author: _docSettings.author,
        subtitle: _docSettings.subtitle,
        firstLineIndent: _docSettings.firstLineIndent,
        chapterNewPage: _docSettings.chapterNewPage,
        marginMm: _docSettings.marginMm,
        landscape: _docSettings.landscape,
        pageNumberStartPage: _docSettings.pageNumberStartPage,
        pageNumberStartAt: _docSettings.pageNumberStartAt,
        fontSize: _docSettings.fontSize,
        lineHeight: _docSettings.lineHeight,
        pageBgColor: _docSettings.pageBgColor,
        fontFamily: _docSettings.fontFamily,
        pageFrame: _docSettings.pageFrame,
        pageNumberStyle: _docSettings.pageNumberStyle,
        bookHeader: _docSettings.bookHeader,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).t(
                az: 'PDF hazırdır. Surəti tətbiqin «exports» qovluğunda da saxlanıldı.',
                en: 'PDF is ready. A copy was also saved in the app\'s exports folder.',
                ru: 'PDF готов. Копия сохранена в папке exports приложения.',
                ar: 'ملف PDF جاهز. حُفظت نسخة في مجلد exports في التطبيق.',
              ),
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      // Also save to DB in background
      _saveToDatabase();
      return;
    }

    // If Word selected, generate and download .docx, then also save to DB
    if (format == ExportFormat.word) {
      final title = _extractTitle();
      await MobileExportService.exportDocx(
        title: title,
        content: source,
        options: DocxOptions(
          title: title,
          author: _docSettings.author,
          subtitle: _docSettings.subtitle,
          fontFamily: _docSettings.fontFamily,
          language: _docSettings.language,
          pageSize: _pageSize,
          landscape: _docSettings.landscape,
          chapterNewPage: _docSettings.chapterNewPage,
          firstLineIndent: _docSettings.firstLineIndent,
          marginMm: _docSettings.marginMm,
          fontSize: _docSettings.fontSize,
          lineHeight: _docSettings.lineHeight,
          textAlign: _alignment,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).t(
                az: 'Word sənədi yükləndi (.docx)',
                en: 'Word document downloaded (.docx)',
                ru: 'Документ Word загружен (.docx)',
                ar: 'تم تنزيل مستند Word (.docx)',
              ),
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: const Color(0xFF2B5CE6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _saveToDatabase();
      return;
    }

    if (format == ExportFormat.txt) {
      final title = _extractTitle();
      await MobileExportService.exportTxt(
        title: title,
        content: source,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t(az: 'TXT hazırdır', en: 'TXT is ready', ru: 'TXT готов', ar: 'ملف TXT جاهز'), style: GoogleFonts.dmSans()),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _saveToDatabase();
      return;
    }

    if (format == ExportFormat.epub) {
      final title = _extractTitle();
      await MobileExportService.exportEpub(
        title: title,
        content: source,
        author: _docSettings.author,
        subtitle: _docSettings.subtitle,
        language: _docSettings.language,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t(az: 'EPUB hazırdır', en: 'EPUB is ready', ru: 'EPUB готов', ar: 'ملف EPUB جاهز'), style: GoogleFonts.dmSans()),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _saveToDatabase();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final l10n = AppLocalizations.of(context);
      final title = _currentTitle();
      final content = _currentContent();

      if (_documentId != null) {
        await SupabaseService.instance.updateDocument(
          id: _documentId!,
          title: title,
          content: content,
        );
      } else {
        final doc = await SupabaseService.instance.createDocument(
          title: title,
          content: content,
        );
        if (doc != null) {
          _documentId = doc.id;
        }
      }

      if (mounted) {
        setState(() {
          _isSaved = true;
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
        final formatLabel = format == ExportFormat.pdf ? 'PDF' : 'Word';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).documentSaved} ($formatLabel)',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).saveFailed,
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveToDatabase() async {
    try {
      final l10n = AppLocalizations.of(context);
      final title = _currentTitle();
      final content = _currentContent();
      if (_documentId != null) {
        await SupabaseService.instance.updateDocument(
          id: _documentId!,
          title: title,
          content: content,
        );
      } else {
        final doc = await SupabaseService.instance.createDocument(
          title: title,
          content: content,
        );
        if (doc != null && mounted) {
          setState(() => _documentId = doc.id);
        }
      }
      final id = _documentId ?? DateTime.now().millisecondsSinceEpoch.toString();
      await LocalDocsCache.saveDoc(
        id: id,
        title: title,
        content: content,
      );
      if (mounted) {
        setState(() {
          _isSaved = true;
          _hasUnsavedChanges = false;
        });
      }
    } catch (_) {
      // Still try local offline save
      try {
        final id = _documentId ?? DateTime.now().millisecondsSinceEpoch.toString();
        await LocalDocsCache.saveDoc(
          id: id,
          title: _currentTitle(),
          content: _currentContent(),
        );
      } catch (_) {}
    }
  }

  Future<ExportFormat?> _showFormatPicker() async {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<ExportFormat>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setLocal) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yalnız əlyazma'),
                subtitle: const Text(
                  'Personaj / məkan / xronologiya cədvəlləri çıxarılır',
                ),
                value: _manuscriptExport,
                onChanged: (v) {
                  setState(() => _manuscriptExport = v);
                  setLocal(() {});
                },
              ),
              Text(
                l10n.t(
                  az: 'Fayl formatını seçin',
                  en: 'Choose file format',
                  ru: 'Выберите формат файла',
                  ar: 'اختر تنسيق الملف',
                ),
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _formatOption(
                      ctx,
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF',
                      subtitle: l10n.t(
                        az: 'Çap üçün ideal',
                        en: 'Ideal for printing',
                        ru: 'Идеально для печати',
                        ar: 'مثالي للطباعة',
                      ),
                      color: const Color(0xFFE53E3E),
                      onTap: () => Navigator.pop(ctx, ExportFormat.pdf),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _formatOption(
                      ctx,
                      icon: Icons.description_rounded,
                      label: 'Word',
                      subtitle: l10n.t(
                        az: 'Redaktə üçün ideal',
                        en: 'Ideal for editing',
                        ru: 'Идеально для редактирования',
                        ar: 'مثالي للتحرير',
                      ),
                      color: const Color(0xFF2B5CE6),
                      onTap: () => Navigator.pop(ctx, ExportFormat.word),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('TXT'),
                subtitle: const Text('Plain text file'),
                onTap: () => Navigator.pop(ctx, ExportFormat.txt),
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('EPUB'),
                subtitle: const Text('E-book format'),
                onTap: () => Navigator.pop(ctx, ExportFormat.epub),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  l10n.cancel,
                  style: GoogleFonts.dmSans(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  Widget _formatOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(ctx);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPageSizePicker() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (context, setS) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.t(
                    az: 'Səhifə ölçüsü',
                    en: 'Page size',
                    ru: 'Размер страницы',
                    ar: 'حجم الصفحة',
                  ),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: PageSize.values.map((size) {
                    final isSelected = _pageSize == size;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _pageSize = size);
                          setS(() {});
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withAlpha(15)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Mini page preview
                              Container(
                                width: size == PageSize.a3
                                    ? 36
                                    : size == PageSize.a4
                                    ? 28
                                    : 22,
                                height: size == PageSize.a3
                                    ? 50
                                    : size == PageSize.a4
                                    ? 40
                                    : 30,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : theme.colorScheme.outline,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(20),
                                      blurRadius: 4,
                                      offset: const Offset(1, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                size.label,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                _pageSizeDimensions(size),
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 4),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.primary,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _pageSizeDimensions(PageSize size) => size.mm;

  /// Part 2: format selection for real — wraps text in markers stored in document.
  void _wrapSelection(String left, String right) {
    _syncCursorFromCanvas();
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    if (!sel.isValid) return;
    if (sel.isCollapsed) {
      // Insert markers and place cursor between them
      final i = sel.start;
      final snippet = '$left$right';
      final newText = text.replaceRange(i, i, snippet);
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: i + left.length),
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      // Toggle off if already wrapped
      String next;
      if (selected.startsWith(left) && selected.endsWith(right) && selected.length >= left.length + right.length) {
        next = selected.substring(left.length, selected.length - right.length);
      } else {
        next = '$left$selected$right';
      }
      final newText = text.replaceRange(sel.start, sel.end, next);
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start,
          extentOffset: sel.start + next.length,
        ),
      );
    }
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    _pushHistory();
  }


  /// Current paragraph range containing the cursor.
  (int, int) _paragraphRange() {
    final text = _bodyCtrl.text;
    final pos = _bodyCtrl.selection.isValid
        ? _bodyCtrl.selection.start
        : text.length;
    var start = text.lastIndexOf('\n', pos - 1) + 1;
    if (start < 0) start = 0;
    var end = text.indexOf('\n', pos);
    if (end < 0) end = text.length;
    return (start, end);
  }

  void _indentParagraph(int delta) {
    if (_canvasKey.currentState?.indentFocused(delta) == true) {
      setState(() {
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      return;
    }
    _syncCursorFromCanvas();
    final text = _bodyCtrl.text;
    final (start, end) = _paragraphRange();
    var para = text.substring(start, end);
    // Keep an [align=…] prefix in front of the indent.
    final am = RegExp(r'^\[align=\w+\]').firstMatch(para);
    final alignPrefix = am?.group(0) ?? '';
    para = para.substring(alignPrefix.length);
    // Count leading spaces (2 per level)
    final leading = RegExp(r'^ *').firstMatch(para)?.group(0)?.length ?? 0;
    final level = (leading ~/ 2 + delta).clamp(0, 8);
    para = para.replaceFirst(RegExp(r'^ *'), '');
    para = alignPrefix + ('  ' * level) + para;
    final newText = text.replaceRange(start, end, para);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + para.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _setParagraphAlign(String align) {
    if (_canvasKey.currentState?.alignFocused(align) == true) {
      setState(() {
        _alignment = align;
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      return;
    }
    setState(() => _alignment = align);
    final text = _bodyCtrl.text;
    final (start, end) = _paragraphRange();
    var para = text.substring(start, end);
    // strip old align marker at start
    para = para.replaceFirst(RegExp(r'^\[align=(left|center|right|justify)\]'), '');
    if (align != 'left') {
      para = '[align=$align]$para';
    }
    final newText = text.replaceRange(start, end, para);
    final cursor = start + para.length;
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }



  void _showPageNumberOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Səhifə nömrəsi',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Göstər'),
                      value: _showPageNumbers,
                      onChanged: (v) {
                        setState(() {
                          _showPageNumbers = v;
                          _docSettings.showPageNumbers = v;
                          _hasUnsavedChanges = true;
                        });
                        setLocal(() {});
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in [
                          ('bottom-center', 'Alt orta'),
                          ('bottom-right', 'Alt sağ'),
                          ('bottom-left', 'Alt sol'),
                          ('top-center', 'Üst orta'),
                          ('top-right', 'Üst sağ'),
                          ('top-left', 'Üst sol'),
                        ])
                          ChoiceChip(
                            label: Text(e.$2),
                            selected: _docSettings.pageNumberPos == e.$1,
                            onSelected: (_) {
                              setState(() {
                                _docSettings.pageNumberPos = e.$1;
                                _showPageNumbers = true;
                                _docSettings.showPageNumbers = true;
                                _hasUnsavedChanges = true;
                              });
                              setLocal(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('Hansı səhifədən')),
                        IconButton(
                          onPressed: _docSettings.pageNumberStartPage > 1
                              ? () {
                                  setState(() {
                                    _docSettings.pageNumberStartPage--;
                                    _hasUnsavedChanges = true;
                                  });
                                  setLocal(() {});
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${_docSettings.pageNumberStartPage}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _docSettings.pageNumberStartPage++;
                              _hasUnsavedChanges = true;
                            });
                            setLocal(() {});
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('İlk rəqəm')),
                        IconButton(
                          onPressed: _docSettings.pageNumberStartAt > 1
                              ? () {
                                  setState(() {
                                    _docSettings.pageNumberStartAt--;
                                    _hasUnsavedChanges = true;
                                  });
                                  setLocal(() {});
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${_docSettings.pageNumberStartAt}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _docSettings.pageNumberStartAt++;
                              _hasUnsavedChanges = true;
                            });
                            setLocal(() {});
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Text(
                      'Səhifə ${_docSettings.pageNumberStartPage}-də ${_docSettings.pageNumberStartAt}, sonra ${_docSettings.pageNumberStartAt + 1}, ${_docSettings.pageNumberStartAt + 2}…',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  void _showLineSpacingPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Line spacing',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ),
            for (final h in [1.0, 1.15, 1.5, 1.7, 2.0, 2.5])
              ListTile(
                title: Text(h.toStringAsFixed(2)),
                trailing: (_docSettings.lineHeight - h).abs() < 0.01
                    ? const Icon(Icons.check, color: Color(0xFF2B5CE6))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setLineHeight(h);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _setLineHeight(double h) {
    setState(() {
      _docSettings.lineHeight = h;
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _onFormatTap(String format) {
    bool wrap(String l, String r) {
      final ok = _canvasKey.currentState?.wrapFocused(l, r) ?? false;
      if (ok) _markDirty();
      return ok;
    }
    void needSel() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t(
            az: 'Əvvəl mətni seçin',
            en: 'Select text first',
            ru: 'Сначала выделите текст',
            ar: 'حدد النص أولاً',
          ).replaceAll('Əvvəl mətni seçin', 'Əvvəl mətnə toxunun və ya mətni seçin')),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    switch (format) {
      case 'bold':
        if (!wrap('**', '**')) needSel();
        break;
      case 'italic':
        if (!wrap('*', '*')) needSel();
        break;
      case 'underline':
        if (!wrap('__', '__')) needSel();
        break;
      case 'strikethrough':
        if (!wrap('~~', '~~')) needSel();
        break;
      case 'align-left':
        _setParagraphAlign('left');
        break;
      case 'align-center':
        _setParagraphAlign('center');
        break;
      case 'align-right':
        _setParagraphAlign('right');
        break;
      case 'align-justify':
        _setParagraphAlign('justify');
        break;
      case 'bullet':
      case 'bullet-list':
        _applyStyle('bullet');
        break;
      case 'number':
      case 'numbered-list':
        _applyStyle('number');
        break;
      case 'indent-more':
        _indentParagraph(1);
        break;
      case 'indent-less':
        _indentParagraph(-1);
        break;
    }
  }

  TextAlign get _textAlign {
    switch (_alignment) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final l10n = AppLocalizations.of(context);
            return AlertDialog(
              title: Text(
                l10n.unsavedChanges,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
              content: Text(l10n.saveBeforeExit, style: GoogleFonts.dmSans()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel, style: GoogleFonts.dmSans()),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    l10n.t(
                      az: 'Saxlama',
                      en: "Don't save",
                      ru: 'Не сохранять',
                      ar: 'عدم الحفظ',
                    ),
                    style: GoogleFonts.dmSans(),
                  ),
                ),
                FilledButton(
                  onPressed: () async {
                    await _saveDocument();
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: Text(l10n.saveAndExit, style: GoogleFonts.dmSans()),
                ),
              ],
            );
          },
        );
        if (shouldPop == true && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(theme),
              if (_focusMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _toggleFocusMode,
                    icon: const Icon(Icons.close_fullscreen_rounded, size: 16),
                    label: Text(AppLocalizations.of(context).t(az: 'Fokus rejimindən çıx', en: 'Exit focus mode', ru: 'Выйти из режима фокуса', ar: 'الخروج من وضع التركيز')),
                  ),
                ),
              if (!_readingMode && !_focusMode) _buildPageIndicator(theme),
              if (!_readingMode && !_focusMode) _buildFormattingToolbar(theme),
              Expanded(child: _buildEditorBody(theme)),
              if (!_readingMode) _buildBottomToolbar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final firstLine = _bodyCtrl.text.split('\n').first.trim();
    final title = firstLine.isEmpty ? l10n.untitledDocument : firstLine;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
            onPressed: () => context.pop(),
            padding: const EdgeInsets.all(8),
          ),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          IconButton(
            icon: Icon(
              _readingMode ? Icons.edit_rounded : Icons.menu_book_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: _toggleReadingMode,
            tooltip: AppLocalizations.of(context).t(
              az: 'Səhifə görünüşü (PDF kimi)',
              en: 'Page view (exactly like PDF)',
              ru: 'Вид страницы (как PDF)',
              ar: 'عرض الصفحة (مثل PDF)',
            ),
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: Icon(
              Icons.undo_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: _undo,
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: Icon(
              Icons.redo_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: _redo,
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: () => _showEditorOptions(context, theme),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    // Real page count from the shared layout engine (same as the PDF).
    final pages = _layout?.pages ?? const <LPage>[];
    final totalPages = pages.isEmpty ? 1 : pages.length;
    final cursorOffset = _bodyCtrl.selection.isValid ? _bodyCtrl.selection.baseOffset : 0;
    var currentPage = 1;
    for (var i = 0; i < pages.length; i++) {
      final lines = pages[i].lines;
      if (lines.isNotEmpty && lines.first.sourceOffset <= cursorOffset) currentPage = i + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(80),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${l10n.page} $currentPage / $totalPages',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _insertTitlePage,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A84C).withAlpha(28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Üz qabığı',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8A6A1A),
                ),
              ),
            ),
          ),
          // Page size selector button
          GestureDetector(
            onTap: _showPageSizePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _pageSize.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Row 1: B/I/U/S + alignment + lists
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ValueListenableBuilder<SpanStyle>(
                  valueListenable: MarkupTextController.caret,
                  builder: (_, cs, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _fmtBtn('B', 'bold', cs.bold, theme, isBold: true),
                      _fmtBtn('I', 'italic', cs.italic, theme, isItalic: true),
                      _fmtBtn('U', 'underline', cs.underline, theme, isUnderline: true),
                      _fmtBtn('S', 'strikethrough', cs.strike, theme, isStrikethrough: true),
                    ],
                  ),
                ),
                _divider(),
                _fmtGroup(
                  theme,
                  _alignIcon(_alignment),
                  [
                    (Icons.format_align_left_rounded, AppLocalizations.of(context).t(az: 'Solda', en: 'Left', ru: 'Слева', ar: 'يسار'), 'align-left'),
                    (Icons.format_align_center_rounded, AppLocalizations.of(context).t(az: 'Ortada', en: 'Center', ru: 'По центру', ar: 'وسط'), 'align-center'),
                    (Icons.format_align_right_rounded, AppLocalizations.of(context).t(az: 'Sağda', en: 'Right', ru: 'Справа', ar: 'يمين'), 'align-right'),
                    (Icons.format_align_justify_rounded, AppLocalizations.of(context).t(az: 'Sığdır', en: 'Justify', ru: 'По ширине', ar: 'ضبط'), 'align-justify'),
                  ],
                ),
                _fmtGroup(
                  theme,
                  Icons.format_list_bulleted_rounded,
                  [
                    (Icons.format_list_bulleted_rounded, AppLocalizations.of(context).t(az: 'Marker', en: 'Bullets', ru: 'Маркеры', ar: 'نقاط'), 'bullet-list'),
                    (Icons.format_list_numbered_rounded, AppLocalizations.of(context).t(az: 'Nömrə', en: 'Numbers', ru: 'Нумерация', ar: 'أرقام'), 'numbered-list'),
                  ],
                ),
                _fmtGroup(
                  theme,
                  Icons.format_indent_increase_rounded,
                  [
                    (Icons.format_indent_increase_rounded, 'Girinti +', 'indent-more'),
                    (Icons.format_indent_decrease_rounded, 'Girinti −', 'indent-less'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Row 2: Text / Color / Styles / More
          Row(
            children: [
              _toolbarAction(
                theme,
                Icons.text_fields_rounded,
                AppLocalizations.of(context).textStyle,
              ),
              _toolbarAction(
                theme,
                Icons.color_lens_outlined,
                AppLocalizations.of(context).color,
              ),
              _toolbarAction(
                theme,
                Icons.image_outlined,
                AppLocalizations.of(context).image,
              ),
              _toolbarAction(
                theme,
                Icons.more_horiz_rounded,
                AppLocalizations.of(context).more,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fmtBtn(
    String label,
    String format,
    bool isActive,
    ThemeData theme, {
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    bool isStrikethrough = false,
  }) {
    return GestureDetector(
      onTap: () => _onFormatTap(format),
      child: Container(
        width: 34,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: AppTheme.primary.withAlpha(60))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: isUnderline
                  ? TextDecoration.underline
                  : isStrikethrough
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              color: isActive ? AppTheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconFmtBtn(
    IconData icon,
    String format,
    bool isActive,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => _onFormatTap(format),
      child: Container(
        width: 34,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: AppTheme.primary.withAlpha(60))
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppTheme.primary : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  IconData _alignIcon(String a) {
    switch (a) {
      case 'center':
        return Icons.format_align_center_rounded;
      case 'right':
        return Icons.format_align_right_rounded;
      case 'justify':
        return Icons.format_align_justify_rounded;
      default:
        return Icons.format_align_left_rounded;
    }
  }

  Widget _fmtGroup(
    ThemeData theme,
    IconData icon,
    List<(IconData, String, String)> items,
  ) {
    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: _onFormatTap,
      itemBuilder: (ctx) => [
        for (final it in items)
          PopupMenuItem<String>(
            value: it.$3,
            child: Row(
              children: [
                Icon(it.$1, size: 18),
                const SizedBox(width: 10),
                Text(it.$2),
              ],
            ),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurface),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.outlineLight,
    );
  }

  Widget _toolbarAction(ThemeData theme, IconData icon, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showToolbarSheet(context, theme, label),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurface),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorBody(ThemeData theme) {
    _scheduleLayout();
    if (_readingMode) {
      final doc = _layout;
      if (doc == null) return const Center(child: CircularProgressIndicator());
      return ColoredBox(
        color: const Color(0xFFE9E6E0),
        child: LayoutPagesView(
          doc: doc,
          onTapLine: (offset) {
            setState(() => _readingMode = false);
            final o = offset.clamp(0, _bodyCtrl.text.length);
            _bodyCtrl.selection = TextSelection.collapsed(offset: o);
            _bodyFocusNode.requestFocus();
          },
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth - 12;
        // Whole page fits the screen. Slightly smaller than print, same shape.
        var scale = avail / _pageW;
        if (scale > 1.0) scale = 1.0;
        if (scale < 0.28) scale = 0.28;
        final dw = _pageW * scale;
        final dh = _pageH * scale;
        final pad = _marginPx * scale;
        final style = _editorTextStyle().copyWith(
          fontSize: (_docSettings.fontSize * scale).clamp(11, 28),
          height: _docSettings.lineHeight,
        );

        final head = _headerText.trim().isNotEmpty
            ? _headerText.trim()
            : _titleCtrl.text.trim();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _bodyCtrl,
            builder: (context, value, child) {
              final plain = _plainForPages(value.text);
              final tp = TextPainter(
                text: TextSpan(
                  text: plain.isEmpty ? ' ' : plain,
                  style: style,
                ),
                textDirection: TextDirection.ltr,
                textAlign: _textAlign,
              )..layout(maxWidth: (dw - pad * 2).clamp(40, 2000));
              final innerH = (dh - pad * 2).clamp(48.0, dh);
              // At least as many sheets as the page engine (= PDF) makes.
              final est = (tp.height / innerH).ceil();
              final eng = _layout?.pages.length ?? 0;
              final pageCount = (est > eng ? est : eng).clamp(1, 400);
              final sheetH = dh * pageCount;

              Alignment numAlign = Alignment.bottomCenter;
              final pos = _docSettings.pageNumberPos;
              if (pos.startsWith('top')) {
                numAlign = pos.endsWith('left')
                    ? Alignment.topLeft
                    : pos.endsWith('right')
                        ? Alignment.topRight
                        : Alignment.topCenter;
              } else {
                numAlign = pos.endsWith('left')
                    ? Alignment.bottomLeft
                    : pos.endsWith('right')
                        ? Alignment.bottomRight
                        : Alignment.bottomCenter;
              }

              return SizedBox(
                width: dw,
                height: sheetH,
                child: Stack(
                  children: [
                    for (int p = 0; p < pageCount; p++)
                      Positioned(
                        top: dh * p,
                        left: 0,
                        width: dw,
                        height: dh,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _focusMode
                                ? const Color(0xFFF7F1E3)
                                : _bgColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(36),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFD0D4E0)),
                          ),
                          child: Stack(
                            children: [
                              if (_docSettings.pageFrame)
                                Positioned.fill(
                                  child: Padding(
                                    padding: EdgeInsets.all((10 * scale).clamp(6, 16)),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF1A1A1A),
                                          width: 1.1,
                                        ),
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFF1A1A1A),
                                            width: 0.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (head.isNotEmpty &&
                                  !(_docSettings.author.isNotEmpty && p == 0))
                                Positioned(
                                  top: pad * 0.28,
                                  left: pad * 0.7,
                                  right: pad * 0.7,
                                  child: _bookHead(
                                    head,
                                    _printedNumber(p + 1),
                                    scale,
                                  ),
                                ),
                              if (!_docSettings.bookHeader)
                                Align(
                                  alignment: numAlign,
                                  child: Padding(
                                    padding: EdgeInsets.all((8 * scale).clamp(4, 10)),
                                    child: _pageNumWidget(
                                      _printedNumber(p + 1),
                                      scale,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      left: 0,
                      width: dw,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
                        child: DocumentCanvas(
                          key: _canvasKey,
                          text: _bodyCtrl.text,
                          hint: AppLocalizations.of(context).t(
                            az: 'Yazmağa başlayın…',
                            en: 'Start writing…',
                            ru: 'Начните писать…',
                            ar: 'ابدأ الكتابة…',
                          ),
                          style: style,
                          textAlign: _textAlign,
                          readOnly: _readingMode,
                          firstLineIndent: _docSettings.firstLineIndent,
                          onChanged: (next) {
                            if (_applyingHistory) return;
                            if (next == _bodyCtrl.text) return;
                            _applyingHistory = true;
                            _bodyCtrl.value = TextEditingValue(text: next);
                            _applyingHistory = false;
                            _onBodyChanged();
                          },
                          onEditTable: _editTableAt,
                          onDeleteTable: _deleteTableAt,
                          onEditImage: _editImageAt,
                          onDeleteImage: _deleteImageAt,
                          pageAspect: _pageH / _pageW,
                          tocEntries: _layout?.toc ?? const [],
                          pxPerPt: (style.fontSize ?? 14) /
                              (_docSettings.fontSize * 0.75).clamp(7.0, 28.0),
                          onEditCover: _openCoverGallery,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomToolbar(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final goal = _docSettings.wordGoal <= 0 ? 50000 : _docSettings.wordGoal;
    final words = _wordCount;
    final session = _sessionWords;
    final daily = _docSettings.dailyGoal <= 0 ? 1000 : _docSettings.dailyGoal;
    final pct = (words / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_focusMode)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: theme.colorScheme.outline.withAlpha(40),
                color: const Color(0xFFC9A84C),
              ),
            ),
          if (!_focusMode) const SizedBox(height: 6),
          Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showManuscriptStats,
              child: Text(
                _focusMode
                    ? '$words söz  ·  +$session seans'
                    : '${_fmtNum(words)} / ${_fmtNum(goal)} ${l10n.wordCount}'
                        '  ·  +$session seans'
                        '  ·  $session/$daily gün',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _isSaving ? null : _saveDocument,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isSaved ? Icons.check_circle_rounded : Icons.save_outlined,
                    size: 16,
                    color: _isSaved ? AppTheme.success : AppTheme.primary,
                  ),
            label: Text(
              _isSaving ? l10n.saving : (_isSaved ? l10n.saved : l10n.save),
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isSaved ? AppTheme.success : AppTheme.primary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }

  void _showEditorOptions(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _editorOption(
              ctx,
              Icons.picture_as_pdf_outlined,
              l10n.t(
                az: 'İxrac et (PDF/DOCX)',
                en: 'Export (PDF/DOCX)',
                ru: 'Экспорт (PDF/DOCX)',
                ar: 'تصدير (PDF/DOCX)',
              ),
              () {
                Navigator.pop(ctx);
                _exportDocument();
              },
            ),
            _editorOption(
              ctx,
              Icons.share_outlined,
              l10n.share,
              () {
                Navigator.pop(ctx);
                _shareDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorOption(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary, size: 22),
      title: Text(
        label,
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  void _showToolbarSheet(BuildContext context, ThemeData theme, String title) {
    final l10n = AppLocalizations.of(context);
    // These open their own UI; never pop a route while it is building.
    if (title == l10n.styles) {
      _showStylesSheet();
      return;
    }
    if (title == l10n.image) {
      _pickImage();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (title == l10n.textStyle) return _buildFontStyleSheet(ctx, theme);
        if (title == l10n.color) return _buildColorSheet(ctx, theme);
        return _buildInsertSheet(ctx, theme);
      },
    );
  }

  Widget _buildFontStyleSheet(BuildContext ctx, ThemeData theme) {
    final l10n = AppLocalizations.of(ctx);
    // Bundled families: what you pick is exactly what the PDF uses.
    final fonts = ['Lora', 'LibreBaskerville', 'DMSans', 'NotoNaskhArabic'];
    final fontNames = ['Lora', 'Libre Baskerville', 'DM Sans', 'Noto Naskh Arabic'];
    int selectedFont = fonts.indexOf(_canvasKey.currentState?.caretStyle().font ?? '');
    if (selectedFont < 0) selectedFont = 0;
    double fontSize = _fontSize;
    int tab = 0; // 0 fonts, 1 size, 2 style
    bool bold = _isBold;
    bool italic = _isItalic;
    bool underline = _isUnderline;
    return StatefulBuilder(
      builder: (context, setS) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t(
                      az: 'Yazı tərzi',
                      en: 'Font style',
                      ru: 'Стиль шрифта',
                      ar: 'نمط الخط',
                    ),
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => tab = 0),
                      child: _sheetTab(theme, l10n.fonts, tab == 0),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => tab = 1),
                      child: _sheetTab(theme, l10n.size, tab == 1),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => tab = 2),
                      child: _sheetTab(
                        theme,
                        l10n.t(
                          az: 'Stil',
                          en: 'Style',
                          ru: 'Стиль',
                          ar: 'النمط',
                        ),
                        tab == 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tab == 0
                  ? ListView.builder(
                      controller: scrollCtrl,
                      itemCount: fonts.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(
                          fontNames[i],
                          style: TextStyle(fontFamily: fonts[i], fontSize: 16),
                        ),
                        trailing: i == selectedFont
                            ? Icon(Icons.check_rounded,
                                color: AppTheme.primary)
                            : null,
                        onTap: () {
                          setS(() => selectedFont = i);
                          if (_canvasKey.currentState?.formatFocused(FormatOp('font', fonts[i])) ?? false) {
                            _markDirty();
                          } else {
                            setState(() => _fontFamily = fonts[i]);
                          }
                        },
                      ),
                    )
                  : tab == 1
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                '${fontSize.round()} pt',
                                style: GoogleFonts.dmSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Slider(
                                value: fontSize,
                                min: 8,
                                max: 48,
                                divisions: 40,
                                activeColor: AppTheme.primary,
                                onChanged: (v) => setS(() => fontSize = v),
                                onChangeEnd: (v) {
                                  Navigator.pop(context);
                                  _applySizeToSelection(v);
                                },
                              ),
                              Wrap(
                                spacing: 8,
                                children: [12, 14, 16, 18, 20, 24, 28, 32]
                                    .map(
                                      (s) => ActionChip(
                                        label: Text('$s'),
                                        onPressed: () {
                                          setS(() => fontSize = s.toDouble());
                                          Navigator.pop(context);
                                          _applySizeToSelection(s.toDouble());
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollCtrl,
                          children: [
                            SwitchListTile(
                              title: const Text('Bold'),
                              value: bold,
                              onChanged: (v) {
                                setS(() => bold = v);
                                if (_canvasKey.currentState?.formatFocused(FormatOp('bold', v)) ?? false) _markDirty();
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Italic'),
                              value: italic,
                              onChanged: (v) {
                                setS(() => italic = v);
                                if (_canvasKey.currentState?.formatFocused(FormatOp('italic', v)) ?? false) _markDirty();
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Underline'),
                              value: underline,
                              onChanged: (v) {
                                setS(() => underline = v);
                                if (_canvasKey.currentState?.formatFocused(FormatOp('underline', v)) ?? false) _markDirty();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.format_clear),
                              title: const Text('Clear format on selection'),
                              onTap: () {
                                Navigator.pop(context);
                                _clearSelectionFormat();
                              },
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSheet(BuildContext ctx, ThemeData theme) {
    final l10n = AppLocalizations.of(ctx);
    final textColors = [
      const Color(0xFF1A1A1A),
      Colors.grey.shade700,
      Colors.red.shade700,
      Colors.orange.shade800,
      Colors.teal.shade800,
      Colors.blue.shade800,
      Colors.purple.shade700,
      Colors.green.shade800,
      const Color(0xFFC9A84C),
      Colors.white,
    ];
    final pageColors = [
      Colors.white,
      const Color(0xFFF7F1E3),
      const Color(0xFFF4EEE6),
      const Color(0xFFEDE4D3),
      const Color(0xFFEEF3EA),
      const Color(0xFFE8EEF6),
      const Color(0xFFF6E8EE),
      const Color(0xFFD9D9D9),
      const Color(0xFF0D1B3E),
      const Color(0xFF1A1208),
      const Color(0xFF111111),
    ];
    int mode = 0;
    double hue = 20;
    return StatefulBuilder(
      builder: (context, setS) {
        final custom = HSVColor.fromAHSV(1, hue, 0.55, 0.92).toColor();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                      ),
                      Text(
                        'Rəng',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.t(az: 'Mətn', en: 'Text', ru: 'Текст', ar: 'نص')),
                        selected: mode == 0,
                        onSelected: (_) => setS(() => mode = 0),
                      ),
                      ChoiceChip(
                        label: Text(l10n.t(az: 'Vurğu', en: 'Highlight', ru: 'Выделение', ar: 'تمييز')),
                        selected: mode == 1,
                        onSelected: (_) => setS(() => mode = 1),
                      ),
                      ChoiceChip(
                        label: Text(l10n.t(az: 'Səhifə fonu', en: 'Page background', ru: 'Фон страницы', ar: 'خلفية الصفحة')),
                        selected: mode == 2,
                        onSelected: (_) => setS(() => mode = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    mode == 2
                        ? l10n.t(
                            az: 'Bütün səhifənin rəngi',
                            en: 'Whole page color',
                            ru: 'Цвет всей страницы',
                            ar: 'لون الصفحة بالكامل')
                        : l10n.t(
                            az: 'Seçilmiş mətn rənglənir. Seçim yoxdursa, növbəti yazı bu rəngdə olur.',
                            en: 'Selected text is colored. If nothing is selected, the next typing uses this color.',
                            ru: 'Выделенный текст красится. Без выделения — следующий набор этим цветом.',
                            ar: 'يُلوَّن النص المحدد. إن لم يُحدد شيء فالكتابة التالية بهذا اللون.'),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in (mode == 2 ? pageColors : textColors))
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            if (mode == 2) {
                              _setPageBackground(c);
                            } else {
                              _applyColorToSelection(c, background: mode == 1);
                            }
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t(az: 'Xüsusi rəng', en: 'Custom color', ru: 'Свой цвет', ar: 'لون مخصص'),
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: hue,
                    min: 0,
                    max: 359,
                    onChanged: (v) => setS(() => hue = v),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      if (mode == 2) {
                        _setPageBackground(custom);
                      } else {
                        _applyColorToSelection(custom, background: mode == 1);
                      }
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: custom,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsertSheet(BuildContext ctx, ThemeData theme) {
    final l10n = AppLocalizations.of(ctx);
    Widget group(String title, List<Widget> children) {
      return Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(
            title,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          children: children,
        ),
      );
    }

    Widget item(IconData icon, String label, String key) {
      return ListTile(
        dense: true,
        leading: Icon(icon, color: AppTheme.primary, size: 22),
        title: Text(label, style: GoogleFonts.dmSans(fontSize: 14)),
        onTap: () {
          Navigator.pop(ctx);
          _handleInsertKey(key);
        },
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
                Text(
                  l10n.more,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          group(
            l10n.t(
              az: 'Daxil et',
              en: 'Insert',
              ru: 'Вставить',
              ar: 'إدراج',
            ),
            [
              item(Icons.table_chart_outlined, l10n.t(az: 'Cədvəl', en: 'Table', ru: 'Таблица', ar: 'جدول'), 'table'),
              item(Icons.link_rounded, l10n.link, 'link'),
              item(Icons.notes_outlined, l10n.t(az: 'Haşiyə', en: 'Margin note', ru: 'Сноска на поле', ar: 'حاشية'), 'marginNote'),
              item(Icons.insert_page_break_outlined, l10n.pageBreak, 'pageBreak'),
              item(Icons.horizontal_rule_rounded, l10n.horizontalLine, 'hline'),
              item(Icons.superscript, l10n.t(az: 'Dipqeyd', en: 'Footnote', ru: 'Сноска', ar: 'حاشية سفلية'), 'footnote'),
              item(Icons.title_rounded, l10n.t(az: 'Başlıq', en: 'Heading', ru: 'Заголовок', ar: 'عنوان'), 'h1'),
              item(Icons.format_quote_rounded, l10n.t(az: 'Sitat', en: 'Quote', ru: 'Цитата', ar: 'اقتباس'), 'quote'),
            ],
          ),
          group(
            l10n.t(
              az: 'Kitab',
              en: 'Book',
              ru: 'Книга',
              ar: 'كتاب',
            ),
            [
              item(Icons.menu_book_rounded, l10n.t(az: 'Üz səhifə', en: 'Cover', ru: 'Обложка', ar: 'غلاف'), 'cover'),
              item(Icons.settings_outlined, l10n.t(az: 'Kitab ayarları', en: 'Book settings', ru: 'Настройки книги', ar: 'إعدادات الكتاب'), 'settings'),
              item(Icons.auto_stories_outlined, l10n.t(az: 'Fəsil', en: 'Chapter', ru: 'Глава', ar: 'فصل'), 'chapter'),
              item(Icons.bookmark_border, l10n.t(az: 'Hissə', en: 'Part', ru: 'Часть', ar: 'جزء'), 'part'),
              item(Icons.list_alt_rounded, l10n.t(az: 'Mündəricat', en: 'Contents', ru: 'Оглавление', ar: 'فهرس'), 'toc'),
              item(Icons.menu_book_outlined, l10n.t(az: 'Fəsillər', en: 'Chapters', ru: 'Главы', ar: 'الفصول'), 'chapters'),
            ],
          ),
          group(
            l10n.t(az: 'Kitab hissələri', en: 'Book parts', ru: 'Части книги', ar: 'أجزاء الكتاب'),
            [
              item(Icons.copyright_rounded, l10n.t(az: 'Müəllif hüquqları səhifəsi', en: 'Copyright page', ru: 'Страница авторских прав', ar: 'صفحة الحقوق'), 'copyright'),
              item(Icons.favorite_border_rounded, l10n.t(az: 'İthaf', en: 'Dedication', ru: 'Посвящение', ar: 'إهداء'), 'dedication'),
              item(Icons.format_quote_outlined, l10n.t(az: 'Epiqraf', en: 'Epigraph', ru: 'Эпиграф', ar: 'تصدير'), 'epigraph'),
              item(Icons.article_outlined, l10n.t(az: 'Ön söz', en: 'Preface', ru: 'Предисловие', ar: 'مقدمة'), 'preface'),
              item(Icons.first_page_rounded, l10n.t(az: 'Proloq', en: 'Prologue', ru: 'Пролог', ar: 'استهلال'), 'prologue'),
              item(Icons.more_horiz_rounded, l10n.t(az: 'Səhnə ayırıcı (* * *)', en: 'Scene break (* * *)', ru: 'Разрыв сцены (* * *)', ar: 'فاصل مشهد (* * *)'), 'sceneBreak'),
              item(Icons.last_page_rounded, l10n.t(az: 'Epiloq', en: 'Epilogue', ru: 'Эпилог', ar: 'خاتمة'), 'epilogue'),
              item(Icons.history_edu_outlined, l10n.t(az: 'Son söz', en: 'Afterword', ru: 'Послесловие', ar: 'كلمة ختامية'), 'afterword'),
              item(Icons.volunteer_activism_outlined, l10n.t(az: 'Təşəkkür', en: 'Acknowledgements', ru: 'Благодарности', ar: 'شكر وتقدير'), 'acknowledgements'),
              item(Icons.person_outline_rounded, l10n.t(az: 'Müəllif haqqında', en: 'About the author', ru: 'Об авторе', ar: 'عن المؤلف'), 'aboutAuthor'),
              item(Icons.translate_rounded, l10n.t(az: 'Lüğət', en: 'Glossary', ru: 'Глоссарий', ar: 'مسرد'), 'glossary'),
              item(Icons.library_books_outlined, l10n.t(az: 'Biblioqrafiya', en: 'Bibliography', ru: 'Библиография', ar: 'المراجع'), 'bibliography'),
            ],
          ),
          group(
            l10n.t(az: 'Yazıçı planı', en: 'Writer\'s plan', ru: 'План писателя', ar: 'خطة الكاتب'),
            [
              item(Icons.groups_outlined, l10n.t(az: 'Personaj cədvəli', en: 'Characters table', ru: 'Таблица персонажей', ar: 'جدول الشخصيات'), 'cast'),
              item(Icons.place_outlined, l10n.t(az: 'Məkan cədvəli', en: 'Places table', ru: 'Таблица мест', ar: 'جدول الأماكن'), 'places'),
              item(Icons.timeline_rounded, l10n.t(az: 'Xronologiya', en: 'Timeline', ru: 'Хронология', ar: 'التسلسل الزمني'), 'timeline'),
              item(Icons.movie_outlined, l10n.t(az: 'Səhnə cədvəli', en: 'Scenes table', ru: 'Таблица сцен', ar: 'جدول المشاهد'), 'scenes'),
              item(Icons.view_list_outlined, l10n.t(az: 'Fəsil planı', en: 'Chapter outline', ru: 'План глав', ar: 'مخطط الفصول'), 'outline'),
              item(Icons.science_outlined, l10n.t(az: 'Tədqiqat qeydləri', en: 'Research notes', ru: 'Исследования', ar: 'ملاحظات البحث'), 'research'),
              item(Icons.style_outlined, l10n.t(az: 'Səhnə kartı', en: 'Scene card', ru: 'Карточка сцены', ar: 'بطاقة مشهد'), 'sceneCard'),
              item(Icons.account_tree_outlined, l10n.t(az: 'Üç pərdəli plan', en: 'Three-act outline', ru: 'Трёхактный план', ar: 'مخطط ثلاثي الفصول'), 'acts'),
              item(Icons.sticky_note_2_outlined, l10n.t(az: 'Kitab qeydləri', en: 'Book notes', ru: 'Заметки книги', ar: 'ملاحظات الكتاب'), 'bookNotes'),
              item(Icons.manage_search_rounded, l10n.t(az: 'Ad indeksi', en: 'Name index', ru: 'Указатель имён', ar: 'فهرس الأسماء'), 'nameIndex'),
            ],
          ),
          group(
            l10n.t(az: 'Mətn', en: 'Text', ru: 'Текст', ar: 'النص'),
            [
              item(Icons.text_increase_rounded, l10n.t(az: 'BÖYÜK HƏRF', en: 'UPPERCASE', ru: 'ПРОПИСНЫЕ', ar: 'أحرف كبيرة'), 'caseUpper'),
              item(Icons.text_decrease_rounded, l10n.t(az: 'kiçik hərf', en: 'lowercase', ru: 'строчные', ar: 'أحرف صغيرة'), 'caseLower'),
              item(Icons.title_rounded, l10n.t(az: 'Hər Söz Böyük', en: 'Title Case', ru: 'Каждое Слово', ar: 'كل كلمة بحرف كبير'), 'caseTitle'),
              item(Icons.format_quote_rounded, l10n.t(az: '«Dırnağa al»', en: 'Wrap in «quotes»', ru: 'В «кавычки»', ar: 'بين «علامتي تنصيص»'), 'wrapQuotes'),
              item(Icons.data_array_rounded, l10n.t(az: '(Mötərizəyə al)', en: 'Wrap in (brackets)', ru: 'В (скобки)', ar: 'بين (قوسين)'), 'wrapParens'),
              item(Icons.center_focus_strong_outlined, l10n.t(az: 'Fokus rejimi', en: 'Focus mode', ru: 'Режим фокуса', ar: 'وضع التركيز'), 'focusMode'),
              item(Icons.refresh_rounded, l10n.t(az: 'Mündəricatı yenilə', en: 'Refresh TOC', ru: 'Обновить оглавление', ar: 'تحديث الفهرس'), 'tocRefresh'),
              item(Icons.call_split_rounded, l10n.t(az: 'Fəsli kursordan böl', en: 'Split chapter at cursor', ru: 'Разделить главу', ar: 'تقسيم الفصل عند المؤشر'), 'splitChapter'),
              item(Icons.format_list_numbered_rounded, l10n.t(az: 'Fəsilləri nömrələ', en: 'Renumber chapters', ru: 'Перенумеровать главы', ar: 'إعادة ترقيم الفصول'), 'renumber'),
            ],
          ),
          group(
            l10n.t(az: 'Səhifə', en: 'Page', ru: 'Страница', ar: 'الصفحة'),
            [
              item(Icons.border_top_rounded, l10n.t(az: 'Başlıq və altlıq', en: 'Header & footer', ru: 'Колонтитулы', ar: 'الرأس والتذييل'), 'headerFooter'),
              item(Icons.format_list_numbered_rounded, l10n.t(az: 'Səhifə nömrələri', en: 'Page numbers', ru: 'Номера страниц', ar: 'أرقام الصفحات'), 'pageNumbers'),
              item(Icons.format_line_spacing_rounded, l10n.t(az: 'Sətir aralığı', en: 'Line spacing', ru: 'Межстрочный интервал', ar: 'تباعد الأسطر'), 'lineSpacing'),
              item(Icons.crop_free_rounded, l10n.t(az: 'Kənarlar', en: 'Margins', ru: 'Поля', ar: 'الهوامش'), 'margins'),
            ],
          ),
          item(
            Icons.search_rounded,
            l10n.t(az: 'Tap və əvəz et', en: 'Find and replace', ru: 'Найти и заменить', ar: 'بحث واستبدال'),
            'find',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _handleInsertKey(String key) {
    _syncCursorFromCanvas();
    switch (key) {
      case 'copyright':
        _insertCopyright();
        break;
      case 'dedication':
        _insertDedication();
        break;
      case 'epigraph':
        _insertEpigraph();
        break;
      case 'preface':
        _insertPreface();
        break;
      case 'prologue':
        _insertPrologue();
        break;
      case 'sceneBreak':
        _insertSceneBreak();
        break;
      case 'epilogue':
        _insertEpilogue();
        break;
      case 'afterword':
        _insertAfterword();
        break;
      case 'acknowledgements':
        _insertAcknowledgements();
        break;
      case 'aboutAuthor':
        _insertAboutAuthor();
        break;
      case 'glossary':
        _insertGlossary();
        break;
      case 'bibliography':
        _insertBibliography();
        break;
      case 'cast':
        _insertCastTable();
        break;
      case 'places':
        _insertPlacesTable();
        break;
      case 'timeline':
        _insertTimelineTable();
        break;
      case 'scenes':
        _insertSceneTable();
        break;
      case 'outline':
        _insertOutlineTable();
        break;
      case 'research':
        _insertResearchTable();
        break;
      case 'sceneCard':
        _insertSceneCard();
        break;
      case 'acts':
        _insertOutlineActs();
        break;
      case 'bookNotes':
        _showBookNotes();
        break;
      case 'nameIndex':
        _showNameIndex();
        break;
      case 'headerFooter':
        _showHeaderFooterDialog();
        break;
      case 'lineSpacing':
        _showLineSpacingPicker();
        break;
      case 'margins':
        _showMarginsPicker();
        break;
      case 'image':
        _pickImage();
        break;
      case 'table':
        _insertTable();
        break;
      case 'link':
        _insertLink();
        break;
      case 'pageBreak':
        _insertAtCursor('\n\n--- Page Break ---\n\n');
        break;
      case 'marginNote':
        _insertMarginNote();
        break;
      case 'hline':
        _insertAtCursor('\n--------------------\n');
        break;
      case 'toc':
        _insertTableOfContents();
        break;
      case 'settings':
        _openDocumentSettings();
        break;
      case 'cover':
        _openCoverGallery();
        break;
      case 'pageNumbers':
        _showPageNumberOptions();
        break;
      case 'find':
        _showFindReplace();
        break;
      case 'chapters':
        _showChaptersPanel();
        break;
      case 'h1':
        _applyStyle('h1');
        break;
      case 'quote':
        _applyStyle('quote');
        break;
      case 'chapter':
        _insertChapterHeading();
        break;
      case 'part':
        _insertPart();
        break;
      case 'footnote':
        _insertFootnote();
        break;
      case 'caseUpper':
        _transformCase('upper');
        break;
      case 'caseLower':
        _transformCase('lower');
        break;
      case 'caseTitle':
        _transformCase('title');
        break;
      case 'wrapQuotes':
        _wrapSelection('«', '»');
        break;
      case 'wrapParens':
        _wrapSelection('(', ')');
        break;
      case 'focusMode':
        _toggleFocusMode();
        break;
      case 'tocRefresh':
        _refreshTableOfContents();
        break;
      case 'splitChapter':
        _splitChapterAtCursor();
        break;
      case 'renumber':
        _renumberChapters();
        break;
      default:
        break;
    }
  }

  Widget _sheetTab(ThemeData theme, String label, bool isActive) {
    return SizedBox(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? AppTheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _colorTab(
    ThemeData theme,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primary : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A dashed line widget that marks the end of a page
class _PageBoundaryLine extends StatelessWidget {
  final PageSize pageSize;
  final int pageNumber;
  final int totalPages;

  const _PageBoundaryLine({
    required this.pageSize,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(double.infinity, 1),
          painter: _DashedLinePainter(),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withAlpha(20),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFE53E3E).withAlpha(60),
                ),
              ),
              child: Text(
                '— ${pageSize.label} · $pageNumber / $totalPages —',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  color: const Color(0xFFE53E3E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53E3E).withAlpha(180)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}
