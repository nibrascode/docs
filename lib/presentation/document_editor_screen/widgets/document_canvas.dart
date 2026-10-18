import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'book_cover_sheet.dart';
import 'table_editor_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/mobile_export_service.dart';

enum DocBlockKind { text, table, image, pageBreak, sceneBreak, hr, note, cover }

class DocBlock {
  DocBlockKind kind;
  String text;
  List<List<String>> cells;
  List<double> widths;
  String imagePath;
  double imageWidth;
  String imageAlign;
  String imageCaption;
  String tableCaption;

  DocBlock.text(this.text)
      : kind = DocBlockKind.text,
        cells = const [],
        widths = const [],
        imagePath = '',
        imageWidth = 0.85,
        imageAlign = 'center',
        imageCaption = '',
        tableCaption = '';

  DocBlock.table(this.cells, this.widths, {this.tableCaption = ''})
      : kind = DocBlockKind.table,
        text = '',
        imagePath = '',
        imageWidth = 0.85,
        imageAlign = 'center',
        imageCaption = '';

  DocBlock.image({
    required this.imagePath,
    this.imageWidth = 0.85,
    this.imageAlign = 'center',
    this.imageCaption = '',
  })  : kind = DocBlockKind.image,
        text = '',
        cells = const [],
        widths = const [],
        tableCaption = '';

  DocBlock.pageBreak()
      : kind = DocBlockKind.pageBreak,
        text = '',
        cells = const [],
        widths = const [],
        imagePath = '',
        imageWidth = 0.85,
        imageAlign = 'center',
        imageCaption = '',
        tableCaption = '';

  DocBlock.sceneBreak()
      : kind = DocBlockKind.sceneBreak,
        text = '',
        cells = const [],
        widths = const [],
        imagePath = '',
        imageWidth = 0.85,
        imageAlign = 'center',
        imageCaption = '',
        tableCaption = '';

  DocBlock.hr()
      : kind = DocBlockKind.hr,
        text = '',
        cells = const [],
        widths = const [],
        imagePath = '',
        imageWidth = 0.85,
        imageAlign = 'center',
        imageCaption = '',
        tableCaption = '';

  DocBlock.note(this.text)
      : kind = DocBlockKind.note,
        cells = const [],
        widths = const [],
        imagePath = '',
        imageWidth = 0.85,
        imageAlign = 'center',
        imageCaption = '',
        tableCaption = '';

  DocBlock.cover(this.text)
      : kind = DocBlockKind.cover,
        cells = const [],
        widths = const [],
        imagePath = '',
        imageWidth = 0.85,
        imageAlign = 'center',
        imageCaption = '',
        tableCaption = '';
}

class DocumentBlocks {
  static final _splitter = RegExp(
    r'(\[TABLE\][\s\S]*?\[/TABLE\])'
    r'|(\[img path="[^"]*"[^\]]*\])'
    r'|(--- Page Break ---)'
    r'|(\n[ \t]*\* \* \*[ \t]*\n)'
    r'|(\n-{12,}\n)'
    r'|(\[note\][\s\S]*?\[/note\])'
    r'|(\[HAŞİYƏ\][\s\S]*?\[/HAŞİYƏ\])'
    r'|(\[COVER[^\]]*\])',
  );

  static List<DocBlock> parse(String raw) {
    if (raw.isEmpty) return [DocBlock.text('')];
    final blocks = <DocBlock>[];
    var cursor = 0;
    for (final m in _splitter.allMatches(raw)) {
      if (m.start > cursor) {
        blocks.add(DocBlock.text(raw.substring(cursor, m.start)));
      }
      final s = m.group(0)!;
      if (s.contains('[TABLE]')) {
        final tb = TableBlock.allIn(s);
        if (tb.isNotEmpty) {
          blocks.add(DocBlock.table(
            tb.first.cells.map((r) => List<String>.from(r)).toList(),
            List<double>.from(tb.first.colWidths),
            tableCaption: tb.first.caption,
          ));
        }
      } else if (s.startsWith('[img')) {
        final path = RegExp(r'path="([^"]+)"').firstMatch(s)?.group(1) ?? '';
        final w = double.tryParse(
              RegExp(r'w=([0-9.]+)').firstMatch(s)?.group(1) ?? '',
            ) ??
            0.85;
        final align =
            RegExp(r'align=(left|center|right)').firstMatch(s)?.group(1) ??
                'center';
        final caption =
            RegExp(r'caption="([^"]*)"').firstMatch(s)?.group(1) ?? '';
        blocks.add(DocBlock.image(
          imagePath: path,
          imageWidth: w,
          imageAlign: align,
          imageCaption: caption,
        ));
      } else if (s.contains('Page Break')) {
        blocks.add(DocBlock.pageBreak());
      } else if (s.contains('* * *')) {
        blocks.add(DocBlock.sceneBreak());
      } else if (s.contains('[note]') || s.contains('[HAŞİYƏ]')) {
        final inner = s
            .replaceAll('[note]', '')
            .replaceAll('[/note]', '')
            .replaceAll('[HAŞİYƏ]', '')
            .replaceAll('[/HAŞİYƏ]', '')
            .trim();
        blocks.add(DocBlock.note(inner));
      } else if (s.contains('[COVER')) {
        blocks.add(DocBlock.cover(s.trim()));
      } else {
        blocks.add(DocBlock.hr());
      }
      cursor = m.end;
    }
    if (cursor < raw.length) {
      blocks.add(DocBlock.text(raw.substring(cursor)));
    }
    if (blocks.isEmpty) blocks.add(DocBlock.text(''));
    return blocks;
  }

