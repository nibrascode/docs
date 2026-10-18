import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Parses [TABLE]...[/TABLE] blocks from document text.
class TableBlock {
  final int start;
  final int end;
  final List<List<String>> cells;
  final List<double> colWidths; // relative 0.5–2.0
  final String caption;
  /// Per-column alignment: 'l', 'c' or 'r'.
  final List<String> colAligns;
  /// First row is a header (bold, shaded).
  final bool header;

  TableBlock({
    required this.start,
    required this.end,
    required this.cells,
    required this.colWidths,
    this.caption = '',
    this.colAligns = const [],
    this.header = true,
  });

  static final RegExp blockRe = RegExp(
    r'\[TABLE\]([\s\S]*?)\[/TABLE\]',
    multiLine: true,
  );

  static TableBlock? findAt(String text, int cursor) {
    for (final m in blockRe.allMatches(text)) {
      if (cursor >= m.start && cursor <= m.end) {
        return _fromMatch(m);
      }
    }
    return null;
  }

  static List<TableBlock> allIn(String text) {
    return blockRe.allMatches(text).map(_fromMatch).toList();
  }

  static TableBlock _fromMatch(RegExpMatch m) {
    final body = m.group(1) ?? '';
    final lines = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('|') && !l.contains('---'))
        .toList();
    final cells = <List<String>>[];
    for (final line in lines) {
      var parts = line.split('|');
      // remove empty edges from leading/trailing |
      if (parts.isNotEmpty && parts.first.trim().isEmpty) {
        parts = parts.sublist(1);
      }
      if (parts.isNotEmpty && parts.last.trim().isEmpty) {
        parts = parts.sublist(0, parts.length - 1);
      }
      cells.add(parts.map((p) => p.trim()).toList());
    }
    if (cells.isEmpty) {
      cells.add(['', '', '']);
      cells.add(['', '', '']);
    }
    final cols = cells.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
    for (final r in cells) {
      while (r.length < cols) {
        r.add('');
      }
    }
    final widths = List<double>.filled(cols, 1.0);
    // optional width line: [W] 1.0 1.2 0.8
    final wLine = RegExp(r'\[W\]\s*([0-9. ]+)').firstMatch(body);
    if (wLine != null) {
      final nums = wLine.group(1)!.trim().split(RegExp(r'\s+'));
      for (var i = 0; i < cols && i < nums.length; i++) {
        widths[i] = double.tryParse(nums[i]) ?? 1.0;
      }
    }
    final cap = RegExp(r'\[CAP\](.*)$', multiLine: true).firstMatch(body)?.group(1)?.trim() ?? '';
    final aligns = List<String>.filled(cols, 'l');
    final aLine = RegExp(r'\[A\]\s*([lcr ]+)').firstMatch(body);
    if (aLine != null) {
      final a = aLine.group(1)!.trim().split(RegExp(r'\s+'));
      for (var i = 0; i < cols && i < a.length; i++) {
        aligns[i] = a[i];
      }
    }
    final header = !RegExp(r'^\s*\[H\]\s*0', multiLine: true).hasMatch(body);
    return TableBlock(
      start: m.start,
      end: m.end,
      cells: cells,
      colWidths: widths,
      caption: cap,
      colAligns: aligns,
      header: header,
    );
  }

  String toMarkup() {
    final buf = StringBuffer();
    buf.writeln('[TABLE]');
    if (colWidths.any((w) => (w - 1.0).abs() > 0.01)) {
      buf.writeln('[W] ${colWidths.map((w) => w.toStringAsFixed(2)).join(' ')}');
    }
    if (colAligns.any((a) => a != 'l')) {
      buf.writeln('[A] ${colAligns.join(' ')}');
    }
    if (!header) buf.writeln('[H] 0');
    for (var r = 0; r < cells.length; r++) {
      buf.writeln('| ${cells[r].map((c) => c.replaceAll('|', '/')).join(' | ')} |');
      if (r == 0) {
        buf.writeln('| ${List.filled(cells[0].length, '---').join(' | ')} |');
      }
    }
    if (caption.trim().isNotEmpty) {
      buf.writeln('[CAP] ${caption.trim()}');
    }
    buf.writeln('[/TABLE]');
    return buf.toString();
  }

  static String markupFrom({
    required int rows,
    required int cols,
    List<String>? headers,
    String caption = '',
    int extraRows = 0,
  }) {
    final h = headers ?? List.generate(cols, (c) => 'Başlıq ${c + 1}');
    final cCount = h.length;
    final rCount = extraRows > 0 ? extraRows + 1 : rows;
    final cells = List.generate(
      rCount.clamp(1, 40),
      (r) => List.generate(
        cCount.clamp(1, 12),
        (c) => r == 0 ? (c < h.length ? h[c] : '') : '',
      ),
    );
    return TableBlock(
      start: 0,
      end: 0,
      cells: cells,
      colWidths: List.filled(cCount.clamp(1, 12), 1.0),
      caption: caption,
    ).toMarkup();
  }

  /// Excel / Sheets / Word paste: TSV, markdown pipes, CSV, semicolon.
  static List<List<String>>? parseClipboardGrid(String raw) {
    var s = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (s.isEmpty) return null;

    List<List<String>> fromDelim(String text, Pattern delim) {
      return text.split('\n').map((l) {
        return l.split(delim).map((c) => c.trim()).toList();
      }).toList();
    }

    List<List<String>> normalize(List<List<String>> grid) {
      final cols =
          grid.fold<int>(0, (a, r) => r.length > a ? r.length : a).clamp(1, 16);
      final out = <List<String>>[];
      for (final r in grid.take(40)) {
        final row = List<String>.from(r.take(cols));
        while (row.length < cols) {
          row.add('');
        }
        out.add(row);
      }
      return out;
    }

    bool multi(List<List<String>> g) =>
        g.isNotEmpty && (g.length > 1 || g.first.length > 1);

    if (s.contains('\t')) {
      final grid = normalize(fromDelim(s, '\t'));
      if (multi(grid)) return grid;
    }

    final pipeLines = s.split('\n').where((l) => l.contains('|')).toList();
    if (pipeLines.isNotEmpty) {
      final cells = <List<String>>[];
      for (final line in pipeLines) {
        if (line.contains('---')) continue;
        var parts = line.split('|');
        if (parts.isNotEmpty && parts.first.trim().isEmpty) {
          parts = parts.sublist(1);
        }
        if (parts.isNotEmpty && parts.last.trim().isEmpty) {
          parts = parts.sublist(0, parts.length - 1);
        }
        cells.add(parts.map((p) => p.trim()).toList());
      }
      if (cells.isNotEmpty) {
        final grid = normalize(cells);
        if (multi(grid)) return grid;
      }
    }

    if (s.contains(';') && s.contains('\n')) {
      final grid = normalize(fromDelim(s, ';'));
      if (grid.length > 1 && grid.first.length > 1) return grid;
    }
    if (s.contains(',') && s.contains('\n')) {
      final grid = normalize(fromDelim(s, ','));
      if (grid.length > 1 && grid.first.length > 1) return grid;
    }
    return null;
  }
}

