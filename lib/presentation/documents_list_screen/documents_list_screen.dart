import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/premium_service.dart';
import '../../services/local_docs_cache.dart';
import '../../services/doc_import_service.dart';
import '../../services/mobile_export_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/language_selector_widget.dart';
import '../../l10n/ui_strings.dart';
import '../document_editor_screen/doc_title.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<DocumentModel> _docs = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDocuments();
    _setupRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Part 1: local store is source of truth (always works offline)
      final local = await LocalDocsCache.load();
      final byId = <String, DocumentModel>{};
      for (final m in local) {
        final id = m['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        DateTime parseDt(dynamic v) {
          if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
          return DateTime.now();
        }
        byId[id] = DocumentModel(
          id: id,
          userId: 'local',
          title: m['title']?.toString() ?? 'Untitled Document',
          content: m['content']?.toString() ?? '',
          isStarred: m['isStarred'] == true,
          wordCount: (m['wordCount'] is int)
              ? m['wordCount'] as int
              : int.tryParse('${m['wordCount']}') ?? 0,
          createdAt: parseDt(m['createdAt']),
          updatedAt: parseDt(m['updatedAt']),
        );
      }
      // Optional cloud merge when logged in
      try {
        if (SupabaseService.instance.isReady &&
            SupabaseService.instance.isAuthenticated) {
          final remote = await SupabaseService.instance.getDocuments();
          for (final d in remote) {
            final existing = byId[d.id];
            if (existing == null || d.updatedAt.isAfter(existing.updatedAt)) {
              byId[d.id] = d;
            }
          }
        }
      } catch (_) {}
      final docs = byId.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (mounted) {
        setState(() {
          _docs = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtime() {
    _realtimeChannel = SupabaseService.instance.subscribeToDocuments(
      onUpdate: (docs) {},
      onRefresh: () {
        if (mounted) _loadDocuments();
      },
    );
  }

  List<DocumentModel> get _filteredDocs {
    List<DocumentModel> result = List.from(_docs);
    if (_searchQuery.isNotEmpty) {
      result = result
          .where(
            (d) =>
                d.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                d.content.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    final tabIndex = _tabController.index;
    if (tabIndex == 1) {
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      result = result.take(5).toList();
    } else if (tabIndex == 2) {
      result = result.where((d) => d.isStarred).toList();
    }
    return result;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  Future<void> _openEditor(DocumentModel doc) async {
    Map<String, dynamic>? settings;
    try {
      final local = await LocalDocsCache.load();
      final match = local.where((e) => e['id'] == doc.id).toList();
      if (match.isNotEmpty && match.first['settings'] is Map) {
        settings = Map<String, dynamic>.from(match.first['settings'] as Map);
      }
      // Prefer local content if newer/available
      if (match.isNotEmpty) {
        final m = match.first;
        if (m['content'] != null) {
          // use local title/content
        }
      }
    } catch (_) {}
    if (!mounted) return;
    final local = await LocalDocsCache.load();
    Map<String, dynamic> extra = {
      'id': doc.id,
      'title': doc.title,
      'content': doc.content,
      'wordCount': doc.wordCount,
    };
    try {
      final match = local.where((e) => e['id'] == doc.id).toList();
      if (match.isNotEmpty) {
        final m = match.first;
        extra = {
          'id': doc.id,
          'title': m['title']?.toString() ?? doc.title,
          'content': m['content']?.toString() ?? doc.content,
          'wordCount': m['wordCount'] ?? doc.wordCount,
          if (m['settings'] is Map)
            'settings': Map<String, dynamic>.from(m['settings'] as Map),
        };
      } else if (settings != null) {
        extra['settings'] = settings;
      }
    } catch (_) {}
    if (!mounted) return;
    await context.push(AppRoutes.documentEditorScreen, extra: extra);
    if (mounted) _loadDocuments();
  }

  Future<void> _createNewDocument() async {
    var count = _docs.length;
    try {
      final local = await LocalDocsCache.load();
      if (local.length > count) count = local.length;
    } catch (_) {}

    final allowed = await PremiumService.canCreateDocument(count);
    if (!allowed) {
      if (!mounted) return;
      final tier = await PremiumService.currentTier();
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Document limit')),
          content: Text(
            tier == PlanTier.free
                ? 'Free plan includes up to ${PremiumService.maxDocsFree} documents. Upgrade to Pro (2.75 USD/mo) for unlimited documents and up to 150 pages each.'
                : 'Upgrade to Elite (5.75 USD/mo) for unlimited page length.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Not now')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('View plans')),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        context.push(AppRoutes.subscriptionPlanScreen);
      }
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: Text(l10n.t(az: 'Boş sənəd', en: 'Blank document', ru: 'Пустой документ', ar: 'مستند فارغ')),
            onTap: () => Navigator.pop(ctx, 'blank'),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_rounded),
            title: Text(l10n.templates),
            onTap: () => Navigator.pop(ctx, 'template'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: Text(l10n.t(az: 'Fayldan idxal (.pdf, .docx, .txt, .md)', en: 'Import file (.pdf, .docx, .txt, .md)', ru: 'Импорт файла (.pdf, .docx, .txt, .md)', ar: 'استيراد ملف (.pdf, .docx, .txt, .md)')),
            onTap: () => Navigator.pop(ctx, 'import'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'template') {
      await context.push(AppRoutes.templatesScreen);
    } else if (choice == 'import') {
      try {
        final doc = await DocImportService.pickDocument();
        if (doc == null || !mounted) return;
        final id = await LocalDocsCache.addNew(doc.title, doc.content);
        await _loadDocuments();
        final created = _docs.where((d) => d.id == id).toList();
        if (created.isNotEmpty) await _openEditor(created.first);
        return;
      } catch (e, st) {
        debugPrint("Error: $e\n$st");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
              l10n.t(az: 'Fayl oxunmadı.', en: 'Could not read file.', ru: 'Не удалось прочитать файл.', ar: 'تعذرت قراءة الملف.'))));
        }
        return;
      }
    } else {
      await context.push(AppRoutes.documentEditorScreen);
    }
    if (mounted) _loadDocuments();
  }

  Future<void> _renameDocument(DocumentModel doc) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: doc.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t(az: 'Adını dəyiş', en: 'Rename', ru: 'Переименовать', ar: 'إعادة تسمية')),
        content: TextField(controller: ctrl, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(l10n.t(az: 'Saxla', en: 'Save', ru: 'Сохранить', ar: 'حفظ'))),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await LocalDocsCache.rename(doc.id, name);
    await _loadDocuments();
  }

  Future<void> _duplicateDocument(DocumentModel doc) async {
    final l10n = AppLocalizations.of(context);
    await LocalDocsCache.duplicate(doc.id,
        suffix: l10n.t(az: ' (surət)', en: ' (copy)', ru: ' (копия)', ar: ' (نسخة)'));
    await _loadDocuments();
  }

  Future<void> _confirmDelete(DocumentModel doc) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t(az: 'Sənəd silinsin?', en: 'Delete document?', ru: 'Удалить документ?', ar: 'حذف المستند؟')),
        content: Text('«${doc.title}»'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteDocument(doc);
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    final l10n = AppLocalizations.of(context);
    try {
      await LocalDocsCache.delete(doc.id);
      try {
        if (SupabaseService.instance.isReady &&
            SupabaseService.instance.isAuthenticated) {
          await SupabaseService.instance.deleteDocument(doc.id);
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _docs.removeWhere((d) => d.id == doc.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.documentDeleted, style: GoogleFonts.dmSans()),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deleteFailed, style: GoogleFonts.dmSans()),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleStarred(DocumentModel doc) async {
    try {
      final next = !doc.isStarred;
      await LocalDocsCache.setStarred(doc.id, next);
      try {
        if (SupabaseService.instance.isReady &&
            SupabaseService.instance.isAuthenticated) {
          await SupabaseService.instance.toggleStarred(doc.id, doc.isStarred);
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          final idx = _docs.indexWhere((d) => d.id == doc.id);
          if (idx != -1) {
            _docs[idx] = DocumentModel(
              id: doc.id,
              userId: doc.userId,
              title: doc.title,
              content: doc.content,
              isStarred: next,
              wordCount: doc.wordCount,
              createdAt: doc.createdAt,
              updatedAt: DateTime.now(),
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _shareDocument(DocumentModel doc) async {
    final title = doc.title.trim().isEmpty ? 'Nibras Docs' : doc.title.trim();
    final plain = MobileExportService.plainText(doc.content);
    final body = plain.trim().isEmpty ? title : plain;
    try {
      await Share.share(body, subject: title);
    } catch (e, st) {
      debugPrint("Error: $e\n$st");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Paylaşmaq alınmadı. Yenidən cəhd edin.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
        children: [
          // Status bar area + dark header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B1F4A), Color(0xFF163A7A)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: _buildHeader(theme, l10n),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildSearchBar(theme, l10n),
                _buildQuickActions(theme, l10n),
                _buildTabBar(theme, l10n),
                Expanded(child: _buildTabContent(theme, l10n)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewDocument,
        backgroundColor: AppTheme.secondary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1F4A),
            Color(0xFF163A7A),
            Color(0xFF1A4A8C),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold.withAlpha(120), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gold.withAlpha(40),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.description_rounded,
              color: AppTheme.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Nibras ',
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: 'Docs',
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.t(
                    az: 'Yaz · Redaktə et · Yarat',
                    en: 'Write · Edit · Create',
                    ru: 'Пиши · Редактируй · Создавай',
                    ar: 'اكتب · حرر · أنشئ',
                  ),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.white70,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const LanguageSelectorWidget(),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            onPressed: () => context.push(AppRoutes.settingsScreen),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.dmSans(fontSize: 14, color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: l10n.t(
            az: 'Sənədlərimi axtar...',
            en: 'Search my documents...',
            ru: 'Поиск документов...',
            ar: 'ابحث في مستنداتي...',
          ),
          hintStyle: GoogleFonts.dmSans(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 22,
          ),
          suffixIcon: Icon(
            Icons.tune_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: Colors.black.withAlpha(12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: AppTheme.primary.withAlpha(80), width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: _buildHomeCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E4B9E), Color(0xFF163A7A)],
              ),
              icon: Icons.note_add_outlined,
              iconBg: Colors.white.withAlpha(30),
              title: l10n.t(
                az: 'Yeni sənəd',
                en: 'Create new document',
                ru: 'Новый документ',
                ar: 'مستند جديد',
              ),
              subtitle: l10n.t(
                az: 'Boş və ya şablonla',
                en: 'Blank document or use templates',
                ru: 'Пустой или из шаблона',
                ar: 'فارغ أو من قالب',
              ),
              titleColor: Colors.white,
              subtitleColor: Colors.white70,
              arrowColor: Colors.white70,
              onTap: _createNewDocument,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildHomeCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF8EE), Color(0xFFF5E6C8)],
              ),
              icon: Icons.grid_view_rounded,
              iconBg: const Color(0xFF1E4B9E).withAlpha(25),
              title: l10n.templates,
              subtitle: l10n.t(
                az: 'Roman, hekayə, şeir…',
                en: 'Novel, story, poetry…',
                ru: 'Роман, рассказ, стихи…',
                ar: 'رواية، قصة، شعر…',
              ),
              titleColor: const Color(0xFF0B1F4A),
              subtitleColor: const Color(0xFF0B1F4A).withAlpha(160),
              arrowColor: const Color(0xFF0B1F4A).withAlpha(140),
              onTap: () async {
                await context.push(AppRoutes.templatesScreen);
                if (mounted) _loadDocuments();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeCard({
    required Gradient gradient,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
    required Color arrowColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 118,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: titleColor, size: 20),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: arrowColor),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: subtitleColor,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTabBar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF5A6A85),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: const Color(0xFF0B1F4A),
          borderRadius: BorderRadius.circular(22),
        ),
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(text: '  ${l10n.allDocuments}  '),
          Tab(text: '  ${l10n.recent}  '),
          Tab(text: '  ${l10n.favorites}  '),
          Tab(text: '  ${l10n.cloud}  '),
        ],
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme, AppLocalizations l10n) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDocList(theme, l10n),
        _buildDocList(theme, l10n),
        _buildDocList(theme, l10n),
        _buildCloudTab(theme, l10n),
      ],
    );
  }

  Widget _buildDocList(ThemeData theme, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.error.withAlpha(180),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadDocuments,
              child: Text(
                l10n.retry,
                style: GoogleFonts.dmSans(color: AppTheme.primary),
              ),
            ),
          ],
        ),
      );
    }
    final docs = _filteredDocs;
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 56,
                  color: AppTheme.primary.withAlpha(180),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.t(
                  az: 'Hələ sənəd yoxdur',
                  en: 'No documents yet',
                  ru: 'Пока нет документов',
                  ar: 'لا مستندات بعد',
                ),
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t(
                  az: 'İlk sənədini yarat və Nibras Docs ilə işə başla.',
                  en: 'Create your first document and start working with Nibras Docs.',
                  ru: 'Создайте первый документ и начните работу.',
                  ar: 'أنشئ مستندك الأول وابدأ العمل.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _createNewDocument,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  l10n.t(
                    az: 'Yeni sənəd yarat',
                    en: 'Create new document',
                    ru: 'Создать документ',
                    ar: 'إنشاء مستند',
                  ),
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B1F4A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: docs.length,
      itemBuilder: (context, i) => _buildDocItem(theme, l10n, docs[i]),
    );
  }

  Widget _buildDocItem(
    ThemeData theme,
    AppLocalizations l10n,
    DocumentModel doc,
  ) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF16A34A),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFFDC2626),
    ];
    final iconColor = colors[doc.id.hashCode.abs() % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _openEditor(doc),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DocTitle.display(typed: doc.title, body: doc.content, untitled: l10n.untitledDocument),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(doc.updatedAt)} · ${doc.wordCount} ${l10n.words}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (doc.isStarred)
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: AppTheme.primary.withAlpha(200),
                ),
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _showDocOptions(context, theme, l10n, doc),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloudTab(ThemeData theme, AppLocalizations l10n) {
    final signedIn = SupabaseService.instance.isReady &&
        SupabaseService.instance.isAuthenticated;
    if (!signedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.cloudSignedOut,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.cloudSignedOutHint,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push(AppRoutes.authScreen),
                child: Text(l10n.signIn),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done_rounded,
            size: 56,
            color: AppTheme.primary.withAlpha(180),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.cloudSyncActive,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.cloudSyncRealtime,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '${_docs.length} ${l10n.documentsSaved}',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDocOptions(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    DocumentModel doc,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              DocTitle.display(typed: doc.title, body: doc.content, untitled: l10n.untitledDocument),
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _optionItem(ctx, Icons.edit_outlined, l10n.edit, () {
              Navigator.pop(ctx);
              _openEditor(doc);
            }),
            _optionItem(
              ctx,
              doc.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
              doc.isStarred ? l10n.removeFromFavorites : l10n.addToFavorites,
              () {
                Navigator.pop(ctx);
                _toggleStarred(doc);
              },
            ),
            _optionItem(
              ctx,
              Icons.share_outlined,
              l10n.share,
              () {
                Navigator.pop(ctx);
                _shareDocument(doc);
              },
            ),
            _optionItem(ctx, Icons.drive_file_rename_outline, l10n.t(az: 'Adını dəyiş', en: 'Rename', ru: 'Переименовать', ar: 'إعادة تسمية'), () {
              Navigator.pop(ctx);
              _renameDocument(doc);
            }),
            _optionItem(ctx, Icons.copy_all_outlined, l10n.t(az: 'Surətini çıxar', en: 'Duplicate', ru: 'Дублировать', ar: 'تكرار'), () {
              Navigator.pop(ctx);
              _duplicateDocument(doc);
            }),
            _optionItem(ctx, Icons.delete_outline_rounded, l10n.delete, () {
              Navigator.pop(ctx);
              _confirmDelete(doc);
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }


  Widget _optionItem(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppTheme.error : AppTheme.primary,
        size: 22,
      ),
      title: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDestructive ? AppTheme.error : null,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
