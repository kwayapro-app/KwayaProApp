import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../domain/models/chat_message.dart';
import '../../../shared/models/enums.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, choirId) {
  return ref.read(chatRepositoryProvider).watchMessages(choirId);
});

final pinnedMessageProvider = StreamProvider.family<ChatMessage?, String>((ref, choirId) {
  return ref.read(chatRepositoryProvider).watchPinnedMessage(choirId);
});

final messageTargetProvider = StateProvider<VoicePart?>((ref) => null);

final chatRecordingProvider = StateProvider<bool>((ref) => false);

final recordingDurationProvider = StateProvider<int>((ref) => 0);