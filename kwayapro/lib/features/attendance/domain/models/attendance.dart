import '../../../../shared/models/enums.dart';

class Attendance {
  final String sessionId;
  final String userId;
  final RSVPStatus rsvp;
  final bool attended;
  final VoicePart? voicePartOverride;

  const Attendance({
    required this.sessionId,
    required this.userId,
    required this.rsvp,
    required this.attended,
    this.voicePartOverride,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      sessionId: json['sessionId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
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
      'rsvp': rsvp.name,
      'attended': attended,
      if (voicePartOverride != null) 'voicePartOverride': voicePartOverride!.name,
    };
  }

  Attendance copyWith({
    String? sessionId,
    String? userId,
    RSVPStatus? rsvp,
    bool? attended,
    VoicePart? voicePartOverride,
  }) {
    return Attendance(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      rsvp: rsvp ?? this.rsvp,
      attended: attended ?? this.attended,
      voicePartOverride: voicePartOverride ?? this.voicePartOverride,
    );
  }
}
