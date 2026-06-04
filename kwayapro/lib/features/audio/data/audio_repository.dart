import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/repositories/base_repository.dart';

class AudioRepository extends BaseRepository {
  final FirebaseStorage _storage;

  AudioRepository({FirebaseStorage? storage, super.firestore})
      : _storage = storage ?? FirebaseStorage.instance;

  // Path A: External file upload (file_picker → Firebase Storage)
  Future<String> uploadExternalAudio({
    required String choirId,
    required String songId,
    required String sectionId,
    required VoicePart voicePart,
    required String localFilePath,
    required void Function(double progress) onProgress,
  }) async {
    final file = File(localFilePath);
    final extension = localFilePath.split('.').last;
    final path = 'audio/$choirId/$songId/$sectionId/${voicePart.name}.$extension';
    
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(file);
    
    uploadTask.snapshotEvents.listen((taskSnapshot) {
      final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
      onProgress(progress.clamp(0.0, 1.0));
    });
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Path B: In-app recording upload (record package → Firebase Storage)
  Future<String> uploadRecordedAudio({
    required String choirId,
    required String songId,
    required String sectionId,
    required VoicePart voicePart,
    required String recordingPath,
    required void Function(double progress) onProgress,
  }) async {
    final file = File(recordingPath);
    final path = 'audio/$choirId/$songId/$sectionId/${voicePart.name}.m4a';
    
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentType: 'audio/m4a',
      ),
    );
    
    uploadTask.snapshotEvents.listen((taskSnapshot) {
      final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
      onProgress(progress.clamp(0.0, 1.0));
    });
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Delete audio file from storage
  Future<void> deleteAudioFile(String audioUrl) async {
    try {
      final ref = _storage.refFromURL(audioUrl);
      await ref.delete();
    } catch (e) {
      // File might not exist, ignore
    }
  }

  // Listen event logging
  Future<void> logListenEvent({
    required String userId,
    required String audioPartId,
    required String songId,
    required String sectionId,
    required int durationPlayedSeconds,
    required bool completed,
  }) async {
    await db.collection('listen_events').add({
      'userId': userId,
      'audioPartId': audioPartId,
      'songId': songId,
      'sectionId': sectionId,
      'listenedAt': Timestamp.now(),
      'durationPlayedSeconds': durationPlayedSeconds,
      'completed': completed,
    });
  }

  // Get listen events for a user
  Stream<List<Map<String, dynamic>>> watchListenEvents(String userId) {
    return db
        .collection('listen_events')
        .where('userId', isEqualTo: userId)
        .orderBy('listenedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Get listen events for a choir (for Pro analytics)
  Stream<List<Map<String, dynamic>>> watchChoirListenEvents(String choirId) {
    return db
        .collection('listen_events')
        .snapshots()
        .asyncMap((snapshot) async {
          final events = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final songDoc = await db.collection('songs').doc(doc.data()['songId'] as String).get();
            if (songDoc.exists && songDoc.data()?['choirId'] == choirId) {
              events.add(doc.data());
            }
          }
          return events;
        });
  }
}