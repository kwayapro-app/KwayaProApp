import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/app_logger.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/repositories/base_repository.dart';
import '../domain/models/song.dart';
import '../domain/models/song_section.dart';
import '../domain/models/audio_part.dart';
import '../../choir/domain/models/choir.dart';

class SongLimitExceededException implements Exception {
  const SongLimitExceededException();
  @override
  String toString() => 'This choir has reached the Free plan song limit. Upgrade to Pro to add more.';
}

class SongRepository extends BaseRepository {
  SongRepository({super.firestore});

  // Phase 4 Fix 1: a single malformed document (e.g. missing a required
  // field on a legacy doc) used to throw inside fromJson and take down the
  // entire stream for every listener. Models now default missing fields
  // instead of hard-casting, but a doc could still fail in a way we haven't
  // anticipated (e.g. a stale/renamed enum value via .byName) — this wraps
  // each doc's parse so one bad document is skipped and logged rather than
  // breaking the stream for every choir member watching it.
  List<T> _parseSkippingBadDocs<T>(
    Iterable<QueryDocumentSnapshot<Object?>> docs,
    T Function(Map<String, dynamic>) fromJson,
    String collectionName,
  ) {
    final result = <T>[];
    for (final doc in docs) {
      try {
        result.add(fromJson(doc.data() as Map<String, dynamic>));
      } catch (e, stackTrace) {
        AppLogger.warning(
          'Skipping malformed $collectionName document ${doc.id}',
          tag: 'SongRepository',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return result;
  }

  // Songs
  //
  // Phase 4 Fix 3: previously the freemium limit check (isAtSongLimit, a
  // plain read) and the count increment (incrementSongCount, a separate
  // non-transactional write) were two independent steps — two concurrent
  // creates could both read songCount == 2, both decide they're under the
  // limit, and both write, landing at songCount == 4 on a free plan.
  // firestore.rules' isUnderSongLimit check (Phase 3 Fix 5) closes the
  // "bypass via a direct write that skips the app entirely" hole, but not
  // this race between two legitimate, app-driven concurrent creates: both
  // requests could still pass the rule's check against the same
  // pre-increment songCount before either commit lands.
  //
  // Wrapping the read-check-write in a single Firestore transaction closes
  // this: runTransaction reads choirs/{choirId}.songCount and the song
  // create + count increment all in one atomic commit. If two transactions
  // race, Firestore's optimistic-concurrency contention check detects that
  // the second transaction's read of choirs/{choirId} went stale the moment
  // the first transaction's commit lands, and automatically retries the
  // second transaction's callback from scratch — which re-reads the
  // now-incremented songCount and correctly throws
  // SongLimitExceededException on the retry instead of proceeding. This is
  // compatible with the Fix 5 rule, not in conflict with it: the rule's
  // plain get() (not getAfter()) reads the same last-committed
  // choirs/{choirId} state this transaction's own read sees, so both layers
  // agree at commit time — see PHASE_4_REPORT.md for the full trace.
  Future<Song> createSong(Song song) async {
    await db.runTransaction((transaction) async {
      final choirRef = db.collection('choirs').doc(song.choirId);
      final choirSnap = await transaction.get(choirRef);
      if (!choirSnap.exists) {
        throw Exception('Choir not found');
      }
      final choir = Choir.fromJson(choirSnap.data()!);
      if (choir.plan == ChoirPlan.free && choir.songCount >= 3) {
        throw const SongLimitExceededException();
      }

      final songRef = db.collection('songs').doc(song.songId);
      transaction.set(songRef, song.toJson());
      transaction.update(choirRef, {'songCount': FieldValue.increment(1)});
    });
    return song;
  }

  Future<void> updateSong(String songId, Map<String, dynamic> fields) async {
    await db.collection('songs').doc(songId).update(fields);
  }

  Future<void> deleteSong(String songId) async {
    final songDoc = await db.collection('songs').doc(songId).get();
    final choirId = songDoc.data()?['choirId'] as String?;
    
    // Delete all audio parts for this song's sections
    final sections = await db
        .collection('song_sections')
        .where('songId', isEqualTo: songId)
        .get();
    
    for (final section in sections.docs) {
      final audioParts = await db
          .collection('audio_parts')
          .where('sectionId', isEqualTo: section.id)
          .get();
      
      for (final ap in audioParts.docs) {
        await ap.reference.delete();
      }
      await section.reference.delete();
    }
    
    await db.collection('songs').doc(songId).delete();
    
    if (choirId != null) {
      await decrementSongCount(choirId);
    }
  }

  Stream<List<Song>> watchSongs(String choirId) {
    return db
        .collection('songs')
        .where('choirId', isEqualTo: choirId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Song.fromJson(doc.data())).toList());
  }

  Stream<List<Song>> watchSongsByVoicePart(String choirId, VoicePart part) {
    return db
        .collection('songs')
        .where('choirId', isEqualTo: choirId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((songSnap) async {
          final songs = <Song>[];
          for (final doc in songSnap.docs) {
            final song = Song.fromJson(doc.data());
            final hasPart = await _songHasVoicePart(song.songId, part);
            if (hasPart) {
              songs.add(song);
            }
          }
          return songs;
        });
  }

  Future<bool> _songHasVoicePart(String songId, VoicePart part) async {
    final sections = await db
        .collection('song_sections')
        .where('songId', isEqualTo: songId)
        .get();
    
    for (final section in sections.docs) {
      final audioParts = await db
          .collection('audio_parts')
          .where('sectionId', isEqualTo: section.id)
          .where('voicePart', isEqualTo: part.name)
          .get();
      
      if (audioParts.docs.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  // Sections
  Future<SongSection> createSection(SongSection section) async {
    final docRef = db.collection('song_sections').doc(section.sectionId);
    await docRef.set(section.toJson());
    return section;
  }

  Future<void> updateSection(String sectionId, Map<String, dynamic> fields) async {
    await db.collection('song_sections').doc(sectionId).update(fields);
  }

  Stream<List<SongSection>> watchSections(String songId) {
    return db
        .collection('song_sections')
        .where('songId', isEqualTo: songId)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => _parseSkippingBadDocs(snapshot.docs, SongSection.fromJson, 'song_sections'));
  }

  // Audio Parts
  Future<AudioPart> createAudioPart(AudioPart part) async {
    final docRef = db.collection('audio_parts').doc(part.audioPartId);
    await docRef.set(part.toJson());
    return part;
  }

  // CHORISTER AUDIT FIX: had no UI call site at all (dead code), so this
  // wasn't a live bug, but it also never reverted a section's status back
  // to comingSoon after its last audio_part was removed — confirmAudioUpload
  // (functions/src/index.ts) is the only place status flips to 'ready', and
  // nothing flipped it back, so a section with zero remaining audio would
  // have falsely shown "Ready" once this ever gets wired to a UI.
  Future<void> deleteAudioPart(String audioPartId) async {
    final partDoc = await db.collection('audio_parts').doc(audioPartId).get();
    final sectionId = partDoc.data()?['sectionId'] as String?;

    await db.collection('audio_parts').doc(audioPartId).delete();

    if (sectionId == null) return;
    final remaining = await db
        .collection('audio_parts')
        .where('sectionId', isEqualTo: sectionId)
        .limit(1)
        .get();
    if (remaining.docs.isEmpty) {
      await db.collection('song_sections').doc(sectionId).update({
        'status': SectionStatus.comingSoon.name,
      });
    }
  }

  // CHORISTER AUDIT FIX: confirmed live that a songId-only filter here got
  // this query rejected outright for a plain chorister — same class of bug
  // as attendance's sessionId-only query earlier in this audit:
  // firestore.rules' audio_parts read rule can only prove itself via
  // resource.data.choirId, so the query's own filter needs to include it.
  Stream<List<AudioPart>> watchAudioParts(String songId, String choirId) {
    return db
        .collection('audio_parts')
        .where('songId', isEqualTo: songId)
        .where('choirId', isEqualTo: choirId)
        .snapshots()
        .map((snapshot) => _parseSkippingBadDocs(snapshot.docs, AudioPart.fromJson, 'audio_parts'));
  }

  // Phase 5 Fix 5: previously listened to the ENTIRE audio_parts collection
  // platform-wide with no .where() at all, then did an N+1 per-doc read of
  // each part's parent song to filter by choirId client-side — cost scaled
  // with total platform-wide audio parts, not this choir's data, and every
  // unrelated choir's upload re-triggered the fan-out for every listener
  // (flagged as the highest-risk finding in the original audit). AudioPart
  // documents already store choirId directly, so this can be scoped at the
  // query level with no per-doc lookups at all. (Currently unused by any
  // screen, but fixed now rather than left as a landmine for whoever wires
  // up voice-part filtering next.)
  Stream<List<AudioPart>> watchAudioPartsByVoicePart(String choirId, VoicePart voicePartFilter) {
    return db
        .collection('audio_parts')
        .where('choirId', isEqualTo: choirId)
        .where('voicePart', isEqualTo: voicePartFilter.name)
        .snapshots()
        .map((snapshot) => _parseSkippingBadDocs(snapshot.docs, AudioPart.fromJson, 'audio_parts'));
  }

  // Freemium enforcement
  Future<bool> isAtSongLimit(String choirId) async {
    final choirDoc = await db.collection('choirs').doc(choirId).get();
    if (!choirDoc.exists) return false;
    
    final choir = Choir.fromJson(choirDoc.data()!);
    return choir.plan == ChoirPlan.free && choir.songCount >= 3;
  }

  Future<void> incrementSongCount(String choirId) async {
    await db.collection('choirs').doc(choirId).update({
      'songCount': FieldValue.increment(1),
    });
  }

  Future<void> decrementSongCount(String choirId) async {
    await db.collection('choirs').doc(choirId).update({
      'songCount': FieldValue.increment(-1),
    });
  }

  // Get audio parts for a specific section
  // Same malformed-doc risk as the streaming methods above (not explicitly
  // named in the Phase 4 fix list, but the same fromJson call over
  // unbounded Firestore data) — applying the same defensive handling here
  // too rather than leaving this one call site inconsistent.
  Future<List<AudioPart>> getAudioPartsForSection(String sectionId) async {
    final snapshot = await db
        .collection('audio_parts')
        .where('sectionId', isEqualTo: sectionId)
        .get();
    return _parseSkippingBadDocs(snapshot.docs, AudioPart.fromJson, 'audio_parts');
  }
}