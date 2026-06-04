import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/repositories/base_repository.dart';
import '../domain/models/choir.dart';
import '../domain/models/choir_membership.dart';
import '../../../core/utils/invite_code_generator.dart';

class ChoirRepository extends BaseRepository {
  ChoirRepository({super.firestore});

  CollectionReference<Choir> get _choirsRef =>
      db.collection('choirs').withConverter<Choir>(
            fromFirestore: (snapshot, _) => Choir.fromJson(snapshot.data()!),
            toFirestore: (choir, _) => choir.toJson(),
          );

  CollectionReference<ChoirMembership> get _membershipsRef =>
      db.collection('choir_memberships').withConverter<ChoirMembership>(
            fromFirestore: (snapshot, _) => ChoirMembership.fromJson(snapshot.data()!),
            toFirestore: (membership, _) => membership.toJson(),
          );

  // static utility
  static String generateInviteCode() => InviteCodeGenerator.generate();

  Future<Choir> createChoir(Choir choir) async {
    await _choirsRef.doc(choir.choirId).set(choir);
    return choir;
  }

  Future<Choir?> getChoirByInviteCode(String code) async {
    final query = await _choirsRef.where('inviteCode', isEqualTo: code).limit(1).get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data();
  }

  Future<void> updateChoir(String choirId, Map<String, dynamic> fields) async {
    await db.collection('choirs').doc(choirId).update(fields);
  }

  Stream<Choir?> watchChoir(String choirId) {
    return _choirsRef.doc(choirId).snapshots().map((snapshot) => snapshot.data());
  }

  // Membership methods
  Future<void> createMembership(ChoirMembership membership) async {
    final docId = '${membership.choirId}_${membership.userId}';
    await _membershipsRef.doc(docId).set(membership);
  }

  Future<ChoirMembership?> getMembership(String choirId, String userId) async {
    final docId = '${choirId}_$userId';
    final doc = await _membershipsRef.doc(docId).get();
    return doc.data();
  }

  Stream<ChoirMembership?> watchMembership(String choirId, String userId) async* {
    final docId = '${choirId}_$userId';
    await for (final snapshot in _membershipsRef.doc(docId).snapshots()) {
      if (!snapshot.exists) {
        yield null;
        continue;
      }
      final membership = snapshot.data()!;
      try {
        final userDoc = await db.collection('users').doc(userId).get();
        final name = userDoc.exists ? (userDoc.data()?['name'] as String? ?? 'Unknown') : 'Unknown';
        yield membership.copyWith(name: name);
      } catch (_) {
        yield membership.copyWith(name: 'Unknown');
      }
    }
  }

  Stream<List<ChoirMembership>> watchMembers(String choirId) {
    return _membershipsRef.where('choirId', isEqualTo: choirId).snapshots().asyncMap((membershipSnap) async {
      final memberships = membershipSnap.docs.map((doc) => doc.data()).toList();
      
      final List<ChoirMembership> result = [];
      for (final m in memberships) {
        try {
          final userDoc = await db.collection('users').doc(m.userId).get();
          final name = userDoc.exists ? (userDoc.data()?['name'] as String? ?? 'Unknown') : 'Unknown';
          result.add(m.copyWith(name: name));
        } catch (_) {
          result.add(m.copyWith(name: 'Unknown'));
        }
      }
      
      return result;
    });
  }

  Stream<List<ChoirMembership>> watchUserMemberships(String userId) {
    return _membershipsRef.where('userId', isEqualTo: userId).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  Future<void> updateMembership(String choirId, String userId, Map<String, dynamic> fields) async {
    final docId = '${choirId}_$userId';
    await db.collection('choir_memberships').doc(docId).update(fields);
  }

  Future<void> deleteMembership(String choirId, String userId) async {
    final docId = '${choirId}_$userId';
    await _membershipsRef.doc(docId).delete();
  }

  // Alias for findByInviteCode (used by deep link join flow)
  Future<Choir?> findByInviteCode(String code) => getChoirByInviteCode(code);

  // Join choir with voice part selection
  Future<void> joinChoir(String choirId, String userId, VoicePart voicePart) async {
    final membership = ChoirMembership(
      choirId: choirId,
      userId: userId,
      name: 'Member',
      role: MemberRole.chorister,
      defaultVoicePart: voicePart,
      permissions: [],
      joinedAt: DateTime.now(),
    );
    await createMembership(membership);
  }

  // Add guest director for a session
  Future<void> addGuestDirector(String choirId, String userId, String sessionId) async {
    final membership = ChoirMembership(
      choirId: choirId,
      userId: userId,
      name: 'Guest Director',
      role: MemberRole.director,
      defaultVoicePart: VoicePart.S,
      permissions: ['audio_uploader', 'attendance_manager', 'song_program_planner'],
      joinedAt: DateTime.now(),
    );
    await createMembership(membership);
  }
}
