import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/utils/attendance_ids.dart';
import '../../../shared/models/enums.dart';
import '../domain/models/attendance.dart';

class AttendanceRepository {
  final FirebaseFirestore _db;

  AttendanceRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // CHORISTER AUDIT FIX: same fix as RehearsalRepository.watchRSVPCounts —
  // firestore.rules' attendance list rule can only prove itself via
  // resource.data.choirId, so a sessionId-only filter got the whole query
  // rejected for a plain chorister even though every result would
  // individually satisfy the rule.
  Stream<List<Attendance>> watchSessionAttendance(String sessionId, String choirId) {
    return _db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .where('choirId', isEqualTo: choirId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Attendance.fromJson(d.data())).toList());
  }

  Stream<Attendance?> watchMemberAttendance(String sessionId, String userId) {
    final docId = AttendanceIds.compositeId(sessionId, userId);
    return _db.collection('attendance').doc(docId).snapshots().map(
          (snap) => snap.exists ? Attendance.fromJson(snap.data()!) : null,
        );
  }

  Future<void> markAttendance({
    required String sessionId,
    required String userId,
    required String choirId,
    required bool attended,
  }) async {
    final docId = AttendanceIds.compositeId(sessionId, userId);
    final targetDoc = _db.collection('attendance').doc(docId);

    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult.contains(ConnectivityResult.none)) {
      await targetDoc.set({
        'sessionId': sessionId,
        'userId': userId,
        'choirId': choirId,
        'attended': attended,
        'lastModifiedClientTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(targetDoc);

      if (!snapshot.exists) {
        transaction.set(targetDoc, {
          'sessionId': sessionId,
          'userId': userId,
          'choirId': choirId,
          'attended': attended,
          'rsvp': 'pending',
        });
      } else {
        transaction.update(targetDoc, {
          'attended': attended,
          'lastModifiedClientTimestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> batchMarkRSVPAttended(String sessionId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final snapshot = await _db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .where('rsvp', isEqualTo: 'coming')
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'attended': true});
    }
    await batch.commit();
  }

  Future<void> setVoicePartOverride({
    required String sessionId,
    required String userId,
    required String choirId,
    required VoicePart? voicePart,
  }) async {
    final docId = AttendanceIds.compositeId(sessionId, userId);

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final doc = _db.collection('attendance').doc(docId);

    if (voicePart == null) {
      await doc.update({'voicePartOverride': FieldValue.delete()});
    } else {
      await doc.set({
        'sessionId': sessionId,
        'userId': userId,
        'choirId': choirId,
        'voicePartOverride': voicePart.name,
      }, SetOptions(merge: true));
    }
  }

  // CHORISTER AUDIT FIX: choirId was accepted but never used — this query
  // returned a member's attendance across every choir they belong to, not
  // just the active one, blending "own attendance %" across choirs.
  Stream<List<Attendance>> watchMemberHistory(String userId, String choirId) {
    return _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('choirId', isEqualTo: choirId)
        .orderBy('sessionId', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Attendance.fromJson(d.data())).toList());
  }

  Future<double> getMemberAttendanceRate(String userId, String choirId) async {
    final snapshot = await _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('choirId', isEqualTo: choirId)
        .get();

    if (snapshot.docs.isEmpty) return 0.0;

    final attended = snapshot.docs.where((d) => d.data()['attended'] == true).length;
    return attended / snapshot.docs.length;
  }

  Future<double> getLastSessionAttendanceRate(String choirId) async {
    final sessionsSnapshot = await _db
        .collection('rehearsal_sessions')
        .where('choirId', isEqualTo: choirId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (sessionsSnapshot.docs.isEmpty) return 0.0;

    final lastSessionId = sessionsSnapshot.docs.first.id;
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('sessionId', isEqualTo: lastSessionId)
        .get();

    if (attendanceSnapshot.docs.isEmpty) return 0.0;

    final attended = attendanceSnapshot.docs.where((d) => d.data()['attended'] == true).length;
    return attended / attendanceSnapshot.docs.length;
  }
}
