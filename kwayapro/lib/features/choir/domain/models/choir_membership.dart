import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/enums.dart';

class ChoirMembership {
  final String choirId;
  final String userId;
  final String name;
  final MemberRole role;
  final VoicePart defaultVoicePart;
  final List<String> permissions;
  final DateTime joinedAt;

  const ChoirMembership({
    required this.choirId,
    required this.userId,
    required this.name,
    required this.role,
    required this.defaultVoicePart,
    required this.permissions,
    required this.joinedAt,
  });

  factory ChoirMembership.fromJson(Map<String, dynamic> json) {
    return ChoirMembership(
      choirId: json['choirId'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String? ?? 'Unknown Member',
      role: MemberRole.values.byName(json['role'] as String),
      defaultVoicePart: VoicePart.values.byName(json['defaultVoicePart'] as String),
      permissions: List<String>.from(json['permissions'] as List),
      joinedAt: (json['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'choirId': choirId,
      'userId': userId,
      'name': name,
      'role': role.name,
      'defaultVoicePart': defaultVoicePart.name,
      'permissions': permissions,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  ChoirMembership copyWith({
    String? choirId,
    String? userId,
    String? name,
    MemberRole? role,
    VoicePart? defaultVoicePart,
    List<String>? permissions,
    DateTime? joinedAt,
  }) {
    return ChoirMembership(
      choirId: choirId ?? this.choirId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      defaultVoicePart: defaultVoicePart ?? this.defaultVoicePart,
      permissions: permissions ?? this.permissions,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
