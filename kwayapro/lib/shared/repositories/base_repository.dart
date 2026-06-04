import 'package:cloud_firestore/cloud_firestore.dart';

abstract class BaseRepository {
  final FirebaseFirestore db;
  BaseRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;
}
