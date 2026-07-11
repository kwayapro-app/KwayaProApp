import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String userId;
  final String name;
  final String phone;
  final String? email;
  final String? profilePhotoUrl;
  final String? fcmToken;
  final bool onboardingComplete;
  final DateTime createdAt;

  const AppUser({
    required this.userId,
    required this.name,
    required this.phone,
    this.email,
    this.profilePhotoUrl,
    this.fcmToken,
    this.onboardingComplete = false,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      fcmToken: json['fcmToken'] as String?,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (fcmToken != null) 'fcmToken': fcmToken,
      'onboardingComplete': onboardingComplete,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppUser copyWith({
    String? userId,
    String? name,
    String? phone,
    String? email,
    String? profilePhotoUrl,
    String? fcmToken,
    bool? onboardingComplete,
    DateTime? createdAt,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