  /// Inverse of [parse]. Idempotent: serialize(parse(serialize(x))) is
  /// stable, so opening and saving a document never adds blank lines.
  /// Newlines that the parser keeps in neighbouring text blocks are not
  /// written again; only those the block pattern itself consumes are.
  static String serialize(List<DocBlock> blocks) {
    final buf = StringBuffer();
    for (final b in blocks) {
      switch (b.kind) {
        case DocBlockKind.text:
          buf.write(b.text);
          break;
        case DocBlockKind.table:
          buf.write(TableBlock(
            start: 0,
            end: 0,
            cells: b.cells,
            colWidths: b.widths,
            caption: b.tableCaption,
          ).toMarkup().trimRight());
          break;
        case DocBlockKind.image:
          var s =
              '[img path="${b.imagePath}" w=${b.imageWidth.toStringAsFixed(2)} align=${b.imageAlign}';
          if (b.imageCaption.isNotEmpty) {
            s += ' caption="${b.imageCaption.replaceAll('"', "'")}"';
          }
          s += ']';
          buf.write(s);
          break;
        case DocBlockKind.pageBreak:
          buf.write('--- Page Break ---');
          break;
        case DocBlockKind.sceneBreak:
          buf.write('\n* * *\n');
          break;
        case DocBlockKind.hr:
          buf.write('\n--------------------\n');
          break;
        case DocBlockKind.note:
          buf.write('[note]${b.text}[/note]');
          break;
        case DocBlockKind.cover:
          buf.write(b.text);
          break;
      }
    }
    return buf.toString();
  }
}

class DocumentCanvas extends StatefulWidget {
  final String text;
  final ValueChanged<String> onChanged;
  final String hint;
  final TextStyle style;
  final TextAlign textAlign;
  final bool readOnly;
  final bool firstLineIndent;
  final Future<void> Function(int tableIndex) onEditTable;
  final void Function(int tableIndex) onDeleteTable;
  final Future<void> Function(int imageIndex) onEditImage;
  final void Function(int imageIndex) onDeleteImage;
  final double pageAspect;
  final VoidCallback? onEditCover;

  const DocumentCanvas({
    super.key,
    required this.text,
    required this.onChanged,
    required this.hint,
    required this.style,
    required this.textAlign,
    required this.readOnly,
    this.firstLineIndent = false,
    required this.onEditTable,
    required this.onDeleteTable,
    required this.onEditImage,
    required this.onDeleteImage,
    this.pageAspect = 1.414,
    this.onEditCover,
  });

  @override
  State<DocumentCanvas> createState() => DocumentCanvasState();
}

class DocumentCanvasState extends State<DocumentCanvas> {
  late List<DocBlock> _blocks;
  late List<TextEditingController> _textCtrls;
  String _lastEmitted = '';
  int _tableOrdinal = 0;
  int _imageOrdinal = 0;
  int? _focusTextIndex;
  TextSelection? _savedSel;
  TextEditingController? _activeCtrl;
  void Function(String align)? _aligner;
  int Function({bool base})? _cursorFn;
  DocBlock? _cursorBlock;

  /// Cursor offset in the full serialized document, or null if no text
  /// paragraph has been focused yet.
  String serialized() => DocumentBlocks.serialize(_blocks);

  /// Selection (base..extent) in serialized-document offsets.
  TextSelection? globalSelection() {
    final e = globalCursor();
    final b = globalCursor(base: true);
    if (e == null || b == null) return null;
    return TextSelection(baseOffset: b, extentOffset: e);
  }

  int? globalCursor({bool base = false}) {
    final fn = _cursorFn;
    final blk = _cursorBlock;
    if (fn == null || blk == null) return null;
    final idx = _blocks.indexOf(blk);
    if (idx < 0) return null;
    final prefix = DocumentBlocks.serialize(_blocks.sublist(0, idx)).length;
    return prefix + fn(base: base);
  }

  bool alignFocused(String align) {
    final fn = _aligner;
    if (fn == null) return false;
    fn(align);
    return true;
  }

  @override
  void initState() {
    super.initState();
    _adopt(widget.text);
  }

  @override
  void didUpdateWidget(DocumentCanvas old) {
    super.didUpdateWidget(old);
    if (widget.text != _lastEmitted) {
      _disposeText();
      _adopt(widget.text);
    }
  }

  void _adopt(String raw) {
    _blocks = DocumentBlocks.parse(raw);
    _textCtrls = [];
    for (final b in _blocks) {
      if (b.kind == DocBlockKind.text || b.kind == DocBlockKind.note) {
        final c = MarkupTextController(text: b.text);
        c.addListener(_onText);
        _textCtrls.add(c);
      }
    }
    _lastEmitted = DocumentBlocks.serialize(_blocks);
  }

  void _disposeText() {
    for (final c in _textCtrls) {
      c.dispose();
    }
    _textCtrls = [];
  }

  @override
  void dispose() {
    _disposeText();
    super.dispose();
  }

  void _onText() {
    var ti = 0;
    for (final b in _blocks) {
      if (b.kind == DocBlockKind.text || b.kind == DocBlockKind.note) {
        final c = _textCtrls[ti];
        if (c.selection.isValid && !c.selection.isCollapsed) {
          _focusTextIndex = ti;
          _savedSel = c.selection;
        }
        b.text = c.text;
        ti++;
      }
    }
    _emit();
  }

