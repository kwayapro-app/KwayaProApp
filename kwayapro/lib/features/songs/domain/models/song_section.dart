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
      sectionId: json['sectionId'] as String? ?? '',
      songId: json['songId'] as String? ?? '',
      choirId: json['choirId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      // Phase 7 note: deliberately kept as byName() (throws on an
      // unrecognized value) rather than the asNameMap() hygiene pattern used
      // elsewhere — SongRepository's _parseSkippingBadDocs (Phase 4 Fix 1)
      // relies on this throwing so the whole malformed doc is skipped and
      // logged, rather than silently kept with a defaulted status.
      status: json['status'] != null
          ? SectionStatus.values.byName(json['status'] as String)
          : SectionStatus.comingSoon,
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
