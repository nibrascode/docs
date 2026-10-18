import 'package:flutter/foundation.dart';
import '../core/page_size.dart';
import 'mobile_export_service.dart';

class PdfService {
  static Future<void> generateAndDownload({
    required String title,
    required String content,
    required PageSize pageSize,
    required String textAlign,
    required bool isBold,
    required bool isItalic,
    required bool isUnderline,
    bool showPageNumbers = true,
    String pageNumberPos = 'bottom-center',
    String headerText = '',
    String footerText = '',
    String author = '',
    String subtitle = '',
    bool firstLineIndent = false,
    bool chapterNewPage = false,
    double marginMm = 20,
    bool landscape = false,
    int pageNumberStartPage = 1,
    int pageNumberStartAt = 1,
    double fontSize = 16,
    double lineHeight = 1.7,
    int pageBgColor = 0xFFFFFFFF,
    String fontFamily = 'Georgia',
    bool pageFrame = false,
    String pageNumberStyle = 'plain',
    bool bookHeader = false,
  }) async {
    if (kIsWeb) return;
    await MobileExportService.exportPdf(
      title: title,
      content: content,
      pageSize: pageSize,
      showPageNumbers: showPageNumbers,
      pageNumberPos: pageNumberPos,
      headerText: headerText,
      footerText: footerText,
      author: author,
      subtitle: subtitle,
      firstLineIndent: firstLineIndent,
      chapterNewPage: chapterNewPage,
      marginMm: marginMm,
      landscape: landscape,
      pageNumberStartPage: pageNumberStartPage,
      pageNumberStartAt: pageNumberStartAt,
      fontSize: fontSize,
      lineHeight: lineHeight,
      pageBgColor: pageBgColor,
      fontFamily: fontFamily,
      pageFrame: pageFrame,
      pageNumberStyle: pageNumberStyle,
      bookHeader: bookHeader,
    );
  }
}
