import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../core/utils/attendance_ids.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/repositories/base_repository.dart';
import '../domain/models/rehearsal_session.dart';
import '../../attendance/domain/models/attendance.dart';

class GuestJoinException implements Exception {
  final String message;
  GuestJoinException(this.message);
  @override
  String toString() => message;
}

class GuestJoinResult {
  final String choirId;
  final String sessionId;
  final String? title;
  GuestJoinResult({required this.choirId, required this.sessionId, this.title});
}

class RehearsalRepository extends BaseRepository {
  final Uuid _uuid = const Uuid();

  // Confirmed project ID: kwayapro-app (see PHASE_2B_REPORT.md — this
  // previously disagreed with functions/src/index.ts's MTN webhook
  // callbackUrl, which hardcoded "kwayapro-production"; that's now fixed to
  // match).
  //
  // URL format verified live in Phase 3c: this legacy cloudfunctions.net
  // address returns the function's own real response (not a 404), same as
  // its Cloud Run-native *.run.app equivalent — both route to the same
  // deployed 2nd-gen function. See PHASE_3C_REPORT.md.
  static const _guestJoinFunctionUrl =
      'https://us-central1-kwayapro-app.cloudfunctions.net/joinAsGuestDirector';

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

  // NOTE (Phase 2b): the previous client-side validateGuestToken() +
  // getSessionByToken() implementation queried rehearsal_sessions by
  // guestToken directly from Firestore. That was never actually compatible
  // with choir-scoped security rules: rehearsal_sessions read access requires
  // isTenantMember(choirId), but a guest, by definition, isn't a member yet —
  // so this query would already have failed with permission-denied under any
  // reasonable choir-scoped rules, Phase 2 or not. Both methods have been
  // replaced by joinAsGuestDirector() below, which performs the equivalent
  // lookup server-side (Cloud Function + Admin SDK, which bypasses rules)
  // and also enforces guestTokenExpiry at the moment of grant.
  Future<GuestJoinResult> joinAsGuestDirector(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw GuestJoinException('You must be signed in to accept this invite.');
    }
    final idToken = await user.getIdToken();
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse(_guestJoinFunctionUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (_) {
      throw GuestJoinException('Could not reach the server. Check your connection and try again.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw GuestJoinException('Something went wrong. Please try again.');
    }

    if (response.statusCode != 200) {
      throw GuestJoinException(body['error'] as String? ?? 'This invite link could not be used.');
    }

    return GuestJoinResult(
      choirId: body['choirId'] as String,
      sessionId: body['sessionId'] as String,
      title: body['title'] as String?,
    );
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
    final docId = AttendanceIds.compositeId(sessionId, userId);
    await db.collection('attendance').doc(docId).set({
      'sessionId': sessionId,
      'userId': userId,
      'rsvp': status.name,
      'attended': false,
    }, SetOptions(merge: true));
  }

  Stream<Attendance?> watchMyRSVP(String sessionId, String userId) {
    final docId = AttendanceIds.compositeId(sessionId, userId);
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
            final rsvp = RSVPStatus.values.asNameMap()[doc.data()['rsvp']] ?? RSVPStatus.pending;
            counts[rsvp] = (counts[rsvp] ?? 0) + 1;
          }
          
          return counts;
        });
  }
}