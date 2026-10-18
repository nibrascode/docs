import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentModel {
  final String id;
  final String userId;
  final String title;
  final String content;
  final bool isStarred;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.isStarred,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Untitled Document',
      content: json['content'] as String? ?? '',
      isStarred: json['is_starred'] as bool? ?? false,
      wordCount: json['word_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'content': content,
      'is_starred': isStarred,
      'word_count': wordCount,
    };
  }

  DocumentModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    bool? isStarred,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      isStarred: isStarred ?? this.isStarred,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static String supabaseUrl = '';
  static String supabaseAnonKey = '';
  static bool _initialized = false;

  /// Load keys from assets/env.json or --dart-define, then init client.
  static Future<void> initialize() async {
    if (_initialized) return;
    // 1) dart-define
    const defineUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const defineKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (defineUrl.isNotEmpty && defineKey.isNotEmpty) {
      supabaseUrl = defineUrl;
      supabaseAnonKey = defineKey;
    }
    // 2) asset env.json
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      try {
        final raw = await rootBundle.loadString('assets/env.json');
        final map = jsonDecode(raw) as Map<String, dynamic>;
        supabaseUrl = (map['SUPABASE_URL'] ?? '').toString();
        supabaseAnonKey = (map['SUPABASE_ANON_KEY'] ?? map['SUPABASE_PUBLISHABLE_KEY'] ?? '').toString();
      } catch (_) {}
    }
    // 3) hardcoded fallback (user project)
    if (supabaseUrl.isEmpty) {
      supabaseUrl = 'https://czewxsvfywqwfozrkbjc.supabase.co';
    }
    if (supabaseAnonKey.isEmpty) {
      supabaseAnonKey = 'sb_publishable_TqgEkKDaHAQ7Hb9bcDcfRw_b8jLg5jJ';
    }
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return;
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _initialized = true;
    } catch (e) {
      // already initialized
      _initialized = true;
    }
  }

  bool get isReady {
    if (!_initialized) return false;
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  // Get Supabase client (only call when isReady)
  SupabaseClient get client => Supabase.instance.client;

  // Current user
  User? get currentUser {
    if (!isReady) return null;
    return client.auth.currentUser;
  }
  bool get isAuthenticated => currentUser != null;

  // ─── Documents CRUD ───────────────────────────────────────────────────────

  /// Fetch all documents for the current user, ordered by last updated
  Future<List<DocumentModel>> getDocuments() async {
    if (!isReady) return [];
    final userId = currentUser?.id;
    if (userId == null) return [];

    final response = await client
        .from('documents')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => DocumentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single document by ID
  Future<DocumentModel?> getDocument(String id) async {
    if (!isReady) return null;
    final response = await client
        .from('documents')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return DocumentModel.fromJson(response);
  }

  /// Create a new document and return it
  Future<DocumentModel?> createDocument({
    String title = 'Untitled Document',
    String content = '',
  }) async {
    if (!isReady) return null;
    final userId = currentUser?.id;
    if (userId == null) return null;

    final wordCount = _countWords(content);

    final response = await client
        .from('documents')
        .insert({
          'user_id': userId,
          'title': title,
          'content': content,
          'is_starred': false,
          'word_count': wordCount,
        })
        .select()
        .single();

    return DocumentModel.fromJson(response);
  }

  /// Update an existing document
  Future<DocumentModel?> updateDocument({
    required String id,
    String? title,
    String? content,
    bool? isStarred,
  }) async {
    if (!isReady) return null;
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) {
      updates['content'] = content;
      updates['word_count'] = _countWords(content);
    }
    if (isStarred != null) updates['is_starred'] = isStarred;

    if (updates.isEmpty) return null;

    final response = await client
        .from('documents')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return DocumentModel.fromJson(response);
  }

  /// Toggle starred status
  Future<DocumentModel?> toggleStarred(String id, bool currentValue) async {
    return updateDocument(id: id, isStarred: !currentValue);
  }

  /// Delete a document
  Future<void> deleteDocument(String id) async {
    if (!isReady) return;
    await client.from('documents').delete().eq('id', id);
  }

  // ─── Real-time Subscriptions ──────────────────────────────────────────────

  /// Subscribe to real-time changes on the documents table for the current user
  RealtimeChannel? subscribeToDocuments({
    required void Function(List<DocumentModel> docs) onUpdate,
    required void Function() onRefresh,
  }) {
    if (!isReady) return null;
    final userId = currentUser?.id ?? '';
    if (userId.isEmpty) return null;

    return client
        .channel('documents_realtime_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'documents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onRefresh();
          },
        )
        .subscribe();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  
  Future<AuthResponse?> signUp({required String email, required String password}) async {
    if (!isReady) return null;
    return client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse?> signIn({required String email, required String password}) async {
    if (!isReady) return null;
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!isReady) return;
    await client.auth.signOut();
  }

  /// Push all local docs to cloud for current user (best-effort).
  Future<int> syncLocalToCloud(List<Map<String, dynamic>> localDocs) async {
    if (!isReady || !isAuthenticated) return 0;
    var n = 0;
    for (final d in localDocs) {
      try {
        final id = d['id']?.toString() ?? '';
        final title = d['title']?.toString() ?? 'Untitled';
        final content = d['content']?.toString() ?? '';
        if (id.startsWith('local_')) {
          await createDocument(title: title, content: content);
        } else {
          try {
            await updateDocument(id: id, title: title, content: content);
          } catch (_) {
            await createDocument(title: title, content: content);
          }
        }
        n++;
      } catch (_) {}
    }
    return n;
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }
}
