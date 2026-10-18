import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline local store — settings included (Part 4).
class LocalDocsCache {
  static const _key = 'nibras_local_docs_v1';

  static Future<List<Map<String, dynamic>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          if (m['id'] != null) out.add(m);
        }
      }
      out.sort((a, b) {
        final aa = a['updatedAt']?.toString() ?? '';
        final bb = b['updatedAt']?.toString() ?? '';
        return bb.compareTo(aa);
      });
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveDoc({
    required String id,
    required String title,
    required String content,
    bool? isStarred,
    Map<String, dynamic>? settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await load();
    final idx = docs.indexWhere((d) => d['id'] == id);
    final entry = <String, dynamic>{
      'id': id,
      'title': title.trim().isEmpty ? 'Untitled Document' : title.trim(),
      'content': content,
      'isStarred': isStarred ?? (idx >= 0 && docs[idx]['isStarred'] == true),
      'wordCount': content
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length,
      'updatedAt': DateTime.now().toIso8601String(),
      'createdAt': idx >= 0
          ? (docs[idx]['createdAt'] ?? DateTime.now().toIso8601String())
          : DateTime.now().toIso8601String(),
    };
    if (settings != null) {
      entry['settings'] = settings;
    } else if (idx >= 0 && docs[idx]['settings'] != null) {
      entry['settings'] = docs[idx]['settings'];
    }
    if (idx >= 0) {
      docs[idx] = {...docs[idx], ...entry};
    } else {
      docs.insert(0, entry);
    }
    await prefs.setString(_key, jsonEncode(docs));
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await load();
    docs.removeWhere((d) => d['id'] == id);
    await prefs.setString(_key, jsonEncode(docs));
  }

  static Future<void> setStarred(String id, bool starred) async {
    final docs = await load();
    final idx = docs.indexWhere((d) => d['id'] == id);
    if (idx < 0) return;
    docs[idx]['isStarred'] = starred;
    docs[idx]['updatedAt'] = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(docs));
  }

  static Future<int> count() async => (await load()).length;

  static Future<void> _write(List<Map<String, dynamic>> docs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(docs));
  }

  static Future<void> rename(String id, String title) async {
    final docs = await load();
    final idx = docs.indexWhere((d) => d['id'] == id);
    if (idx < 0) return;
    docs[idx]['title'] = title.trim().isEmpty ? 'Untitled Document' : title.trim();
    docs[idx]['updatedAt'] = DateTime.now().toIso8601String();
    await _write(docs);
  }

  /// Copies a document (content + settings). Returns the new id.
  static Future<String?> duplicate(String id, {String suffix = ' (copy)'}) async {
    final docs = await load();
    final idx = docs.indexWhere((d) => d['id'] == id);
    if (idx < 0) return null;
    final now = DateTime.now();
    final copy = Map<String, dynamic>.from(jsonDecode(jsonEncode(docs[idx])) as Map);
    copy['id'] = 'local_${now.microsecondsSinceEpoch}';
    copy['title'] = '${docs[idx]['title'] ?? ''}$suffix';
    copy['isStarred'] = false;
    copy['createdAt'] = now.toIso8601String();
    copy['updatedAt'] = now.toIso8601String();
    docs.insert(0, copy);
    await _write(docs);
    return copy['id'] as String;
  }

  /// Full backup as JSON (all documents with their settings).
  static Future<String> exportAll() async {
    final docs = await load();
    return const JsonEncoder.withIndent(' ').convert({
      'app': 'nibras_docs',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'documents': docs,
    });
  }

  /// Restores a backup. Documents with the same id are replaced only when the
  /// backup copy is newer. Returns how many documents were added or updated.
  static Future<int> importAll(String json) async {
    final decoded = jsonDecode(json);
    final list = decoded is Map ? decoded['documents'] : decoded;
    if (list is! List) throw const FormatException('Not a Nibras Docs backup');
    final docs = await load();
    var n = 0;
    for (final item in list) {
      if (item is! Map || item['id'] == null || item['content'] is! String) continue;
      final m = Map<String, dynamic>.from(item);
      final idx = docs.indexWhere((d) => d['id'] == m['id']);
      if (idx < 0) {
        docs.add(m);
        n++;
      } else if ((m['updatedAt']?.toString() ?? '').compareTo(docs[idx]['updatedAt']?.toString() ?? '') > 0) {
        docs[idx] = m;
        n++;
      }
    }
    await _write(docs);
    return n;
  }

  /// Adds a new document (e.g. imported file). Returns its id.
  static Future<String> addNew(String title, String content) async {
    final id = 'local_${DateTime.now().microsecondsSinceEpoch}';
    await saveDoc(id: id, title: title, content: content, isStarred: false);
    return id;
  }
}
