import 'package:docspro/widgets/dark_sheet.dart';
import '../../../core/rich_markup.dart';
import '../../../core/cover_art.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/page_size.dart';
import '../../../l10n/app_localizations.dart';

TextStyle _serif({
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'LibreBaskerville',
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle _sans({
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'DMSans',
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class CoverData {
  final String templateId;
  final String title;
  final String subtitle;
  final String author;
  final String year;
  final String publisher;
  final int titleColor;
  final double titleScale;
  final String titlePlace;

  const CoverData({
    required this.templateId,
    required this.title,
    this.subtitle = '',
    this.author = '',
    this.year = '',
    this.publisher = '',
    this.titleColor = 0,
    this.titleScale = 1,
    this.titlePlace = 'middle',
  });

  String toMarkup() {
    String esc(String s) => s.replaceAll('"', "'");
    final hex = titleColor == 0
        ? ''
        : ' tc=${(titleColor & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return '[COVER id=$templateId title="${esc(title)}" sub="${esc(subtitle)}" '
        'author="${esc(author)}" year="${esc(year)}" publisher="${esc(publisher)}"'
        '$hex ts=${titleScale.toStringAsFixed(2)} tp=$titlePlace]';
  }

  /// Default cover title (the user changes it in the cover editor).
  static const brandTitle = 'Nibras Code';

  /// Plain text of a cover field: no markup, line prefixes or block tokens
  /// (older versions copied the first raw line of the document here).
  static String cleanText(String s) {
    var t = s.trim();
    if (RegExp(r'^\[(COVER|img|TABLE|note)').hasMatch(t)) return '';
    t = t.replaceAll(RegExp(r'\[align=\w+\]'), '');
    t = t.replaceFirst(RegExp(r'^(#{1,6} |> |[•-] |\d+[.)] )'), '');
    t = RichMarkup.parse(t).plain;
    t = t.replaceAll(RegExp(r'\[\^\d+\]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static const _untitled = {'untitled document', 'untitled', 'adsız sənəd', 'adsız', 'без названия', 'документ без названия', 'مستند بدون عنوان', 'بدون عنوان'};

  static String cleanTitle(String s) {
    final t = cleanText(s);
    if (t.isEmpty || _untitled.contains(t.toLowerCase())) return brandTitle;
    return t.length > 90 ? '${t.substring(0, 90).trimRight()}…' : t;
  }

  static CoverData? parse(String raw) {
    if (!raw.contains('[COVER')) return null;
    String attr(String k) =>
        RegExp('$k="([^"]*)"').firstMatch(raw)?.group(1) ?? '';
    final id = RegExp(r'id=([a-zA-Z0-9_]+)').firstMatch(raw)?.group(1) ??
        'classic';
    final tc = RegExp(r'tc=([0-9A-Fa-f]{6})').firstMatch(raw)?.group(1);
    final ts = double.tryParse(
          RegExp(r'ts=([0-9.]+)').firstMatch(raw)?.group(1) ?? '',
        ) ??
        1;
    final tp = RegExp(r'tp=(top|middle|bottom)').firstMatch(raw)?.group(1) ??
        'middle';
    return CoverData(
      templateId: id,
      title: cleanTitle(attr('title')),
      subtitle: cleanText(attr('sub')),
      author: cleanText(attr('author')),
      year: attr('year'),
      publisher: attr('publisher'),
      titleColor: tc == null ? 0 : int.parse('FF$tc', radix: 16),
      titleScale: ts.clamp(0.7, 1.8),
      titlePlace: tp,
    );
  }
}

class CoverTemplate {
  final String id;
  final String name;
  final Color bg;
  final Color fg;
  final Color accent;
  final String layout; // classic, navy, banner, minimal, ornate, poetry, linen, night

  const CoverTemplate({
    required this.id,
    required this.name,
    required this.bg,
    required this.fg,
    required this.accent,
    required this.layout,
  });
}

final coverTemplates = <CoverTemplate>[
  ..._baseCoverTemplates,
  for (final c in artCovers)
    CoverTemplate(id: c.templateId, name: c.name, bg: c.bg, fg: c.ink, accent: c.accent, layout: 'nibrasart'),
];

const _baseCoverTemplates = <CoverTemplate>[
  CoverTemplate(
    id: 'classic',
    name: 'Klassik',
    bg: Color(0xFFF4EBD8),
    fg: Color(0xFF1A1630),
    accent: Color(0xFFC9A84C),
    layout: 'classic',
  ),
  CoverTemplate(
    id: 'navy',
    name: 'Gecə',
    bg: Color(0xFF0B1733),
    fg: Color(0xFFF5E6C8),
    accent: Color(0xFFC9A84C),
    layout: 'navy',
  ),
  CoverTemplate(
    id: 'linen',
    name: 'Kətan',
    bg: Color(0xFFE8D9BE),
    fg: Color(0xFF3A2A18),
    accent: Color(0xFF8A6A1A),
    layout: 'linen',
  ),
  CoverTemplate(
    id: 'banner',
    name: 'Banner',
    bg: Color(0xFFFAFAF7),
    fg: Color(0xFF111111),
    accent: Color(0xFF8B1E3F),
    layout: 'banner',
  ),
  CoverTemplate(
    id: 'minimal',
    name: 'Minimal',
    bg: Color(0xFFF7F7F4),
    fg: Color(0xFF111111),
    accent: Color(0xFF111111),
    layout: 'minimal',
  ),
  CoverTemplate(
    id: 'ornate',
    name: 'Qızıl çərçivə',
    bg: Color(0xFF1A1208),
    fg: Color(0xFFE8C97A),
    accent: Color(0xFFC9A84C),
    layout: 'ornate',
  ),
  CoverTemplate(
    id: 'poetry',
    name: 'Poeziya',
    bg: Color(0xFFF3E6D8),
    fg: Color(0xFF2C1810),
    accent: Color(0xFF9A6B4F),
    layout: 'poetry',
  ),
  CoverTemplate(
    id: 'night',
    name: 'Qara',
    bg: Color(0xFF0A0A0A),
    fg: Color(0xFFF2F2F2),
    accent: Color(0xFFC9A84C),
    layout: 'night',
  ),
  CoverTemplate(
    id: 'emerald',
    name: 'Zümrüd',
    bg: Color(0xFF0F3D32),
    fg: Color(0xFFF3E6C4),
    accent: Color(0xFFD4AF37),
    layout: 'emerald',
  ),
  CoverTemplate(
    id: 'crimson',
    name: 'Qırmızı cild',
    bg: Color(0xFF6B1220),
    fg: Color(0xFFF7E7C5),
    accent: Color(0xFFE8C97A),
    layout: 'crimson',
  ),
  CoverTemplate(
    id: 'manuscript',
    name: 'Əlyazma',
    bg: Color(0xFFF1DEC0),
    fg: Color(0xFF3B1E12),
    accent: Color(0xFF8C1C13),
    layout: 'manuscript',
  ),
  CoverTemplate(
    id: 'geometric',
    name: 'Həndəsi',
    bg: Color(0xFF101C3A),
    fg: Color(0xFFF6E7C1),
    accent: Color(0xFFC9A84C),
    layout: 'geometric',
  ),
  CoverTemplate(
    id: 'royal',
    name: 'Şahane',
    bg: Color(0xFF2A1540),
    fg: Color(0xFFF0D48A),
    accent: Color(0xFFE0B84A),
    layout: 'royal',
  ),
  CoverTemplate(
    id: 'marble',
    name: 'Mərmər',
    bg: Color(0xFFD9E0E8),
    fg: Color(0xFF1B2430),
    accent: Color(0xFF4A667A),
    layout: 'marble',
  ),
  CoverTemplate(
    id: 'ocean',
    name: 'Dəniz',
    bg: Color(0xFF0B3A4A),
    fg: Color(0xFFE8F4F8),
    accent: Color(0xFF7ED6DF),
    layout: 'ocean',
  ),
  CoverTemplate(
    id: 'forest',
    name: 'Meşə',
    bg: Color(0xFF1B3324),
    fg: Color(0xFFE6E0C8),
    accent: Color(0xFFC4A35A),
    layout: 'emerald',
  ),
  CoverTemplate(
    id: 'desert',
    name: 'Səhra',
    bg: Color(0xFFC9A06A),
    fg: Color(0xFF2C1810),
    accent: Color(0xFF7A3E1D),
    layout: 'linen',
  ),
  CoverTemplate(
    id: 'snow',
    name: 'Qar',
    bg: Color(0xFFF4F7FB),
    fg: Color(0xFF1A2A44),
    accent: Color(0xFF7A8BA6),
    layout: 'minimal',
  ),
  CoverTemplate(
    id: 'bronze',
    name: 'Bürünc',
    bg: Color(0xFF3A2414),
    fg: Color(0xFFE8C9A0),
    accent: Color(0xFFC47A3A),
    layout: 'leather',
  ),
  CoverTemplate(
    id: 'rose',
    name: 'Qızılgül',
    bg: Color(0xFF4A1730),
    fg: Color(0xFFF6DCE8),
    accent: Color(0xFFE8A0B8),
    layout: 'poetry',
  ),
  CoverTemplate(
    id: 'academic',
    name: 'Akademik',
    bg: Color(0xFF0E2244),
    fg: Color(0xFFF4E6C4),
    accent: Color(0xFFC9A84C),
    layout: 'academic',
  ),
  CoverTemplate(
    id: 'leather',
    name: 'Dəri',
    bg: Color(0xFF4A2C1A),
    fg: Color(0xFFF0D9B5),
    accent: Color(0xFFD4A056),
    layout: 'leather',
  ),
  CoverTemplate(
    id: 'sunrise',
    name: 'Sübh',
    bg: Color(0xFFE8A060),
    fg: Color(0xFF2A1408),
    accent: Color(0xFF8C3A12),
    layout: 'band',
  ),
  CoverTemplate(
    id: 'nibras',
    name: 'Nibras',
    bg: Color(0xFF071428),
    fg: Color(0xFFF5E6C8),
    accent: Color(0xFFC9A84C),
    layout: 'nibras',
  ),
  CoverTemplate(
    id: 'ink',
    name: 'Mürəkkəb',
    bg: Color(0xFF12151C),
    fg: Color(0xFFE8E4D8),
    accent: Color(0xFF8AA0B8),
    layout: 'night',
  ),
  CoverTemplate(
    id: 'ivory',
    name: 'Fil sümüyü',
    bg: Color(0xFFF6F0E4),
    fg: Color(0xFF2A2218),
    accent: Color(0xFF8A6A3A),
    layout: 'classic',
  ),
  CoverTemplate(
    id: 'copper',
    name: 'Mis',
    bg: Color(0xFF8C3B1E),
    fg: Color(0xFFF8E6D0),
    accent: Color(0xFFE0B070),
    layout: 'crimson',
  ),
  CoverTemplate(
    id: 'slate',
    name: 'Şifer',
    bg: Color(0xFF3A4450),
    fg: Color(0xFFF0F2F4),
    accent: Color(0xFFA8C0C8),
    layout: 'marble',
  ),
  CoverTemplate(
    id: 'botanical',
    name: 'Botanika',
    bg: Color(0xFFE7EFD8),
    fg: Color(0xFF1E3318),
    accent: Color(0xFF4A7A3A),
    layout: 'botanical',
  ),
  CoverTemplate(
    id: 'vintage',
    name: 'Köhnə cild',
    bg: Color(0xFF5C1A1A),
    fg: Color(0xFFF0D9A0),
    accent: Color(0xFFC9A84C),
    layout: 'ornate',
  ),
  CoverTemplate(
    id: 'splitnavy',
    name: 'İki hissə',
    bg: Color(0xFFF7F1E3),
    fg: Color(0xFF0D1B3E),
    accent: Color(0xFF0D1B3E),
    layout: 'split',
  ),
  CoverTemplate(
    id: 'sand',
    name: 'Qum',
    bg: Color(0xFFE6D2A8),
    fg: Color(0xFF3A2A14),
    accent: Color(0xFF8A5A22),
    layout: 'linen',
  ),
  CoverTemplate(
    id: 'teal',
    name: 'Firuzə',
    bg: Color(0xFF145A5A),
    fg: Color(0xFFF0E6C8),
    accent: Color(0xFFE0C070),
    layout: 'band',
  ),
  CoverTemplate(
    id: 'plum',
    name: 'Gavalı',
    bg: Color(0xFF3A1638),
    fg: Color(0xFFF4DCE8),
    accent: Color(0xFFD4A0C0),
    layout: 'royal',
  ),
  CoverTemplate(
    id: 'olive',
    name: 'Zeytun',
    bg: Color(0xFF4A4A22),
    fg: Color(0xFFF4E8C4),
    accent: Color(0xFFC9B86A),
    layout: 'leather',
  ),
  CoverTemplate(
    id: 'sky',
    name: 'Səma',
    bg: Color(0xFFD6E8F4),
    fg: Color(0xFF12304A),
    accent: Color(0xFF2A6A9A),
    layout: 'minimal',
  ),
  CoverTemplate(
    id: 'goldleaf',
    name: 'Qızıl yarpaq',
    bg: Color(0xFF1A1408),
    fg: Color(0xFFF0D48A),
    accent: Color(0xFFE0B84A),
    layout: 'nibras',
  ),
  CoverTemplate(
    id: 'atlas',
    name: 'Atlas',
    bg: Color(0xFF0A2342),
    fg: Color(0xFFF3E6C4),
    accent: Color(0xFFD4AF37),
    layout: 'academic',
  ),
  CoverTemplate(
    id: 'morocco',
    name: 'Marakesh',
    bg: Color(0xFF7A1F2B),
    fg: Color(0xFFF6E3C4),
    accent: Color(0xFFE0B070),
    layout: 'leather',
  ),
  CoverTemplate(
    id: 'oxford',
    name: 'Oxford',
    bg: Color(0xFF0C1B33),
    fg: Color(0xFFF7F1E1),
    accent: Color(0xFFC9A84C),
    layout: 'academic',
  ),
  CoverTemplate(
    id: 'cairo',
    name: 'Qahirə',
    bg: Color(0xFF123524),
    fg: Color(0xFFF4E7C5),
    accent: Color(0xFFD4AF37),
    layout: 'nibras',
  ),
  CoverTemplate(
    id: 'silk',
    name: 'İpək',
    bg: Color(0xFF3D1E4A),
    fg: Color(0xFFF6E6F0),
    accent: Color(0xFFE0B0C8),
    layout: 'band',
  ),
  CoverTemplate(
    id: 'vellum',
    name: 'Vellum',
    bg: Color(0xFFF3E6C8),
    fg: Color(0xFF3A2414),
    accent: Color(0xFF8C3A1E),
    layout: 'manuscript',
  ),
  CoverTemplate(
    id: 'paris',
    name: 'Paris',
    bg: Color(0xFF111111),
    fg: Color(0xFFF5F5F5),
    accent: Color(0xFFE8C97A),
    layout: 'minimal',
  ),
  CoverTemplate(
    id: 'istanbul',
    name: 'İstanbul',
    bg: Color(0xFF1A2744),
    fg: Color(0xFFF0D48A),
    accent: Color(0xFFC9A84C),
    layout: 'ornate',
  ),
  CoverTemplate(id: 'medal_teal', name: 'Medalyon', bg: Color(0xFF1C3D45), fg: Color(0xFFF4E7C5), accent: Color(0xFFC6A15B), layout: 'medallion'),
  CoverTemplate(id: 'medal_navy', name: 'Medalyon gecə', bg: Color(0xFF152238), fg: Color(0xFFF6E7C1), accent: Color(0xFFD4AF37), layout: 'medallion'),
  CoverTemplate(id: 'medal_wine', name: 'Medalyon şərab', bg: Color(0xFF5C1A2A), fg: Color(0xFFF8E7C8), accent: Color(0xFFE0C070), layout: 'medallion'),
  CoverTemplate(id: 'medal_forest', name: 'Medalyon yaşıl', bg: Color(0xFF1B3A2F), fg: Color(0xFFF3E6C4), accent: Color(0xFFD4AF37), layout: 'medallion'),
  CoverTemplate(id: 'medal_black', name: 'Qara qızıl', bg: Color(0xFF121212), fg: Color(0xFFF5E6C8), accent: Color(0xFFC9A84C), layout: 'medallion'),
  CoverTemplate(id: 'lit_cream', name: 'Ədəbi', bg: Color(0xFFF6F1E7), fg: Color(0xFF2A241C), accent: Color(0xFF6B8F3C), layout: 'literary'),
  CoverTemplate(id: 'lit_sand', name: 'Kağız', bg: Color(0xFFF3E6D0), fg: Color(0xFF3A2A18), accent: Color(0xFF8C5A2B), layout: 'literary'),
  CoverTemplate(id: 'lit_sage', name: 'Zeytun', bg: Color(0xFFF4F1E6), fg: Color(0xFF243024), accent: Color(0xFF5E7A3A), layout: 'literary'),
  CoverTemplate(id: 'curve_navy', name: 'Dalğa', bg: Color(0xFFF7F7F7), fg: Color(0xFF111111), accent: Color(0xFFE25B12), layout: 'curve'),
  CoverTemplate(id: 'curve_teal', name: 'Dalğa firuzə', bg: Color(0xFFF4F7F6), fg: Color(0xFF102820), accent: Color(0xFF0E7C66), layout: 'curve'),
  CoverTemplate(id: 'curve_wine', name: 'Dalğa tünd', bg: Color(0xFFF8F4F2), fg: Color(0xFF2A1214), accent: Color(0xFF8C1C2C), layout: 'curve'),
  CoverTemplate(id: 'diag_teal', name: 'Kəsim', bg: Color(0xFF0E4C54), fg: Colors.white, accent: Color(0xFF2A2E33), layout: 'diagonal'),
  CoverTemplate(id: 'diag_navy', name: 'Kəsim göy', bg: Color(0xFF16315C), fg: Colors.white, accent: Color(0xFFE07A2F), layout: 'diagonal'),
  CoverTemplate(id: 'diag_wine', name: 'Kəsim tünd', bg: Color(0xFF6B2430), fg: Colors.white, accent: Color(0xFF2C2C2C), layout: 'diagonal'),
  CoverTemplate(id: 'diag_black', name: 'Kəsim qara', bg: Color(0xFF1A1A1A), fg: Colors.white, accent: Color(0xFFC9A84C), layout: 'diagonal'),
  CoverTemplate(id: 'nc_emerald', name: 'Nibras zümrüd', bg: Color(0xFF1D4537), fg: Color(0xFFECD9A4), accent: Color(0xFFE2BF63), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_wine', name: 'Nibras şərab', bg: Color(0xFF5B2129), fg: Color(0xFFECD9A4), accent: Color(0xFFE2BF63), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_navy', name: 'Nibras göy', bg: Color(0xFF22396A), fg: Color(0xFFECD9A4), accent: Color(0xFFE2BF63), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_gold', name: 'Nibras qızılı', bg: Color(0xFF4A3A12), fg: Color(0xFFF1E2B4), accent: Color(0xFFE8C66A), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_black', name: 'Nibras qara', bg: Color(0xFF161616), fg: Color(0xFFEADBB0), accent: Color(0xFFD4AF37), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_teal', name: 'Nibras firuzə', bg: Color(0xFF154A4E), fg: Color(0xFFEDE0B8), accent: Color(0xFFD9B968), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_plum', name: 'Nibras bənövşə', bg: Color(0xFF41213F), fg: Color(0xFFEEDDB2), accent: Color(0xFFDDB866), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_olive', name: 'Nibras zeytun', bg: Color(0xFF3B4220), fg: Color(0xFFEEE0B6), accent: Color(0xFFD8B760), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_brown', name: 'Nibras qəhvəyi', bg: Color(0xFF4A2C1A), fg: Color(0xFFF0DDB2), accent: Color(0xFFDDB260), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_slate', name: 'Nibras boz', bg: Color(0xFF2E3640), fg: Color(0xFFE9DDB8), accent: Color(0xFFD2B46A), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_ruby', name: 'Nibras yaqut', bg: Color(0xFF7A1F2B), fg: Color(0xFFF2E1B8), accent: Color(0xFFE8C774), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_sapphire', name: 'Nibras safir', bg: Color(0xFF1B2C58), fg: Color(0xFFE9DDB4), accent: Color(0xFFD9BB6C), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_forest', name: 'Nibras meşə', bg: Color(0xFF1A3324), fg: Color(0xFFECDDB0), accent: Color(0xFFD6B35E), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_indigo', name: 'Nibras indiqo', bg: Color(0xFF2A2559), fg: Color(0xFFECDDB6), accent: Color(0xFFDCBD70), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_copper', name: 'Nibras mis', bg: Color(0xFF6A3A1E), fg: Color(0xFFF3E2BC), accent: Color(0xFFE9B877), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_ivory', name: 'Nibras fil dişi', bg: Color(0xFFEFE6D2), fg: Color(0xFF3A2A18), accent: Color(0xFF9A7428), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_cream', name: 'Nibras krem', bg: Color(0xFFF4EBD8), fg: Color(0xFF1D4537), accent: Color(0xFFB08A30), layout: 'nibrascode'),
  CoverTemplate(id: 'nc_rose', name: 'Nibras qızılgül', bg: Color(0xFF6B2E3A), fg: Color(0xFFF2E1C2), accent: Color(0xFFE3BE7A), layout: 'nibrascode'),
];

CoverTemplate coverById(String id) => coverTemplates.firstWhere(
      (t) => t.id == id,
      orElse: () => coverTemplates.first,
    );

class CoverPagePreview extends StatelessWidget {
  final CoverTemplate template;
  final CoverData data;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const CoverPagePreview({
    super.key,
    required this.template,
    required this.data,
    required this.width,
    required this.height,
    this.onTap,
  });

  static const double _designW = 320;

  @override
  Widget build(BuildContext context) {
    // Lay the cover out once at a fixed design width and scale it, so a
    // thumbnail is an exact miniature of the full cover (no clamped fonts,
    // no overflow at small sizes).
    if ((width - _designW).abs() > 0.5) {
      final design = CoverPagePreview(
        template: template,
        data: data,
        width: _designW,
        height: _designW * height / width,
      );
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(width: width, height: height, child: FittedBox(fit: BoxFit.fill, child: design)),
      );
    }
    final title = data.title.trim().isEmpty ? CoverData.brandTitle : data.title.trim();
    final author = data.author.trim();
    final sub = data.subtitle.trim();
    final scale = width / 320.0;
    final mul = data.titleScale <= 0 ? 1.0 : data.titleScale;
    var titleSize = (22 * scale * mul).clamp(11.0, 48.0);
    // Shrink long titles (and a large title scale) until the title fits a
    // fixed share of the page, so no layout can overflow at any page size.
    {
      final maxW = width * 0.62;
      double hOf(double fs) => (TextPainter(
            text: TextSpan(text: title, style: _serif(fontSize: fs, fontWeight: FontWeight.w700, height: 1.25)),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxW))
              .height;
      while (titleSize > 9 && hOf(titleSize) > height * 0.26) {
        titleSize *= 0.92;
      }
    }
    final subSize = (12 * scale).clamp(8.0, 16.0);
    final authSize = (11 * scale).clamp(8.0, 14.0);
    final pad = (22 * scale).clamp(8.0, 36.0);

    Widget inner;
    switch (template.layout) {
      case 'medallion':
      case 'literary':
      case 'curve':
      case 'diagonal':
        inner = _StyledCover(
          template: template,
          data: data,
          title: title,
          sub: sub,
          author: author,
          titleSize: titleSize,
          subSize: subSize,
          authSize: authSize,
        );
        break;
      case 'nibrasart':
        final art = artCoverFor(template.id);
        if (art != null) {
          return GestureDetector(
            onTap: onTap,
            child: ArtCoverView(art: art, data: data, width: width, height: height),
          );
        }
        inner = const SizedBox();
        break;
      case 'nibrascode':
        inner = _NibrasCodeCover(
          template: template,
          title: title,
          sub: sub,
          author: author,
          titleSize: titleSize,
          subSize: subSize,
          authSize: authSize,
          scale: scale,
          titleColor: data.titleColor,
        );
        break;
      case 'banner':
        inner = Column(
          children: [
            Container(
              width: double.infinity,
              color: template.accent,
              padding: EdgeInsets.fromLTRB(pad, pad * 1.4, pad, pad * 1.2),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _serif(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
            ),
            if (sub.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10 * scale),
                child: Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: _sans(
                    fontSize: subSize,
                    color: template.fg.withValues(alpha: 0.7),
                  ),
                ),
              ),
            const Spacer(),
            Text(
              author,
              style: _sans(
                fontSize: authSize,
                letterSpacing: 1.2,
                color: template.fg,
              ),
            ),
            if (data.year.isNotEmpty)
              Text(data.year,
                  style: _sans(
                      fontSize: authSize * 0.9, color: template.fg.withValues(alpha: 0.6))),
            SizedBox(height: pad),
          ],
        );
        break;
      case 'minimal':
        inner = Column(
          children: [
            const Spacer(flex: 3),
            Text(
              title,
              textAlign: TextAlign.left,
              style: _serif(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                color: template.fg,
                height: 1.2,
              ),
            ),
            if (sub.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              Text(sub,
                  style: _sans(
                      fontSize: subSize, color: template.fg.withValues(alpha: 0.6))),
            ],
            const Spacer(flex: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(author.toUpperCase(),
                  style: _sans(
                    fontSize: authSize,
                    letterSpacing: 2,
                    color: template.fg,
                  )),
            ),
            SizedBox(height: pad),
          ],
        );
        break;
      case 'ornate':
      case 'navy':
      case 'night':
      case 'emerald':
      case 'crimson':
      case 'royal':
      case 'geometric':
      case 'marble':
      case 'leather':
      case 'nibras':
      case 'ocean':
      case 'botanical':        inner = Container(
          margin: EdgeInsets.all(pad * 0.7),
          decoration: BoxDecoration(
            border: Border.all(color: template.accent, width: 1.2),
          ),
          padding: EdgeInsets.all(pad * 0.7),
          child: Column(
            children: [
              const Spacer(),
              Container(width: 48 * scale, height: 1, color: template.accent),
              SizedBox(height: 14 * scale),
              Text(
                title,
                textAlign: TextAlign.center,
                style: _serif(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: template.fg,
                  height: 1.15,
                ),
              ),
              if (sub.isNotEmpty) ...[
                SizedBox(height: 10 * scale),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: _sans(
                        fontSize: subSize,
                        fontStyle: FontStyle.italic,
                        color: template.fg.withValues(alpha: 0.75))),
              ],
              SizedBox(height: 14 * scale),
              Container(width: 48 * scale, height: 1, color: template.accent),
              const Spacer(),
              Text(author,
                  style: _sans(
                    fontSize: authSize,
                    letterSpacing: 1.4,
                    color: template.accent,
                  )),
              if (data.publisher.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 6 * scale),
                  child: Text(data.publisher,
                      style: _sans(
                          fontSize: authSize * 0.85,
                          color: template.fg.withValues(alpha: 0.55))),
                ),
              SizedBox(height: 8 * scale),
            ],
          ),
        );
        break;
      case 'poetry':
        inner = Column(
          children: [
            SizedBox(height: pad * 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _serif(
                fontSize: titleSize,
                fontStyle: FontStyle.italic,
                color: template.fg,
                height: 1.3,
              ),
            ),
            const Spacer(),
            Text(author,
                style: _sans(
                    fontSize: authSize, color: template.accent)),
            SizedBox(height: pad),
          ],
        );
        break;
      case 'manuscript':
        inner = Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8 * scale),
              color: template.accent,
              child: Text(
                author.toUpperCase(),
                textAlign: TextAlign.center,
                style: _sans(
                  fontSize: authSize,
                  letterSpacing: 2,
                  color: const Color(0xFFF7E7C5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _serif(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: template.fg,
                height: 1.2,
              ),
            ),
            if (sub.isNotEmpty) ...[
              SizedBox(height: 10 * scale),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: _serif(
                    fontSize: subSize,
                    fontStyle: FontStyle.italic,
                    color: template.fg.withValues(alpha: 0.75),
                  )),
            ],
            const Spacer(),
            if (data.year.isNotEmpty)
              Text(data.year,
                  style: _sans(
                      fontSize: authSize, color: template.accent)),
            SizedBox(height: pad * 0.4),
          ],
        );
        break;
      case 'linen':
        inner = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author.toUpperCase(),
                style: _sans(
                  fontSize: authSize,
                  letterSpacing: 2.2,
                  color: template.accent,
                )),
            const Spacer(),
            Text(
              title,
              style: _serif(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: template.fg,
                height: 1.15,
              ),
            ),
            if (sub.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              Text(sub,
                  style: _sans(
                      fontSize: subSize, color: template.fg.withValues(alpha: 0.65))),
            ],
            const Spacer(),
            if (data.year.isNotEmpty)
              Text(data.year,
                  style: _sans(
                      fontSize: authSize, color: template.accent)),
          ],
        );
        break;
      case 'split':
        inner = Row(
          children: [
            Container(
              width: (width * 0.32).clamp(36.0, 90.0),
              color: template.accent,
              padding: EdgeInsets.all(8 * scale),
              child: Column(
                children: [
                  const Spacer(),
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      author.toUpperCase(),
                      style: _sans(
                        fontSize: authSize,
                        letterSpacing: 2,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(pad * 0.6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      title,
                      style: _serif(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: template.fg,
                        height: 1.15,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      SizedBox(height: 8 * scale),
                      Text(sub,
                          style: _sans(
                              fontSize: subSize,
                              color: template.fg.withValues(alpha: 0.65))),
                    ],
                    const Spacer(),
                    if (data.year.isNotEmpty)
                      Text(data.year,
                          style: _sans(
                              fontSize: authSize, color: template.accent)),
                  ],
                ),
              ),
            ),
          ],
        );
        break;
      case 'band':
        inner = Column(
          children: [
            const Spacer(),
            Container(
              width: double.infinity,
              color: template.accent,
              padding: EdgeInsets.symmetric(
                  vertical: 14 * scale, horizontal: 8 * scale),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _serif(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
            ),
            if (sub.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10 * scale),
                child: Text(sub,
                    textAlign: TextAlign.center,
                    style: _sans(
                        fontSize: subSize,
                        color: template.fg.withValues(alpha: 0.75))),
              ),
            const Spacer(),
            Text(author.toUpperCase(),
                style: _sans(
                  fontSize: authSize,
                  letterSpacing: 2,
                  color: template.fg,
                )),
            SizedBox(height: pad * 0.5),
          ],
        );
        break;
      case 'academic':
        inner = Column(
          children: [
            SizedBox(height: pad * 0.4),
            Container(
              width: 36 * scale,
              height: 36 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: template.accent, width: 1.4),
              ),
              child: Icon(Icons.menu_book_rounded,
                  size: 18 * scale, color: template.accent),
            ),
            SizedBox(height: 10 * scale),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _serif(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: template.fg,
                height: 1.15,
              ),
            ),
            SizedBox(height: 8 * scale),
            Container(width: 48 * scale, height: 1, color: template.accent),
            if (sub.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: _sans(
                      fontSize: subSize,
                      fontStyle: FontStyle.italic,
                      color: template.fg.withValues(alpha: 0.75))),
            ],
            const Spacer(),
            Text(author.toUpperCase(),
                style: _sans(
                  fontSize: authSize,
                  letterSpacing: 1.6,
                  color: template.accent,
                )),
            if (data.publisher.isNotEmpty)
              Text(data.publisher,
                  style: _sans(
                      fontSize: authSize * 0.85,
                      color: template.fg.withValues(alpha: 0.55))),
            SizedBox(height: pad * 0.3),
          ],
        );
        break;
      default:
        inner = Column(
          children: [
            const Spacer(flex: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _serif(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: template.fg,
                height: 1.15,
              ),
            ),
            SizedBox(height: 10 * scale),
            Container(width: 40 * scale, height: 1.2, color: template.accent),
            if (sub.isNotEmpty) ...[
              SizedBox(height: 10 * scale),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: _sans(
                      fontSize: subSize,
                      fontStyle: FontStyle.italic,
                      color: template.fg.withValues(alpha: 0.7))),
            ],
            const Spacer(flex: 2),
            Text(author,
                style: _sans(
                  fontSize: authSize,
                  letterSpacing: 1.5,
                  color: template.fg,
                )),
            if (data.publisher.isNotEmpty || data.year.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 6 * scale),
                child: Text(
                  [data.publisher, data.year].where((e) => e.isNotEmpty).join(' · '),
                  style: _sans(
                      fontSize: authSize * 0.9,
                      color: template.fg.withValues(alpha: 0.55)),
                ),
              ),
            SizedBox(height: pad * 0.4),
          ],
        );
    }

    final page = SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    template.bg,
                    Color.lerp(template.bg, template.accent, 0.18) ?? template.bg,
                    template.bg,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
            CustomPaint(
              painter: _CoverOrnamentPainter(
                accent: template.accent,
                layout: template.layout,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad + 6, pad, pad, pad),
              child: inner,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: (width * 0.045).clamp(4.0, 10.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      template.accent.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );

    final framed = Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(3, 6),
          ),
        ],
      ),
      child: page,
    );

    if (onTap == null) return framed;
    return GestureDetector(onTap: onTap, child: framed);
  }
}

