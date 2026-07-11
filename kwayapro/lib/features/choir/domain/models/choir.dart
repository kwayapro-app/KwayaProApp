import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/enums.dart';

class Choir {
  final String choirId;
  final String name;
  final String churchName;
  final String leaderId;
  final String? coverPhotoUrl;
  final String inviteCode;
  final ChoirPlan plan;
  final int songCount;
  final DateTime createdAt;

  const Choir({
    required this.choirId,
    required this.name,
    required this.churchName,
    required this.leaderId,
    this.coverPhotoUrl,
    required this.inviteCode,
    required this.plan,
    required this.songCount,
    required this.createdAt,
  });

  factory Choir.fromJson(Map<String, dynamic> json) {
    return Choir(
      choirId: json['choirId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      churchName: json['churchName'] as String? ?? '',
      leaderId: json['leaderId'] as String? ?? '',
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      inviteCode: json['inviteCode'] as String? ?? '',
      plan: ChoirPlan.values.asNameMap()[json['plan']] ?? ChoirPlan.free,
      songCount: json['songCount'] as int? ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'choirId': choirId,
      'name': name,
      'churchName': churchName,
      'leaderId': leaderId,
      if (coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
      'inviteCode': inviteCode,
      'plan': plan.name,
      'songCount': songCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Choir copyWith({
    String? choirId,
    String? name,
    String? churchName,
    String? leaderId,
    String? coverPhotoUrl,
    String? inviteCode,
    ChoirPlan? plan,
    int? songCount,
    DateTime? createdAt,
  }) {
    return Choir(
      choirId: choirId ?? this.choirId,
      name: name ?? this.name,
      churchName: churchName ?? this.churchName,
      leaderId: leaderId ?? this.leaderId,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      inviteCode: inviteCode ?? this.inviteCode,
      plan: plan ?? this.plan,
      songCount: songCount ?? this.songCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
