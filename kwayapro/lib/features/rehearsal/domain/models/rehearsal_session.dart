import 'package:cloud_firestore/cloud_firestore.dart';

class RehearsalSession {
  final String sessionId;
  final String choirId;
  final String? programId;
  final String title;
  final DateTime date;
  final String time;
  final String location;
  final String directorId;
  final bool isGuestDirector;
  final String? notes;
  final String? guestToken;
  final DateTime? guestTokenExpiry;

  const RehearsalSession({
    required this.sessionId,
    required this.choirId,
    this.programId,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.directorId,
    required this.isGuestDirector,
    this.notes,
    this.guestToken,
    this.guestTokenExpiry,
  });

  factory RehearsalSession.fromJson(Map<String, dynamic> json) {
    return RehearsalSession(
      sessionId: json['sessionId'] as String? ?? '',
      choirId: json['choirId'] as String? ?? '',
      programId: json['programId'] as String?,
      title: json['title'] as String? ?? 'Rehearsal',
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      time: json['time'] as String? ?? '',
      location: json['location'] as String? ?? '',
      directorId: json['directorId'] as String? ?? '',
      isGuestDirector: json['isGuestDirector'] as bool? ?? false,
      notes: json['notes'] as String?,
      guestToken: json['guestToken'] as String?,
      guestTokenExpiry: (json['guestTokenExpiry'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'choirId': choirId,
      if (programId != null) 'programId': programId,
      'title': title,
      'date': Timestamp.fromDate(date),
      'time': time,
      'location': location,
      'directorId': directorId,
      'isGuestDirector': isGuestDirector,
      if (notes != null) 'notes': notes,
      if (guestToken != null) 'guestToken': guestToken,
      if (guestTokenExpiry != null) 'guestTokenExpiry': Timestamp.fromDate(guestTokenExpiry!),
    };
  }

  RehearsalSession copyWith({
    String? sessionId,
    String? choirId,
    String? programId,
    String? title,
    DateTime? date,
    String? time,
    String? location,
    String? directorId,
    bool? isGuestDirector,
    String? notes,
    String? guestToken,
    DateTime? guestTokenExpiry,
  }) {
    return RehearsalSession(
      sessionId: sessionId ?? this.sessionId,
      choirId: choirId ?? this.choirId,
      programId: programId ?? this.programId,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      directorId: directorId ?? this.directorId,
      isGuestDirector: isGuestDirector ?? this.isGuestDirector,
      notes: notes ?? this.notes,
      guestToken: guestToken ?? this.guestToken,
      guestTokenExpiry: guestTokenExpiry ?? this.guestTokenExpiry,
    );
  }
}
