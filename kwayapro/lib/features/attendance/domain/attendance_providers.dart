import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_providers.dart';
import '../../choir/domain/choir_providers.dart';
import '../data/attendance_repository.dart';
import 'models/attendance.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

// Phase 5 Fix 4: previously not autoDispose — see song_providers.dart /
// chat_providers.dart for the same fix and reasoning.
final sessionAttendanceProvider = StreamProvider.autoDispose.family<List<Attendance>, String>((ref, sessionId) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  final sub = ref.watch(attendanceRepositoryProvider).watchSessionAttendance(sessionId, choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final myAttendanceHistoryProvider = StreamProvider.autoDispose<List<Attendance>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final choirId = ref.watch(activeChoirIdProvider);
  if (user == null || choirId == null) return Stream.value([]);
  final sub = ref.watch(attendanceRepositoryProvider).watchMemberHistory(user.uid, choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final memberAttendanceRateProvider = FutureProvider.autoDispose.family<double, String>((ref, userId) async {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return 0.0;
  return ref.read(attendanceRepositoryProvider).getMemberAttendanceRate(userId, choirId);
});

final lastSessionAttendanceRateProvider = FutureProvider.autoDispose<double>((ref) async {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return 0.0;
  return ref.read(attendanceRepositoryProvider).getLastSessionAttendanceRate(choirId);
});