  /// Bold / italic / color only on the text the user selected.
  bool wrapFocused(String left, String right) {
    final c = _activeCtrl ??
        ((_focusTextIndex != null && _focusTextIndex! < _textCtrls.length)
            ? _textCtrls[_focusTextIndex!]
            : null);
    if (c == null) return false;
    var sel = c.selection;
    if (!sel.isValid || sel.isCollapsed) {
      sel = _savedSel ?? sel;
    }
    if (!sel.isValid || sel.isCollapsed) return false;
    var start = sel.start.clamp(0, c.text.length);
    var end = sel.end.clamp(0, c.text.length);
    if (end < start) {
      final t = start;
      start = end;
      end = t;
    }
    final selected = c.text.substring(start, end);
    String next;
    if (selected.startsWith(left) &&
        selected.endsWith(right) &&
        selected.length >= left.length + right.length) {
      next = selected.substring(left.length, selected.length - right.length);
    } else {
      next = '$left$selected$right';
    }
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, next),
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + next.length,
      ),
    );
    _savedSel = c.selection;
    _onText();
    return true;
  }

  Future<void> _colorMenu() async {
    final l10n = AppLocalizations.of(context);
    final colors = <Color>[
      const Color(0xFF1A1A1A),
      const Color(0xFFB42318),
      const Color(0xFFB54708),
      const Color(0xFF027A48),
      const Color(0xFF175CD3),
      const Color(0xFF6941C6),
      const Color(0xFFC9A84C),
    ];
    final picked = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in colors)
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    final hex =
        '#${picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    if (!wrapFocused('[color=$hex]', '[/color]')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t(
            az: 'Əvvəl mətni seçin',
            en: 'Select text first',
            ru: 'Сначала выделите текст',
            ar: 'حدد النص أولاً',
          )),
        ),
      );
    }
  }

  void _emit() {
    final s = DocumentBlocks.serialize(_blocks);
    _lastEmitted = s;
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    _tableOrdinal = 0;
    _imageOrdinal = 0;
    var textIndex = 0;
    final children = <Widget>[];
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      switch (b.kind) {
        case DocBlockKind.text:
          final ctrl = _textCtrls[textIndex++];
          children.add(
            _ParagraphEditor(
              master: ctrl,
              style: widget.style,
              readOnly: widget.readOnly,
              hint: children.isEmpty ? widget.hint : null,
              firstLineIndent: widget.firstLineIndent,
              onActive: (c) => _activeCtrl = c,
              onBindAlign: (fn) => _aligner = fn,
              onBindCursor: (fn) {
                _cursorFn = fn;
                _cursorBlock = b;
              },
              onColor: _colorMenu,
              onWrap: wrapFocused,
            ),
          );
          break;
        case DocBlockKind.note:
          final nctrl = _textCtrls[textIndex++];
          children.add(
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 120,
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFC9A84C), width: 1.5),
                  ),
                  color: Color(0xFFFFF8E7),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haşiyə',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A6A1A),
                      ),
                    ),
                    TextField(
                      controller: nctrl,
                      readOnly: widget.readOnly,
                      maxLines: null,
                      style: GoogleFonts.lora(
                        fontSize: 11,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF3A2A10),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Kənar qeyd yazın…',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          break;
        case DocBlockKind.table:
          final tIndex = _tableOrdinal++;
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _VisualTable(
                cells: b.cells,
                widths: b.widths,
                caption: b.tableCaption,
                readOnly: widget.readOnly,
                onOpenEditor: () => widget.onEditTable(tIndex),
                onDeleteTable: () => widget.onDeleteTable(tIndex),
                onCaptionChanged: (v) {
                  b.tableCaption = v;
                  _emit();
                },
                onCellChanged: (r, c, v) {
                  while (b.cells.length <= r) {
                    b.cells.add(List.filled(
                      b.cells.isEmpty ? 1 : b.cells.first.length,
                      '',
                    ));
                  }
                  while (b.cells[r].length <= c) {
                    b.cells[r].add('');
                  }
                  b.cells[r][c] = v;
                  _emit();
                },
                onInsertRow: (at) {
                  final cols = b.cells.isEmpty ? 3 : b.cells.first.length;
                  final i = at.clamp(0, b.cells.length);
                  b.cells.insert(i, List.filled(cols, ''));
                  setState(_emit);
                },
                onDuplicateRow: (at) {
                  if (b.cells.isEmpty) return;
                  final i = at.clamp(0, b.cells.length - 1);
                  b.cells.insert(i + 1, List<String>.from(b.cells[i]));
                  setState(_emit);
                },
                onDeleteRow: (at) {
                  if (b.cells.length <= 1) return;
                  b.cells.removeAt(at.clamp(0, b.cells.length - 1));
                  setState(_emit);
                },
                onInsertCol: (at) {
                  if (b.cells.isEmpty) {
                    b.cells.add(['', '']);
                    b.widths
                      ..clear()
                      ..addAll([1, 1]);
                  } else {
                    final i = at.clamp(0, b.cells.first.length);
                    for (final row in b.cells) {
                      row.insert(i, '');
                    }
                    b.widths.insert(i.clamp(0, b.widths.length), 1);
                  }
                  setState(_emit);
                },
                onDeleteCol: (at) {
                  if (b.cells.isEmpty || b.cells.first.length <= 1) return;
                  final i = at.clamp(0, b.cells.first.length - 1);
                  for (final row in b.cells) {
                    if (i < row.length) row.removeAt(i);
                  }
                  if (i < b.widths.length) b.widths.removeAt(i);
                  setState(_emit);
                },
                onPasteGrid: (r, c, grid) {
                  if (grid.isEmpty) return;
                  if (b.cells.isEmpty) {
                    b.cells.addAll(
                      grid.map((row) => List<String>.from(row)),
                    );
                    b.widths
                      ..clear()
                      ..addAll(List.filled(grid.first.length, 1.0));
                    setState(_emit);
                    return;
                  }
                  final extraCols = grid.fold<int>(
                    0,
                    (a, row) => row.length > a ? row.length : a,
                  );
                  final needCols = c + extraCols;
                  final needRows = r + grid.length;
                  final curCols = b.cells.first.length;
                  if (needCols > curCols) {
                    final add = needCols - curCols;
                    for (final row in b.cells) {
                      row.addAll(List.filled(add, ''));
                    }
                    b.widths.addAll(List.filled(add, 1.0));
                  }
                  while (b.cells.length < needRows) {
                    b.cells.add(List.filled(b.cells.first.length, ''));
                  }
                  for (var i = 0; i < grid.length; i++) {
                    for (var j = 0; j < grid[i].length; j++) {
                      final rr = r + i;
                      final cc = c + j;
                      if (rr < b.cells.length && cc < b.cells[rr].length) {
                        b.cells[rr][cc] = grid[i][j];
                      }
                    }
                  }
                  setState(_emit);
                },
                onColWidth: (col, delta) {
                  while (b.widths.length <= col) {
                    b.widths.add(1.0);
                  }
                  b.widths[col] = (b.widths[col] + delta).clamp(0.5, 2.5);
                  setState(_emit);
                },
              ),
            ),
          );
          break;
        case DocBlockKind.image:
          final iIndex = _imageOrdinal++;
          children.add(_imageBlock(b, iIndex));
          break;
        case DocBlockKind.pageBreak:
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFC9A84C))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Səhifə sonu',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFFC9A84C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFC9A84C))),
                ],
              ),
            ),
          );
          break;
        case DocBlockKind.sceneBreak:
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '*   *   *',
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 16,
                  letterSpacing: 6,
                  color: const Color(0xFF0D1B3E),
                ),
              ),
            ),
          );
          break;
        case DocBlockKind.hr:
          children.add(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(thickness: 1, color: Color(0xFFDDE1EE)),
            ),
          );
          break;
        case DocBlockKind.cover:
          final parsed = CoverData.parse(b.text);
          if (parsed != null) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LayoutBuilder(
                  builder: (ctx, c) {
                    final w = c.maxWidth;
                    final h = w * widget.pageAspect;
                    return CoverPagePreview(
                      template: coverById(parsed.templateId),
                      data: parsed,
                      width: w,
                      height: h,
                      onTap: widget.readOnly ? null : widget.onEditCover,
                    );
                  },
                ),
              ),
            );
          }
          break;
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _imageBlock(DocBlock b, int index) {
    final f = MobileExportService.resolveImage(b.imagePath);
    final l10n = AppLocalizations.of(context);
    AlignmentGeometry al = Alignment.center;
    if (b.imageAlign == 'left') al = Alignment.centerLeft;
    if (b.imageAlign == 'right') al = Alignment.centerRight;

    Future<void> manage() async {
      if (widget.readOnly) return;
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: Text(l10n.t(
                  az: 'Ölçü / izah / mövqe',
                  en: 'Size / caption / position',
                  ru: 'Размер / подпись / позиция',
                  ar: 'الحجم / التعليق / الموضع',
                )),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFB42318)),
                title: Text(
                  l10n.t(az: 'Sil', en: 'Delete', ru: 'Удалить', ar: 'حذف'),
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      );
      if (action == 'edit') {
        await widget.onEditImage(index);
      } else if (action == 'delete') {
        widget.onDeleteImage(index);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Align(
            alignment: al,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: manage,
                  onLongPress: manage,
                  child: f.existsSync()
                      ? Image.file(
                          f,
                          width: MediaQuery.of(context).size.width *
                              b.imageWidth *
                              0.72,
                          fit: BoxFit.contain,
                        )
                      : Container(
                          height: 80,
                          alignment: Alignment.center,
                          color: const Color(0xFFEEF1F8),
                          child: Text(l10n.t(
                            az: 'Şəkil tapılmadı',
                            en: 'Image not found',
                            ru: 'Изображение не найдено',
                            ar: 'الصورة غير موجودة',
                          )),
                        ),
                ),
                if (!widget.readOnly)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: const Color(0xFF0D1B3E),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: manage,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.key_rounded,
                            size: 16,
                            color: Color(0xFFC9A84C),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (b.imageCaption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                b.imageCaption,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _VisualTable extends StatefulWidget {
  final List<List<String>> cells;
  final List<double> widths;
  final String caption;
  final bool readOnly;
  final VoidCallback onOpenEditor;
  final VoidCallback onDeleteTable;
  final ValueChanged<String> onCaptionChanged;
  final void Function(int row, int col, String value) onCellChanged;
  final void Function(int at) onInsertRow;
  final void Function(int at) onDuplicateRow;
  final void Function(int at) onDeleteRow;
  final void Function(int at) onInsertCol;
  final void Function(int at) onDeleteCol;
  final void Function(int row, int col, List<List<String>> grid) onPasteGrid;
  final void Function(int col, double delta) onColWidth;

  const _VisualTable({
    required this.cells,
    required this.widths,
    required this.caption,
    required this.readOnly,
    required this.onOpenEditor,
    required this.onDeleteTable,
    required this.onCaptionChanged,
    required this.onCellChanged,
    required this.onInsertRow,
    required this.onDuplicateRow,
    required this.onDeleteRow,
    required this.onInsertCol,
    required this.onDeleteCol,
    required this.onPasteGrid,
    required this.onColWidth,
  });

  @override
  State<_VisualTable> createState() => _VisualTableState();
}

class _VisualTableState extends State<_VisualTable> {
  late List<List<TextEditingController>> _ctrls;
  late List<List<FocusNode>> _nodes;
  late TextEditingController _capCtrl;
  int _selR = 0;
  int _selC = 0;

  @override
  void initState() {
    super.initState();
    _capCtrl = TextEditingController(text: widget.caption);
    _buildCtrls();
  }

  @override
  void didUpdateWidget(_VisualTable old) {
    super.didUpdateWidget(old);
    final oldR = _ctrls.length;
    final oldC = oldR == 0 ? 0 : _ctrls.first.length;
    final newR = widget.cells.length;
    final newC = newR == 0 ? 0 : widget.cells.first.length;
    if (oldR != newR || oldC != newC) {
      _disposeCtrls();
      _buildCtrls();
      _selR = _selR.clamp(0, newR == 0 ? 0 : newR - 1);
      _selC = _selC.clamp(0, newC == 0 ? 0 : newC - 1);
    } else {
      for (var r = 0; r < newR; r++) {
        for (var c = 0; c < newC && c < _ctrls[r].length; c++) {
          if (!_nodes[r][c].hasFocus &&
              _ctrls[r][c].text != widget.cells[r][c]) {
            _ctrls[r][c].text = widget.cells[r][c];
          }
        }
      }
    }
    if (widget.caption != _capCtrl.text && !_capCtrl.selection.isValid) {
      _capCtrl.text = widget.caption;
    }
  }

  void _buildCtrls() {
    _nodes = List.generate(widget.cells.length, (r) {
      return List.generate(widget.cells[r].length, (c) => FocusNode());
    });
    _ctrls = List.generate(widget.cells.length, (r) {
      return List.generate(widget.cells[r].length, (c) {
        return TextEditingController(text: widget.cells[r][c]);
      });
    });
  }

  void _disposeCtrls() {
    for (final row in _ctrls) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _nodes) {
      for (final n in row) {
        n.dispose();
      }
    }
  }

  @override
  void dispose() {
    _capCtrl.dispose();
    _disposeCtrls();
    super.dispose();
  }

  int get _rows => widget.cells.length;
  int get _cols =>
      widget.cells.fold<int>(0, (a, r) => r.length > a ? r.length : a);

  void _move(int dr, int dc) {
    if (_rows == 0 || _cols == 0) return;
    var r = _selR + dr;
    var c = _selC + dc;
    if (c >= _cols) {
      c = 0;
      r++;
    }
    if (c < 0) {
      c = _cols - 1;
      r--;
    }
    if (r < 0 || r >= _rows) return;
    setState(() {
      _selR = r;
      _selC = c;
    });
    if (r < _nodes.length && c < _nodes[r].length) {
      _nodes[r][c].requestFocus();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    if (raw.isEmpty) return;
    _applyPastedText(raw);
  }

  void _applyPastedText(String raw) {
    final grid = TableBlock.parseClipboardGrid(raw);
    if (grid != null &&
        (grid.length > 1 || (grid.isNotEmpty && grid.first.length > 1))) {
      widget.onPasteGrid(_selR, _selC, grid);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              '${grid.length}×${grid.first.length} xana yapışdırıldı',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (_selR < _ctrls.length && _selC < _ctrls[_selR].length) {
      _ctrls[_selR][_selC].text = raw;
      widget.onCellChanged(_selR, _selC, raw);
    }
  }

  void _copyTable() {
    final buf = StringBuffer();
    for (final row in widget.cells) {
      buf.writeln(row.join('\t'));
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Cədvəl kopyalandı — Excel / Sheets-ə yapışdırın'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyRow() {
    if (_selR < 0 || _selR >= widget.cells.length) return;
    Clipboard.setData(
      ClipboardData(text: widget.cells[_selR].join('\t')),
    );
  }

  Future<void> _openTableMenu() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE1EE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  l10n.t(az: 'Cədvəl', en: 'Table', ru: 'Таблица', ar: 'جدول'),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                _menuItem(ctx, Icons.add, l10n.t(az: 'Sətir əlavə et', en: 'Add row', ru: 'Добавить строку', ar: 'إضافة صف'), () {
                  widget.onInsertRow(_selR + 1);
                }),
                _menuItem(ctx, Icons.remove, l10n.t(az: 'Sətir sil', en: 'Delete row', ru: 'Удалить строку', ar: 'حذف صف'), () {
                  widget.onDeleteRow(_selR);
                }),
                _menuItem(ctx, Icons.view_week_outlined, l10n.t(az: 'Sütun əlavə et', en: 'Add column', ru: 'Добавить столбец', ar: 'إضافة عمود'), () {
                  widget.onInsertCol(_selC + 1);
                }),
                _menuItem(ctx, Icons.view_column_outlined, l10n.t(az: 'Sütun sil', en: 'Delete column', ru: 'Удалить столбец', ar: 'حذف عمود'), () {
                  widget.onDeleteCol(_selC);
                }),
                const Divider(height: 16),
                _menuItem(ctx, Icons.copy, l10n.t(az: 'Kopyala', en: 'Copy', ru: 'Копировать', ar: 'نسخ'), _copyTable),
                _menuItem(ctx, Icons.content_paste, l10n.t(az: 'Yapışdır', en: 'Paste', ru: 'Вставить', ar: 'لصق'), _pasteFromClipboard),
                _menuItem(ctx, Icons.edit_outlined, l10n.t(az: 'Düzəlt', en: 'Edit', ru: 'Изменить', ar: 'تعديل'), widget.onOpenEditor),
                _menuItem(
                  ctx,
                  Icons.delete_outline,
                  l10n.t(az: 'Cədvəli sil', en: 'Delete table', ru: 'Удалить таблицу', ar: 'حذف الجدول'),
                  widget.onDeleteTable,
                  danger: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFB42318) : const Color(0xFF0D1B3E);
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cells.isEmpty) return const SizedBox.shrink();
    final cols = _cols;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.tab): () => _move(0, 1),
            const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
                _move(0, -1),
            const SingleActivator(LogicalKeyboardKey.enter): () => _move(1, 0),
            const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
                () => _move(0, 1),
            const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
                () => _move(0, -1),
            const SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
                () => _move(1, 0),
            const SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
                () => _move(-1, 0),
            const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                () { _pasteFromClipboard(); },
            const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                () { _pasteFromClipboard(); },
          },
          child: Focus(
            child: LayoutBuilder(
              builder: (context, constraints) {
                var avail = constraints.maxWidth;
                if (!avail.isFinite || avail <= 0) {
                  avail = (MediaQuery.of(context).size.width - 48).clamp(160.0, 900.0);
                }
                final colW = List<double>.filled(cols, avail / cols);
                return Container(
                  width: avail,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF37474F),
                      width: 0.8,
                    ),
                  ),
                  child: Table(
                    border: const TableBorder(
                      horizontalInside: BorderSide(color: Color(0xFF37474F), width: 0.5),
                      verticalInside: BorderSide(color: Color(0xFF37474F), width: 0.5),
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: {
                      for (var c = 0; c < cols; c++) c: FixedColumnWidth(colW[c]),
                    },
                    children: List.generate(widget.cells.length, (r) {
                      return TableRow(
                        decoration: BoxDecoration(
                          color: r == 0
                              ? const Color(0xFF37474F)
                              : (r.isOdd
                                  ? const Color(0xFFEEEEEE)
                                  : Colors.white),
                        ),
                        children: List.generate(cols, (c) {
                              if (r >= _ctrls.length ||
                                  c >= _ctrls[r].length) {
                                return const SizedBox(height: 44);
                              }
                              final selected = r == _selR && c == _selC;
                              return GestureDetector(
                                onLongPress: widget.readOnly
                                    ? null
                                    : widget.onOpenEditor,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  decoration: selected && !widget.readOnly
                                      ? BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFC9A84C),
                                            width: 1.6,
                                          ),
                                        )
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: widget.readOnly
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            _ctrls[r][c].text,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              fontWeight: r == 0
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              color: r == 0
                                                  ? const Color(0xFFE8C97A)
                                                  : const Color(0xFF0D1B3E),
                                            ),
                                          ),
                                        )
                                      : TextField(
                                          controller: _ctrls[r][c],
                                          focusNode: _nodes[r][c],
                                          maxLines: 8,
                                          minLines: 1,
                                          textInputAction:
                                              TextInputAction.next,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            fontWeight: r == 0
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            color: r == 0
                                                ? const Color(0xFFFFE082)
                                                : const Color(0xFF1A1A1A),
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            hintText:
                                                r == 0 ? 'Başlıq' : 'Yaz…',
                                            hintStyle: TextStyle(
                                              color: r == 0
                                                  ? Colors.white38
                                                  : Colors.black26,
                                              fontSize: 12,
                                            ),
                                          ),
                                          onTap: () => setState(() {
                                            _selR = r;
                                            _selC = c;
                                          }),
                                          onChanged: (v) {
                                            final grid =
                                                TableBlock.parseClipboardGrid(v);
                                            if (grid != null &&
                                                (v.contains('\t') ||
                                                    v.contains('\n')) &&
                                                (grid.length > 1 ||
                                                    grid.first.length > 1)) {
                                              _ctrls[r][c].text =
                                                  widget.cells[r][c];
                                              widget.onPasteGrid(r, c, grid);
                                              return;
                                            }
                                            widget.onCellChanged(r, c, v);
                                          },
                                          onEditingComplete: () =>
                                              _move(0, 1),
                                        ),
                                ),
                              );
                            }),
                          );
                        }),
                      ),
                    );
              },
            ),
          ),
        ),
            if (!widget.readOnly)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: const Color(0xFF0D1B3E),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openTableMenu,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.key_rounded,
                        size: 16,
                        color: Color(0xFFC9A84C),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _capCtrl,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF5A6A8A),
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Cədvəl başlığı',
              hintStyle: TextStyle(fontSize: 12, color: Colors.black26),
            ),
            onChanged: widget.onCaptionChanged,
          ),
        ] else if (widget.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.caption,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
          ),
      ],
    );
  }

  Widget _tblBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF1F8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE1EE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF0D1B3E)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0D1B3E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _P {
  String align;
  final TextEditingController c;
  final FocusNode f = FocusNode();
  _P(this.align, this.c);
}

