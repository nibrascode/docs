import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'billing_service.dart';

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

  /// Dedicated Nibras Docs project (separate from the nibrascode.com site DB).
  /// Publishable keys ship in the client; data is protected by RLS.
  static const defaultUrl = 'https://nocruxpgwldlrsuraavv.supabase.co';
  static const defaultPublishableKey = 'sb_publishable_z6cR-BVwVROf4ymNR7q52Q_K_TN2LwF';

  static String supabaseUrl = '';
  static String supabaseAnonKey = '';
  static String googleWebClientId = '';
  static bool _initialized = false;

  /// Pick the client key: publishable first, legacy anon JWT as fallback.
  static String pickKey(Map<String, dynamic> m) {
    for (final k in const ['SUPABASE_PUBLISHABLE_KEY', 'SUPABASE_ANON_KEY']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// Merge config sources: dart-define > env.json > built-in defaults.
  static Map<String, String> resolveConfig(
      Map<String, dynamic> defines, Map<String, dynamic> envJson) {
    String url = (defines['SUPABASE_URL'] ?? '').toString().trim();
    String key = pickKey(defines);
    String gid = (defines['GOOGLE_WEB_CLIENT_ID'] ?? '').toString().trim();
    if (url.isEmpty) url = (envJson['SUPABASE_URL'] ?? '').toString().trim();
    if (key.isEmpty) key = pickKey(envJson);
    if (gid.isEmpty) gid = (envJson['GOOGLE_WEB_CLIENT_ID'] ?? '').toString().trim();
    if (url.isEmpty) url = defaultUrl;
    if (key.isEmpty) key = defaultPublishableKey;
    return {'url': url, 'key': key, 'googleWebClientId': gid};
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    const defines = <String, dynamic>{
      'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
      'GOOGLE_WEB_CLIENT_ID': String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    };
    Map<String, dynamic> env = {};
    try {
      env = jsonDecode(await rootBundle.loadString('assets/env.json'))
          as Map<String, dynamic>;
    } catch (_) {}
    final cfg = resolveConfig(defines, env);
    supabaseUrl = cfg['url']!;
    supabaseAnonKey = cfg['key']!;
    googleWebClientId = cfg['googleWebClientId']!;
    try {
      // supabase_flutter names the param anonKey; publishable keys work here.
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _initialized = true;
    } catch (e) {
      _initialized = true; // already initialized
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
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await BillingService.instance.logOut();
    await client.auth.signOut();
  }

  /// Google: native account picker → idToken → Supabase session.
  /// Returns null if the user cancelled. Throws [StateError] if not configured.
  Future<AuthResponse?> signInWithGoogle() async {
    if (!isReady) return null;
    if (googleWebClientId.isEmpty) {
      throw StateError('GOOGLE_WEB_CLIENT_ID missing');
    }
    final gsi = GoogleSignIn.instance;
    await gsi.initialize(serverClientId: googleWebClientId);
    final GoogleSignInAccount account;
    try {
      account = await gsi.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw StateError('Google returned no idToken');
    return client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }
}
