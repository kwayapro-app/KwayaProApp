import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../choir/domain/choir_providers.dart';
import '../data/planner_repository.dart';
import 'models/song_program.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository();
});

final songProgramsProvider = StreamProvider<List<SongProgram>>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value([]);
  return ref.read(plannerRepositoryProvider).watchPrograms(choirId);
});

final publishedProgramsProvider = StreamProvider<List<SongProgram>>((ref) {
  final programs = ref.watch(songProgramsProvider).valueOrNull ?? [];
  return Stream.value(programs.where((p) => p.publishedAt != null).toList());
});

final draftProgramsProvider = StreamProvider<List<SongProgram>>((ref) {
  final programs = ref.watch(songProgramsProvider).valueOrNull ?? [];
  return Stream.value(programs.where((p) => p.publishedAt == null).toList());
});