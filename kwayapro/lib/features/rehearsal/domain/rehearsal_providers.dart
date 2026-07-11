import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/rehearsal_repository.dart';
import '../../../shared/models/enums.dart';
import '../domain/models/rehearsal_session.dart';
import '../../attendance/domain/models/attendance.dart';
import '../../choir/domain/choir_providers.dart';
import '../../auth/domain/auth_providers.dart';

final rehearsalRepositoryProvider = Provider<RehearsalRepository>((ref) {
  return RehearsalRepository();
});

// Phase 5 Fix 4: previously not autoDispose — see song_providers.dart for
// the same fix and reasoning.
final upcomingRehearsalsProvider = StreamProvider.autoDispose<List<RehearsalSession>>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  final sub = ref.watch(rehearsalRepositoryProvider).watchUpcomingSessions(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final pastRehearsalsProvider = StreamProvider.autoDispose<List<RehearsalSession>>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  final sub = ref.watch(rehearsalRepositoryProvider).watchPastSessions(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final myRSVPProvider = StreamProvider.autoDispose.family<Attendance?, String>((ref, sessionId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  final sub = ref.watch(rehearsalRepositoryProvider).watchMyRSVP(sessionId, userId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final rsvpCountsProvider = StreamProvider.autoDispose.family<Map<RSVPStatus, int>, String>((ref, sessionId) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value(<RSVPStatus, int>{});
  final sub = ref.watch(rehearsalRepositoryProvider).watchRSVPCounts(sessionId, choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final pendingGuestTokenProvider = StateProvider<String?>((ref) => null);
