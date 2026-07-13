import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/score_repository.dart';
import '../domain/models/score_attachment.dart';

final scoreRepositoryProvider = Provider<ScoreRepository>((ref) {
  return ScoreRepository();
});

// Phase 5 Fix 4: previously not autoDispose — see song_providers.dart for
// the same fix and reasoning.
//
// Family key is (songId, choirId): watchScores needs both to build a query
// firestore.rules can actually authorize — see the comment on
// ScoreRepository.watchScores.
final songScoresProvider = StreamProvider.autoDispose
    .family<List<ScoreAttachment>, ({String songId, String choirId})>((ref, params) {
  final sub = ref.watch(scoreRepositoryProvider).watchScores(params.songId, params.choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});
