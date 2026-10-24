import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

/// A premium, code-drawn artwork cover (leather / linen / suede / silk with
/// gilded or blind-embossed Islamic geometry). The artwork carries no text;
/// the brand, emblem, title, author and URL are drawn on top by the app and by
/// the PDF exporter from the same [ArtCoverGeometry].
class ArtCover {
  final String id;
  final String name;
  final String style; // border, shamsa, corners, field, headfoot, plaque
  final bool light;
  final Color bg;
  final Color ink;
  final Color accent;
  final String? _category;
  const ArtCover(this.id, this.name, this.style, this.light, this.bg, this.ink, this.accent, {String? category})
      : _category = category;

  /// Browsing category (see [coverCategories]).
  String get category {
    if (_category != null) return _category;
    if (id.startsWith('nibras_ai')) return 'islamic';
    if (id.contains('leather') || id.contains('suede')) return 'leather';
    return 'linen';
  }

  String get asset => 'assets/covers/$id.webp';
  String get templateId => 'art_$id';

  /// AI-generated artwork whose ornament may run under the text: the overlay
  /// sits on translucent panels so the title stays readable.
  bool get plaque => style == 'plaque';
}

/// Rectangle in page units.
class ArtBox {
  final double x, y, w, h;
  const ArtBox(this.x, this.y, this.w, this.h);
  double get cx => x + w / 2;
  double get cy => y + h / 2;
  double get right => x + w;
  double get bottom => y + h;
  @override
  String toString() => 'ArtBox($x,$y,$w,$h)';
}

/// Where every overlay element goes on a page of any size/aspect. The artwork
/// (2:3) is cover-fitted (centred crop, never stretched); anchor fractions are
/// defined on the artwork and mapped through the same crop, then clamped into
/// the page's safe margin so nothing can overflow on A3/A4/A5/Letter/landscape.
class ArtCoverGeometry {
  static const double artAspect = 2 / 3; // width / height
  final double pageW, pageH;
  final double scale; // artwork px (1200-wide space) -> page units
  final double offX, offY;
  final ArtBox brand, emblem, title, author, url;
  final double brandSize, authorSize, urlSize, titleSize, ruleW;

  ArtCoverGeometry._(this.pageW, this.pageH, this.scale, this.offX, this.offY, this.brand, this.emblem,
      this.title, this.author, this.url, this.brandSize, this.authorSize, this.urlSize, this.titleSize, this.ruleW);

  // brandY, emblemY, emblemD(×W), titleX0, titleY0, titleX1, titleY1, authorY, urlY
  static const _anchors = <String, List<double>>{
    'border': [0.165, 0.245, 0.085, 0.22, 0.36, 0.78, 0.65, 0.705, 0.825],
    'shamsa': [0.07, 0.27, 0.10, 0.14, 0.45, 0.86, 0.75, 0.80, 0.925],
    'corners': [0.07, 0.175, 0.085, 0.16, 0.33, 0.84, 0.65, 0.71, 0.93],
    'field': [0.085, 0.19, 0.085, 0.15, 0.34, 0.85, 0.65, 0.71, 0.915],
    'headfoot': [0.262, 0.33, 0.07, 0.13, 0.395, 0.87, 0.655, 0.70, 0.745],
    'plaque': [0.075, 0.205, 0.085, 0.19, 0.335, 0.81, 0.635, 0.705, 0.925],
  };

