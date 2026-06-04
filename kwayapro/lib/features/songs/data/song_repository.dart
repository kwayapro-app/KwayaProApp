import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/repositories/base_repository.dart';
import '../domain/models/song.dart';
import '../domain/models/song_section.dart';
import '../domain/models/audio_part.dart';
import '../../choir/domain/models/choir.dart';

class SongRepository extends BaseRepository {
  SongRepository({super.firestore});

  // Songs
  Future<Song> createSong(Song song) async {
    final docRef = db.collection('songs').doc(song.songId);
    await docRef.set(song.toJson());
    await incrementSongCount(song.choirId);
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
        .map((snapshot) => snapshot.docs.map((doc) => SongSection.fromJson(doc.data())).toList());
  }

  // Audio Parts
  Future<AudioPart> createAudioPart(AudioPart part) async {
    final docRef = db.collection('audio_parts').doc(part.audioPartId);
    await docRef.set(part.toJson());
    return part;
  }

  Future<void> deleteAudioPart(String audioPartId) async {
    await db.collection('audio_parts').doc(audioPartId).delete();
  }

  Stream<List<AudioPart>> watchAudioParts(String songId) {
    return db
        .collection('audio_parts')
        .where('songId', isEqualTo: songId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AudioPart.fromJson(doc.data())).toList());
  }

  Stream<List<AudioPart>> watchAudioPartsByVoicePart(String choirId, VoicePart voicePartFilter) {
    return db
        .collection('audio_parts')
        .snapshots()
        .asyncMap((snapshot) async {
          final parts = <AudioPart>[];
          for (final doc in snapshot.docs) {
            final audioPart = AudioPart.fromJson(doc.data());
            // Check if this part belongs to the choir
            final song = await db.collection('songs').doc(audioPart.songId).get();
            if (song.exists && song.data()?['choirId'] == choirId && audioPart.voicePart == voicePartFilter) {
              parts.add(audioPart);
            }
          }
          return parts;
        });
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
  Future<List<AudioPart>> getAudioPartsForSection(String sectionId) async {
    final snapshot = await db
        .collection('audio_parts')
        .where('sectionId', isEqualTo: sectionId)
        .get();
    return snapshot.docs.map((doc) => AudioPart.fromJson(doc.data())).toList();
  }
}