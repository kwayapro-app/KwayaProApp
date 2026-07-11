import '../../../../shared/models/enums.dart';

class Attendance {
  final String sessionId;
  final String userId;
  // CHORISTER AUDIT FIX: previously absent from both the model and every
  // write path, even though AttendanceRepository.watchMemberHistory/
  // getMemberAttendanceRate already accepted a choirId parameter — it was
  // just never usable, since there was no field to filter on. Without it, a
  // chorister who belongs to more than one choir got their "own attendance
  // %" blended across every choir they're in. Defaults to '' for any
  // pre-existing doc written before this field existed.
  final String choirId;
  final RSVPStatus rsvp;
  final bool attended;
  final VoicePart? voicePartOverride;

  const Attendance({
    required this.sessionId,
    required this.userId,
    this.choirId = '',
    required this.rsvp,
    required this.attended,
    this.voicePartOverride,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      sessionId: json['sessionId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      choirId: json['choirId'] as String? ?? '',
      rsvp: RSVPStatus.values.asNameMap()[json['rsvp']] ?? RSVPStatus.pending,
      attended: json['attended'] as bool? ?? false,
      voicePartOverride: json['voicePartOverride'] != null
          ? VoicePart.values.asNameMap()[json['voicePartOverride']]
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'choirId': choirId,
      'rsvp': rsvp.name,
      'attended': attended,
      if (voicePartOverride != null) 'voicePartOverride': voicePartOverride!.name,
    };
  }

  Attendance copyWith({
    String? sessionId,
    String? userId,
    String? choirId,
    RSVPStatus? rsvp,
    bool? attended,
    VoicePart? voicePartOverride,
  }) {
    return Attendance(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      choirId: choirId ?? this.choirId,
      rsvp: rsvp ?? this.rsvp,
      attended: attended ?? this.attended,
      voicePartOverride: voicePartOverride ?? this.voicePartOverride,
    );
  }
}
