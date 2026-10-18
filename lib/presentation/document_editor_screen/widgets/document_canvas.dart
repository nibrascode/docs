import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/rich_markup.dart';
import '../../../core/rich_doc.dart';
import '../../../core/rich_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import 'book_cover_sheet.dart';
import 'table_editor_dialog.dart';
import '../../../core/table_spec.dart';
import '../../../core/toc.dart';
import '../../../core/page_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/mobile_export_service.dart';
import '../../../l10n/ui_strings.dart';

enum DocBlockKind { text, table, image, pageBreak, sceneBreak, hr, note, cover, toc }

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
  List<String> tableAligns = [];
  bool tableHeader = true;
  int tocLevels = 3;

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

  DocBlock.toc(this.text, this.tocLevels)
      : kind = DocBlockKind.toc,
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
    r'(\[TOC[^\]]*\][\s\S]*?\[/TOC\])'
    r'|(\[TABLE\][\s\S]*?\[/TABLE\])'
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
      if (s.startsWith('[TOC')) {
        final (title, lv) = TocSpec.parseMarker(s);
        blocks.add(DocBlock.toc(title, lv));
      } else if (s.contains('[TABLE]')) {
        final tb = TableBlock.allIn(s);
        if (tb.isNotEmpty) {
          blocks.add(DocBlock.table(
            tb.first.cells.map((r) => List<String>.from(r)).toList(),
            List<double>.from(tb.first.colWidths),
            tableCaption: tb.first.caption,
          )
            ..tableAligns = List<String>.from(tb.first.colAligns)
            ..tableHeader = tb.first.header);
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
            colAligns: b.tableAligns,
            header: b.tableHeader,
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
        case DocBlockKind.toc:
          buf.write(TocSpec.marker(b.text, b.tocLevels));
          break;
      }
    }
    return buf.toString();
  }
}

/// Start of a page as laid out by the page engine.
class PageStart {
  final int block; // DocumentBlocks index
  final int offset; // engine text offset of the paragraph (-1: block start)
  final int k; // visual line inside that paragraph
  final String label; // printed page number
  const PageStart(this.block, this.offset, this.k, this.label);

  static List<PageStart> fromLayout(DocLayout d) => [
        for (var i = 1; i < d.pages.length; i++)
          if (d.pages[i].startBlock >= 0)
            PageStart(d.pages[i].startBlock, d.pages[i].startOffset, d.pages[i].startK,
                d.pages[i].pageLabel.isNotEmpty ? d.pages[i].pageLabel : '${d.pages[i].physical}'),
      ];
}