class TableSizeChoice {
  final int rows;
  final int cols;
  final bool openCustomEditor;
  const TableSizeChoice({
    required this.rows,
    required this.cols,
    this.openCustomEditor = false,
  });
}

/// Word-style grid picker: tap a cell to insert that many rows × columns.
Future<TableSizeChoice?> showTableSizePicker(BuildContext context) {
  return showModalBottomSheet<TableSizeChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _TableSizePickerSheet(),
  );
}

class _TableSizePickerSheet extends StatefulWidget {
  const _TableSizePickerSheet();

  @override
  State<_TableSizePickerSheet> createState() => _TableSizePickerSheetState();
}

class _TableSizePickerSheetState extends State<_TableSizePickerSheet> {
  static const int maxR = 8;
  static const int maxC = 8;
  int hoverR = 3;
  int hoverC = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(type: MaterialType.transparency, child: SafeArea(
        top: false,
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
              'Cədvəl daxil et',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$hoverR sətir × $hoverC sütun  ·  xanaya toxun',
              style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFC9A84C)),
            ),
            const SizedBox(height: 14),
            Center(
              child: Column(
                children: List.generate(maxR, (r) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(maxC, (c) {
                      final on = r < hoverR && c < hoverC;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            hoverR = r + 1;
                            hoverC = c + 1;
                          });
                          Navigator.pop(
                            context,
                            TableSizeChoice(rows: r + 1, cols: c + 1),
                          );
                        },
                        onTapDown: (_) => setState(() {
                          hoverR = r + 1;
                          hoverC = c + 1;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          width: 28,
                          height: 22,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: on
                                ? const Color(0xFF0D1B3E)
                                : const Color(0xFF2A2A2A),
                            border: Border.all(
                              color: on
                                  ? const Color(0xFFC9A84C)
                                  : Colors.white24,
                              width: on ? 1.4 : 1,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in [
                  (2, 2),
                  (3, 3),
                  (4, 4),
                  (5, 3),
                  (6, 4),
                  (8, 5),
                ])
                  ActionChip(
                    label: Text(
                      '${p.$1}×${p.$2}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFF2A2A2A),
                    side: BorderSide.none,
                    onPressed: () => Navigator.pop(
                      context,
                      TableSizeChoice(rows: p.$1, cols: p.$2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  const TableSizeChoice(
                    rows: 3,
                    cols: 3,
                    openCustomEditor: true,
                  ),
                ),
                icon: const Icon(Icons.grid_on, color: Color(0xFFC9A84C)),
                label: Text(
                  'Özəl ölçü / başlıqları yaz',
                  style: GoogleFonts.dmSans(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class TableEditorDialog extends StatefulWidget {
  final int initialRows;
  final int initialCols;
  final List<List<String>>? initialData;
  final List<double>? initialWidths;
  final String initialCaption;
  final List<String> initialAligns;
  final bool initialHeader;
  final bool editing;

  const TableEditorDialog({
    super.key,
    this.initialRows = 3,
    this.initialCols = 3,
    this.initialData,
    this.initialWidths,
    this.initialCaption = '',
    this.initialAligns = const [],
    this.initialHeader = true,
    this.editing = false,
  });

  static Future<String?> show(
    BuildContext context, {
    List<List<String>>? data,
    List<double>? widths,
    String caption = '',
    int rows = 3,
    int cols = 3,
    List<String> aligns = const [],
    bool header = true,
    bool editing = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TableEditorDialog(
        initialRows: data?.length ?? rows,
        initialCols: data?.isNotEmpty == true ? data!.first.length : cols,
        initialData: data,
        initialWidths: widths,
        initialCaption: caption,
        initialAligns: aligns,
        initialHeader: header,
        editing: editing,
      ),
    );
  }

  @override
  State<TableEditorDialog> createState() => _TableEditorDialogState();
}

class _TableEditorDialogState extends State<TableEditorDialog> {
  late int _rows;
  late int _cols;
  late List<List<TextEditingController>> _cells;
  late List<double> _widths;
  late TextEditingController _caption;
  int _selectedRow = 0;
  int _selectedCol = 0;

  @override
  void initState() {
    super.initState();
    _rows = (widget.initialData?.length ?? widget.initialRows).clamp(1, 40);
    _cols = (widget.initialData?.isNotEmpty == true
            ? widget.initialData!.first.length
            : widget.initialCols)
        .clamp(1, 12);
    _widths = List<double>.generate(
      _cols,
      (i) => (widget.initialWidths != null && i < widget.initialWidths!.length)
          ? widget.initialWidths![i].clamp(0.5, 2.5)
          : 1.0,
    );
    _caption = TextEditingController(text: widget.initialCaption);
    _initCells(widget.initialData);
  }

  void _initCells(List<List<String>>? data) {
    _cells = List.generate(_rows, (r) {
      return List.generate(_cols, (c) {
        final text = (data != null && r < data.length && c < data[r].length)
            ? data[r][c]
            : (r == 0 ? 'Başlıq ${c + 1}' : '');
        return TextEditingController(text: text);
      });
    });
  }

  void _disposeCells() {
    for (final row in _cells) {
      for (final c in row) {
        c.dispose();
      }
    }
  }

  List<List<String>> _snapshot() =>
      _cells.map((row) => row.map((c) => c.text).toList()).toList();

  void _resize(int newRows, int newCols) {
    newRows = newRows.clamp(1, 40);
    newCols = newCols.clamp(1, 12);
    final old = _snapshot();
    _disposeCells();
    final oldW = List<double>.from(_widths);
    _rows = newRows;
    _cols = newCols;
    _widths = List.generate(
      _cols,
      (i) => i < oldW.length ? oldW[i] : 1.0,
    );
    _initCells(old);
    _selectedRow = _selectedRow.clamp(0, _rows - 1);
    _selectedCol = _selectedCol.clamp(0, _cols - 1);
    setState(() {});
  }

  void _insertRow(int at) {
    final data = _snapshot();
    data.insert(at.clamp(0, data.length), List.filled(_cols, ''));
    _disposeCells();
    _rows = data.length;
    _initCells(data);
    setState(() => _selectedRow = at.clamp(0, _rows - 1));
  }

  void _deleteRow(int at) {
    if (_rows <= 1) return;
    final data = _snapshot();
    data.removeAt(at.clamp(0, data.length - 1));
    _disposeCells();
    _rows = data.length;
    _initCells(data);
    setState(() => _selectedRow = _selectedRow.clamp(0, _rows - 1));
  }

  void _insertCol(int at) {
    final data = _snapshot();
    for (final row in data) {
      row.insert(at.clamp(0, row.length), '');
    }
    _widths.insert(at.clamp(0, _widths.length), 1.0);
    _disposeCells();
    _cols = data.first.length;
    _initCells(data);
    setState(() => _selectedCol = at.clamp(0, _cols - 1));
  }

  void _deleteCol(int at) {
    if (_cols <= 1) return;
    final data = _snapshot();
    for (final row in data) {
      if (row.isNotEmpty) row.removeAt(at.clamp(0, row.length - 1));
    }
    if (_widths.isNotEmpty) {
      _widths.removeAt(at.clamp(0, _widths.length - 1));
    }
    _disposeCells();
    _cols = data.first.length;
    _initCells(data);
    setState(() => _selectedCol = _selectedCol.clamp(0, _cols - 1));
  }

  void _clearSelected() {
    _cells[_selectedRow][_selectedCol].text = '';
    setState(() {});
  }

  Future<void> _pasteGrid() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    if (raw.isEmpty) return;
    final grid = TableBlock.parseClipboardGrid(raw);
    if (grid == null || grid.isEmpty) {
      _cells[_selectedRow][_selectedCol].text = raw;
      setState(() {});
      return;
    }
    final dataNow = _snapshot();
    final needCols = _selectedCol + grid.first.length;
    final needRows = _selectedRow + grid.length;
    while (dataNow.length < needRows) {
      dataNow.add(List.filled(_cols, ''));
    }
    if (needCols > _cols) {
      final add = needCols - _cols;
      for (final row in dataNow) {
        row.addAll(List.filled(add, ''));
      }
      _widths.addAll(List.filled(add, 1.0));
    }
    for (var i = 0; i < grid.length; i++) {
      for (var j = 0; j < grid[i].length; j++) {
        dataNow[_selectedRow + i][_selectedCol + j] = grid[i][j];
      }
    }
    _disposeCells();
    _rows = dataNow.length;
    _cols = dataNow.first.length;
    _initCells(dataNow);
    setState(() {});
  }

  String _toMarkup() {
    final block = TableBlock(
      start: 0,
      end: 0,
      cells: _snapshot(),
      colWidths: List<double>.from(_widths),
      caption: _caption.text,
      colAligns: [for (var c = 0; c < _widths.length; c++) c < widget.initialAligns.length ? widget.initialAligns[c] : 'l'],
      header: widget.initialHeader,
    );
    return '\n${block.toMarkup()}\n';
  }

  @override
  void dispose() {
    _caption.dispose();
    _disposeCells();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.92;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(type: MaterialType.transparency, child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(
                  widget.editing ? 'Cədvəli redaktə et' : 'Cədvəl daxil et',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _chip(Icons.add, 'Sətir+', () => _insertRow(_selectedRow + 1)),
                _chip(Icons.remove, 'Sətir−', () => _deleteRow(_selectedRow)),
                _chip(Icons.view_column, 'Sütun+', () => _insertCol(_selectedCol + 1)),
                _chip(Icons.view_column_outlined, 'Sütun−', () => _deleteCol(_selectedCol)),
                _chip(Icons.clear, 'Xananı sil', _clearSelected),
                _chip(Icons.content_paste, 'Yapışdır', _pasteGrid),
                _chip(Icons.unfold_more, '$_rows×$_cols', () {}),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text('Sətir', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _rows.toDouble().clamp(1, 40),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_rows',
                    onChanged: (v) => _resize(v.round(), _cols),
                  ),
                ),
                Text('Sütun', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _cols.toDouble().clamp(1, 12),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_cols',
                    onChanged: (v) => _resize(_rows, v.round()),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Xana S${_selectedRow + 1} C${_selectedCol + 1} · toxun və yaz · sürgü = sütun eni',
              style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white54),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Sütun eni',
                  style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _widths[_selectedCol.clamp(0, _widths.length - 1)],
                    min: 0.5,
                    max: 2.5,
                    divisions: 20,
                    label: _widths[_selectedCol.clamp(0, _widths.length - 1)]
                        .toStringAsFixed(1),
                    onChanged: (v) {
                      setState(() {
                        _widths[_selectedCol.clamp(0, _widths.length - 1)] = v;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.white24, width: 1),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: {
                    for (var c = 0; c < _cols; c++)
                      c: FixedColumnWidth(110.0 * _widths[c]),
                  },
                  children: List.generate(_rows, (r) {
                    return TableRow(
                      decoration: BoxDecoration(
                        color: r == 0
                            ? const Color(0xFF0D1B3E)
                            : (r == _selectedRow
                                ? const Color(0xFF1E1E28)
                                : const Color(0xFF181818)),
                      ),
                      children: List.generate(_cols, (c) {
                        final selected =
                            r == _selectedRow && c == _selectedCol;
                        return Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.all(4),
                          decoration: selected
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFC9A84C),
                                    width: 2,
                                  ),
                                )
                              : null,
                          child: TextField(
                            controller: _cells[r][c],
                            maxLines: 4,
                            minLines: 1,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  r == 0 ? FontWeight.w700 : FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: r == 0 ? 'Başlıq' : 'Yaz…',
                              hintStyle: const TextStyle(
                                color: Colors.white30,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => setState(() {
                              _selectedRow = r;
                              _selectedCol = c;
                            }),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _caption,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cədvəl başlığı (məs. Cədvəl 1. Personajlar)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _toMarkup()),
                  icon: const Icon(Icons.check),
                  label: Text(
                    widget.editing ? 'Cədvəli yenilə' : 'Cədvəli daxil et',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1B3E),
                    foregroundColor: const Color(0xFFC9A84C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      )),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        onPressed: onTap,
        backgroundColor: const Color(0xFF2A2A2A),
        side: BorderSide.none,
      ),
    );
  }
}
