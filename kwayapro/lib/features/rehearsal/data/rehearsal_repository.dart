import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/repositories/base_repository.dart';
import '../domain/models/rehearsal_session.dart';
import '../../attendance/domain/models/attendance.dart';

class RehearsalRepository extends BaseRepository {
  final Uuid _uuid = const Uuid();

  // Sessions
  Future<RehearsalSession> createSession(RehearsalSession session) async {
    final docRef = db.collection('rehearsal_sessions').doc(session.sessionId);
    await docRef.set(session.toJson());
    return session;
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> fields) async {
    await db.collection('rehearsal_sessions').doc(sessionId).update(fields);
  }

  Future<void> deleteSession(String sessionId) async {
    await db.collection('rehearsal_sessions').doc(sessionId).delete();
  }

  Stream<List<RehearsalSession>> watchUpcomingSessions(String choirId) {
    return db
        .collection('rehearsal_sessions')
        .where('choirId', isEqualTo: choirId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RehearsalSession.fromJson(doc.data())).toList());
  }

  Stream<List<RehearsalSession>> watchPastSessions(String choirId) {
    return db
        .collection('rehearsal_sessions')
        .where('choirId', isEqualTo: choirId)
        .where('date', isLessThan: Timestamp.now())
        .orderBy('date', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RehearsalSession.fromJson(doc.data())).toList());
  }

  Future<RehearsalSession?> getSession(String sessionId) async {
    final doc = await db.collection('rehearsal_sessions').doc(sessionId).get();
    if (!doc.exists) return null;
    return RehearsalSession.fromJson(doc.data()!);
  }

  // Guest director tokens
  Future<String> generateGuestToken(String sessionId) async {
    final token = _uuid.v4();
    final session = await getSession(sessionId);
    if (session == null) throw Exception('Session not found');

    // Token expires at 6 PM on the day of the session
    final sessionDateTime = session.date;
    final expiry = DateTime(
      sessionDateTime.year,
      sessionDateTime.month,
      sessionDateTime.day,
    ).add(const Duration(hours: 18));

    await db.collection('rehearsal_sessions').doc(sessionId).update({
      'guestToken': token,
      'guestTokenExpiry': Timestamp.fromDate(expiry),
      'isGuestDirector': true,
    });

    return token;
  }

  Future<bool> validateGuestToken(String token) async {
    final snapshot = await db
        .collection('rehearsal_sessions')
        .where('guestToken', isEqualTo: token)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;

    final data = snapshot.docs.first.data();
    final expiry = (data['guestTokenExpiry'] as Timestamp).toDate();
    return DateTime.now().isBefore(expiry);
  }

  Future<void> revokeGuestToken(String sessionId) async {
    await db.collection('rehearsal_sessions').doc(sessionId).update({
      'guestToken': FieldValue.delete(),
      'guestTokenExpiry': FieldValue.delete(),
      'isGuestDirector': false,
    });
  }

  // RSVP
  Future<void> setRSVP({
    required String sessionId,
    required String userId,
    required RSVPStatus status,
  }) async {
    final docId = '${sessionId}_$userId';
    await db.collection('attendance').doc(docId).set({
      'sessionId': sessionId,
      'userId': userId,
      'rsvp': status.name,
      'attended': false,
    }, SetOptions(merge: true));
  }

  Stream<Attendance?> watchMyRSVP(String sessionId, String userId) {
    final docId = '${sessionId}_$userId';
    return db
        .collection('attendance')
        .doc(docId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return Attendance.fromJson(snapshot.data()!);
        });
  }

  Stream<Map<RSVPStatus, int>> watchRSVPCounts(String sessionId) {
    return db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snapshot) {
          final counts = <RSVPStatus, int>{
            RSVPStatus.coming: 0,
            RSVPStatus.notComing: 0,
            RSVPStatus.pending: 0,
          };
          
          for (final doc in snapshot.docs) {
            final rsvp = RSVPStatus.values.byName(doc.data()['rsvp'] as String? ?? 'pending');
            counts[rsvp] = (counts[rsvp] ?? 0) + 1;
          }
          
          return counts;
        });
  }

  // Get session by guest token
  Future<RehearsalSession?> getSessionByToken(String token) async {
    final snapshot = await db
        .collection('rehearsal_sessions')
        .where('guestToken', isEqualTo: token)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return RehearsalSession.fromJson(snapshot.docs.first.data());
  }
}