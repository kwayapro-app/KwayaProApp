import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';
import '../../../shared/providers/shared_prefs_provider.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/choir_repository.dart';
import 'models/choir.dart';
import 'models/choir_membership.dart';

final choirRepositoryProvider = Provider<ChoirRepository>((ref) {
  return ChoirRepository();
});

class ActiveChoirNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  static const _key = 'active_choir_id';

  ActiveChoirNotifier(this._prefs) : super(_prefs.getString(_key));

  Future<void> setChoir(String? choirId) async {
    state = choirId;
    if (choirId == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, choirId);
    }
  }
}

final activeChoirIdProvider = StateNotifierProvider<ActiveChoirNotifier, String?>((ref) {
  return ActiveChoirNotifier(ref.watch(sharedPrefsProvider));
});

final activeChoirProvider = StreamProvider.autoDispose<Choir?>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value(null);
  final sub = ref.watch(choirRepositoryProvider).watchChoir(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final currentMembershipProvider = StreamProvider.autoDispose<ChoirMembership?>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (choirId == null || user == null) return Stream.value(null);
  final sub = ref.watch(choirRepositoryProvider).watchMembership(choirId, user.uid);
  ref.onDispose(() => sub.drain());
  return sub;
});

class ChoirWithMembership {
  final Choir choir;
  final ChoirMembership membership;
  const ChoirWithMembership({required this.choir, required this.membership});
}

final userChoirsProvider = StreamProvider.autoDispose<List<ChoirWithMembership>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  final choirRepo = ref.watch(choirRepositoryProvider);

  return choirRepo.watchUserMemberships(user.uid).switchMap((memberships) {
    if (memberships.isEmpty) return Stream.value([]);

    final choirStreams = memberships.map((m) {
      return choirRepo.watchChoir(m.choirId).map((choir) {
        if (choir == null) return null;
        return ChoirWithMembership(choir: choir, membership: m);
      });
    });

    return CombineLatestStream.list(choirStreams).map(
      (list) => list.whereType<ChoirWithMembership>().toList(),
    );
  });
});

final choirMembersProvider = StreamProvider.autoDispose<List<ChoirMembership>>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  final sub = ref.watch(choirRepositoryProvider).watchMembers(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

// Phase 5 Fix 4: removed a duplicate `songLibraryProvider` that used to be
// defined here (raw Firestore query, bypassing SongRepository — flagged in
// PHASE_2_REPORT.md as a repository-pattern violation and dead-code risk).
// Nothing actually referenced this copy — planner_screen.dart explicitly
// imports the real one from song_providers.dart via `show
// songLibraryProvider`. The two same-named top-level providers compiled
// fine only because Dart doesn't error on an ambiguous import until the
// ambiguous name is actually used unqualified; deleting this one resolves
// the collision outright rather than leaving it as a landmine.
