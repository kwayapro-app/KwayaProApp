import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/song_program.dart';

class PlannerRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<SongProgram> createProgram(SongProgram program) async {
    final docRef = _db.collection('song_programs').doc(program.programId);
    await docRef.set(program.toJson());
    return program;
  }

  Future<void> updateProgram(String programId, Map<String, dynamic> fields) async {
    await _db.collection('song_programs').doc(programId).update(fields);
  }

  Future<void> deleteProgram(String programId) async {
    await _db.collection('song_programs').doc(programId).delete();
  }

  Stream<List<SongProgram>> watchPrograms(String choirId) {
    return _db
        .collection('song_programs')
        .where('choirId', isEqualTo: choirId)
        .orderBy('eventDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SongProgram.fromJson(d.data())).toList());
  }

  Future<void> publishProgram(String programId) async {
    await _db.collection('song_programs').doc(programId).update({
      'publishedAt': Timestamp.now(),
    });
  }

  Future<void> unpublishProgram(String programId) async {
    await _db.collection('song_programs').doc(programId).update({
      'publishedAt': FieldValue.delete(),
    });
  }

  Future<void> reorderSongs(String programId, List<String> orderedSongIds) async {
    await _db.collection('song_programs').doc(programId).update({
      'songIds': orderedSongIds,
    });
  }
}