import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';

class ImageInsertResult {
  final String path;
  final double widthFactor; // 0.25 - 1.0
  final String caption;
  final String align; // left | center | right
  ImageInsertResult(
    this.path,
    this.widthFactor, {
    this.caption = '',
    this.align = 'center',
  });
}

class ImageInsertDialog extends StatefulWidget {
  final String path;
  final double initialWidth;
  final String initialCaption;
  final String initialAlign;
  final bool editing;

  const ImageInsertDialog({
    super.key,
    required this.path,
    this.initialWidth = 0.85,
    this.initialCaption = '',
    this.initialAlign = 'center',
    this.editing = false,
  });

  static Future<ImageInsertResult?> show(
    BuildContext context,
    String path, {
    double width = 0.85,
    String caption = '',
    String align = 'center',
    bool editing = false,
  }) {
    return showModalBottomSheet<ImageInsertResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImageInsertDialog(
        path: path,
        initialWidth: width,
        initialCaption: caption,
        initialAlign: align,
        editing: editing,
      ),
    );
  }

  @override
  State<ImageInsertDialog> createState() => _ImageInsertDialogState();
}

class _ImageInsertDialogState extends State<ImageInsertDialog> {
  late double _width;
  late String _align;
  late TextEditingController _caption;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth.clamp(0.25, 1.0);
    _align = widget.initialAlign;
    _caption = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final file = File(widget.path);
    final screenW = MediaQuery.of(context).size.width;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.editing
                      ? l10n.t(az: 'Şəkli düzəlt', en: 'Edit image', ru: 'Изменить изображение', ar: 'تعديل الصورة')
                      : l10n.t(az: 'Şəkil əlavə et', en: 'Insert image', ru: 'Вставить изображение', ar: 'إضافة صورة'),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Align(
                    alignment: _align == 'left'
                        ? Alignment.centerLeft
                        : _align == 'right'
                            ? Alignment.centerRight
                            : Alignment.center,
                    child: file.existsSync()
                        ? Image.file(
                            file,
                            width: screenW * _width,
                            fit: BoxFit.contain,
                          )
                        : Text(
                            l10n.t(az: 'Fayl tapılmadı', en: 'File not found', ru: 'Файл не найден', ar: 'الملف غير موجود'),
                            style: const TextStyle(color: Colors.white54)),
                  ),
                  if (_caption.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _caption.text,
                      style: GoogleFonts.dmSans(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    l10n.t(az: 'Ölçü', en: 'Size', ru: 'Размер', ar: 'الحجم') +
                        ' ${(_width * 100).round()}%',
                    style: GoogleFonts.dmSans(color: Colors.white70)),
                Slider(
                  value: _width,
                  min: 0.25,
                  max: 1.0,
                  divisions: 15,
                  label: '${(_width * 100).round()}%',
                  onChanged: (v) => setState(() => _width = v),
                ),
                Text(
                    l10n.t(az: 'Mövqe', en: 'Position', ru: 'Позиция', ar: 'الموضع'),
                    style: GoogleFonts.dmSans(color: Colors.white70)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final a in [
                      ('left', l10n.t(az: 'Sol', en: 'Left', ru: 'Слева', ar: 'يسار')),
                      ('center', l10n.t(az: 'Orta', en: 'Center', ru: 'Центр', ar: 'وسط')),
                      ('right', l10n.t(az: 'Sağ', en: 'Right', ru: 'Справа', ar: 'يمين')),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(a.$2),
                          selected: _align == a.$1,
                          onSelected: (_) => setState(() => _align = a.$1),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caption,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: l10n.t(az: 'İzah (istəyə bağlı)', en: 'Caption (optional)', ru: 'Подпись (необязательно)', ar: 'تعليق (اختياري)'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    ImageInsertResult(
                      widget.path,
                      _width,
                      caption: _caption.text.trim(),
                      align: _align,
                    ),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    widget.editing
                        ? l10n.t(az: 'Yenilə', en: 'Update', ru: 'Обновить', ar: 'تحديث')
                        : l10n.t(az: 'Əlavə et', en: 'Insert', ru: 'Вставить', ar: 'إضافة'),
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5CE6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
