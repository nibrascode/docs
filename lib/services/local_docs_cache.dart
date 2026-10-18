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
    bool isStarred = false,
    Map<String, dynamic>? settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await load();
    final idx = docs.indexWhere((d) => d['id'] == id);
    final entry = <String, dynamic>{
      'id': id,
      'title': title.trim().isEmpty ? 'Untitled Document' : title.trim(),
      'content': content,
      'isStarred': isStarred,
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
}
