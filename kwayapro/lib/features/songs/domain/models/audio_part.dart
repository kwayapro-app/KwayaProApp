import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/enums.dart';

class AudioPart {
  final String audioPartId;
  final String sectionId;
  final String songId;
  final String choirId;
  final VoicePart voicePart;
  final String audioUrl;
  final int durationSeconds;
  final String uploadedBy;
  final DateTime createdAt;

  const AudioPart({
    required this.audioPartId,
    required this.sectionId,
    required this.songId,
    required this.choirId,
    required this.voicePart,
    required this.audioUrl,
    required this.durationSeconds,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory AudioPart.fromJson(Map<String, dynamic> json) {
    return AudioPart(
      audioPartId: json['audioPartId'] as String? ?? '',
      sectionId: json['sectionId'] as String? ?? '',
      songId: json['songId'] as String? ?? '',
      choirId: json['choirId'] as String? ?? '',
      // Phase 7 note: deliberately kept as byName() (throws on an
      // unrecognized value) rather than the asNameMap() hygiene pattern used
      // elsewhere — SongRepository's _parseSkippingBadDocs (Phase 4 Fix 1)
      // relies on this throwing so the whole malformed doc is skipped and
      // logged, rather than silently kept with a defaulted voicePart that
      // could put an audio part in the wrong voice section.
      voicePart: json['voicePart'] != null
          ? VoicePart.values.byName(json['voicePart'] as String)
          : VoicePart.S,
      audioUrl: json['audioUrl'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      uploadedBy: json['uploadedBy'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioPartId': audioPartId,
      'sectionId': sectionId,
      'songId': songId,
      'choirId': choirId,
      'voicePart': voicePart.name,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'uploadedBy': uploadedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AudioPart copyWith({
    String? audioPartId,
    String? sectionId,
    String? songId,
    String? choirId,
    VoicePart? voicePart,
    String? audioUrl,
    int? durationSeconds,
    String? uploadedBy,
    DateTime? createdAt,
  }) {
    return AudioPart(
      audioPartId: audioPartId ?? this.audioPartId,
      sectionId: sectionId ?? this.sectionId,
      songId: songId ?? this.songId,
      choirId: choirId ?? this.choirId,
      voicePart: voicePart ?? this.voicePart,
      audioUrl: audioUrl ?? this.audioUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
