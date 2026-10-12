class StudyCard {
  const StudyCard({
    required this.id,
    required this.slug,
    required this.title,
    required this.numberOfDays,
    this.centralMessage,
    this.publishedAt,
    this.thumbnailUrl,
    this.preacher,
    this.sermonDate,
  });

  factory StudyCard.fromJson(Map<String, dynamic> json) {
    final sermon = (json['sermons'] as Map<String, dynamic>?) ?? const {};
    return StudyCard(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      numberOfDays: json['number_of_days'] as int,
      centralMessage: json['central_message'] as String?,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      thumbnailUrl: sermon['thumbnail_url'] as String?,
      preacher: (sermon['preacher'] ?? sermon['channel']) as String?,
      sermonDate: DateTime.tryParse(sermon['sermon_date'] as String? ?? ''),
    );
  }

  final String id;
  final String slug;
  final String title;
  final int numberOfDays;
  final String? centralMessage;
  final DateTime? publishedAt;
  final String? thumbnailUrl;
  final String? preacher;
  final DateTime? sermonDate;
}

class SermonRow {
  const SermonRow({required this.id, required this.title, this.thumbnailUrl, this.studyStatus});

  factory SermonRow.fromJson(Map<String, dynamic> json) {
    final study = json['studies'];
    final first = study is List ? (study.isEmpty ? null : study.first) : study;
    return SermonRow(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? json['youtube_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      studyStatus: (first as Map<String, dynamic>?)?['status'] as String?,
    );
  }

  final String id;
  final String title;
  final String? thumbnailUrl;
  final String? studyStatus;
}
