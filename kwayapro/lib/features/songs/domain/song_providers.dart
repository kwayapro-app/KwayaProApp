import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/song_repository.dart';
import '../domain/models/song.dart';
import '../domain/models/song_section.dart';
import '../domain/models/audio_part.dart';
import '../../../shared/models/enums.dart';
import '../../choir/domain/choir_providers.dart';

// Repository provider
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository();
});

// Full song library for active choir
final songLibraryProvider = StreamProvider<List<Song>>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  return ref.watch(songRepositoryProvider).watchSongs(choirId);
});

// Songs filtered by voice part
final songsByVoicePartProvider = StreamProvider.family<List<Song>, VoicePart>((ref, part) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  return ref.watch(songRepositoryProvider).watchSongsByVoicePart(choirId, part);
});

// Sections for a specific song
final songSectionsProvider = StreamProvider.family<List<SongSection>, String>((ref, songId) {
  return ref.watch(songRepositoryProvider).watchSections(songId);
});

// Audio parts for a specific song
final audioPartsProvider = StreamProvider.family<List<AudioPart>, String>((ref, songId) {
  return ref.watch(songRepositoryProvider).watchAudioParts(songId);
});

// Audio parts for a section
final audioPartsForSectionProvider = FutureProvider.family<List<AudioPart>, String>((ref, sectionId) async {
  return await ref.read(songRepositoryProvider).getAudioPartsForSection(sectionId);
});

// Freemium gate
final isAtSongLimitProvider = FutureProvider<bool>((ref) async {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return false;
  return await ref.read(songRepositoryProvider).isAtSongLimit(choirId);
});

// Filter state for library screen
final libraryFilterProvider = StateProvider<VoicePart?>((ref) => null);

// Combine songs with their audio parts
class SongWithParts {
  final Song song;
  final Map<VoicePart, List<AudioPart>> partsByVoicePart;
  
  SongWithParts({required this.song, required this.partsByVoicePart});
  
  List<AudioPart> getPartsForVoicePart(VoicePart part) {
    return partsByVoicePart[part] ?? [];
  }
  
  bool hasAudioForVoicePart(VoicePart part) {
    return partsByVoicePart.containsKey(part) && partsByVoicePart[part]!.isNotEmpty;
  }
}

// Derived provider that combines songs with their audio parts
final songsWithPartsProvider = StreamProvider<List<SongWithParts>>((ref) {
  final songsAsync = ref.watch(songLibraryProvider);
  final filterPart = ref.watch(libraryFilterProvider);
  
  return songsAsync.when(
    data: (songs) {
      return Stream.value(songs).asyncExpand((songs) async* {
        final songsWithParts = <SongWithParts>[];
        
        for (final song in songs) {
          final parts = await ref.read(audioPartsProvider(song.songId).future);
          
          final partsByVoicePart = <VoicePart, List<AudioPart>>{};
          for (final part in parts) {
            partsByVoicePart.putIfAbsent(part.voicePart, () => []).add(part);
          }
          
          // Apply filter if set
          if (filterPart != null) {
            if (partsByVoicePart.containsKey(filterPart) && partsByVoicePart[filterPart]!.isNotEmpty) {
              songsWithParts.add(SongWithParts(song: song, partsByVoicePart: partsByVoicePart));
            }
          } else {
            songsWithParts.add(SongWithParts(song: song, partsByVoicePart: partsByVoicePart));
          }
        }
        
        yield songsWithParts;
      });
    },
    loading: () => Stream.value([]),
    error: (e, st) => Stream.error(e, st),
  );
});