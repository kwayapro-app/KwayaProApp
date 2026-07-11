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

// Phase 5 Fix 4: none of the providers in this file were .autoDispose —
// each held a live Firestore snapshots() listener that was never torn down
// on choir switch (or, for the family providers, per distinct song/section
// ID ever viewed), accumulating one live listener set per choir/song
// browsed for the lifetime of the app session. Matches the pattern already
// established in choir_providers.dart (StreamProvider.autoDispose +
// ref.onDispose draining the subscription).

// Full song library for active choir
final songLibraryProvider = StreamProvider.autoDispose<List<Song>>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  final sub = ref.watch(songRepositoryProvider).watchSongs(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

// Songs filtered by voice part
final songsByVoicePartProvider = StreamProvider.autoDispose.family<List<Song>, VoicePart>((ref, part) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  final sub = ref.watch(songRepositoryProvider).watchSongsByVoicePart(choirId, part);
  ref.onDispose(() => sub.drain());
  return sub;
});

// Sections for a specific song
final songSectionsProvider = StreamProvider.autoDispose.family<List<SongSection>, String>((ref, songId) {
  final sub = ref.watch(songRepositoryProvider).watchSections(songId);
  ref.onDispose(() => sub.drain());
  return sub;
});

// Audio parts for a specific song
final audioPartsProvider = StreamProvider.autoDispose.family<List<AudioPart>, String>((ref, songId) {
  final sub = ref.watch(songRepositoryProvider).watchAudioParts(songId);
  ref.onDispose(() => sub.drain());
  return sub;
});

// Audio parts for a section
final audioPartsForSectionProvider = FutureProvider.autoDispose.family<List<AudioPart>, String>((ref, sectionId) async {
  return await ref.read(songRepositoryProvider).getAudioPartsForSection(sectionId);
});

// Freemium gate
final isAtSongLimitProvider = FutureProvider.autoDispose<bool>((ref) async {
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
final songsWithPartsProvider = StreamProvider.autoDispose<List<SongWithParts>>((ref) {
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
