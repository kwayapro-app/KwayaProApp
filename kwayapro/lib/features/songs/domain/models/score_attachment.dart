import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/enums.dart';

class ScoreAttachment {
  final String scoreId;
  final String songId;
  final String choirId;
  final ScoreType type;
  final String fileUrl;
  final String label;
  final String uploadedBy;
  final DateTime createdAt;

  const ScoreAttachment({
    required this.scoreId,
    required this.songId,
    required this.choirId,
    required this.type,
    required this.fileUrl,
    required this.label,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory ScoreAttachment.fromJson(Map<String, dynamic> json) {
    return ScoreAttachment(
      scoreId: json['scoreId'] as String,
      songId: json['songId'] as String,
      choirId: json['choirId'] as String,
      type: ScoreType.values.byName(json['type'] as String),
      fileUrl: json['fileUrl'] as String,
      label: json['label'] as String,
      uploadedBy: json['uploadedBy'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scoreId': scoreId,
      'songId': songId,
      'choirId': choirId,
      'type': type.name,
      'fileUrl': fileUrl,
      'label': label,
      'uploadedBy': uploadedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}