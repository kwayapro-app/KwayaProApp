enum ChoirPlan { free, pro }

enum MemberRole { leader, director, chorister }

enum VoicePart { S, A, T, B }

enum SectionStatus { ready, comingSoon }

enum ScoreType { pdf, image }

enum EventType { mass, wedding, concert, rehearsal, other }

enum RSVPStatus { coming, notComing, pending }

enum MessageType { text, audio, image }

enum PaymentProvider { mtn, airtel }

enum SubscriptionStatus { active, expired, pending, cancelled }

extension VoicePartX on VoicePart {
  String get displayName => switch (this) {
    VoicePart.S => 'Soprano',
    VoicePart.A => 'Alto',
    VoicePart.T => 'Tenor',
    VoicePart.B => 'Bass',
  };

  String get initial => name; // 'S', 'A', 'T', 'B'
}
