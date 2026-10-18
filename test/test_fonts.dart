import 'package:flutter/services.dart';

Future<void> loadAppFonts() async {
  for (final fam in {
    'LibreBaskerville': ['LibreBaskerville-Regular', 'LibreBaskerville-Bold', 'LibreBaskerville-Italic', 'LibreBaskerville-BoldItalic'],
    'Lora': ['Lora-Regular', 'Lora-Bold', 'Lora-Italic', 'Lora-BoldItalic'],
    'NotoNaskhArabic': ['NotoNaskhArabic-Regular', 'NotoNaskhArabic-Bold'],
    'DMSans': ['DMSans-Regular', 'DMSans-Bold', 'DMSans-Italic', 'DMSans-BoldItalic'],
  }.entries) {
    final l = FontLoader(fam.key);
    for (final f in fam.value) {
      l.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await l.load();
  }
}
