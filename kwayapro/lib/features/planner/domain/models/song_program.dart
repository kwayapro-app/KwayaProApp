import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/enums.dart';

class SongProgram {
  final String programId;
  final String choirId;
  final String eventName;
  final EventType eventType;
  final DateTime eventDate;
  final List<String> songIds;
  final String createdBy;
  final DateTime? publishedAt;

  const SongProgram({
    required this.programId,
    required this.choirId,
    required this.eventName,
    required this.eventType,
    required this.eventDate,
    required this.songIds,
    required this.createdBy,
    this.publishedAt,
  });

  factory SongProgram.fromJson(Map<String, dynamic> json) {
    return SongProgram(
      programId: json['programId'] as String,
      choirId: json['choirId'] as String,
      eventName: json['eventName'] as String,
      eventType: EventType.values.byName(json['eventType'] as String),
      eventDate: (json['eventDate'] as Timestamp).toDate(),
      songIds: List<String>.from(json['songIds'] as List),
      createdBy: json['createdBy'] as String,
      publishedAt: json['publishedAt'] != null
          ? (json['publishedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'programId': programId,
      'choirId': choirId,
      'eventName': eventName,
      'eventType': eventType.name,
      'eventDate': Timestamp.fromDate(eventDate),
      'songIds': songIds,
      'createdBy': createdBy,
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
    };
  }

  SongProgram copyWith({
    String? programId,
    String? choirId,
    String? eventName,
    EventType? eventType,
    DateTime? eventDate,
    List<String>? songIds,
    String? createdBy,
    DateTime? publishedAt,
  }) {
    return SongProgram(
      programId: programId ?? this.programId,
      choirId: choirId ?? this.choirId,
      eventName: eventName ?? this.eventName,
      eventType: eventType ?? this.eventType,
      eventDate: eventDate ?? this.eventDate,
      songIds: songIds ?? this.songIds,
      createdBy: createdBy ?? this.createdBy,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}
