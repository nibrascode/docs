import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/page_size.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/ui_strings.dart';

class DocumentSettings {
  String language;
  PageSize pageSize;
  bool landscape;
  double marginMm;
  String fontFamily;
  double fontSize;
  double lineHeight;
  bool showPageNumbers;
  String pageNumberPos;
  String headerText;
  String footerText;
  bool autoSave;
  String author;
  String subtitle;
  bool firstLineIndent;
  bool chapterNewPage;
  String bookNotes;
  int wordGoal;
  int dailyGoal;
  String genre;
  String series;
  String isbn;
  String publisher;
  int pageNumberStartPage;
  int pageNumberStartAt;
  int pageBgColor;
  bool pageFrame;
  String pageNumberStyle;
  bool bookHeader;

  DocumentSettings({
    this.language = 'az',
    this.pageSize = PageSize.a4,
    this.landscape = false,
    this.marginMm = 20,
    this.fontFamily = 'Georgia',
    this.fontSize = 16,
    this.lineHeight = 1.7,
    this.showPageNumbers = true,
    this.pageNumberPos = 'bottom-center',
    this.headerText = '',
    this.footerText = '',
    this.autoSave = true,
    this.author = '',
    this.subtitle = '',
    this.firstLineIndent = true,
    this.chapterNewPage = true,
    this.bookNotes = '',
    this.wordGoal = 50000,
    this.dailyGoal = 1000,
    this.genre = '',
    this.series = '',
    this.isbn = '',
    this.publisher = '',
    this.pageNumberStartPage = 1,
    this.pageNumberStartAt = 1,
    this.pageBgColor = 0xFFFFFFFF,
    this.pageFrame = false,
    this.pageNumberStyle = 'plain',
    this.bookHeader = false,
  });
}

Future<DocumentSettings?> showDocumentSettingsSheet(
  BuildContext context,
  DocumentSettings initial, {
  VoidCallback? onOpenCover,
}) {
  return showModalBottomSheet<DocumentSettings>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DocSettingsBody(initial: initial, onOpenCover: onOpenCover),
  );
}

class _DocSettingsBody extends StatefulWidget {
  final DocumentSettings initial;
  final VoidCallback? onOpenCover;
  const _DocSettingsBody({required this.initial, this.onOpenCover});
  @override
  State<_DocSettingsBody> createState() => _DocSettingsBodyState();
}

class _DocSettingsBodyState extends State<_DocSettingsBody> {
  late DocumentSettings s;
  late TextEditingController _header;
  late TextEditingController _footer;
  late TextEditingController _author;
  late TextEditingController _subtitle;
  late TextEditingController _notes;
  late TextEditingController _genre;
  late TextEditingController _series;
  late TextEditingController _isbn;
  late TextEditingController _publisher;

  @override
  void initState() {
    super.initState();
    s = DocumentSettings(
      language: widget.initial.language,
      pageSize: widget.initial.pageSize,
      landscape: widget.initial.landscape,
      marginMm: widget.initial.marginMm,
      fontFamily: widget.initial.fontFamily,
      fontSize: widget.initial.fontSize,
      lineHeight: widget.initial.lineHeight,
      showPageNumbers: widget.initial.showPageNumbers,
      pageNumberPos: widget.initial.pageNumberPos,
      headerText: widget.initial.headerText,
      footerText: widget.initial.footerText,
      autoSave: widget.initial.autoSave,
      author: widget.initial.author,
      subtitle: widget.initial.subtitle,
      firstLineIndent: widget.initial.firstLineIndent,
      chapterNewPage: widget.initial.chapterNewPage,
      bookNotes: widget.initial.bookNotes,
      wordGoal: widget.initial.wordGoal,
      dailyGoal: widget.initial.dailyGoal,
      genre: widget.initial.genre,
      series: widget.initial.series,
      isbn: widget.initial.isbn,
      publisher: widget.initial.publisher,
      pageNumberStartPage: widget.initial.pageNumberStartPage,
      pageNumberStartAt: widget.initial.pageNumberStartAt,
      pageBgColor: widget.initial.pageBgColor,
      pageFrame: widget.initial.pageFrame,
      pageNumberStyle: widget.initial.pageNumberStyle,
      bookHeader: widget.initial.bookHeader,
    );
    _header = TextEditingController(text: s.headerText);
    _footer = TextEditingController(text: s.footerText);
    _author = TextEditingController(text: s.author);
    _subtitle = TextEditingController(text: s.subtitle);
    _notes = TextEditingController(text: s.bookNotes);
    _genre = TextEditingController(text: s.genre);
    _series = TextEditingController(text: s.series);
    _isbn = TextEditingController(text: s.isbn);
    _publisher = TextEditingController(text: s.publisher);
  }