class _ParagraphEditor extends StatefulWidget {
  final TextEditingController master;
  final TextStyle style;
  final bool readOnly;
  final String? hint;
  final bool firstLineIndent;
  final void Function(TextEditingController c) onActive;
  final void Function(void Function(String align) fn) onBindAlign;
  final VoidCallback onColor;
  final bool Function(String left, String right) onWrap;
  final void Function(int Function({bool base}) masterCursor) onBindCursor;

  const _ParagraphEditor({
    required this.master,
    required this.style,
    required this.readOnly,
    required this.hint,
    required this.firstLineIndent,
    required this.onActive,
    required this.onBindAlign,
    required this.onColor,
    required this.onWrap,
    required this.onBindCursor,
  });

  @override
  State<_ParagraphEditor> createState() => _ParagraphEditorState();
}

class _ParagraphEditorState extends State<_ParagraphEditor> {
  final List<_P> _paras = [];
  int _focus = 0;
  bool _writing = false;

  static final _alignRe = RegExp(r'^\[align=(left|center|right|justify)\]');

  @override
  void initState() {
    super.initState();
    _load(widget.master.text);
    widget.master.addListener(_onMaster);
  }

  /// This block became the active one: route align / cursor queries here.
  void _activate(int i) {
    _focus = i;
    widget.onActive(_paras[i].c);
    widget.onBindAlign(_applyAlign);
    widget.onBindCursor(_masterCursor);
  }

