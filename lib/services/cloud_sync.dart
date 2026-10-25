import 'billing_service.dart';
import 'local_docs_cache.dart';
import 'supabase_service.dart';

/// What to do for one document during a two-way sync.
enum SyncAction { create, push, pull, none }

class SyncStep {
  final SyncAction action;
  final String id;
  const SyncStep(this.action, this.id);
  @override
  String toString() => '${action.name}:$id';
}

/// Pure two-way sync planner (offline-first, last-write-wins by updatedAt).
/// [local]: LocalDocsCache maps (`id`, `updatedAt` ISO). [remote]: cloud docs.
class CloudSync {
  static final _uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);

  static bool isCloudId(String id) => _uuid.hasMatch(id);

  static List<SyncStep> plan(
      List<Map<String, dynamic>> local, List<DocumentModel> remote) {
    final remoteById = {for (final r in remote) r.id: r};
    final steps = <SyncStep>[];
    final seen = <String>{};
    for (final l in local) {
      final id = l['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      seen.add(id);
      final r = remoteById[id];
      if (r == null) {
        // Never uploaded (local_*), or deleted in cloud / other account → create.
        steps.add(SyncStep(SyncAction.create, id));
        continue;
      }
      final lu = DateTime.tryParse(l['updatedAt']?.toString() ?? '');
      if (lu == null) {
        steps.add(SyncStep(SyncAction.pull, id));
      } else if (lu.isAfter(r.updatedAt)) {
        steps.add(SyncStep(SyncAction.push, id));
      } else if (r.updatedAt.isAfter(lu)) {
        steps.add(SyncStep(SyncAction.pull, id));
      } else {
        steps.add(SyncStep(SyncAction.none, id));
      }
    }
    for (final r in remote) {
      if (!seen.contains(r.id)) steps.add(SyncStep(SyncAction.pull, r.id));
    }
    return steps;
  }

  static Map<String, dynamic> toLocal(DocumentModel d) => {
        'id': d.id,
        'title': d.title,
        'content': d.content,
        'isStarred': d.isStarred,
        'wordCount': d.wordCount,
        'createdAt': d.createdAt.toIso8601String(),
        'updatedAt': d.updatedAt.toIso8601String(),
      };

  /// Run a full sync for the signed-in user. Returns number of changed docs.
  /// Safe no-op when offline / not signed in.
  static Future<int> run() async {
    final svc = SupabaseService.instance;
    if (!svc.isReady || !svc.isAuthenticated) return 0;
    await BillingService.instance.logIn(svc.currentUser!.id);
    final local = await LocalDocsCache.load();
    final remote = await svc.getDocuments();
    final localById = {for (final l in local) l['id'].toString(): l};
    final remoteById = {for (final r in remote) r.id: r};
    var n = 0;
    for (final s in plan(local, remote)) {
      try {
        switch (s.action) {
          case SyncAction.create:
            final l = localById[s.id]!;
            final created = await svc.createDocument(
              title: l['title']?.toString() ?? 'Untitled Document',
              content: l['content']?.toString() ?? '',
            );
            if (created != null) {
              await LocalDocsCache.replaceId(s.id, created.id);
              n++;
            }
          case SyncAction.push:
            final l = localById[s.id]!;
            await svc.updateDocument(
              id: s.id,
              title: l['title']?.toString(),
              content: l['content']?.toString(),
              isStarred: l['isStarred'] == true,
            );
            n++;
          case SyncAction.pull:
            await LocalDocsCache.putRaw(toLocal(remoteById[s.id]!));
            n++;
          case SyncAction.none:
            break;
        }
      } catch (_) {}
    }
    return n;
  }
}
