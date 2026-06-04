import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/enums.dart';
import '../domain/models/attendance.dart';

class AttendanceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Attendance>> watchSessionAttendance(String sessionId) {
    return _db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Attendance.fromJson(d.data())).toList());
  }

  Stream<Attendance?> watchMemberAttendance(String sessionId, String userId) {
    final docId = '${sessionId}_$userId';
    return _db.collection('attendance').doc(docId).snapshots().map(
          (snap) => snap.exists ? Attendance.fromJson(snap.data()!) : null,
        );
  }

  Future<void> markAttendance({
    required String sessionId,
    required String userId,
    required bool attended,
  }) async {
    final docId = '${sessionId}_$userId';
    final doc = _db.collection('attendance').doc(docId);
    
    final existing = await doc.get();
    final existingData = existing.exists ? existing.data()! : <String, dynamic>{};
    
    await doc.set({
      ...existingData,
      'sessionId': sessionId,
      'userId': userId,
      'attended': attended,
      'rsvp': existingData['rsvp'] ?? 'coming',
    }, SetOptions(merge: true));
  }

  Future<void> batchMarkRSVPAttended(String sessionId) async {
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
    required VoicePart? voicePart,
  }) async {
    final docId = '${sessionId}_$userId';
    final doc = _db.collection('attendance').doc(docId);
    
    if (voicePart == null) {
      await doc.update({'voicePartOverride': FieldValue.delete()});
    } else {
      await doc.set({
        'sessionId': sessionId,
        'userId': userId,
        'voicePartOverride': voicePart.name,
      }, SetOptions(merge: true));
    }
  }

  Stream<List<Attendance>> watchMemberHistory(String userId, String choirId) {
    return _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('sessionId', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Attendance.fromJson(d.data())).toList());
  }

  Future<double> getMemberAttendanceRate(String userId, String choirId) async {
    final snapshot = await _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
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