  factory ArtCoverGeometry.of(String style, double w, double h,
      {double titleScale = 1, String title = '', String subtitle = ''}) {
    final a = _anchors[style] ?? _anchors['border']!;
    // Artwork displayed size under cover-fit.
    final artW = (w / h > artAspect) ? w : h * artAspect;
    final artH = artW / artAspect;
    final ox = (w - artW) / 2, oy = (h - artH) / 2;
    final safeX = w * 0.06, safeY = h * 0.04;
    double px(double f) => (ox + f * artW).clamp(safeX, w - safeX);
    double py(double f) => (oy + f * artH).clamp(safeY, h - safeY);
    // Text unit: visible artwork width, but never more than the page allows.
    final u = w < h * artAspect ? w : h * artAspect;
    final bs = u * 0.030, as = u * 0.038, us = u * 0.027;
    final tx0 = px(a[3]), ty0 = py(a[4]), tx1 = px(a[5]), ty1 = py(a[6]);
    final tw = tx1 - tx0, th = ty1 - ty0;
    ArtBox line(double fy, double size) {
      final x0 = tx0, x1 = tx1;
      final yy = py(fy) - size * 0.75;
      return ArtBox(x0, yy.clamp(safeY, h - safeY - size * 1.5), x1 - x0, size * 1.5);
    }
    final ed = (a[2] * artW).clamp(0.0, (w - 2 * safeX) * 0.4);
    final ecy = py(a[1]).clamp(safeY + ed / 2, h - safeY - ed / 2);
    // Pick the title size from the text itself (same estimate on screen and in
    // PDF), so long titles wrap into fewer, smaller lines instead of being
    // squeezed; FittedBox remains only as a final guard.
    var ts = tw * 0.12 * titleScale.clamp(0.7, 1.8);
    double est(String t, double fs, double lh) {
      if (t.isEmpty) return 0;
      var lines = 0;
      for (final para in t.split('\n')) {
        var cur = 0.0;
        var n = 1;
        for (final word in para.split(' ')) {
          final ww = word.length * fs * 0.56;
          final add = cur == 0 ? ww : cur + fs * 0.28 + ww;
          if (add > tw * 0.96 && cur > 0) {
            n++;
            cur = ww;
          } else {
            cur = add;
          }
          if (ww > tw * 0.96) return double.infinity;
        }
        lines += n;
      }
      return lines * fs * lh;
    }
    double total(double fs) =>
        est(title.isEmpty ? 'Nibras Code' : title, fs, 1.3) +
        (subtitle.isEmpty ? 0 : fs * 0.4 + est(subtitle, fs * 0.45, 1.35)) +
        fs * 0.55;
    while (ts > 4 && total(ts) > th * 0.92) {
      ts *= 0.94;
    }
    return ArtCoverGeometry._(
      w, h, artW / 1200, ox, oy,
      line(a[0], bs),
      ArtBox(w / 2 - ed / 2, ecy - ed / 2, ed, ed),
      ArtBox(tx0, ty0, tw, th),
      line(a[7], as),
      line(a[8], us),
      bs, as, us,
      ts,
      u * 0.12,
    );
  }

  ArtBox get page => ArtBox(0, 0, pageW, pageH);

  /// Readability panel behind title + author ('plaque' style). Stays inside
  /// the page's safe area.
  ArtBox get plaqueBox {
    final pad = title.w * 0.07;
    final x0 = (title.x - pad).clamp(pageW * 0.04, pageW);
    final x1 = (title.right + pad).clamp(0.0, pageW * 0.96);
    final y0 = (title.y - pad).clamp(pageH * 0.03, pageH);
    final y1 = (author.bottom + pad * 0.6).clamp(0.0, url.y - pad * 0.3);
    return ArtBox(x0, y0, x1 - x0, y1 - y0);
  }

  /// Small pill behind a single overlay line (brand / URL).
  ArtBox pill(ArtBox line, double chars, double size) {
    final w = (chars * size * 0.72 + size * 2.4).clamp(0.0, line.w);
    final h = size * 2.0;
    return ArtBox(line.cx - w / 2, line.cy - h / 2, w, h);
  }
  List<ArtBox> get boxes => [brand, emblem, title, author, url];
}

