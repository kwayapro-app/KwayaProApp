import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwayapro/features/songs/data/song_repository.dart';
import 'package:kwayapro/features/songs/domain/models/song.dart';

void main() {
  // Phase 4 Fix 1 (repository-level): confirms a malformed document doesn't
  // take down watchSections/watchAudioParts for every other listener — the
  // bad doc is skipped, the stream keeps emitting the good ones.
  group('SongRepository malformed-doc handling (Phase 4 Fix 1)', () {
    test('watchSections skips a doc with a stale/invalid enum value and keeps the rest', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = SongRepository(firestore: firestore);

      await firestore.collection('song_sections').doc('good1').set({
        'sectionId': 'good1',
        'songId': 'song1',
        'choirId': 'choir1',
        'title': 'Verse 1',
        'order': 0,
        'status': 'ready',
      });
      // Simulates a legacy/malformed doc: 'status' holds a value that no
      // longer exists in the SectionStatus enum, so SectionStatus.values
      // .byName() throws even though the model's null-safety fix (Fix 1)
      // handles a MISSING field fine — this covers the "we haven't
      // anticipated" case the try/catch in the repository is there for.
      await firestore.collection('song_sections').doc('bad1').set({
        'sectionId': 'bad1',
        'songId': 'song1',
        'choirId': 'choir1',
        'title': 'Corrupted',
        'order': 1,
        'status': 'no_longer_a_real_status',
      });
      await firestore.collection('song_sections').doc('good2').set({
        'sectionId': 'good2',
        'songId': 'song1',
        'choirId': 'choir1',
        'title': 'Chorus',
        'order': 2,
        'status': 'comingSoon',
      });

      final sections = await repo.watchSections('song1').first;

      expect(sections.length, 2);
      expect(sections.map((s) => s.sectionId), containsAll(['good1', 'good2']));
      expect(sections.map((s) => s.sectionId), isNot(contains('bad1')));
    });

    test('watchAudioParts skips a doc with a stale/invalid enum value and keeps the rest', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = SongRepository(firestore: firestore);

      await firestore.collection('audio_parts').doc('good1').set({
        'audioPartId': 'good1',
        'sectionId': 'sec1',
        'songId': 'song1',
        'choirId': 'choir1',
        'voicePart': 'S',
        'audioUrl': 'https://example.com/s.m4a',
        'durationSeconds': 60,
        'uploadedBy': 'user1',
        'createdAt': Timestamp.now(),
      });
      await firestore.collection('audio_parts').doc('bad1').set({
        'audioPartId': 'bad1',
        'sectionId': 'sec1',
        'songId': 'song1',
        'choirId': 'choir1',
        'voicePart': 'NOT_A_REAL_VOICE_PART',
        'audioUrl': 'https://example.com/bad.m4a',
        'durationSeconds': 60,
        'uploadedBy': 'user1',
        'createdAt': Timestamp.now(),
      });

      final parts = await repo.watchAudioParts('song1').first;

      expect(parts.length, 1);
      expect(parts.single.audioPartId, 'good1');
    });
  });

  // Phase 4 Fix 3: two concurrent creates at songCount == 2 for a free-plan
  // choir must not both succeed — see PHASE_4_REPORT.md for why the real
  // multi-transaction contention/retry behavior this depends on can't be
  // faithfully exercised via fake_cloud_firestore (its runTransaction is a
  // single-shot pass-through, not a real optimistic-concurrency engine) —
  // that part is verified separately against the real Firestore emulator.
  // This test instead confirms the single-transaction logic itself: the
  // limit check and the write happen atomically, and a create that's
  // already over the limit is correctly rejected before any write occurs.
  group('SongRepository.createSong transactional limit check (Phase 4 Fix 3)', () {
    test('rejects a create when songCount is already at the free-plan cap', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = SongRepository(firestore: firestore);

      await firestore.collection('choirs').doc('choir1').set({
        'choirId': 'choir1',
        'name': 'Test Choir',
        'churchName': 'Test Church',
        'leaderId': 'leader1',
        'inviteCode': 'ABC123',
        'plan': 'free',
        'songCount': 3,
        'createdAt': Timestamp.now(),
      });

      await expectLater(
        repo.createSong(_song('song1', 'choir1')),
        throwsA(isA<SongLimitExceededException>()),
      );

      final songsSnap = await firestore.collection('songs').get();
      expect(songsSnap.docs, isEmpty);
      final choirSnap = await firestore.collection('choirs').doc('choir1').get();
      expect(choirSnap.data()!['songCount'], 3);
    });

    test('allows a create under the cap and atomically increments songCount', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = SongRepository(firestore: firestore);

      await firestore.collection('choirs').doc('choir1').set({
        'choirId': 'choir1',
        'name': 'Test Choir',
        'churchName': 'Test Church',
        'leaderId': 'leader1',
        'inviteCode': 'ABC123',
        'plan': 'free',
        'songCount': 2,
        'createdAt': Timestamp.now(),
      });

      await repo.createSong(_song('song1', 'choir1'));

      final songsSnap = await firestore.collection('songs').get();
      expect(songsSnap.docs.length, 1);
      final choirSnap = await firestore.collection('choirs').doc('choir1').get();
      expect(choirSnap.data()!['songCount'], 3);
    });

    test('pro-plan choirs are never capped regardless of songCount', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = SongRepository(firestore: firestore);

      await firestore.collection('choirs').doc('choir1').set({
        'choirId': 'choir1',
        'name': 'Test Choir',
        'churchName': 'Test Church',
        'leaderId': 'leader1',
        'inviteCode': 'ABC123',
        'plan': 'pro',
        'songCount': 12,
        'createdAt': Timestamp.now(),
      });

      await repo.createSong(_song('song1', 'choir1'));

      final choirSnap = await firestore.collection('choirs').doc('choir1').get();
      expect(choirSnap.data()!['songCount'], 13);
    });
  });
}

Song _song(String songId, String choirId) => Song(
      songId: songId,
      choirId: choirId,
      title: 'Test Song',
      uploadedBy: 'user1',
      createdAt: DateTime.now(),
    );
