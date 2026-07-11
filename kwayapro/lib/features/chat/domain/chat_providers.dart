import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../domain/models/chat_message.dart';
import '../../../shared/models/enums.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// Phase 5 Fix 4: previously not autoDispose — one live Firestore listener
// per distinct choirId ever viewed, kept alive for the app's lifetime even
// after switching away from that choir.
final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, choirId) {
  final sub = ref.watch(chatRepositoryProvider).watchMessages(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final pinnedMessageProvider = StreamProvider.autoDispose.family<ChatMessage?, String>((ref, choirId) {
  final sub = ref.watch(chatRepositoryProvider).watchPinnedMessage(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final messageTargetProvider = StateProvider<VoicePart?>((ref) => null);

final chatRecordingProvider = StateProvider<bool>((ref) => false);

final recordingDurationProvider = StateProvider<int>((ref) => 0);
