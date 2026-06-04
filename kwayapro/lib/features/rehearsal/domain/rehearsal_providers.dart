import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/rehearsal_repository.dart';
import '../../../shared/models/enums.dart';
import '../domain/models/rehearsal_session.dart';
import '../../attendance/domain/models/attendance.dart';

// Repository provider
final rehearsalRepositoryProvider = Provider<RehearsalRepository>((ref) {
  return RehearsalRepository();
});

// Upcoming rehearsals - uses activeChoirIdProvider from choir_providers
final upcomingRehearsalsProvider = StreamProvider<List<RehearsalSession>>((ref) {
  // Will be provided by the screens that use this
  return Stream.value([]);
});

// Past rehearsals
final pastRehearsalsProvider = StreamProvider<List<RehearsalSession>>((ref) {
  return Stream.value([]);
});

// My RSVP for a session
final myRSVPProvider = StreamProvider.family<Attendance?, String>((ref, sessionId) {
  return Stream.value(null);
});

// RSVP counts for a session
final rsvpCountsProvider = StreamProvider.family<Map<RSVPStatus, int>, String>((ref, sessionId) {
  return Stream.value({});
});

// Pending guest token for deep link handling
final pendingGuestTokenProvider = StateProvider<String?>((ref) => null);

// Actual implementations require importing activeChoirIdProvider from choir_providers