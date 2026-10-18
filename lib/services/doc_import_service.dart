import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import 'local_docs_cache.dart';

class ImportedDoc {
  final String title;
  final String content;
  const ImportedDoc(this.title, this.content);
}

/// Imports .txt / .md / .docx files as new documents, and restores backups.
class DocImportService {
  static Future<ImportedDoc?> pickDocument() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'docx'],
      withData: true,
    );
    final f = res?.files.single;
    if (f == null) return null;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return null;
    final name = f.name.replaceAll(RegExp(r'\.(txt|md|docx)$', caseSensitive: false), '');
    final ext = f.extension?.toLowerCase() ?? '';
    final content = ext == 'docx' ? docxToMarkup(bytes) : utf8.decode(bytes, allowMalformed: true);
    return ImportedDoc(name, content.replaceAll('\r\n', '\n'));
  }

  /// Picks a backup JSON and restores it. Returns the number of documents
  /// added or updated, or null if the user cancelled.
  static Future<int?> pickAndRestoreBackup() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final f = res?.files.single;
    if (f == null) return null;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return null;
    return LocalDocsCache.importAll(utf8.decode(bytes));
  }

  /// Minimal DOCX reader: paragraphs, Heading 1-3, bold/italic/underline
  /// runs and simple tables, converted to the editor's markup.
  static String docxToMarkup(List<int> bytes) {
    final arc = ZipDecoder().decodeBytes(bytes);
    final entry = arc.findFile('word/document.xml');
    if (entry == null) return '';
    final xml = utf8.decode(entry.content as List<int>, allowMalformed: true);
    final body = RegExp(r'<w:body>([\s\S]*)</w:body>').firstMatch(xml)?.group(1) ?? xml;
    final out = StringBuffer();
    String unesc(String s) => s
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');

    String para(String p) {
      final buf = StringBuffer();
      for (final r in RegExp(r'<w:r[ >][\s\S]*?</w:r>').allMatches(p)) {
        final run = r.group(0)!;
        final text = RegExp(r'<w:t[^>]*>([\s\S]*?)</w:t>')
            .allMatches(run)
            .map((m) => unesc(m.group(1)!))
            .join();
        final tabs = RegExp(r'<w:tab/>').allMatches(run).length;
        var t = '${'\t' * tabs}$text';
        if (t.trim().isEmpty) {
          buf.write(t);
          continue;
        }
        final b = RegExp(r'<w:b(?: w:val="(?:1|true)")?/>').hasMatch(run);
        final i = RegExp(r'<w:i(?: w:val="(?:1|true)")?/>').hasMatch(run);
        final u = RegExp(r'<w:u w:val="(?!none)').hasMatch(run);
        if (u) t = '__${t}__';
        if (i) t = '*$t*';
        if (b) t = '**$t**';
        buf.write(t);
      }
      final style = RegExp(r'<w:pStyle w:val="([^"]+)"').firstMatch(p)?.group(1) ?? '';
      final txt = buf.toString();
      final h = RegExp(r'(?:Heading|Başlıq|Title)\s*([1-3])?', caseSensitive: false).firstMatch(style);
      if (h != null && txt.trim().isNotEmpty) {
        final lvl = int.tryParse(h.group(1) ?? '1') ?? 1;
        return '${'#' * lvl} ${txt.replaceAll('**', '')}';
      }
      return txt;
    }

    final blocks = RegExp(r'<w:tbl>[\s\S]*?</w:tbl>|<w:p[ >][\s\S]*?</w:p>|<w:p/>').allMatches(body);
    for (final m in blocks) {
      final s = m.group(0)!;
      if (s.startsWith('<w:tbl>')) {
        out.writeln('[TABLE]');
        var first = true;
        for (final row in RegExp(r'<w:tr[ >][\s\S]*?</w:tr>').allMatches(s)) {
          final cells = RegExp(r'<w:tc>[\s\S]*?</w:tc>')
              .allMatches(row.group(0)!)
              .map((c) => RegExp(r'<w:p[ >][\s\S]*?</w:p>')
                  .allMatches(c.group(0)!)
                  .map((p) => para(p.group(0)!).replaceAll('|', '/'))
                  .join(' ')
                  .trim())
              .toList();
          out.writeln('| ${cells.join(' | ')} |');
          if (first) {
            out.writeln('| ${List.filled(cells.length, '---').join(' | ')} |');
            first = false;
          }
        }
        out.writeln('[/TABLE]');
        out.writeln();
      } else {
        out.writeln(s == '<w:p/>' ? '' : para(s));
        out.writeln();
      }
    }
    return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
