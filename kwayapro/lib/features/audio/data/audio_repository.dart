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
  //
  // CHORISTER AUDIT FIX: this method previously had zero call sites — no
  // ListenEvent was ever created regardless of playback (now wired from
  // AudioPlayerNotifier.play()). It also never wrote `choirId`, even though
  // firestore.rules' create rule requires it (`isTenantMember(request
  // .resource.data.choirId)`) — a write missing that field would have been
  // rejected outright the moment this WAS wired up. Also added here so
  // watchChoirListenEvents' `where('choirId', ...)` query (below) has a
  // field to actually filter on.
  Future<void> logListenEvent({
    required String userId,
    required String choirId,
    required String audioPartId,
    required String songId,
    required String sectionId,
    required int durationPlayedSeconds,
    required bool completed,
  }) async {
    await db.collection('listen_events').add({
      'userId': userId,
      'choirId': choirId,
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
  //
  // Phase 5 Fix 5: previously listened to the ENTIRE listen_events
  // collection platform-wide with no .where() at all, then did an N+1
  // per-doc read of each event's parent song to filter by choirId
  // client-side — same unbounded-listener pattern as
  // SongRepository.watchAudioPartsByVoicePart, and the sibling method just
  // above (watchListenEvents) already shows listen_events documents carry
  // queryable fields directly, so this scopes the same way. Currently
  // unused by any screen, but fixed now rather than left as a landmine.
  Stream<List<Map<String, dynamic>>> watchChoirListenEvents(String choirId) {
    return db
        .collection('listen_events')
        .where('choirId', isEqualTo: choirId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}