/// Dashed page-end marker drawn where the PDF starts a new page.
class _PageEndLine extends StatelessWidget {
  final String label;
  const _PageEndLine({required this.label});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter()),
          ),
          Positioned(
            top: 2,
            right: 0,
            child: Text('— $label —',
                style: const TextStyle(fontSize: 9, color: Color(0xFFB54708), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xCCB54708)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
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
  /// Editor pixels per layout point (tables, rules and notes are drawn with
  /// the same point sizes as the page engine / PDF).
  final double pxPerPt;
  /// Headings with page numbers from the page engine (same as the PDF).
  final List<TocEntry> tocEntries;
  /// Where the page engine (= PDF) starts each page after the first.
  final List<PageStart> pageStarts;
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
    this.pxPerPt = 4 / 3,
    this.tocEntries = const [],
    this.pageStarts = const [],
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
  RichController? _activeCtrl;
  _ParagraphEditorState? _activeEd;
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
    final ed = _activeEd;
    final blk = _cursorBlock;
    if (ed == null || !ed.mounted || blk == null) return null;
    final idx = _blocks.indexOf(blk);
    if (idx < 0) return null;
    final prefix = DocumentBlocks.serialize(_blocks.sublist(0, idx)).length;
    return prefix + ed.masterCursor(base: base);
  }

  bool _historyBreak = true;

  /// True once after a formatting/structure action (new undo step).
  bool takeHistoryBreak() {
    final b = _historyBreak;
    _historyBreak = false;
    return b;
  }

  bool alignFocused(String align) {
    _historyBreak = true;
    final ed = _activeEd;
    if (ed == null || !ed.mounted) return false;
    ed.applyAlign(align);
    return true;
  }

  /// Heading / quote / list / normal on the focused lines (no rebuild).
  bool lineStyleFocused(String id) {
    _historyBreak = true;
    final ed = _activeEd;
    return ed != null && ed.mounted && ed.applyLineStyle(id);
  }

  bool indentFocused(int delta) {
    _historyBreak = true;
    final ed = _activeEd;
    return ed != null && ed.mounted && ed.indent(delta);
  }

  /// Link on the focused selection.
  bool linkFocused(String? url) => _activeCtrl?.setLink(url) ?? false;

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
        final c = TextEditingController(text: b.text);
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

  /// Marker pair → formatting operation (kept for older call sites).
  static FormatOp? opForMarkers(String left) {
    switch (left) {
      case '**':
        return const FormatOp('bold');
      case '*':
        return const FormatOp('italic');
      case '__':
        return const FormatOp('underline');
      case '~~':
        return const FormatOp('strike');
    }
    final m = RegExp(r'^\[(color|bg|size|font)=([^\]]+)\]$').firstMatch(left);
    if (m == null) return null;
    final v = m.group(2)!;
    return switch (m.group(1)) {
      'size' => FormatOp('size', int.tryParse(v)),
      'color' || 'bg' => FormatOp(m.group(1)!, v.toUpperCase()),
      _ => FormatOp('font', v),
    };
  }

  bool wrapFocused(String left, String right) {
    final op = opForMarkers(left);
    return op != null && formatFocused(op);
  }

  /// Applies formatting to the selection of the focused paragraph, or, with
  /// a bare cursor, to the text typed next. Returns false if nothing is focused.
  bool formatFocused(FormatOp op) {
    _historyBreak = true;
    final c = _activeCtrl;
    if (c == null) return false;
    try {
      return c.format(op);
    } on FlutterError {
      return false; // disposed
    }
  }

  /// Style at the focused caret (for toolbar highlighting).
  SpanStyle caretStyle() {
    final c = _activeCtrl;
    return c == null ? SpanStyle.plain : c.caretStyle();
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

  final Map<int, GlobalKey> _blockKeys = {};
  final Map<int, GlobalKey<_ParagraphEditorState>> _paraKeys = {};
  final GlobalKey _stackKey = GlobalKey();
  List<(double, String)> _breakYs = const [];
  bool _measureQueued = false;

  /// Measured y of each engine page start (for tests too).
  List<(double, String)> get pageBreakYs => _breakYs;

  void _queueMeasure() {
    if (_measureQueued || widget.pageStarts.isEmpty && _breakYs.isEmpty) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (!mounted) return;
      final ref = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (ref == null || !ref.hasSize) return;
      final out = <(double, String)>[];
      for (final ps in widget.pageStarts) {
        double? y;
        if (ps.block < 0 || ps.block >= _blocks.length) continue;
        final b = _blocks[ps.block];
        if (ps.offset >= 0 && b.kind == DocBlockKind.text) {
          var base = 0;
          for (var i = 0; i < ps.block; i++) {
            if (_blocks[i].kind == DocBlockKind.text) base += _blocks[i].text.length;
          }
          final local = (ps.offset - base).clamp(0, b.text.length);
          final rawLine = '\n'.allMatches(b.text.substring(0, local)).length;
          y = _paraKeys[ps.block]?.currentState?.yOf(rawLine, ps.k, ref);
        }
        if (y == null) {
          final box = _blockKeys[ps.block]?.currentContext?.findRenderObject() as RenderBox?;
          if (box != null && box.attached) y = ref.globalToLocal(box.localToGlobal(Offset.zero)).dy;
        }
        if (y != null) out.add((y, ps.label));
      }
      final same = out.length == _breakYs.length &&
          [for (var i = 0; i < out.length; i++) (out[i].$1 - _breakYs[i].$1).abs() < 0.5 && out[i].$2 == _breakYs[i].$2]
              .every((e) => e);
      if (!same) setState(() => _breakYs = out);
    });
  }

  @override
  Widget build(BuildContext context) {
    final col = _buildBlocks(context);
    _queueMeasure();
    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        col,
        for (final (y, label) in _breakYs)
          Positioned(
            key: ValueKey('page-break-$label'),
            top: y - 1,
            left: -6,
            right: -6,
            child: IgnorePointer(child: _PageEndLine(label: label)),
          ),
      ],
    );
  }

  Widget _buildBlocks(BuildContext context) {
    _tableOrdinal = 0;
    _imageOrdinal = 0;
    var textIndex = 0;
    final children = <Widget>[];
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      final before = children.length;
      switch (b.kind) {
        case DocBlockKind.text:
          final ctrl = _textCtrls[textIndex++];
          children.add(
            _ParagraphEditor(
              key: _paraKeys.putIfAbsent(i, () => GlobalKey<_ParagraphEditorState>()),
              hasPrev: i > 0,
              hasNext: i < _blocks.length - 1,
              master: ctrl,
              style: widget.style,
              readOnly: widget.readOnly,
              hint: children.isEmpty ? widget.hint : null,
              firstLineIndent: widget.firstLineIndent,
              onActive: (c) => _activeCtrl = c,
              onBind: (s) {
                _activeEd = s;
                _cursorBlock = b;
              },
              onColor: _colorMenu,
              onFormat: formatFocused,
            ),
          );
          break;
        case DocBlockKind.note:
          // Same as the page engine / PDF: full width, 10pt indent, gold
          // 2pt rule on the left, italic at 90 % of body size.
          final nctrl = _textCtrls[textIndex++];
          final k = widget.pxPerPt;
          children.add(
            Container(
              key: ValueKey('note-$i'),
              margin: EdgeInsets.symmetric(vertical: 4 * k),
              padding: EdgeInsets.only(left: 8 * k), // + 2pt rule = text at 10pt
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: const Color(0xFFC9A84C), width: 2 * k),
                ),
              ),
              child: _ParagraphEditor(
                master: nctrl,
                readOnly: widget.readOnly,
                hint: tr('Kənar qeyd yazın…'),
                firstLineIndent: false,
                style: widget.style.copyWith(
                  fontSize: (widget.style.fontSize ?? 14) * 0.9,
                  fontStyle: FontStyle.italic,
                ),
                onActive: (c) => _activeCtrl = c,
                onBind: (s) {
                  _activeEd = s;
                  _cursorBlock = b;
                },
                onColor: _colorMenu,
                onFormat: formatFocused,
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
                aligns: b.tableAligns,
                header: b.tableHeader,
                style: widget.style,
                pxPerPt: widget.pxPerPt,
                onActive: (c) {
                  _activeCtrl = c;
                  _activeEd = null;
                },
                onAlignCol: (col, a) {
                  final cols = b.cells.isEmpty ? 0 : b.cells.first.length;
                  b.tableAligns = List<String>.generate(
                      cols, (i) => i < b.tableAligns.length ? b.tableAligns[i] : 'l');
                  if (col < cols) b.tableAligns[col] = a;
                  setState(_emit);
                },
                onToggleHeader: () {
                  b.tableHeader = !b.tableHeader;
                  setState(_emit);
                },
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
                    if (b.tableAligns.length >= i) b.tableAligns.insert(i, 'l');
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
                  if (i < b.tableAligns.length) b.tableAligns.removeAt(i);
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
                  b.widths[col] = (b.widths[col] + delta).clamp(TableSpec.minRel, TableSpec.maxRel).toDouble();
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
                      tr('Səhifə sonu'),
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
          // Engine: body style, centred, half a line above and below.
          final lineH = (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.5);
          children.add(
            Padding(
              key: ValueKey('scene-$i'),
              padding: EdgeInsets.symmetric(vertical: lineH * 0.5),
              child: Text('*   *   *', textAlign: TextAlign.center, style: widget.style),
            ),
          );
          break;
        case DocBlockKind.hr:
          // Engine: 6pt space, 0.6pt rule in text colour, 6pt space.
          final k = widget.pxPerPt;
          children.add(
            Padding(
              key: ValueKey('hr-$i'),
              padding: EdgeInsets.symmetric(vertical: 6 * k),
              child: Container(height: 0.6 * k, color: widget.style.color ?? const Color(0xFF1A1A1A)),
            ),
          );
          break;
        case DocBlockKind.toc:
          children.add(_tocBlock(b));
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
      if (children.length > before) {
        children[before] = KeyedSubtree(
          key: _blockKeys.putIfAbsent(i, () => GlobalKey()),
          child: children[before],
        );
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// Table of contents: generated from the headings, page numbers from the
  /// page engine, drawn with the same sizes as the PDF (TocSpec).
  Widget _tocBlock(DocBlock b) {
    final k = widget.pxPerPt;
    final base = widget.style;
    final fs = base.fontSize ?? 14;
    final lh = base.height ?? 1.5;
    final ink = base.color ?? const Color(0xFF1A1A1A);
    var entries = widget.tocEntries;
    if (entries.isEmpty) entries = PageLayoutEngine.scanHeadings(serialized());
    entries = entries.where((e) => e.level <= b.tocLevels).toList();
    Widget row(TocEntry e) {
      final st = base.copyWith(
        fontWeight: e.level == 1 ? FontWeight.w700 : FontWeight.w400,
        color: ink,
        height: lh,
      );
      return Padding(
        key: ValueKey('toc-${e.level}-${e.title}'),
        padding: EdgeInsets.only(
          left: (e.level - 1) * TocSpec.indentPerLevel * k,
          bottom: TocSpec.entryGap * k,
        ),
        child: Row(
          children: [
            Flexible(child: Text(e.title, style: st, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(
              child: Text(
                ' ${'.' * 400}',
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: base.copyWith(color: const Color(0xFF888888), height: lh),
              ),
            ),
            Text(' ${e.page}', style: st),
          ],
        ),
      );
    }

    return GestureDetector(
      key: const ValueKey('toc-block'),
      onTap: widget.readOnly ? null : () => _tocMenu(b),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: fs * lh * 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              b.text,
              textAlign: TextAlign.center,
              style: base.copyWith(
                fontSize: fs * TocSpec.titleScale,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            SizedBox(height: fs * lh * 0.6),
            for (final e in entries) row(e),
          ],
        ),
      ),
    );
  }

  Future<void> _tocMenu(DocBlock b) async {
    final l10n = AppLocalizations.of(context);
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final n in [1, 2, 3])
              ListTile(
                leading: Icon(b.tocLevels == n ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(l10n.t(az: '$n səviyyə başlıq', en: '$n heading level(s)', ru: 'Уровней: $n', ar: 'المستويات: $n')),
                onTap: () => Navigator.pop(ctx, 'l$n'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(l10n.t(az: 'Mündəricatı sil', en: 'Delete contents', ru: 'Удалить оглавление', ar: 'حذف الفهرس')),
              onTap: () => Navigator.pop(ctx, 'del'),
            ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      if (pick == 'del') {
        _blocks.remove(b);
        if (_blocks.isEmpty) _blocks.add(DocBlock.text(''));
        _emit();
        _disposeText();
        _adopt(_lastEmitted);
      } else {
        b.tocLevels = int.parse(pick.substring(1));
        _emit();
      }
    });
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

    // Same box as the page engine / PDF: width = text width × w, aligned,
    // 6pt below, caption at 80 % italic centred.
    final k = widget.pxPerPt;
    return LayoutBuilder(
      key: ValueKey('img-$index'),
      builder: (context, cons) {
        final w = cons.maxWidth * b.imageWidth.clamp(0.2, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        ? Image.file(f, key: ValueKey('img-file-$index'), width: w, fit: BoxFit.contain)
                        : Container(
                            width: w,
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
                            child: Icon(Icons.key_rounded, size: 16, color: Color(0xFFC9A84C)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 6 * k),
            if (b.imageCaption.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 6 * k),
                child: Text(
                  b.imageCaption,
                  style: widget.style.copyWith(
                    fontSize: (widget.style.fontSize ?? 14) * 0.8,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
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
  final List<String> aligns;
  final bool header;
  final TextStyle style;
  final double pxPerPt;
  final ValueChanged<RichController> onActive;
  final void Function(int col, String align) onAlignCol;
  final VoidCallback onToggleHeader;

  const _VisualTable({
    required this.aligns,
    required this.header,
    required this.style,
    required this.pxPerPt,
    required this.onActive,
    required this.onAlignCol,
    required this.onToggleHeader,
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
  late List<List<RichController>> _ctrls;

  static String _enc(RichController c) => RichDoc.encode(c.lines('left'));
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
              _enc(_ctrls[r][c]) != _txt(r, c)) {
            _ctrls[r][c].setLines(RichDoc.decode(_txt(r, c)));
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
        final ctrl = RichController(lines: RichDoc.decode(_txt(r, c)));
        // Formatting from the toolbar changes the controller without an
        // onChanged; push those changes to the document too.
        ctrl.addListener(() {
          final t = ctrl.text;
          if (t.contains('\n') || t.contains('\t')) return; // onChanged handles
          if (r >= widget.cells.length || c >= widget.cells[r].length) return;
          final e = _enc(ctrl);
          if (e != _txt(r, c)) _set(r, c, e);
        });
        return ctrl;
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
      widget.onActive(_ctrls[r][c]);
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
              trf('{r}×{c} xana yapışdırıldı', {'r': grid.length, 'c': grid.first.length}),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (_selR < _ctrls.length && _selC < _ctrls[_selR].length) {
      _ctrls[_selR][_selC].setLines(RichDoc.decode(raw.replaceAll('\n', ' ')));
      _set(_selR, _selC, _enc(_ctrls[_selR][_selC]));
    }
  }

  void _copyTable() {
    final buf = StringBuffer();
    for (final row in widget.cells) {
      buf.writeln(row.join('\t'));
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(tr('Cədvəl kopyalandı — Excel / Sheets-ə yapışdırın')),
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

  String _txt(int r, int c) =>
      c < widget.cells[r].length ? CellAttr.parse(widget.cells[r][c]).$3 : '';

  /// Writes cell text keeping its colour / merge attributes.
  void _set(int r, int c, String text) {
    final (bg, span, _) = CellAttr.parse(widget.cells[r][c]);
    widget.onCellChanged(r, c, CellAttr.make(bg, span, text));
  }

  Widget _cell(int r, int c, int span, bool head, List<double> colW, double fs,
      double pad, Color ink, BorderSide grid) {
    final (bg, _, _) = CellAttr.parse(widget.cells[r][c]);
    final w = colW.sublist(c, c + span).fold(0.0, (a, v) => a + v);
    final selected = r == _selR && c == _selC && _nodes[r][c].hasFocus;
    final ts = widget.style.copyWith(
      fontSize: fs,
      height: TableSpec.lineScale,
      fontWeight: head ? FontWeight.w700 : FontWeight.w400,
      color: ink,
    );
    final a = TableSpec.align(widget.aligns, c);
    return SizedBox(
      key: ValueKey('cell-$r-$c'),
      width: w,
      child: GestureDetector(
        onLongPress: widget.readOnly ? null : _openTableMenu,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Container(
              color: Color(bg ?? (head ? TableSpec.headerFill : 0x00000000)),
              padding: EdgeInsets.all(pad),
              child: TextField(
                controller: _ctrls[r][c],
                focusNode: _nodes[r][c],
                readOnly: widget.readOnly,
                maxLines: null,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                textAlign: switch (a) {
                  'center' => TextAlign.center,
                  'right' => TextAlign.right,
                  _ => TextAlign.start,
                },
                style: ts,
                strutStyle: StrutStyle(fontSize: fs, height: TableSpec.lineScale, forceStrutHeight: true),
                decoration: const InputDecoration.collapsed(hintText: ''),
                onTap: () {
                  widget.onActive(_ctrls[r][c]);
                  setState(() {
                    _selR = r;
                    _selC = c;
                  });
                },
                onChanged: (_) {
                  final ctrl = _ctrls[r][c];
                  final v = ctrl.text;
                  final g = TableBlock.parseClipboardGrid(v);
                  if (g != null && (v.contains('\t') || v.contains('\n')) && (g.length > 1 || g.first.length > 1)) {
                    ctrl.setLines(RichDoc.decode(_txt(r, c)));
                    widget.onPasteGrid(r, c, g);
                    return;
                  }
                  if (v.contains('\n')) {
                    // Enter in a cell = next cell (cells are one paragraph).
                    ctrl.setLines(RichDoc.decode(_enc(ctrl).replaceAll('\n', ' ').trimRight()));
                    _set(r, c, _enc(ctrl));
                    _move(0, 1);
                    return;
                  }
                  _set(r, c, _enc(ctrl));
                },
                onEditingComplete: () => _move(0, 1),
              ),
            ),
            // Grid lines / selection: drawn on top, never change the layout.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: selected && !widget.readOnly
                        ? Border.all(color: const Color(0xFFC9A84C), width: 1.6)
                        : Border(top: grid, left: grid, right: grid, bottom: grid),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mergeRight() {
    final row = widget.cells[_selR];
    final cols = row.length;
    final (bg, span, text) = CellAttr.parse(row[_selC]);
    final next = _selC + span;
    if (next >= cols) return;
    final (_, nspan, ntext) = CellAttr.parse(row[next]);
    final joined = [text, ntext].where((e) => e.trim().isNotEmpty).join(' ');
    for (var c = next; c < next + nspan && c < cols; c++) {
      widget.onCellChanged(_selR, c, '');
      _ctrls[_selR][c].setLines(RichDoc.decode(''));
    }
    widget.onCellChanged(_selR, _selC, CellAttr.make(bg, span + nspan, joined));
    _ctrls[_selR][_selC].setLines(RichDoc.decode(joined));
    setState(() {});
  }

  void _unmerge() {
    final (bg, _, text) = CellAttr.parse(widget.cells[_selR][_selC]);
    widget.onCellChanged(_selR, _selC, CellAttr.make(bg, 1, text));
    setState(() {});
  }

  Future<void> _cellColour() async {
    const colors = [0, 0xFFF1ECE0, 0xFFFDE2E1, 0xFFE3F2E1, 0xFFE1ECFB, 0xFFFFF4CC, 0xFFEDE3F7, 0xFFE0E0E0];
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (final c in colors)
              GestureDetector(
                key: ValueKey('cell-colour-$c'),
                onTap: () => Navigator.pop(ctx, c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(c == 0 ? 0xFFFFFFFF : c),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD0D5DD)),
                  ),
                  child: c == 0 ? const Icon(Icons.block, size: 18) : null,
                ),
              ),
          ]),
        ),
      ),
    );
    if (picked == null) return;
    final (_, span, text) = CellAttr.parse(widget.cells[_selR][_selC]);
    widget.onCellChanged(_selR, _selC, CellAttr.make(picked == 0 ? null : picked, span, text));
    setState(() {});
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final (a, icon) in const [
                      ('l', Icons.format_align_left),
                      ('c', Icons.format_align_center),
                      ('r', Icons.format_align_right),
                    ])
                      IconButton(
                        key: ValueKey('tbl-align-$a'),
                        icon: Icon(icon),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onAlignCol(_selC, a);
                        },
                      ),
                    IconButton(
                      key: const ValueKey('tbl-narrow'),
                      icon: const Icon(Icons.compress),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onColWidth(_selC, -0.25);
                      },
                    ),
                    IconButton(
                      key: const ValueKey('tbl-widen'),
                      icon: const Icon(Icons.expand),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onColWidth(_selC, 0.25);
                      },
                    ),
                  ],
                ),
                _menuItem(ctx, Icons.call_merge, l10n.t(az: 'Sağdakı xana ilə birləşdir', en: 'Merge with right cell', ru: 'Объединить с правой', ar: 'دمج مع الخلية اليمنى'), _mergeRight),
                if (CellAttr.parse(widget.cells[_selR.clamp(0, widget.cells.length - 1)][_selC.clamp(0, widget.cells.first.length - 1)]).$2 > 1)
                  _menuItem(ctx, Icons.call_split, l10n.t(az: 'Birləşməni ayır', en: 'Unmerge', ru: 'Разъединить', ar: 'إلغاء الدمج'), _unmerge),
                _menuItem(ctx, Icons.format_color_fill, l10n.t(az: 'Xana rəngi', en: 'Cell colour', ru: 'Цвет ячейки', ar: 'لون الخلية'), _cellColour),
                _menuItem(ctx, Icons.table_rows_outlined, widget.header
                    ? l10n.t(az: 'Başlıq sətrini söndür', en: 'Turn off header row', ru: 'Без строки заголовка', ar: 'إلغاء صف العنوان')
                    : l10n.t(az: 'Başlıq sətri', en: 'Header row', ru: 'Строка заголовка', ar: 'صف العنوان'), widget.onToggleHeader),
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
                // Same geometry as the page engine / PDF (TableSpec).
                final k = widget.pxPerPt;
                final colW = TableSpec.columnWidths(widget.widths, cols, avail);
                final fs = (widget.style.fontSize ?? 14) * TableSpec.fontScale;
                final pad = TableSpec.pad * k;
                final ink = widget.style.color ?? const Color(0xFF1A1A1A);
                final grid = BorderSide(
                  color: const Color(TableSpec.borderColor),
                  width: TableSpec.borderWidth * k,
                );
                return SizedBox(
                  width: avail,
                  child: Column(
                    key: const ValueKey('visual-table'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(widget.cells.length, (r) {
                      final head = r == 0 && widget.header;
                      // Row height = tallest cell, measured like the engine
                      // (lines × font × 1.35 + padding).
                      var maxLines = 1;
                      for (final (c, span) in CellAttr.visible(widget.cells[r], cols)) {
                        if (r >= _ctrls.length || c >= _ctrls[r].length) continue;
                        final w = colW.sublist(c, c + span).fold(0.0, (a, v) => a + v);
                        final tp = TextPainter(
                          text: TextSpan(
                            text: _ctrls[r][c].text.isEmpty ? ' ' : _ctrls[r][c].text,
                            style: widget.style.copyWith(
                              fontSize: fs,
                              height: TableSpec.lineScale,
                              fontWeight: head ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                          strutStyle: StrutStyle(fontSize: fs, height: TableSpec.lineScale, forceStrutHeight: true),
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: (w - pad * 2).clamp(1.0, double.infinity));
                        final n = tp.computeLineMetrics().length;
                        tp.dispose();
                        if (n > maxLines) maxLines = n;
                      }
                      final rowH = maxLines * fs * TableSpec.lineScale + pad * 2;
                      return SizedBox(
                        height: rowH,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (c, span) in CellAttr.visible(widget.cells[r], cols))
                              if (r < _ctrls.length && c < _ctrls[r].length)
                                _cell(r, c, span, head, colW, fs, pad, ink, grid),
                          ],
                        ),
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
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: tr('Cədvəl başlığı'),
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

class _G {
  String align;
  final RichController c;
  final FocusNode f = FocusNode();
  final GlobalKey key = GlobalKey();
  bool rtl = false;
  _G(this.align, this.c);
}

final _strongRe = RegExp(r'[A-Za-z\u00C0-\u024F\u0259\u018F\u0400-\u04FF\u0590-\u08FF\uFB50-\uFEFF]');
final _rtlCharRe = RegExp(r'[\u0590-\u08FF\uFB50-\uFEFF]');

bool _isRtl(String s) {
  final m = _strongRe.firstMatch(s);
  return m != null && _rtlCharRe.hasMatch(m.group(0)!);
}

/// Edits one text block. Lines live in as few TextFields as possible: one
/// per run of lines with the same alignment (long blocks are cut at blank
/// lines every few thousand characters). Enter only inserts a line break in
/// the same field, so any number of empty lines works and the keyboard never
/// jumps between fields while typing.
class _ParagraphEditor extends StatefulWidget {
  final TextEditingController master;
  final TextStyle style;
  final bool readOnly;
  final String? hint;
  final bool firstLineIndent;
  final void Function(RichController c) onActive;
  final void Function(_ParagraphEditorState s) onBind;
  final VoidCallback onColor;
  final bool Function(FormatOp op) onFormat;

  /// A table/image/break sits before/after this block: one leading/trailing
  /// line break is only a separator, not an empty line.
  final bool hasPrev, hasNext;

  const _ParagraphEditor({
    super.key,
    this.hasPrev = false,
    this.hasNext = false,
    required this.master,
    required this.style,
    required this.readOnly,
    required this.hint,
    required this.firstLineIndent,
    required this.onActive,
    required this.onBind,
    required this.onColor,
    required this.onFormat,
  });

  @override
  State<_ParagraphEditor> createState() => _ParagraphEditorState();
}

class _ParagraphEditorState extends State<_ParagraphEditor> {
  final List<_G> _gs = [];
  int _focus = 0;
  bool _writing = false;
  static const _chunk = 4000;

  bool _lead = false, _trail = false;

  List<RLine> _decode(String raw) {
    var r = raw;
    _lead = widget.hasPrev && r.startsWith('\n');
    if (_lead) r = r.substring(1);
    _trail = widget.hasNext && r.endsWith('\n');
    if (_trail) r = r.substring(0, r.length - 1);
    return RichDoc.decode(r);
  }

  String _encode() => '${_lead ? '\n' : ''}${RichDoc.encode(_allLines())}${_trail ? '\n' : ''}';

  @override
  void initState() {
    super.initState();
    _build(_decode(widget.master.text));
    widget.master.addListener(_onMaster);
  }

  @override
  void didUpdateWidget(covariant _ParagraphEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.master != widget.master) {
      oldWidget.master.removeListener(_onMaster);
      widget.master.addListener(_onMaster);
      _reload(widget.master.text);
    }
  }

  @override
  void dispose() {
    widget.master.removeListener(_onMaster);
    for (final g in _gs) {
      g.c.removeListener(_onG);
      g.c.dispose();
      g.f.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ structure

  List<RLine> _allLines() => [for (final g in _gs) ...g.c.lines(g.align)];

  void _build(List<RLine> lines) {
    final old = List.of(_gs);
    _gs.clear();
    var cur = <RLine>[];
    var size = 0;
    void close() {
      if (cur.isEmpty) return;
      final c = RichController(lines: cur);
      c.addListener(_onG);
      final g = _G(cur.first.align, c)..rtl = _isRtl(c.text);
      g.f.addListener(() {
        if (g.f.hasFocus) {
          final i = _gs.indexOf(g);
          if (i >= 0) _activate(i);
        }
      });
      g.f.onKeyEvent = (node, e) => _onKey(g, e);
      _gs.add(g);
      cur = [];
      size = 0;
    }

    for (final l in lines) {
      final split = cur.isNotEmpty &&
          (l.align != cur.first.align || (size > _chunk && cur.last.text.trim().isEmpty && l.text.trim().isNotEmpty));
      if (split) close();
      cur.add(l);
      size += l.text.length + 1;
    }
    close();
    if (_gs.isEmpty) {
      cur = [RLine.empty()];
      close();
    }
    if (_focus >= _gs.length) _focus = _gs.length - 1;
    if (old.isNotEmpty) {
      for (final g in old) {
        g.c.removeListener(_onG);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final g in old) {
          g.c.dispose();
          g.f.dispose();
        }
      });
    }
  }

  /// (global line, column) of an offset inside group [gi].
  (int, int) _global(int gi, int off) {
    var gl = 0;
    for (var k = 0; k < gi; k++) {
      gl += '\n'.allMatches(_gs[k].c.text).length + 1;
    }
    final c = _gs[gi].c;
    final o = off.clamp(0, c.text.length);
    return (gl + c.lineOf(o), o - c.lineStart(o));
  }

  (int, int) _locate(int gl, int col) {
    var base = 0;
    for (var gi = 0; gi < _gs.length; gi++) {
      final n = '\n'.allMatches(_gs[gi].c.text).length + 1;
      if (gl < base + n || gi == _gs.length - 1) {
        final c = _gs[gi].c;
        var off = 0;
        for (var k = 0; k < gl - base && off <= c.text.length; k++) {
          final i = c.text.indexOf('\n', off);
          if (i < 0) break;
          off = i + 1;
        }
        final end = c.lineEnd(off);
        return (gi, (off + col).clamp(off, end));
      }
      base += n;
    }
    return (0, 0);
  }

  void _refocus((int, int) a, [(int, int)? b]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _gs.isEmpty) return;
      final (gi, off) = _locate(a.$1, a.$2);
      var base = off;
      if (b != null) {
        final (gb, ob) = _locate(b.$1, b.$2);
        if (gb == gi) base = ob;
      }
      _gs[gi].f.requestFocus();
      _gs[gi].c.selection = TextSelection(baseOffset: base, extentOffset: off);
      _activate(gi);
    });
  }

  void _rebuild(List<RLine> lines, (int, int) caret, [(int, int)? base]) {
    setState(() => _build(lines));
    _push();
    _refocus(caret, base);
  }

  void _reload(String raw) {
    final had = _gs.any((g) => g.f.hasFocus);
    (int, int)? pos;
    if (had && _focus < _gs.length) {
      final sel = _gs[_focus].c.selection;
      if (sel.isValid) pos = _global(_focus, sel.extentOffset);
    }
    _build(_decode(raw));
    if (pos != null) _refocus(pos);
  }

  // ------------------------------------------------------------- binding

  void _activate(int i) {
    _focus = i;
    widget.onActive(_gs[i].c);
    widget.onBind(this);
  }

  RichController? get focused => _gs.isEmpty ? null : _gs[_focus.clamp(0, _gs.length - 1)].c;

  /// Cursor position inside the master (raw) text of this block.
  int masterCursor({bool base = false}) {
    if (_gs.isEmpty) return 0;
    final i = _focus.clamp(0, _gs.length - 1);
    final sel = _gs[i].c.selection;
    final c = _gs[i].c;
    final off = sel.isValid ? (base ? sel.baseOffset : sel.extentOffset) : c.text.length;
    final (gl, col) = _global(i, off);
    return (_lead ? 1 : 0) + RichDoc.rawOffset(_allLines(), gl, col);
  }

  /// Alignment for the selected lines of the focused field.
  void applyAlign(String align) {
    if (_gs.isEmpty) return;
    final i = _focus.clamp(0, _gs.length - 1);
    final c = _gs[i].c;
    final sel = c.selection.isValid ? c.selection : TextSelection.collapsed(offset: c.text.length);
    final a = _global(i, sel.start), z = _global(i, sel.end);
    final lines = _allLines();
    for (var l = a.$1; l <= z.$1 && l < lines.length; l++) {
      lines[l].align = align;
    }
    final ext = _global(i, sel.extentOffset), bas = _global(i, sel.baseOffset);
    _rebuild(lines, ext, bas);
  }

  /// Heading / quote / list / normal for the selected lines.
  bool applyLineStyle(String id) {
    final c = focused;
    if (c == null || !c.selection.isValid) return false;
    switch (id) {
      case 'h1':
      case 'chapter':
        c.setKind('h1');
      case 'h2':
      case 'subchapter':
        c.setKind('h2');
      case 'h3':
      case 'h4':
        c.setKind('h3');
      case 'quote':
        c.setKind('quote');
      case 'normal':
        c.setKind('');
        c.removeListMarkers();
      case 'bullet':
        c.toggleList(false);
      case 'number':
        c.toggleList(true);
      default:
        return false;
    }
    return true;
  }

  bool indent(int delta) {
    final c = focused;
    if (c == null || !c.selection.isValid) return false;
    c.indent(delta);
    return true;
  }

  // ------------------------------------------------------------- events

  KeyEventResult _onKey(_G g, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final i = _gs.indexOf(g);
    final sel = g.c.selection;
    if (i < 0 || !sel.isValid || !sel.isCollapsed) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.backspace && sel.baseOffset == 0 && i > 0) {
      _mergeUp(i);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp && g.c.lineOf(sel.baseOffset) == 0 && i > 0) {
      final p = _gs[i - 1];
      p.f.requestFocus();
      p.c.selection = TextSelection.collapsed(offset: p.c.text.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown && g.c.lineEnd(sel.baseOffset) == g.c.text.length && i < _gs.length - 1) {
      final n = _gs[i + 1];
      n.f.requestFocus();
      n.c.selection = const TextSelection.collapsed(offset: 0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Backspace at the very start of a field joins it with the line above.
  void _mergeUp(int i) {
    final (gl, _) = _global(i, 0);
    final lines = _allLines();
    final up = lines[gl - 1], low = lines[gl];
    final col = up.text.length;
    final kind = up.text.isEmpty ? low.kind : up.kind;
    final align = up.text.isEmpty ? low.align : up.align;
    lines[gl - 1] = RLine(up.text + low.text, [...up.st, ...low.st], align: align, kind: kind);
    lines.removeAt(gl);
    _rebuild(lines, (gl - 1, col));
  }

  void _onMaster() {
    if (_writing) return;
    if (_encode() == widget.master.text) return;
    setState(() => _reload(widget.master.text));
  }

  void _onG() {
    _push();
    var changed = false;
    for (final g in _gs) {
      final r = _isRtl(g.c.text);
      if (r != g.rtl) {
        g.rtl = r;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  void _push() {
    final joined = _encode();
    if (joined == widget.master.text) return;
    _writing = true;
    widget.master.text = joined;
    _writing = false;
  }

  TextAlign _ta(String a) => switch (a) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'justify' => TextAlign.justify,
        _ => TextAlign.start,
      };

  Widget _menu(BuildContext ctx, EditableTextState editable) {
    final l10n = AppLocalizations.of(ctx);
    final c = editable.widget.controller;
    ContextMenuButtonItem fmt(String label, FormatOp op) => ContextMenuButtonItem(
          label: label,
          onPressed: () {
            ContextMenuController.removeAny();
            widget.onFormat(op);
          },
        );
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editable.contextMenuAnchors,
      buttonItems: [
        for (final it in editable.contextMenuButtonItems)
          if ((it.type == ContextMenuButtonType.copy || it.type == ContextMenuButtonType.cut) && c is RichController)
            ContextMenuButtonItem(
              type: it.type,
              onPressed: () async {
                final v = c.value;
                ContextMenuController.removeAny();
                await c.copySelection();
                if (it.type == ContextMenuButtonType.cut && v.selection.isValid && !v.selection.isCollapsed) {
                  c.value = TextEditingValue(
                    text: v.text.replaceRange(v.selection.start, v.selection.end, ''),
                    selection: TextSelection.collapsed(offset: v.selection.start),
                  );
                }
              },
            )
          else
            it,
        ContextMenuButtonItem(
          label: l10n.t(az: 'Rəng', en: 'Color', ru: 'Цвет', ar: 'لون'),
          onPressed: () {
            ContextMenuController.removeAny();
            widget.onColor();
          },
        ),
        fmt(l10n.t(az: 'Qalın', en: 'Bold', ru: 'Жирный', ar: 'عريض'), const FormatOp('bold')),
        fmt(l10n.t(az: 'Əyri', en: 'Italic', ru: 'Курсив', ar: 'مائل'), const FormatOp('italic')),
        fmt(l10n.t(az: 'Xətt', en: 'Underline', ru: 'Подчёркнутый', ar: 'تسطير'), const FormatOp('underline')),
      ],
    );
  }

  /// Y (in [ref]'s coordinates) of the top of visual line [k] of raw line
  /// [rawLine] of this block, or null if not laid out.
  double? yOf(int rawLine, int k, RenderBox ref) {
    var line = rawLine - (_lead ? 1 : 0);
    if (line < 0) line = 0;
    final (gi, off) = _locate(line, 0);
    if (gi < 0 || gi >= _gs.length) return null;
    final ro = _gs[gi].key.currentContext?.findRenderObject();
    if (ro == null) return null;
    RenderEditable? re;
    void walk(RenderObject o) {
      if (re != null) return;
      if (o is RenderEditable) {
        re = o;
        return;
      }
      o.visitChildren(walk);
    }

    walk(ro);
    final ed = re;
    if (ed == null || !ed.attached || !ref.attached) return null;
    final caret = ed.getLocalRectForCaret(TextPosition(offset: off.clamp(0, _gs[gi].c.text.length)));
    final y = caret.top + k * ed.preferredLineHeight;
    return ref.globalToLocal(ed.localToGlobal(Offset(0, y))).dy;
  }

  @override
  Widget build(BuildContext context) {
    final empty = _gs.length == 1 && _gs.first.c.text.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _gs.length; i++)
          TextField(
            key: _gs[i].key,
            controller: _gs[i].c,
            focusNode: _gs[i].f,
            readOnly: widget.readOnly,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            style: widget.style,
            textAlign: _ta(_gs[i].align),
            textDirection: _gs[i].rtl ? TextDirection.rtl : TextDirection.ltr,
            contextMenuBuilder: _menu,
            onTap: () => _activate(i),
            decoration: InputDecoration(
              hintText: i == 0 && empty ? widget.hint : null,
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

/// Kept for the toolbar and older call sites.
class MarkupTextController extends TextEditingController {
  MarkupTextController({super.text});
  static ValueNotifier<SpanStyle> get caret => RichController.caret;
  static String? fontFamilyFor(String? f) => RichController.fontFamilyFor(f);
}
