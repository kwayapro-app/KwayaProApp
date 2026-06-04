import '../../../../shared/models/enums.dart';

class SongSection {
  final String sectionId;
  final String songId;
  final String choirId;
  final String title;
  final int order;
  final SectionStatus status;

  const SongSection({
    required this.sectionId,
    required this.songId,
    required this.choirId,
    required this.title,
    required this.order,
    required this.status,
  });

  factory SongSection.fromJson(Map<String, dynamic> json) {
    return SongSection(
      sectionId: json['sectionId'] as String,
      songId: json['songId'] as String,
      choirId: json['choirId'] as String,
      title: json['title'] as String,
      order: json['order'] as int,
      status: SectionStatus.values.byName(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sectionId': sectionId,
      'songId': songId,
      'choirId': choirId,
      'title': title,
      'order': order,
      'status': status.name,
    };
  }

  SongSection copyWith({
    String? sectionId,
    String? songId,
    String? choirId,
    String? title,
    int? order,
    SectionStatus? status,
  }) {
    return SongSection(
      sectionId: sectionId ?? this.sectionId,
      songId: songId ?? this.songId,
      choirId: choirId ?? this.choirId,
      title: title ?? this.title,
      order: order ?? this.order,
      status: status ?? this.status,
    );
  }
}