  @override
  void dispose() {
    _header.dispose();
    _footer.dispose();
    _author.dispose();
    _subtitle.dispose();
    _notes.dispose();
    _genre.dispose();
    _series.dispose();
    _isbn.dispose();
    _publisher.dispose();
    super.dispose();
  }

  void _commit() {
    s.headerText = _header.text;
    s.footerText = _footer.text;
    s.author = _author.text;
    s.subtitle = _subtitle.text;
    s.bookNotes = _notes.text;
    s.genre = _genre.text.trim();
    s.series = _series.text.trim();
    s.isbn = _isbn.text.trim();
    s.publisher = _publisher.text.trim();
    Navigator.pop(context, s);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.88;
    final l10n = AppLocalizations.of(context);
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  l10n.t(az: 'Kitab ayarları', en: 'Book settings', ru: 'Настройки книги', ar: 'إعدادات الكتاب'),
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: _commit, child: Text(l10n.t(az: 'Hazır', en: 'Done', ru: 'Готово', ar: 'تم'))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                InkWell(
                  onTap: widget.onOpenCover,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D1B3E), Color(0xFF1A1630)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFC9A84C), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_stories, color: Color(0xFFC9A84C), size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t(az: 'Üz səhifə', en: 'Cover page', ru: 'Обложка', ar: 'غلاف'),
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trf('Nümunə seç, {size} ölçüdə dəyiş', {'size': s.pageSize.label}),
                                style: GoogleFonts.dmSans(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFFC9A84C)),
                      ],
                    ),
                  ),
                ),
                _label(tr('Ölçü')),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in PageSize.values)
                      ChoiceChip(
                        label: Text(p.label),
                        selected: s.pageSize == p,
                        onSelected: (_) => setState(() => s.pageSize = p),
                      ),
                  ],
                ),
                SwitchListTile(
                  title: Text(tr('Albom (yan)'),
                      style: TextStyle(color: Colors.white)),
                  value: s.landscape,
                  onChanged: (v) => setState(() => s.landscape = v),
                ),
                _label(tr('Kənar')),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [
                      (12.0, tr('Dar')),
                      (20.0, tr('Normal')),
                      (30.0, tr('Geniş')),
                    ])
                      ChoiceChip(
                        label: Text(m.$2),
                        selected: s.marginMm == m.$1,
                        onSelected: (_) => setState(() => s.marginMm = m.$1),
                      ),
                  ],
                ),
                _label(tr('Səhifə nömrəsi')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Göstər'),
                      style: TextStyle(color: Colors.white)),
                  value: s.showPageNumbers,
                  onChanged: (v) => setState(() => s.showPageNumbers = v),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in [
                      ('bottom-center', tr('Alt orta')),
                      ('bottom-right', tr('Alt sağ')),
                      ('bottom-left', tr('Alt sol')),
                      ('top-center', tr('Üst orta')),
                      ('top-right', tr('Üst sağ')),
                      ('top-left', tr('Üst sol')),
                    ])
                      ChoiceChip(
                        label: Text(e.$2),
                        selected: s.pageNumberPos == e.$1,
                        onSelected: (_) =>
                            setState(() => s.pageNumberPos = e.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in [
                      ('plain', '1'),
                      ('dashed', '- 1 -'),
                      ('oval', '①'),
                      ('eastern', '١٢٣'),
                      ('easternDash', '- ١٠١ -'),
                    ])
                      ChoiceChip(
                        label: Text(e.$2),
                        selected: s.pageNumberStyle == e.$1,
                        onSelected: (_) =>
                            setState(() => s.pageNumberStyle = e.$1),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Kitab çərçivəsi'),
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(tr('İki xəttli səhifə çərçivəsi'),
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: s.pageFrame,
                  onChanged: (v) => setState(() => s.pageFrame = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Kitab başlığı'),
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(tr('Nömrə ovalda, altı iki xətt'),
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: s.bookHeader,
                  onChanged: (v) => setState(() => s.bookHeader = v),
                ),
                _stepper(
                  tr('Hansı səhifədən'),
                  s.pageNumberStartPage,
                  1,
                  30,
                  (v) => setState(() => s.pageNumberStartPage = v),
                ),
                _stepper(
                  tr('İlk rəqəm'),
                  s.pageNumberStartAt,
                  1,
                  99,
                  (v) => setState(() => s.pageNumberStartAt = v),
                ),
                Text(
                  trf('Səhifə {p}-də {a}, sonra {b}, {c}…', {'p': s.pageNumberStartPage, 'a': s.pageNumberStartAt, 'b': s.pageNumberStartAt + 1, 'c': s.pageNumberStartAt + 2}),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                _label(tr('Yazı')),
                DropdownButton<String>(
                  value: [
                    'Georgia',
                    'Lora',
                    'Times New Roman',
                    'Roboto',
                    'Arial',
                  ].contains(s.fontFamily)
                      ? s.fontFamily
                      : 'Georgia',
                  dropdownColor: const Color(0xFF1E1E1E),
                  isExpanded: true,
                  items: [
                    for (final f in [
                      'Georgia',
                      'Lora',
                      'Times New Roman',
                      'Roboto',
                      'Arial',
                    ])
                      DropdownMenuItem(
                        value: f,
                        child:
                            Text(f, style: const TextStyle(color: Colors.white)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => s.fontFamily = v);
                  },
                ),
                _label(trf('Ölçü: {n}', {'n': s.fontSize.round()})),
                Slider(
                  value: s.fontSize,
                  min: 10,
                  max: 36,
                  divisions: 26,
                  onChanged: (v) => setState(() => s.fontSize = v),
                ),
                _label(trf('Sətir aralığı: {n}', {'n': s.lineHeight.toStringAsFixed(1)})),
                Slider(
                  value: s.lineHeight,
                  min: 1.0,
                  max: 2.5,
                  divisions: 15,
                  onChanged: (v) => setState(() => s.lineHeight = v),
                ),
                SwitchListTile(
                  title: Text(tr('Abzas girintisi'),
                      style: TextStyle(color: Colors.white)),
                  value: s.firstLineIndent,
                  onChanged: (v) => setState(() => s.firstLineIndent = v),
                ),
                const Divider(color: Colors.white24, height: 32),
                _label('Kitab'),
                TextField(
                  controller: _author,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: tr('Müəllif'),
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                TextField(
                  controller: _subtitle,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: tr('Alt başlıq'),
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('Yazı yerində «Üz qabığı» düyməsi ana səhifə yaradır.'),
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                SwitchListTile(
                  title: Text(tr('Fəsil yeni səhifədən'),
                      style: TextStyle(color: Colors.white)),
                  value: s.chapterNewPage,
                  onChanged: (v) => setState(() => s.chapterNewPage = v),
                ),
                ExpansionTile(
                  title: Text(tr('Daha çox'),
                      style: TextStyle(color: Colors.white70)),
                  collapsedIconColor: Colors.white54,
                  iconColor: Colors.white70,
                  children: [
                    TextField(
                      controller: _genre,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: tr('Janr'),
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    TextField(
                      controller: _series,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: tr('Seriya'),
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    TextField(
                      controller: _publisher,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: tr('Nəşriyyat'),
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    TextField(
                      controller: _isbn,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'ISBN',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    TextField(
                      controller: _header,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: tr('Üst qeyd'),
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    TextField(
                      controller: _footer,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: tr('Alt qeyd'),
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    SwitchListTile(
                      title: Text(tr('Avto-saxla'),
                          style: TextStyle(color: Colors.white)),
                      value: s.autoSave,
                      onChanged: (v) => setState(() => s.autoSave = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          t,
          style: GoogleFonts.dmSans(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _stepper(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
