import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String songId;
  final String choirId;
  final String title;
  final String? key;
  final String? language;
  final String? category;
  final String uploadedBy;
  final DateTime createdAt;

  const Song({
    required this.songId,
    required this.choirId,
    required this.title,
    this.key,
    this.language,
    this.category,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      songId: json['songId'] as String,
      choirId: json['choirId'] as String,
      title: json['title'] as String,
      key: json['key'] as String?,
      language: json['language'] as String?,
      category: json['category'] as String?,
      uploadedBy: json['uploadedBy'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songId': songId,
      'choirId': choirId,
      'title': title,
      if (key != null) 'key': key,
      if (language != null) 'language': language,
      if (category != null) 'category': category,
      'uploadedBy': uploadedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Song copyWith({
    String? songId,
    String? choirId,
    String? title,
    String? key,
    String? language,
    String? category,
    String? uploadedBy,
    DateTime? createdAt,
  }) {
    return Song(
      songId: songId ?? this.songId,
      choirId: choirId ?? this.choirId,
      title: title ?? this.title,
      key: key ?? this.key,
      language: language ?? this.language,
      category: category ?? this.category,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