const artCovers = <ArtCover>[
  ArtCover('emerald_leather_star', 'Nibras zümrüd dəri · ulduz haşiyə', 'border', false, Color(0xFF1F4A3A), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('navy_leather_shamsa', 'Nibras lacivərd dəri · şəmsə', 'shamsa', false, Color(0xFF16264A), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('burgundy_leather_corners', 'Nibras bordo dəri · künc', 'corners', false, Color(0xFF5A1A22), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('onyx_leather_hex', 'Nibras oniks dəri · ulduz haşiyə', 'border', false, Color(0xFF17171A), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('ivory_linen_corners', 'Nibras fil dişi kətan · künc', 'corners', true, Color(0xFFEBE2CD), Color(0xFF1A120A), Color(0xFF7A4E22)),
  ArtCover('sand_linen_star_emboss', 'Nibras qum kətan · kabartma', 'field', true, Color(0xFFD9C7A3), Color(0xFF1A120A), Color(0xFF6E552A)),
  ArtCover('teal_suede_shamsa', 'Nibras firuzə zamşa · şəmsə', 'shamsa', false, Color(0xFF164A4F), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('plum_leather_hex_emboss', 'Nibras gavalı dəri · kabartma', 'field', false, Color(0xFF3D1F3F), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('pearl_silk_corners', 'Nibras mirvari ipək · künc', 'corners', true, Color(0xFFECE4D4), Color(0xFF1A120A), Color(0xFF8A631C)),
  ArtCover('forest_leather_headfoot', 'Nibras meşə dəri · zolaq', 'headfoot', false, Color(0xFF1C3324), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('noir_suede_headfoot', 'Nibras gecə zamşa · zolaq', 'headfoot', false, Color(0xFF141416), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('cocoa_leather_star_emboss', 'Nibras kakao dəri · kabartma', 'field', false, Color(0xFF4A2E1C), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('midnight_suede_hex', 'Nibras gecəyarısı zamşa · ulduz haşiyə', 'border', false, Color(0xFF0F1A33), Color(0xFFF3E6C4), Color(0xFFD5DAE0)),
  ArtCover('terracotta_linen_star', 'Nibras terrakota kətan · ulduz haşiyə', 'border', false, Color(0xFF9A4B34), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('olive_leather_shamsa', 'Nibras zeytun dəri · şəmsə', 'shamsa', false, Color(0xFF3A4220), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('charcoal_linen_star', 'Nibras kömür kətan · ulduz haşiyə', 'border', false, Color(0xFF2B2D31), Color(0xFFF3E6C4), Color(0xFFEABEA6)),
  ArtCover('cream_leather_hex_emboss', 'Nibras krem dəri · kabartma', 'field', true, Color(0xFFD8CBB0), Color(0xFF1A120A), Color(0xFF6E552A)),
  ArtCover('sapphire_leather_corners', 'Nibras safir dəri · künc', 'corners', false, Color(0xFF123A6B), Color(0xFFF3E6C4), Color(0xFFD5DAE0)),
  ArtCover('rose_silk_star', 'Nibras qızılgül ipək · ulduz haşiyə', 'border', true, Color(0xFFE7D3CC), Color(0xFF1A120A), Color(0xFF8A4E3C)),
  ArtCover('wine_suede_hex', 'Nibras şərab zamşa · ulduz haşiyə', 'border', false, Color(0xFF4A1520), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('slate_silk_shamsa', 'Nibras şist ipək · şəmsə', 'shamsa', false, Color(0xFF3A4049), Color(0xFFF3E6C4), Color(0xFFD5DAE0)),
  ArtCover('saffron_linen_star_emboss', 'Nibras zəfəran kətan · kabartma', 'field', true, Color(0xFFD6A650), Color(0xFF1A120A), Color(0xFF6E552A)),
  ArtCover('ink_leather_headfoot', 'Nibras mürəkkəb dəri · zolaq', 'headfoot', false, Color(0xFF101826), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('jade_silk_hex', 'Nibras yəşm ipək · ulduz haşiyə', 'border', false, Color(0xFF2F5D50), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('copper_leather_shamsa', 'Nibras mis dəri · şəmsə', 'shamsa', false, Color(0xFF5B3020), Color(0xFFF3E6C4), Color(0xFF7A4E22)),
  ArtCover('ivory_linen_shamsa', 'Nibras fil dişi kətan · şəmsə', 'shamsa', true, Color(0xFFEFE9DD), Color(0xFF1A120A), Color(0xFF8A631C)),
  ArtCover('indigo_linen_hex_emboss', 'Nibras indiqo kətan · kabartma', 'field', false, Color(0xFF23305A), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('black_silk_star', 'Nibras qara ipək · ulduz haşiyə', 'border', false, Color(0xFF121214), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('maroon_silk_corners', 'Nibras tünd qırmızı ipək · künc', 'corners', false, Color(0xFF3F1418), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('moss_linen_headfoot', 'Nibras mamır kətan · zolaq', 'headfoot', false, Color(0xFF4C5A36), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('royal_suede_shamsa', 'Nibras şahanə zamşa · şəmsə', 'shamsa', false, Color(0xFF2A1D5C), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('ash_linen_star_emboss', 'Nibras kül kətan · kabartma', 'field', true, Color(0xFFCFCBC4), Color(0xFF1A120A), Color(0xFF6E552A)),
  ArtCover('tobacco_leather_hex', 'Nibras tütün dəri · ulduz haşiyə', 'border', false, Color(0xFF3B2618), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('aqua_linen_corners', 'Nibras dəniz kətan · künc', 'corners', false, Color(0xFF2F6B6B), Color(0xFFF3E6C4), Color(0xFFD5DAE0)),
  ArtCover('garnet_leather_headfoot', 'Nibras nar dəri · zolaq', 'headfoot', false, Color(0xFF4C0F1A), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('obsidian_silk_shamsa', 'Nibras obsidian ipək · şəmsə', 'shamsa', false, Color(0xFF0E0F12), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('desert_suede_star_emboss', 'Nibras səhra zamşa · kabartma', 'field', true, Color(0xFFC9A77A), Color(0xFF1A120A), Color(0xFF6E552A)),
  ArtCover('petrol_leather_star', 'Nibras neft dəri · ulduz haşiyə', 'border', false, Color(0xFF123B40), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('ivory_silk_hex', 'Nibras fil dişi ipək · ulduz haşiyə', 'border', true, Color(0xFFF1ECE2), Color(0xFF1A120A), Color(0xFF8A631C)),
  ArtCover('aubergine_linen_shamsa', 'Nibras badımcan kətan · şəmsə', 'shamsa', false, Color(0xFF3A1F36), Color(0xFFF3E6C4), Color(0xFFEABEA6)),
  ArtCover('steel_suede_corners', 'Nibras polad zamşa · künc', 'corners', false, Color(0xFF2C3540), Color(0xFFF3E6C4), Color(0xFFD5DAE0)),
  ArtCover('honey_leather_headfoot', 'Nibras bal dəri · zolaq', 'headfoot', false, Color(0xFF7A5222), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('noir_linen_hex', 'Nibras gecə kətan · ulduz haşiyə', 'border', false, Color(0xFF1A1A1D), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('emerald_silk_corners', 'Nibras zümrüd ipək · künc', 'corners', false, Color(0xFF1D4537), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('navy_linen_star_emboss', 'Nibras lacivərd kətan · kabartma', 'field', false, Color(0xFF1D2B4D), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('nibras_ai_01', 'Nibras premium naxış №1', 'plaque', false, Color(0xFF331E20), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('nibras_ai_02', 'Nibras premium naxış №2', 'plaque', false, Color(0xFF2B2822), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('nibras_ai_03', 'Nibras premium naxış №3', 'plaque', false, Color(0xFF29341D), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('nibras_ai_04', 'Nibras premium naxış №4', 'plaque', false, Color(0xFF232E2D), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  ArtCover('bordeaux_suede_star', 'Nibras bordo zamşa · ulduz haşiyə', 'border', false, Color(0xFF4B1424), Color(0xFFF3E6C4), Color(0xFFE2BF63)),
  // Library covers: Nibras cover-gen + covers made by Maher (700px WebP).
  ArtCover('lib_leather_01', 'Nibras dəri №1', 'plaque', false, Color(0xFF1C211A), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_islamic_01', 'Nibras naxış №1', 'plaque', false, Color(0xFF615B5F), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_02', 'Nibras naxış №2', 'plaque', false, Color(0xFF170C04), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_03', 'Nibras naxış №3', 'plaque', false, Color(0xFF3D1C13), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_04', 'Nibras naxış №4', 'plaque', false, Color(0xFF28354B), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_leather_02', 'Nibras dəri №2', 'plaque', false, Color(0xFF3D2D1F), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_islamic_05', 'Nibras naxış №5', 'plaque', false, Color(0xFF362923), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_06', 'Nibras naxış №6', 'plaque', false, Color(0xFF264E32), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_leather_03', 'Nibras dəri №3', 'plaque', false, Color(0xFF3A3129), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_islamic_07', 'Nibras naxış №7', 'plaque', false, Color(0xFF2D3C27), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_08', 'Nibras naxış №8', 'plaque', false, Color(0xFF383532), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_09', 'Nibras naxış №9', 'plaque', false, Color(0xFF1B1711), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_leather_04', 'Nibras dəri №4', 'plaque', false, Color(0xFF4B130B), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_islamic_10', 'Nibras naxış №10', 'plaque', false, Color(0xFF473A2B), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_11', 'Nibras naxış №11', 'plaque', false, Color(0xFF5A4029), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_12', 'Nibras naxış №12', 'plaque', false, Color(0xFF4C301A), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_13', 'Nibras naxış №13', 'plaque', false, Color(0xFF2D311A), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_14', 'Nibras naxış №14', 'plaque', false, Color(0xFF271919), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_leather_05', 'Nibras dəri №5', 'plaque', false, Color(0xFF4D2210), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_islamic_15', 'Nibras naxış №15', 'plaque', false, Color(0xFF47403B), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_16', 'Nibras naxış №16', 'plaque', false, Color(0xFF262728), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_17', 'Nibras naxış №17', 'plaque', false, Color(0xFF5A4A38), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_18', 'Nibras naxış №18', 'plaque', false, Color(0xFF27271E), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_19', 'Nibras naxış №19', 'plaque', false, Color(0xFF201C17), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_leather_06', 'Nibras dəri №6', 'plaque', false, Color(0xFF3D2009), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_islamic_20', 'Nibras naxış №20', 'plaque', false, Color(0xFF21260F), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_21', 'Nibras naxış №21', 'plaque', false, Color(0xFF2A1818), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_22', 'Nibras naxış №22', 'plaque', false, Color(0xFF211F1D), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_leather_07', 'Nibras dəri №7', 'plaque', false, Color(0xFF2E0F04), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_islamic_23', 'Nibras naxış №23', 'plaque', false, Color(0xFF242830), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_24', 'Nibras naxış №24', 'plaque', false, Color(0xFF143522), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_25', 'Nibras naxış №25', 'plaque', false, Color(0xFF492720), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_night_01', 'Nibras gecə №1', 'plaque', false, Color(0xFF151513), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'night'),
  ArtCover('lib_leather_08', 'Nibras dəri №8', 'plaque', false, Color(0xFF501E17), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_islamic_26', 'Nibras naxış №26', 'plaque', false, Color(0xFF272916), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_leather_09', 'Nibras dəri №9', 'plaque', false, Color(0xFF4B0E06), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_leather_10', 'Nibras dəri №10', 'field', false, Color(0xFF05112A), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_marble_01', 'Nibras mərmər №1', 'field', false, Color(0xFF0C0C0C), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'marble'),
  ArtCover('lib_nature_01', 'Nibras təbiət №1', 'field', false, Color(0xFF09281E), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'nature'),
  ArtCover('lib_linen_01', 'Nibras kətan-ipək №1', 'field', true, Color(0xFFE0D7C8), Color(0xFF1A120A), Color(0xFF7A4E22), category: 'linen'),
  ArtCover('lib_leather_11', 'Nibras dəri №11', 'field', false, Color(0xFF042C33), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_leather_12', 'Nibras dəri №12', 'field', false, Color(0xFF371708), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_marble_02', 'Nibras mərmər №2', 'field', true, Color(0xFFE3E1DD), Color(0xFF1A120A), Color(0xFF7A4E22), category: 'marble'),
  ArtCover('lib_night_02', 'Nibras gecə №2', 'field', false, Color(0xFF100515), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'night'),
  ArtCover('lib_leather_13', 'Nibras dəri №13', 'field', false, Color(0xFF3C0405), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'leather'),
  ArtCover('lib_night_03', 'Nibras gecə №3', 'field', false, Color(0xFF1D1E21), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'night'),
  ArtCover('lib_linen_02', 'Nibras kətan-ipək №2', 'field', true, Color(0xFFB2A28D), Color(0xFF1A120A), Color(0xFF7A4E22), category: 'linen'),
  ArtCover('lib_islamic_27', 'Nibras naxış №27', 'field', false, Color(0xFF0A1E3C), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_islamic_28', 'Nibras naxış №28', 'field', false, Color(0xFF000604), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'islamic'),
  ArtCover('lib_linen_03', 'Nibras kətan-ipək №3', 'field', true, Color(0xFFDDD6CD), Color(0xFF1A120A), Color(0xFF7A4E22), category: 'linen'),
  ArtCover('lib_night_04', 'Nibras gecə №4', 'plaque', false, Color(0xFF212C46), Color(0xFFF3E6C4), Color(0xFFE2BF63), category: 'night'),
  ArtCover('lib_nature_02', 'Nibras təbiət №2', 'plaque', true, Color(0xFFD0A67B), Color(0xFF1A120A), Color(0xFF7A4E22), category: 'nature'),
  ArtCover('lib_nature_03', 'Nibras təbiət №3', 'plaque', true, Color(0xFFB69659), Color(0xFF1A120A), Color(0xFF7A4E22), category: 'nature'),
  ArtCover('lib_nature_04', 'Nibras təbiət №4', 'plaque', true, Color(0xFF9A9992), Color(0xFF1A120A), Color(0xFF7A4E22), category: 'nature'),
];

/// Cover browsing category with labels and search tags in every app language
/// (az, en, ru, ar).
class CoverCategory {
  final String id;
  final List<String> label; // az, en, ru, ar
  final String tags;
  const CoverCategory(this.id, this.label, this.tags);
  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return '${label.join(' ')} $tags'.toLowerCase().contains(s);
  }
}

const coverCategories = <CoverCategory>[
  CoverCategory('leather', ['Dəri', 'Leather', 'Кожа', 'جلد'],
      'dəri zamşa klassik leather suede classic кожа замша классика جلد شمواه كلاسيكي'),
  CoverCategory('islamic', ['İslami naxış', 'Islamic pattern', 'Исламский узор', 'زخرفة إسلامية'],
      'islami naxış ornament şəmsə həndəsi arabesk islamic pattern geometric arabesque исламский узор орнамент арабеска إسلامي زخرفة هندسي أرابيسك نقش'),
  CoverCategory('linen', ['Kətan və ipək', 'Linen & silk', 'Лён и шёлк', 'كتان وحرير'],
      'kətan ipək parça linen silk fabric cloth лён шёлк ткань كتان حرير قماش'),
  CoverCategory('marble', ['Mərmər', 'Marble', 'Мрамор', 'رخام'], 'mərmər daş marble stone мрамор камень رخام حجر'),
  CoverCategory('night', ['Gecə və ulduz', 'Night & stars', 'Ночь и звёзды', 'ليل ونجوم'],
      'gecə ulduz qaranlıq night star dark ночь звезда тёмный ليل نجوم نجمة داكن'),
  CoverCategory('nature', ['Təbiət', 'Nature', 'Природа', 'طبيعة'],
      'təbiət mənzərə dəniz meşə dağ nature landscape sea forest mountain природа пейзаж море лес горы طبيعة منظر بحر غابة جبل'),
];

/// Search tags for the code-drawn ('basic') covers.
const basicCoverTags = 'sadə simple простой بسيط';

CoverCategory? coverCategoryById(String id) {
  for (final c in coverCategories) {
    if (c.id == id) return c;
  }
  return null;
}

ArtCover? artCoverFor(String templateId) {
  if (!templateId.startsWith('art_')) return null;
  final id = templateId.substring(4);
  for (final c in artCovers) {
    if (c.id == id) return c;
  }
  return null;
}

/// JPEG bytes of artworks for the (synchronous) PDF cover builder. PDF embeds
/// JPEG natively, so this keeps exported files small.
class ArtCoverCache {
  static final Map<String, Uint8List> jpeg = {};

  static Future<void> warm(Iterable<String> templateIds) async {
    for (final t in templateIds) {
      final c = artCoverFor(t);
      if (c == null || jpeg.containsKey(c.id)) continue;
      try {
        final data = await rootBundle.load(c.asset);
        final dec = img.decodeWebP(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        if (dec != null) jpeg[c.id] = Uint8List.fromList(img.encodeJpg(dec, quality: 88));
      } catch (_) {}
    }
  }

  /// Template ids of art covers referenced by `[COVER ...]` markup in [text].
  static List<String> idsIn(String text) =>
      RegExp(r'art_[a-z0-9_]+').allMatches(text).map((m) => m.group(0)!).toSet().toList();
}
