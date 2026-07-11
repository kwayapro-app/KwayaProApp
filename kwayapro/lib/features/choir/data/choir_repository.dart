import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../shared/models/enums.dart';
import '../../../shared/repositories/base_repository.dart';
import '../domain/models/choir.dart';
import '../domain/models/choir_membership.dart';
import '../../../core/utils/invite_code_generator.dart';

/// Minimal projection returned by the lookupChoirByInviteCode Cloud
/// Function — deliberately narrower than [Choir] (see ChoirRepository
/// .getChoirByInviteCode for why this can't be a direct Firestore query).
class ChoirInviteLookup {
  final String choirId;
  final String name;
  final String churchName;
  const ChoirInviteLookup({
    required this.choirId,
    required this.name,
    required this.churchName,
  });
}

class ChoirRepository extends BaseRepository {
  ChoirRepository({super.firestore});

  // Same project/URL-format rationale as RehearsalRepository's
  // _guestJoinFunctionUrl (see PHASE_2B_REPORT.md / PHASE_3C_REPORT.md).
  static const _lookupChoirFunctionUrl =
      'https://us-central1-kwayapro-app.cloudfunctions.net/lookupChoirByInviteCode';
  static const _checkInviteCodeFunctionUrl =
      'https://us-central1-kwayapro-app.cloudfunctions.net/checkInviteCodeAvailable';

  Future<String> _requireIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You must be signed in.');
    final token = await user.getIdToken();
    if (token == null) throw Exception('Could not verify your session. Please sign in again.');
    return token;
  }

  /// Surfaces the Cloud Function's own {error: "..."} message when present
  /// (e.g. the 429 rate-limit response) instead of a generic fallback.
  String _serverErrorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['error'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {
      // Response body wasn't JSON — fall through to the generic message.
    }
    return fallback;
  }

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

  // Phase 4 Fix 6: invite codes were previously generated with no
  // uniqueness check at all — InviteCodeGenerator picks from 33^6 (~1.3
  // billion) combinations, so a collision is rare, but rare isn't the same
  // as impossible, and an undetected collision would let a user join the
  // wrong choir. A full transaction isn't warranted here (low-stakes, not
  // security-critical — worst case on a race between this check and the
  // eventual write is the same rare collision this already tolerated
  // before), so this is a plain post-generation existence check with retry
  // rather than a transactional reservation.
  //
  // The existence check itself runs server-side (checkInviteCodeAvailable
  // Cloud Function) rather than as a client Firestore query — see
  // getChoirByInviteCode below for why a `where('inviteCode', ...)` query
  // can't be safely authorized by Firestore rules for a non-tenant caller.
  Future<String> generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = InviteCodeGenerator.generate();
      if (await _isInviteCodeAvailable(code)) return code;
    }
    throw Exception('Could not generate a unique invite code. Please try again.');
  }

  Future<bool> _isInviteCodeAvailable(String code) async {
    final idToken = await _requireIdToken();
    final response = await http.post(
      Uri.parse(_checkInviteCodeFunctionUrl),
      headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode != 200) {
      throw Exception(_serverErrorMessage(
        response,
        'Could not check invite code availability. Please try again.',
      ));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['available'] as bool;
  }

  Future<Choir> createChoir(Choir choir) async {
    await _choirsRef.doc(choir.choirId).set(choir);
    return choir;
  }

  // Runs server-side (lookupChoirByInviteCode Cloud Function, Admin SDK)
  // rather than a client `where('inviteCode', isEqualTo: ...)` Firestore
  // query. Firestore security rules can only authorize a query when the
  // rule is expressible purely in terms of resource.data + request.auth —
  // they can't check "the caller already knows this specific code" — so the
  // only rule that made this query succeed directly was
  // `allow read: if isAuthenticated()`, which really means "any signed-in
  // user can list the entire choirs collection" (every invite code, for
  // every choir, not just the one being looked up). That was caught on
  // review before shipping. This Cloud Function returns only the minimal
  // {choirId, name, churchName} the join UI actually needs, while
  // firestore.rules stays isTenantMember(choirId)-only.
  Future<ChoirInviteLookup?> getChoirByInviteCode(String code) async {
    final idToken = await _requireIdToken();
    final response = await http.post(
      Uri.parse(_lookupChoirFunctionUrl),
      headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(_serverErrorMessage(
        response,
        'Could not look up that invite code. Please try again.',
      ));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ChoirInviteLookup(
      choirId: body['choirId'] as String,
      name: body['name'] as String,
      churchName: body['churchName'] as String,
    );
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

  // Phase 2b fix: name is now denormalized onto the membership doc itself at
  // creation time (see joinChoir below, onboarding_screen.dart, and the
  // joinAsGuestDirector Cloud Function), so these no longer need a live
  // cross-read of users/{userId} for other members — which firestore.rules
  // now correctly blocks for anyone but the profile's own owner anyway.
  Stream<ChoirMembership?> watchMembership(String choirId, String userId) {
    final docId = '${choirId}_$userId';
    return _membershipsRef.doc(docId).snapshots().map((snapshot) => snapshot.data());
  }

  Stream<List<ChoirMembership>> watchMembers(String choirId) {
    return _membershipsRef.where('choirId', isEqualTo: choirId).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
        );
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
  Future<ChoirInviteLookup?> findByInviteCode(String code) => getChoirByInviteCode(code);

  // Join choir with voice part selection
  Future<void> joinChoir(String choirId, String userId, VoicePart voicePart) async {
    // Self-read of the joiner's own user doc — always permitted under
    // firestore.rules' owner-only users/{userId} read rule, since userId
    // here is always the caller's own uid. Denormalizes the real display
    // name onto the membership doc instead of a generic placeholder (Phase
    // 2b Fix 2), so member lists don't depend on a live cross-user read.
    final userDoc = await db.collection('users').doc(userId).get();
    final displayName = (userDoc.data()?['name'] as String?)?.trim();
    final membership = ChoirMembership(
      choirId: choirId,
      userId: userId,
      name: (displayName != null && displayName.isNotEmpty) ? displayName : 'Member',
      role: MemberRole.chorister,
      defaultVoicePart: voicePart,
      permissions: [],
      joinedAt: DateTime.now(),
    );
    await createMembership(membership);
  }
}
