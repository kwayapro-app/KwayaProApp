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

final activeChoirProvider = StreamProvider<Choir?>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value(null);
  return ref.watch(choirRepositoryProvider).watchChoir(choirId);
});

final currentMembershipProvider = StreamProvider<ChoirMembership?>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  final user = ref.watch(authStateProvider).value;
  if (choirId == null || user == null) return Stream.value(null);
  return ref.watch(choirRepositoryProvider).watchMembership(choirId, user.uid);
});

class ChoirWithMembership {
  final Choir choir;
  final ChoirMembership membership;
  const ChoirWithMembership({required this.choir, required this.membership});
}

final userChoirsProvider = StreamProvider<List<ChoirWithMembership>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  final choirRepo = ref.watch(choirRepositoryProvider);
  
  return choirRepo.watchUserMemberships(user.uid).switchMap((memberships) {
    if (memberships.isEmpty) return Stream.value([]);
    
    // Create a stream that emits the list of ChoirWithMembership
    // by combining the latest values from each watchChoir stream.
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

final choirMembersProvider = StreamProvider<List<ChoirMembership>>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  return ref.watch(choirRepositoryProvider).watchMembers(choirId);
});