  /// Cursor position inside the master text of this block.
  int _masterCursor({bool base = false}) {
    if (_paras.isEmpty) return 0;
    final i = _focus.clamp(0, _paras.length - 1);
    var off = 0;
    for (var k = 0; k < i; k++) {
      final p = _paras[k];
      off += (p.align == 'left' ? 0 : '[align=${p.align}]'.length) + p.c.text.length + 2;
    }
    final p = _paras[i];
    off += p.align == 'left' ? 0 : '[align=${p.align}]'.length;
    final sel = p.c.selection;
    off += sel.isValid ? (base ? sel.baseOffset : sel.extentOffset).clamp(0, p.c.text.length) : p.c.text.length;
    return off;
  }

  @override
  void didUpdateWidget(covariant _ParagraphEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.master != widget.master) {
      oldWidget.master.removeListener(_onMaster);
      widget.master.addListener(_onMaster);
      _load(widget.master.text);
    }
  }

  @override
  void dispose() {
    widget.master.removeListener(_onMaster);
    for (final p in _paras) {
      p.c.removeListener(_onPara);
      p.c.dispose();
      p.f.dispose();
    }
    super.dispose();
  }

  TextAlign _ta(String a) {
    switch (a) {
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

  _P _newP(String align, TextEditingController c) {
    final p = _P(align, c);
    p.f.addListener(() {
      if (p.f.hasFocus) {
        final i = _paras.indexOf(p);
        if (i >= 0) _activate(i);
      }
    });
    return p;
  }

  void _load(String raw) {
    for (final p in _paras) {
      p.c.removeListener(_onPara);
      p.c.dispose();
      p.f.dispose();
    }
    _paras.clear();
    final chunks = raw.isEmpty ? [''] : raw.split('\n\n');
    for (final chunk in chunks) {
      final m = _alignRe.firstMatch(chunk);
      final align = m?.group(1) ?? 'left';
      final body = m == null ? chunk : chunk.substring(m.end);
      final c = MarkupTextController(text: body);
      c.addListener(_onPara);
      _paras.add(_newP(align, c));
    }
    if (_focus >= _paras.length) _focus = _paras.length - 1;
  }

  String _dump() {
    return _paras.map((p) {
      if (p.align == 'left') return p.c.text;
      return '[align=${p.align}]${p.c.text}';
    }).join('\n\n');
  }

  void _push() {
    final joined = _dump();
    if (joined == widget.master.text) return;
    _writing = true;
    widget.master.text = joined;
    _writing = false;
  }

  void _onMaster() {
    if (_writing) return;
    if (_dump() == widget.master.text) return;
    setState(() => _load(widget.master.text));
  }

  void _onPara() {
    for (var i = 0; i < _paras.length; i++) {
      final sel = _paras[i].c.selection;
      if (sel.isValid && !sel.isCollapsed) {
        _activate(i);
      }
    }
    for (var i = 0; i < _paras.length; i++) {
      final t = _paras[i].c.text;
      if (t.contains('\n\n')) {
        final parts = t.split('\n\n');
        _paras[i].c.removeListener(_onPara);
        _paras[i].c.text = parts.first;
        _paras[i].c.addListener(_onPara);
        for (var k = 1; k < parts.length; k++) {
          final c = MarkupTextController(text: parts[k]);
          c.addListener(_onPara);
          _paras.insert(i + k, _newP(_paras[i].align, c));
        }
        _push();
        setState(() {});
        return;
      }
    }
    _push();
  }

  void _applyAlign(String align) {
    if (_paras.isEmpty) return;
    final i = _focus.clamp(0, _paras.length - 1);
    setState(() => _paras[i].align = align);
    _push();
  }

  Widget _menu(BuildContext ctx, EditableTextState editable) {
    final l10n = AppLocalizations.of(ctx);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editable.contextMenuAnchors,
      buttonItems: [
        ...editable.contextMenuButtonItems,
        ContextMenuButtonItem(
          label: l10n.t(az: 'Rəng', en: 'Color', ru: 'Цвет', ar: 'لون'),
          onPressed: () {
            ContextMenuController.removeAny();
            widget.onColor();
          },
        ),
        ContextMenuButtonItem(
          label: l10n.t(az: 'Qalın', en: 'Bold', ru: 'Жирный', ar: 'عريض'),
          onPressed: () {
            ContextMenuController.removeAny();
            widget.onWrap('**', '**');
          },
        ),
        ContextMenuButtonItem(
          label: l10n.t(az: 'Əyri', en: 'Italic', ru: 'Курсив', ar: 'مائل'),
          onPressed: () {
            ContextMenuController.removeAny();
            widget.onWrap('*', '*');
          },
        ),
        ContextMenuButtonItem(
          label: l10n.t(az: 'Xətt', en: 'Underline', ru: 'Подчёркнутый', ar: 'تسطير'),
          onPressed: () {
            ContextMenuController.removeAny();
            widget.onWrap('__', '__');
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _paras.length; i++)
          TextField(
            controller: _paras[i].c,
            focusNode: _paras[i].f,
            readOnly: widget.readOnly,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: widget.style,
            textAlign: _ta(_paras[i].align),
            contextMenuBuilder: _menu,
            onTap: () => _activate(i),
            decoration: InputDecoration(
              hintText: i == 0 ? widget.hint : null,
              hintStyle: widget.style.copyWith(color: Colors.black38),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: widget.firstLineIndent
                  ? const EdgeInsets.only(left: 22, bottom: 8)
                  : const EdgeInsets.only(bottom: 8),
              isDense: true,
            ),
          ),
      ],
    );
  }
}

class MarkupTextController extends TextEditingController {
  MarkupTextController({super.text});

  static final _inline = RegExp(
    r'\[color=(#[0-9A-Fa-f]{6,8})\]([\s\S]*?)\[/color\]'
    r'|\[bg=(#[0-9A-Fa-f]{6,8})\]([\s\S]*?)\[/bg\]'
    r'|\*\*(.+?)\*\*'
    r'|__(.+?)__'
    r'|~~(.+?)~~'
    r'|\*(.+?)\*'
    r'|\[\^(\d+)\]',
  );

  static final _tag = _inline;

  static Color? _hex(String? s) {
    if (s == null || s.isEmpty) return null;
    var h = s.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    return Color(int.parse(h, radix: 16));
  }

  static const _hidden = TextStyle(
    fontSize: 0.01,
    height: 0.01,
    color: Colors.transparent,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle(fontSize: 16, color: const Color(0xFF1A1A1A));
    final lines = text.split('\n');
    final children = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var lineStyle = base;
      var hide = 0;
      final fs = base.fontSize ?? 16;
      if (line.startsWith('### ')) {
        hide = 4;
        lineStyle = base.copyWith(fontSize: fs * 1.05, fontWeight: FontWeight.w700, height: 1.25);
      } else if (line.startsWith('## ')) {
        hide = 3;
        lineStyle = base.copyWith(fontSize: fs * 1.22, fontWeight: FontWeight.w700, height: 1.25);
      } else if (line.startsWith('# ')) {
        hide = 2;
        lineStyle = base.copyWith(fontSize: fs * 1.55, fontWeight: FontWeight.w700, height: 1.2);
      } else if (line.startsWith('> ')) {
        hide = 2;
        lineStyle = base.copyWith(fontStyle: FontStyle.italic, color: const Color(0xFF424242));
      } else if (RegExp(r'^\[\^\d+\]:').hasMatch(line)) {
        lineStyle = base.copyWith(
          fontSize: fs * 0.72,
          height: 1.25,
          color: const Color(0xFF333333),
        );
      }
      if (hide > 0 && hide <= line.length) {
        children.add(TextSpan(text: line.substring(0, hide), style: _hidden));
        line = line.substring(hide);
      }
      children.addAll(_inlineSpans(line, lineStyle));
      if (i < lines.length - 1) {
        children.add(TextSpan(text: '\n', style: lineStyle));
      }
    }
    return TextSpan(style: base, children: children);
  }

  List<InlineSpan> _inlineSpans(String src, TextStyle style) {
    if (!_inline.hasMatch(src)) {
      return [TextSpan(text: src, style: style)];
    }
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final m in _inline.allMatches(src)) {
      if (m.start > cursor) {
        children.add(TextSpan(text: src.substring(cursor, m.start), style: style));
      }
      void hideWrap(String open, String inner, TextStyle st) {
        children.add(TextSpan(text: open, style: _hidden));
        children.add(TextSpan(text: inner, style: st));
        children.add(TextSpan(text: open, style: _hidden));
      }

      if (m.group(1) != null) {
        children.add(TextSpan(text: '[color=${m.group(1)}]', style: _hidden));
        children.add(TextSpan(
          text: m.group(2) ?? '',
          style: style.copyWith(color: _hex(m.group(1))),
        ));
        children.add(const TextSpan(text: '[/color]', style: _hidden));
      } else if (m.group(3) != null) {
        children.add(TextSpan(text: '[bg=${m.group(3)}]', style: _hidden));
        children.add(TextSpan(
          text: m.group(4) ?? '',
          style: style.copyWith(backgroundColor: _hex(m.group(3))),
        ));
        children.add(const TextSpan(text: '[/bg]', style: _hidden));
      } else if (m.group(5) != null) {
        hideWrap('**', m.group(5)!, style.copyWith(fontWeight: FontWeight.w700));
      } else if (m.group(6) != null) {
        hideWrap('__', m.group(6)!, style.copyWith(decoration: TextDecoration.underline));
      } else if (m.group(7) != null) {
        hideWrap('~~', m.group(7)!, style.copyWith(decoration: TextDecoration.lineThrough));
      } else if (m.group(8) != null) {
        hideWrap('*', m.group(8)!, style.copyWith(fontStyle: FontStyle.italic));
      } else if (m.group(9) != null) {
        final fs = style.fontSize ?? 16;
        children.add(const TextSpan(text: '[^', style: _hidden));
        children.add(TextSpan(
          text: m.group(9),
          style: style.copyWith(
            fontSize: fs * 0.62,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8C1C13),
            height: 1,
          ),
        ));
        children.add(const TextSpan(text: ']', style: _hidden));
      }
      cursor = m.end;
    }
    if (cursor < src.length) {
      children.add(TextSpan(text: src.substring(cursor), style: style));
    }
    return children;
  }
}
