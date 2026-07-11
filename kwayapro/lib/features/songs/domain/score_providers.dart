import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/score_repository.dart';
import '../domain/models/score_attachment.dart';

final scoreRepositoryProvider = Provider<ScoreRepository>((ref) {
  return ScoreRepository();
});

// Phase 5 Fix 4: previously not autoDispose — see song_providers.dart for
// the same fix and reasoning.
final songScoresProvider = StreamProvider.autoDispose.family<List<ScoreAttachment>, String>((ref, songId) {
  final sub = ref.watch(scoreRepositoryProvider).watchScores(songId);
  ref.onDispose(() => sub.drain());
  return sub;
});