class _CoverOrnamentPainter extends CustomPainter {
  final Color accent;
  final String layout;
  _CoverOrnamentPainter({required this.accent, required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final thin = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final fill = Paint()..color = accent.withValues(alpha: 0.08);

    void frame(double m) {
      canvas.drawRect(
        Rect.fromLTWH(m, m, size.width - m * 2, size.height - m * 2),
        gold,
      );
      canvas.drawRect(
        Rect.fromLTWH(m + 4, m + 4, size.width - (m + 4) * 2, size.height - (m + 4) * 2),
        thin,
      );
    }

    void corners() {
      const s = 16.0;
      final p = Paint()
        ..color = accent
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      void corner(double x, double y, double dx, double dy) {
        canvas.drawLine(Offset(x, y), Offset(x + dx * s, y), p);
        canvas.drawLine(Offset(x, y), Offset(x, y + dy * s), p);
      }
      corner(14, 14, 1, 1);
      corner(size.width - 14, 14, -1, 1);
      corner(14, size.height - 14, 1, -1);
      corner(size.width - 14, size.height - 14, -1, -1);
    }

    switch (layout) {
      case 'geometric':
        frame(10);
        final star = Paint()
          ..color = accent.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill;
        for (var y = 28.0; y < size.height - 24; y += 28) {
          for (var x = 22.0; x < size.width - 16; x += 28) {
            canvas.drawCircle(Offset(x, y), 1.6, star);
          }
        }
        break;
      case 'ornate':
      case 'navy':
      case 'night':
      case 'emerald':
      case 'crimson':
      case 'royal':
        frame(11);
        corners();
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.22),
            width: size.width * 0.42,
            height: 10,
          ),
          fill,
        );
        break;
      case 'manuscript':
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 36), Paint()..color = accent.withValues(alpha: 0.15));
        corners();
        break;
      case 'marble':
        final g = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.white.withValues(alpha: 0.25),
              accent.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.05),
            ],
          ).createShader(Offset.zero & size);
        canvas.drawRect(Offset.zero & size, g);
        frame(12);
        break;
      case 'classic':
      case 'linen':
      case 'poetry':
        frame(10);
        corners();
        break;
      case 'ocean':
        frame(10);
        final wave = Paint()
          ..color = accent.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        for (var i = 0; i < 6; i++) {
          final y = size.height * 0.62 + i * 10;
          final path = Path()
            ..moveTo(12, y)
            ..quadraticBezierTo(size.width * 0.25, y - 8, size.width * 0.5, y)
            ..quadraticBezierTo(size.width * 0.75, y + 8, size.width - 12, y);
          canvas.drawPath(path, wave);
        }
        break;
      case 'botanical':
        frame(10);
        final leaf = Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        for (var i = 0; i < 12; i++) {
          final x = 18.0 + (i % 4) * (size.width / 5);
          final y = 22.0 + (i ~/ 4) * (size.height / 5);
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 10, height: 18), leaf);
        }
        break;
      case 'leather':
        frame(12);
        corners();
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.18, size.height * 0.42, size.width * 0.64, 2),
          Paint()..color = accent.withValues(alpha: 0.5),
        );
        break;
      case 'nibras':
        frame(10);
        corners();
        final cx = size.width / 2;
        final cy = size.height * 0.22;
        canvas.drawCircle(Offset(cx, cy), 16, thin);
        canvas.drawCircle(Offset(cx, cy), 8, gold);
        break;
      case 'split':
      case 'band':
      case 'academic':
        corners();
        break;
      default:
        corners();
    }
  }

  @override
  bool shouldRepaint(covariant _CoverOrnamentPainter old) =>
      old.accent != accent || old.layout != layout;
}

