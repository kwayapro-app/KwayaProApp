import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_providers.dart';
import '../../choir/domain/choir_providers.dart';
import '../data/attendance_repository.dart';
import 'models/attendance.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

final sessionAttendanceProvider = StreamProvider.family<List<Attendance>, String>((ref, sessionId) {
  return ref.read(attendanceRepositoryProvider).watchSessionAttendance(sessionId);
});

final myAttendanceHistoryProvider = StreamProvider<List<Attendance>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final choirId = ref.watch(activeChoirIdProvider);
  if (user == null || choirId == null) return Stream.value([]);
  return ref.read(attendanceRepositoryProvider).watchMemberHistory(user.uid, choirId);
});

final memberAttendanceRateProvider = FutureProvider.family<double, String>((ref, userId) async {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return 0.0;
  return ref.read(attendanceRepositoryProvider).getMemberAttendanceRate(userId, choirId);
});

final lastSessionAttendanceRateProvider = FutureProvider<double>((ref) async {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return 0.0;
  return ref.read(attendanceRepositoryProvider).getLastSessionAttendanceRate(choirId);
});