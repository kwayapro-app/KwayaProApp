import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/repositories/base_repository.dart';
import '../domain/models/app_user.dart';

class UserRepository extends BaseRepository {
  UserRepository({super.firestore});

  CollectionReference<AppUser> get _usersRef =>
      db.collection('users').withConverter<AppUser>(
            fromFirestore: (snapshot, _) => AppUser.fromJson(snapshot.data()!),
            toFirestore: (user, _) => user.toJson(),
          );

  Future<AppUser?> getUser(String userId) async {
    final doc = await _usersRef.doc(userId).get();
    return doc.data();
  }

  Future<void> createUser(AppUser user) async {
    await _usersRef.doc(user.userId).set(user);
  }

  Future<void> updateUser(String userId, Map<String, dynamic> fields) async {
    await db.collection('users').doc(userId).update(fields);
  }

  Stream<AppUser?> watchUser(String userId) {
    return _usersRef.doc(userId).snapshots().map((snapshot) => snapshot.data());
  }
}
