import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/score_repository.dart';
import '../domain/models/score_attachment.dart';

final scoreRepositoryProvider = Provider<ScoreRepository>((ref) {
  return ScoreRepository();
});

final songScoresProvider = StreamProvider.family<List<ScoreAttachment>, String>((ref, songId) {
  return ref.read(scoreRepositoryProvider).watchScores(songId);
});