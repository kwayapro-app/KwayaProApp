import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../choir/domain/choir_providers.dart';
import '../data/planner_repository.dart';
import 'models/song_program.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository();
});

// Phase 5 Fix 4: previously not autoDispose — see song_providers.dart for
// the same fix and reasoning.
final songProgramsProvider = StreamProvider.autoDispose<List<SongProgram>>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  final sub = ref.watch(plannerRepositoryProvider).watchPrograms(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final publishedProgramsProvider = StreamProvider.autoDispose<List<SongProgram>>((ref) {
  final programs = ref.watch(songProgramsProvider).valueOrNull ?? [];
  return Stream.value(programs.where((p) => p.publishedAt != null).toList());
});

final draftProgramsProvider = StreamProvider.autoDispose<List<SongProgram>>((ref) {
  final programs = ref.watch(songProgramsProvider).valueOrNull ?? [];
  return Stream.value(programs.where((p) => p.publishedAt == null).toList());
});
