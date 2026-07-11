import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/enums.dart';

class ChatMessage {
  final String messageId;
  final String choirId;
  final String senderId;
  final MessageType type;
  final String content;
  final VoicePart? targetVoicePart;
  final bool pinned;
  final DateTime timestamp;

  const ChatMessage({
    required this.messageId,
    required this.choirId,
    required this.senderId,
    required this.type,
    required this.content,
    this.targetVoicePart,
    required this.pinned,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId'] as String? ?? '',
      choirId: json['choirId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      type: MessageType.values.asNameMap()[json['type']] ?? MessageType.text,
      content: json['content'] as String? ?? '',
      targetVoicePart: json['targetVoicePart'] != null
          ? VoicePart.values.asNameMap()[json['targetVoicePart']]
          : null,
      pinned: json['pinned'] as bool? ?? false,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'choirId': choirId,
      'senderId': senderId,
      'type': type.name,
      'content': content,
      if (targetVoicePart != null) 'targetVoicePart': targetVoicePart!.name,
      'pinned': pinned,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  ChatMessage copyWith({
    String? messageId,
    String? choirId,
    String? senderId,
    MessageType? type,
    String? content,
    VoicePart? targetVoicePart,
    bool? pinned,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      choirId: choirId ?? this.choirId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      content: content ?? this.content,
      targetVoicePart: targetVoicePart ?? this.targetVoicePart,
      pinned: pinned ?? this.pinned,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