Future<CoverData?> showCoverGallery({
  required BuildContext context,
  required PageSize pageSize,
  required bool landscape,
  required CoverData initial,
}) {
  return showDarkSheet<CoverData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF121212),
    builder: (_) => _CoverGalleryBody(
      pageSize: pageSize,
      landscape: landscape,
      initial: initial,
    ),
  );
}

class _CoverGalleryBody extends StatefulWidget {
  final PageSize pageSize;
  final bool landscape;
  final CoverData initial;
  const _CoverGalleryBody({
    required this.pageSize,
    required this.landscape,
    required this.initial,
  });
  @override
  State<_CoverGalleryBody> createState() => _CoverGalleryBodyState();
}

class _CoverGalleryBodyState extends State<_CoverGalleryBody> {
  late PageSize _size;
  late bool _landscape;
  late CoverData _data;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _size = widget.pageSize;
    _landscape = widget.landscape;
    _data = widget.initial;
  }

  double get _pw => _landscape ? _size.heightPx : _size.widthPx;
  double get _ph => _landscape ? _size.widthPx : _size.heightPx;
  double get _aspect => _ph / _pw;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.94;
    final l10n = AppLocalizations.of(context);
    if (_editingId != null) {
      return SizedBox(
        height: h,
        child: _CoverEditor(
          template: coverById(_editingId!),
          data: _data.copyWith(templateId: _editingId!),
          pageSize: _size,
          landscape: _landscape,
          onBack: () => setState(() => _editingId = null),
          onChanged: (d) => setState(() => _data = d),
          onApply: (d) => Navigator.pop(context, d),
        ),
      );
    }
    return SizedBox(
      height: h,
      child: Column(
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
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Text(
                  l10n.t(az: 'Üz səhifə', en: 'Cover page', ru: 'Обложка', ar: 'غلاف'),
                  style: _sans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  _size.label,
                  style: _sans(
                    color: const Color(0xFFC9A84C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final p in PageSize.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _size == p,
                    onSelected: (_) => setState(() => _size = p),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t(
              az: '${coverTemplates.length} nümunə · toxun, sonra yazıları dəyiş',
              en: '${coverTemplates.length} samples · tap, then edit text',
              ru: '${coverTemplates.length} образцов · нажми, затем правь',
              ar: '${coverTemplates.length} نماذج · اضغط ثم عدّل النص',
            ),
            style: _sans(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.62,
              ),
              itemCount: coverTemplates.length,
              itemBuilder: (ctx, i) {
                final t = coverTemplates[i];
                return LayoutBuilder(
                  builder: (ctx, c) {
                    final w = c.maxWidth;
                    final ph = w * _aspect;
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: CoverPagePreview(
                              template: t,
                              data: _data.copyWith(templateId: t.id),
                              width: w,
                              height: ph > c.maxHeight - 22
                                  ? c.maxHeight - 22
                                  : ph,
                              onTap: () => setState(() => _editingId = t.id),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.name,
                          style: _sans(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension on CoverData {
  CoverData copyWith({
    String? templateId,
    String? title,
    String? subtitle,
    String? author,
    String? year,
    String? publisher,
    String? titlePlace,
    int? titleColor,
    double? titleScale,
  }) {
    return CoverData(
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      year: year ?? this.year,
      publisher: publisher ?? this.publisher,
      titleColor: titleColor ?? this.titleColor,
      titleScale: titleScale ?? this.titleScale,
      titlePlace: titlePlace ?? this.titlePlace,
    );
  }
}

class _CoverEditor extends StatefulWidget {
  final CoverTemplate template;
  final CoverData data;
  final PageSize pageSize;
  final bool landscape;
  final VoidCallback onBack;
  final ValueChanged<CoverData> onChanged;
  final ValueChanged<CoverData> onApply;

  const _CoverEditor({
    required this.template,
    required this.data,
    required this.pageSize,
    required this.landscape,
    required this.onBack,
    required this.onChanged,
    required this.onApply,
  });

  @override
  State<_CoverEditor> createState() => _CoverEditorState();
}

class _CoverEditorState extends State<_CoverEditor> {
  late TextEditingController _title;
  late TextEditingController _sub;
  late TextEditingController _author;
  late TextEditingController _year;
  late TextEditingController _pub;

  late int _color;
  late double _scale;
  late String _place;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.data.title);
    _sub = TextEditingController(text: widget.data.subtitle);
    _author = TextEditingController(text: widget.data.author);
    _year = TextEditingController(text: widget.data.year);
    _pub = TextEditingController(text: widget.data.publisher);
    _color = widget.data.titleColor;
    _scale = widget.data.titleScale <= 0 ? 1 : widget.data.titleScale;
    _place = widget.data.titlePlace;
    for (final c in [_title, _sub, _author, _year, _pub]) {
      c.addListener(_emit);
    }
  }

  CoverData _now() => CoverData(
        templateId: widget.template.id,
        title: _title.text,
        subtitle: _sub.text,
        author: _author.text,
        year: _year.text,
        publisher: _pub.text,
        titleColor: _color,
        titleScale: _scale,
        titlePlace: _place,
      );

  void _emit() {
    setState(() {});
    widget.onChanged(_now());
  }

  @override
  void dispose() {
    _title.dispose();
    _sub.dispose();
    _author.dispose();
    _year.dispose();
    _pub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pw = widget.landscape
        ? widget.pageSize.heightPx
        : widget.pageSize.widthPx;
    final ph = widget.landscape
        ? widget.pageSize.widthPx
        : widget.pageSize.heightPx;
    final aspect = ph / pw;
    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  '${widget.template.name} · ${widget.pageSize.label}',
                  style: _sans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => widget.onApply(_now()),
                child: const Text('Tətbiq et'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              LayoutBuilder(
                builder: (ctx, c) {
                  final w = c.maxWidth.clamp(0, 360).toDouble();
                  final h = w * aspect;
                  return Center(
                    child: CoverPagePreview(
                      template: widget.template,
                      data: _now(),
                      width: w,
                      height: h,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Bu ${widget.pageSize.label} səhifənin real nisbətidir. Yazını dəyiş.',
                style: _sans(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _field('Kitabın adı', _title),
              _field('Alt başlıq', _sub),
              _field('Müəllif', _author),
              _field('İl', _year),
              _field('Nəşriyyat', _pub),
              const SizedBox(height: 8),
              Text('Yazının yeri', style: _sans(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in [('top', 'Üst'), ('middle', 'Orta'), ('bottom', 'Alt')])
                    ChoiceChip(
                      label: Text(e.$2),
                      selected: _place == e.$1,
                      onSelected: (_) => setState(() {
                        _place = e.$1;
                        widget.onChanged(_now());
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Ölçü', style: _sans(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in [(0.85, 'Kiçik'), (1.0, 'Orta'), (1.3, 'Böyük'), (1.6, 'Çox böyük')])
                    ChoiceChip(
                      label: Text(e.$2),
                      selected: (_scale - e.$1).abs() < 0.05,
                      onSelected: (_) => setState(() {
                        _scale = e.$1;
                        widget.onChanged(_now());
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Yazı rəngi', style: _sans(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in const [
                    0,
                    0xFFFFFFFF,
                    0xFF1A1A1A,
                    0xFFC9A84C,
                    0xFFF4E7C5,
                    0xFF8C1C13,
                    0xFF16315C,
                    0xFFE25B12,
                    0xFF0E7C66,
                  ])
                    GestureDetector(
                      onTap: () => setState(() {
                        _color = c;
                        widget.onChanged(_now());
                      }),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c == 0 ? widget.template.fg : Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? Colors.white : Colors.white24,
                            width: _color == c ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class _StyledCover extends StatelessWidget {
  final CoverTemplate template;
  final CoverData data;
  final String title;
  final String sub;
  final String author;
  final double titleSize;
  final double subSize;
  final double authSize;

  const _StyledCover({
    required this.template,
    required this.data,
    required this.title,
    required this.sub,
    required this.author,
    required this.titleSize,
    required this.subSize,
    required this.authSize,
  });

  Color get _ink =>
      data.titleColor == 0 ? template.fg : Color(data.titleColor | 0xFF000000);

  @override
  Widget build(BuildContext context) {
    final align = switch (data.titlePlace) {
      'top' => Alignment.topCenter,
      'bottom' => Alignment.bottomCenter,
      _ => Alignment.center,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        _art(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          child: Align(
            alignment: align,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: _serif(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    height: 1.15,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: _sans(fontSize: subSize, color: _ink.withValues(alpha: 0.75)),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  author,
                  textAlign: TextAlign.center,
                  style: _sans(
                    fontSize: authSize,
                    letterSpacing: 1.2,
                    color: _ink.withValues(alpha: 0.9),
                  ),
                ),
                if (data.year.isNotEmpty || data.publisher.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [data.publisher, data.year].where((e) => e.trim().isNotEmpty).join(' · '),
                      textAlign: TextAlign.center,
                      style: _sans(fontSize: authSize * 0.85, color: _ink.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _art() {
    switch (template.layout) {
      case 'medallion':
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: template.bg),
            const Positioned(left: 0, top: 0, bottom: 0, width: 10, child: ColoredBox(color: Color(0x33000000))),
            Align(
              alignment: const Alignment(0, -0.55),
              child: CustomPaint(
                size: const Size(120, 120),
                painter: _RosettePainter(template.accent),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.42),
              child: Container(height: 54, color: template.accent.withValues(alpha: 0.9)),
            ),
          ],
        );
      case 'literary':
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: template.bg),
            const Align(
              alignment: Alignment.topLeft,
              child: CustomPaint(size: Size(140, 90), painter: _OlivePainter()),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: CustomPaint(size: Size(150, 70), painter: _InkPainter()),
              ),
            ),
          ],
        );
      case 'curve':
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFF7F7F7)),
            ClipPath(
              clipper: const _SweepClip(shift: 0.08),
              child: ColoredBox(color: template.bg.computeLuminance() > 0.7 ? const Color(0xFF16315C) : template.bg),
            ),
            ClipPath(
              clipper: const _SweepClip(),
              child: ColoredBox(color: template.accent),
            ),
          ],
        );
      default:
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.white),
            ClipPath(clipper: const _DiagClip(), child: ColoredBox(color: template.bg)),
            Align(
              alignment: Alignment.bottomRight,
              child: FractionallySizedBox(
                widthFactor: 0.55,
                heightFactor: 0.38,
                child: ClipPath(clipper: const _CornerClip(), child: ColoredBox(color: template.accent)),
              ),
            ),
          ],
        );
    }
  }
}

class _RosettePainter extends CustomPainter {
  final Color color;
  const _RosettePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(c, size.width * 0.12, stroke);
    canvas.drawCircle(c, size.width * 0.22, stroke);
    canvas.drawCircle(c, size.width * 0.46, stroke);
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi * 2 / 16;
      final o = Offset(c.dx + math.cos(a) * size.width * 0.33, c.dy + math.sin(a) * size.width * 0.33);
      canvas.drawCircle(o, size.width * 0.07, stroke);
    }
    canvas.drawCircle(c, size.width * 0.05, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RosettePainter oldDelegate) => oldDelegate.color != color;
}

class _OlivePainter extends CustomPainter {
  const _OlivePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF4E6B32)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(8, size.height - 6)
      ..quadraticBezierTo(size.width * 0.4, 10, size.width - 8, 18);
    canvas.drawPath(path, stem);
    final leaf = Paint()..color = const Color(0xFF6B8F3C);
    for (var i = 0; i < 6; i++) {
      final x = 18.0 + i * 16;
      final y = size.height * 0.55 - i * 6;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 14, height: 8), leaf);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InkPainter extends CustomPainter {
  const _InkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final pot = Paint()..color = const Color(0xFF7A4E2D);
    canvas.drawOval(Rect.fromLTWH(8, size.height * 0.35, 46, 28), pot);
    canvas.drawRect(Rect.fromLTWH(18, size.height * 0.22, 26, 16), pot);
    final pen = Paint()
      ..color = const Color(0xFF3A2414)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(52, size.height * 0.7), Offset(size.width - 8, size.height * 0.25), pen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SweepClip extends CustomClipper<Path> {
  final double shift;
  const _SweepClip({this.shift = 0});
  @override
  Path getClip(Size size) {
    final y = size.height * (0.48 + shift);
    return Path()
      ..moveTo(0, y)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.18, size.width * 0.62, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.95, size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _SweepClip oldDelegate) => oldDelegate.shift != shift;
}

class _DiagClip extends CustomClipper<Path> {
  const _DiagClip();
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.46)
      ..lineTo(0, size.height * 0.72)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CornerClip extends CustomClipper<Path> {
  const _CornerClip();
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height * 0.35)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}


/// Nibras Code family: thin gold frame, round emblem, brand on top,
/// NibrasCode.com at the bottom. Only the colour changes between variants.
class _NibrasCodeCover extends StatelessWidget {
  final CoverTemplate template;
  final String title;
  final String sub;
  final String author;
  final double titleSize;
  final double subSize;
  final double authSize;
  final double scale;
  final int titleColor;

  const _NibrasCodeCover({
    required this.template,
    required this.title,
    required this.sub,
    required this.author,
    required this.titleSize,
    required this.subSize,
    required this.authSize,
    required this.scale,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final a = template.accent;
    final ink = titleColor == 0 ? template.fg : Color(titleColor | 0xFF000000);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: a.withValues(alpha: 0.6), width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 12 * scale),
      child: Column(
        children: [
          Text(
            'NIBRAS CODE',
            maxLines: 1,
            style: _sans(
              fontSize: (9 * scale).clamp(6.0, 12.0),
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: a,
            ),
          ),
          SizedBox(height: 14 * scale),
          Container(
            width: 46 * scale,
            height: 46 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: a.withValues(alpha: 0.8), width: 1),
            ),
            child: Icon(Icons.auto_stories_outlined, color: a, size: 26 * scale),
          ),
          const Spacer(),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: _serif(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: ink,
              height: 1.25,
            ),
          ),
          if (sub.isNotEmpty) ...[
            SizedBox(height: 8 * scale),
            Text(
              sub,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _serif(
                fontSize: subSize,
                fontStyle: FontStyle.italic,
                color: template.fg.withValues(alpha: 0.8),
              ),
            ),
          ],
          SizedBox(height: 12 * scale),
          Container(width: 60 * scale, height: 1, color: a.withValues(alpha: 0.5)),
          SizedBox(height: 10 * scale),
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _sans(
              fontSize: authSize,
              letterSpacing: 1.2,
              color: template.fg.withValues(alpha: 0.85),
            ),
          ),
          const Spacer(),
          Text(
            'NibrasCode.com',
            maxLines: 1,
            style: _sans(
              fontSize: (8.5 * scale).clamp(6.0, 11.0),
              letterSpacing: 0.8,
              color: a.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Artwork cover: full-bleed cover-fit artwork plus the Nibras overlay, placed
/// by [ArtCoverGeometry] (shared with the PDF exporter).
class ArtCoverView extends StatelessWidget {
  final ArtCover art;
  final CoverData data;
  final double width;
  final double height;
  const ArtCoverView({super.key, required this.art, required this.data, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final g = ArtCoverGeometry.of(art.style, width, height,
        titleScale: data.titleScale <= 0 ? 1 : data.titleScale, title: data.title.trim(), subtitle: data.subtitle.trim());
    final title = data.title.trim().isEmpty ? CoverData.brandTitle : data.title.trim();
    final author = data.author.trim();
    final sub = data.subtitle.trim();
    final ink = data.titleColor == 0 ? art.ink : Color(data.titleColor | 0xFF000000);
    final a = art.accent;
    Widget at(ArtBox b, Widget child) => Positioned(left: b.x, top: b.y, width: b.w, height: b.h, child: child);
    Widget line(ArtBox b, String s, TextStyle st) => at(
        b,
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(s, maxLines: 1, softWrap: false, style: st),
          ),
        ));
    const serif = 'LibreBaskerville';
    const sans = 'DMSans';
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(children: [
          Positioned.fill(
            child: ColoredBox(
              color: art.bg,
              child: Image.asset(art.asset, fit: BoxFit.cover, alignment: Alignment.center,
                  filterQuality: FilterQuality.medium, errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ),
          if (art.plaque) ...[
            for (final b in [g.pill(g.brand, 11 * 1.3, g.brandSize), g.pill(g.url, 14, g.urlSize)])
              at(
                  b,
                  DecoratedBox(
                      decoration: BoxDecoration(
                          color: art.bg.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(b.h / 2),
                          border: Border.all(color: a.withValues(alpha: 0.7), width: g.brandSize * 0.06)))),
            at(
                g.plaqueBox,
                DecoratedBox(
                    decoration: BoxDecoration(
                        color: art.bg.withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(g.plaqueBox.w * 0.03),
                        border: Border.all(color: a.withValues(alpha: 0.85), width: g.brandSize * 0.08)))),
          ],
          line(g.brand, 'NIBRAS CODE',
              TextStyle(fontFamily: sans, fontSize: g.brandSize, fontWeight: FontWeight.w700, letterSpacing: g.brandSize * 0.3, color: a)),
          at(
            g.emblem,
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: art.bg.withValues(alpha: 0.55),
                border: Border.all(color: a, width: g.emblem.w * 0.025),
              ),
              child: Text('NC',
                  style: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700, fontSize: g.emblem.w * 0.3, letterSpacing: g.emblem.w * 0.02, color: a, height: 1.0)),
            ),
          ),
          at(
            g.title,
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: g.title.w,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700, fontSize: g.titleSize, height: 1.25, color: ink)),
                    if (sub.isNotEmpty) ...[
                      SizedBox(height: g.titleSize * 0.4),
                      Text(sub,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: g.titleSize * 0.45, height: 1.3, color: ink.withValues(alpha: 0.85))),
                    ],
                    SizedBox(height: g.titleSize * 0.5),
                    Container(width: g.ruleW, height: g.titleSize * 0.03 + 0.4, color: a),
                  ]),
                ),
              ),
            ),
          ),
          if (author.isNotEmpty)
            line(g.author, author, TextStyle(fontFamily: sans, fontSize: g.authorSize, letterSpacing: g.authorSize * 0.08, color: ink)),
          line(g.url, 'NibrasCode.com', TextStyle(fontFamily: sans, fontSize: g.urlSize, letterSpacing: g.urlSize * 0.06, color: a)),
        ]),
      ),
    );
  }
}
