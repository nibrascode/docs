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

  Widget _buildActionTile(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
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

  void _showTemplatesSheet(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.templates,
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Icon(Icons.grid_view_outlined,
                  size: 44, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                l10n.t(
                  az: 'Şablonlar hələ yoxdur',
                  en: 'No templates yet',
                  ru: 'Шаблонов пока нет',
                  ar: 'لا توجد قوالب بعد',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.t(
                  az: 'Bu bölmə sonra doldurulacaq.',
                  en: 'This section will be filled later.',
                  ru: 'Этот раздел будет заполнен позже.',
                  ar: 'سيتم ملء هذا القسم لاحقاً.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  List<Map<String, dynamic>> _getTemplates(AppLocalizations l10n) {
    return [
      {
        'emoji': '📝',
        'color': const Color(0xFF2563EB),
        'title': l10n.t(
          az: 'Boş sənəd',
          en: 'Blank document',
          ru: 'Пустой документ',
          ar: 'مستند فارغ',
        ),
        'subtitle': l10n.t(
          az: 'Sıfırdan başlayın',
          en: 'Start from scratch',
          ru: 'Начать с нуля',
          ar: 'ابدأ من الصفر',
        ),
        'content': '',
      },
      {
        'emoji': '📋',
        'color': const Color(0xFF16A34A),
        'title': l10n.t(
          az: 'İş hesabatı',
          en: 'Business report',
          ru: 'Деловой отчёт',
          ar: 'تقرير الأعمال',
        ),
        'subtitle': l10n.t(
          az: 'Peşəkar hesabat şablonu',
          en: 'Professional report template',
          ru: 'Профессиональный шаблон отчёта',
          ar: 'قالب تقرير احترافي',
        ),
        'content': l10n.t(
          az: 'İş Hesabatı\n\nTarix: \nHazırlayan: \n\n1. Xülasə\n\n[Hesabatın qısa xülasəsini buraya yazın]\n\n2. Giriş\n\n[Mövzunun əsas məqsədi və əhatə dairəsi]\n\n3. Əsas Nəticələr\n\n• Nəticə 1\n• Nəticə 2\n• Nəticə 3\n\n4. Tövsiyələr\n\n[Tövsiyə olunan addımlar]\n\n5. Nəticə\n\n[Yekun qeydlər]',
          en: 'Business Report\n\nDate: \nPrepared by: \n\n1. Executive Summary\n\n[Write a brief summary of the report here]\n\n2. Introduction\n\n[Main purpose and scope of the topic]\n\n3. Key Findings\n\n• Finding 1\n• Finding 2\n• Finding 3\n\n4. Recommendations\n\n[Recommended next steps]\n\n5. Conclusion\n\n[Final remarks]',
          ru: 'Деловой отчёт\n\nДата: \nПодготовил: \n\n1. Краткое резюме\n\n[Напишите краткое резюме отчёта]\n\n2. Введение\n\n[Основная цель и охват темы]\n\n3. Ключевые выводы\n\n• Вывод 1\n• Вывод 2\n• Вывод 3\n\n4. Рекомендации\n\n[Рекомендуемые следующие шаги]\n\n5. Заключение\n\n[Заключительные замечания]',
          ar: 'تقرير الأعمال\n\nالتاريخ: \nأعده: \n\n1. الملخص التنفيذي\n\n[اكتب ملخصاً موجزاً للتقرير هنا]\n\n2. المقدمة\n\n[الغرض الرئيسي ونطاق الموضوع]\n\n3. النتائج الرئيسية\n\n• النتيجة 1\n• النتيجة 2\n• النتيجة 3\n\n4. التوصيات\n\n[الخطوات التالية الموصى بها]\n\n5. الخاتمة\n\n[الملاحظات الختامية]',
        ),
      },
      {
        'emoji': '✉️',
        'color': const Color(0xFF7C3AED),
        'title': l10n.t(
          az: 'Rəsmi məktub',
          en: 'Formal letter',
          ru: 'Официальное письмо',
          ar: 'رسالة رسمية',
        ),
        'subtitle': l10n.t(
          az: 'Peşəkar yazışma şablonu',
          en: 'Professional correspondence template',
          ru: 'Шаблон деловой переписки',
          ar: 'قالب المراسلات المهنية',
        ),
        'content': l10n.t(
          az: '[Göndərənin adı]\n[Ünvan]\n[Tarix]\n\n[Alıcının adı]\n[Vəzifəsi]\n[Şirkətin adı]\n\nHörmətli [Ad],\n\n[Məktubun əsas məzmunu buraya yazılır. Birinci abzasda məqsədi qısaca izah edin.]\n\n[İkinci abzasda ətraflı məlumat verin.]\n\n[Üçüncü abzasda nəticə çıxarın və növbəti addımları göstərin.]\n\nHörmətlə,\n\n[İmza]\n[Ad Soyad]\n[Əlaqə məlumatları]',
          en: '[Sender Name]\n[Address]\n[Date]\n\n[Recipient Name]\n[Title]\n[Company Name]\n\nDear [Name],\n\n[Write the main content of the letter here. Briefly explain the purpose in the first paragraph.]\n\n[Provide detailed information in the second paragraph.]\n\n[Draw conclusions and indicate next steps in the third paragraph.]\n\nSincerely,\n\n[Signature]\n[Full Name]\n[Contact Information]',
          ru: '[Имя отправителя]\n[Адрес]\n[Дата]\n\n[Имя получателя]\n[Должность]\n[Название компании]\n\nУважаемый [Имя],\n\n[Напишите основное содержание письма здесь. Кратко объясните цель в первом абзаце.]\n\n[Предоставьте подробную информацию во втором абзаце.]\n\n[Сделайте выводы и укажите следующие шаги в третьем абзаце.]\n\nС уважением,\n\n[Подпись]\n[Полное имя]\n[Контактная информация]',
          ar: '[اسم المرسل]\n[العنوان]\n[التاريخ]\n\n[اسم المستلم]\n[المسمى الوظيفي]\n[اسم الشركة]\n\nعزيزي [الاسم]،\n\n[اكتب المحتوى الرئيسي للرسالة هنا. اشرح الغرض باختصار في الفقرة الأولى.]\n\n[قدم معلومات تفصيلية في الفقرة الثانية.]\n\n[استخلص النتائج وأشر إلى الخطوات التالية في الفقرة الثالثة.]\n\nمع التحية،\n\n[التوقيع]\n[الاسم الكامل]\n[معلومات الاتصال]',
        ),
      },
      {
        'emoji': '📖',
        'color': const Color(0xFFD97706),
        'title': l10n.t(
          az: 'Esse / Məqalə',
          en: 'Essay / Article',
          ru: 'Эссе / Статья',
          ar: 'مقال / مقالة',
        ),
        'subtitle': l10n.t(
          az: 'Akademik yazı şablonu',
          en: 'Academic writing template',
          ru: 'Шаблон академического текста',
          ar: 'قالب الكتابة الأكاديمية',
        ),
        'content': l10n.t(
          az: 'Başlıq\n\nMüəllif: \nTarix: \n\nGiriş\n\n[Mövzunu təqdim edin. Oxucunun diqqətini çəkəcək bir cümlə ilə başlayın. Tezis bəyanatınızı buraya yazın.]\n\nI. Birinci Bölmə\n\n[Əsas arqumenti izah edin. Dəstəkləyici faktlar və nümunələr əlavə edin.]\n\nII. İkinci Bölmə\n\n[İkinci arqumenti inkişaf etdirin. Birinci bölmə ilə əlaqəni göstərin.]\n\nIII. Üçüncü Bölmə\n\n[Üçüncü arqumenti təqdim edin. Əks fikirləri nəzərə alın.]\n\nNəticə\n\n[Əsas fikirləri ümumiləşdirin. Tezis bəyanatını yenidən ifadə edin. Oxucuya düşünmək üçün bir şey verin.]\n\nİstinadlar\n\n1. \n2. ',
          en: 'Title\n\nAuthor: \nDate: \n\nIntroduction\n\n[Introduce the topic. Start with a hook sentence. Write your thesis statement here.]\n\nI. First Section\n\n[Explain the main argument. Add supporting facts and examples.]\n\nII. Second Section\n\n[Develop the second argument. Show the connection to the first section.]\n\nIII. Third Section\n\n[Present the third argument. Consider counterarguments.]\n\nConclusion\n\n[Summarize the main ideas. Restate the thesis. Give the reader something to think about.]\n\nReferences\n\n1. \n2. ',
          ru: 'Заголовок\n\nАвтор: \nДата: \n\nВведение\n\n[Представьте тему. Начните с захватывающего предложения. Напишите тезис.]\n\nI. Первый раздел\n\n[Объясните основной аргумент. Добавьте факты и примеры.]\n\nII. Второй раздел\n\n[Развейте второй аргумент. Покажите связь с первым разделом.]\n\nIII. Третий раздел\n\n[Представьте третий аргумент. Рассмотрите контраргументы.]\n\nЗаключение\n\n[Обобщите основные идеи. Перефразируйте тезис. Дайте читателю пищу для размышлений.]\n\nСписок литературы\n\n1. \n2. ',
          ar: 'العنوان\n\nالمؤلف: \nالتاريخ: \n\nالمقدمة\n\n[قدّم الموضوع. ابدأ بجملة جذابة. اكتب أطروحتك هنا.]\n\nأولاً. القسم الأول\n\n[اشرح الحجة الرئيسية. أضف حقائق وأمثلة داعمة.]\n\nثانياً. القسم الثاني\n\n[طوّر الحجة الثانية. أظهر الصلة بالقسم الأول.]\n\nثالثاً. القسم الثالث\n\n[قدّم الحجة الثالثة. ضع في اعتبارك الحجج المضادة.]\n\nالخاتمة\n\n[لخّص الأفكار الرئيسية. أعد صياغة الأطروحة. أعطِ القارئ شيئاً للتفكير فيه.]\n\nالمراجع\n\n1. \n2. ',
        ),
      },
      {
        'emoji': '📅',
        'color': const Color(0xFFDC2626),
        'title': l10n.t(
          az: 'Gündəlik plan',
          en: 'Daily planner',
          ru: 'Ежедневный план',
          ar: 'المخطط اليومي',
        ),
        'subtitle': l10n.t(
          az: 'Günlük tapşırıq siyahısı',
          en: 'Daily task list template',
          ru: 'Шаблон ежедневных задач',
          ar: 'قالب قائمة المهام اليومية',
        ),
        'content': l10n.t(
          az: 'Gündəlik Plan\n\nTarix: \n\n🎯 Bu günün məqsədi:\n\n\n⏰ Sabah üçün prioritetlər:\n\n1. [ ] \n2. [ ] \n3. [ ] \n\n📋 Tapşırıqlar:\n\nSəhər:\n• [ ] \n• [ ] \n\nGündüz:\n• [ ] \n• [ ] \n\nAxşam:\n• [ ] \n• [ ] \n\n📝 Qeydlər:\n\n\n✅ Tamamlananlar:\n\n',
          en: 'Daily Planner\n\nDate: \n\n🎯 Today\'s goal:\n\n\n⏰ Top priorities:\n\n1. [ ] \n2. [ ] \n3. [ ] \n\n📋 Tasks:\n\nMorning:\n• [ ] \n• [ ] \n\nAfternoon:\n• [ ] \n• [ ] \n\nEvening:\n• [ ] \n• [ ] \n\n📝 Notes:\n\n\n✅ Completed:\n\n',
          ru: 'Ежедневный план\n\nДата: \n\n🎯 Цель на сегодня:\n\n\n⏰ Главные приоритеты:\n\n1. [ ] \n2. [ ] \n3. [ ] \n\n📋 Задачи:\n\nУтро:\n• [ ] \n• [ ] \n\nДень:\n• [ ] \n• [ ] \n\nВечер:\n• [ ] \n• [ ] \n\n📝 Заметки:\n\n\n✅ Выполнено:\n\n',
          ar: 'المخطط اليومي\n\nالتاريخ: \n\n🎯 هدف اليوم:\n\n\n⏰ الأولويات الرئيسية:\n\n1. [ ] \n2. [ ] \n3. [ ] \n\n📋 المهام:\n\nالصباح:\n• [ ] \n• [ ] \n\nالظهيرة:\n• [ ] \n• [ ] \n\nالمساء:\n• [ ] \n• [ ] \n\n📝 ملاحظات:\n\n\n✅ المنجزات:\n\n',
        ),
      },
      {
        'emoji': '💼',
        'color': const Color(0xFF0891B2),
        'title': l10n.t(
          az: 'CV / Özgeçmiş',
          en: 'CV / Resume',
          ru: 'Резюме',
          ar: 'السيرة الذاتية',
        ),
        'subtitle': l10n.t(
          az: 'Peşəkar CV şablonu',
          en: 'Professional CV template',
          ru: 'Профессиональный шаблон резюме',
          ar: 'قالب السيرة الذاتية الاحترافية',
        ),
        'content': l10n.t(
          az: '[Ad Soyad]\n[Vəzifə / İxtisas]\n[E-poçt] | [Telefon] | [Şəhər]\n\nHAQQIMDA\n\n[Özünüzü qısaca təqdim edin. Əsas bacarıqlarınızı və karyera hədəflərinizi qeyd edin.]\n\nTƏHSİL\n\n[Universitet adı] — [İxtisas], [İl]\n[Orta məktəb] — [İl]\n\nİŞ TƏCRÜBƏSİ\n\n[Şirkət adı] | [Vəzifə] | [Tarix aralığı]\n• [Əsas məsuliyyət 1]\n• [Əsas məsuliyyət 2]\n• [Nailiyyət]\n\n[Şirkət adı] | [Vəzifə] | [Tarix aralığı]\n• [Əsas məsuliyyət]\n\nBACARI QLAR\n\nTexniki: [Bacarıq 1], [Bacarıq 2], [Bacarıq 3]\nDillər: [Dil 1 — Səviyyə], [Dil 2 — Səviyyə]\n\nSERTİFİKATLAR\n\n• [Sertifikat adı] — [Tarix]',
          en: '[Full Name]\n[Job Title / Profession]\n[Email] | [Phone] | [City]\n\nABOUT ME\n\n[Briefly introduce yourself. Mention your key skills and career goals.]\n\nEDUCATION\n\n[University Name] — [Major], [Year]\n[High School] — [Year]\n\nWORK EXPERIENCE\n\n[Company Name] | [Position] | [Date Range]\n• [Key responsibility 1]\n• [Key responsibility 2]\n• [Achievement]\n\n[Company Name] | [Position] | [Date Range]\n• [Key responsibility]\n\nSKILLS\n\nTechnical: [Skill 1], [Skill 2], [Skill 3]\nLanguages: [Language 1 — Level], [Language 2 — Level]\n\nCERTIFICATES\n\n• [Certificate Name] — [Date]',
          ru: '[Полное имя]\n[Должность / Специальность]\n[Email] | [Телефон] | [Город]\n\nОБО МНЕ\n\n[Кратко представьтесь. Укажите ключевые навыки и карьерные цели.]\n\nОБРАЗОВАНИЕ\n\n[Название университета] — [Специальность], [Год]\n[Школа] — [Год]\n\nОПЫТ РАБОТЫ\n\n[Название компании] | [Должность] | [Период]\n• [Ключевая обязанность 1]\n• [Ключевая обязанность 2]\n• [Достижение]\n\n[Название компании] | [Должность] | [Период]\n• [Ключевая обязанность]\n\nالمهارات\n\nالتقنية: [مهارة 1]، [مهارة 2]، [مهارة 3]\nاللغات: [اللغة 1 — المستوى]، [اللغة 2 — المستوى]\n\nالشهادات\n\n• [اسم الشهادة] — [التاريخ]',
          ar: '[الاسم الكامل]\n[المسمى الوظيفي / التخصص]\n[البريد الإلكتروني] | [الهاتف] | [المدينة]\n\nعني\n\n[قدّم نفسك باختصار. اذكر مهاراتك الرئيسية وأهدافك المهنية.]\n\nالتعليم\n\n[اسم الجامعة] — [التخصص]، [السنة]\n[المدرسة الثانوية] — [السنة]\n\nالخبرة العملية\n\n[اسم الشركة] | [المنصب] | [الفترة الزمنية]\n• [المسؤولية الرئيسية 1]\n• [المسؤولية الرئيسية 2]\n• [الإنجاز]\n\n[اسم الشركة] | [المنصب] | [الفترة الزمنية]\n• [المسؤولية الرئيسية]\n\nالمهارات\n\nالتقنية: [مهارة 1]، [مهارة 2]، [مهارة 3]\nاللغات: [اللغة 1 — المستوى]، [اللغة 2 — المستوى]\n\nالشهادات\n\n• [اسم الشهادة] — [التاريخ]',
        ),
      },
    ];
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
