import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/enums.dart';
import '../domain/models/score_attachment.dart';

class ScoreRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<ScoreAttachment> uploadScore({
    required String songId,
    required String choirId,
    required String filePath,
    required ScoreType type,
    required String label,
    required String uploadedBy,
    void Function(double)? onProgress,
  }) async {
    final scoreId = const Uuid().v4();
    final extension = filePath.split('.').last;
    final storagePath = 'scores/$choirId/$songId/$scoreId.$extension';

    final storageRef = _storage.ref().child(storagePath);
    final file = File(filePath);

    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: type == ScoreType.pdf ? 'application/pdf' : 'image/jpeg'),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    final snapshot = await uploadTask;
    final fileUrl = await snapshot.ref.getDownloadURL();

    final score = ScoreAttachment(
      scoreId: scoreId,
      songId: songId,
      choirId: choirId,
      type: type,
      fileUrl: fileUrl,
      label: label,
      uploadedBy: uploadedBy,
      createdAt: DateTime.now(),
    );

    await _db.collection('score_attachments').doc(scoreId).set(score.toJson());
    return score;
  }

  Future<void> deleteScore(String scoreId) async {
    final doc = await _db.collection('score_attachments').doc(scoreId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final fileUrl = data['fileUrl'] as String;

    try {
      final storageRef = _storage.refFromURL(fileUrl);
      await storageRef.delete();
    } catch (_) {}

    await _db.collection('score_attachments').doc(scoreId).delete();
  }

  Stream<List<ScoreAttachment>> watchScores(String songId) {
    return _db
        .collection('score_attachments')
        .where('songId', isEqualTo: songId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ScoreAttachment.fromJson(d.data())).toList());
  }
}