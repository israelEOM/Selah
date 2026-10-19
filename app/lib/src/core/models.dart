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
    this.translatedTitles = const {},
    this.translatedMessages = const {},
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
      translatedTitles: {
        for (final t in (json['study_translations'] as List? ?? const []).cast<Map<String, dynamic>>())
          t['language'] as String: t['title'] as String,
      },
      translatedMessages: {
        for (final t in (json['study_translations'] as List? ?? const []).cast<Map<String, dynamic>>())
          if (t['central_message'] != null) t['language'] as String: t['central_message'] as String,
      },
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

  /// Titles of the visible translations, by language code.
  final Map<String, String> translatedTitles;

  /// Central messages of the visible translations, by language code.
  final Map<String, String> translatedMessages;

  /// The card with its title and central message in [language] when a translation exists, otherwise unchanged.
  StudyCard localizedTo(String language) {
    final translated = translatedTitles[language];
    if (translated == null) return this;
    return StudyCard(
      id: id,
      slug: slug,
      title: translated,
      numberOfDays: numberOfDays,
      centralMessage: translatedMessages[language] ?? centralMessage,
      publishedAt: publishedAt,
      thumbnailUrl: thumbnailUrl,
      preacher: preacher,
      sermonDate: sermonDate,
      translatedTitles: translatedTitles,
      translatedMessages: translatedMessages,
    );
  }
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

class Job {
  const Job({required this.id, required this.step, required this.status, required this.payload, this.result, this.error, required this.createdAt});

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String,
        step: json['step'] as String,
        status: json['status'] as String,
        payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
        result: json['result'] as Map<String, dynamic>?,
        error: json['error'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String step;
  final String status;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? result;
  final String? error;
  final DateTime createdAt;

  bool get isActive => status == 'queued' || status == 'running';
}

/// Everything the admin sermon page shows. Generated content stays as JSON maps because
/// its shape is owned by the worker's schemas.
class SermonDetail {
  const SermonDetail({
    required this.sermon,
    required this.hasTranscript,
    this.analysis,
    this.references = const [],
    this.study,
    this.days = const [],
  });

  final Map<String, dynamic> sermon;
  final bool hasTranscript;
  final Map<String, dynamic>? analysis;
  final List<Map<String, dynamic>> references;
  final Map<String, dynamic>? study;
  final List<Map<String, dynamic>> days;

  String get videoId => sermon['youtube_video_id'] as String;
}

/// A published study as members see it.
class PublicStudy {
  const PublicStudy({
    required this.id,
    required this.slug,
    required this.title,
    required this.numberOfDays,
    required this.bibleVersionCode,
    required this.summary,
    required this.sermon,
    required this.days,
    this.centralMessage,
    this.publishedAt,
    this.outputLanguage = 'es',
    this.translations = const {},
    this.translatedFrom,
  });

  factory PublicStudy.fromJson(Map<String, dynamic> json) {
    final days = _sortedDays(json['devotional_days']);
    return PublicStudy(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      numberOfDays: json['number_of_days'] as int,
      bibleVersionCode: json['bible_version_code'] as String,
      summary: (json['summary'] as Map<String, dynamic>?) ?? const {},
      sermon: SermonInfo.fromJson(json['sermons'] as Map<String, dynamic>),
      days: days,
      centralMessage: json['central_message'] as String?,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      outputLanguage: (json['output_language'] as String?) ?? 'es',
      translations: {
        for (final t in (json['study_translations'] as List? ?? const []).cast<Map<String, dynamic>>())
          t['language'] as String: StudyTranslation.fromJson(t),
      },
    );
  }

  final String id;
  final String slug;
  final String title;
  final int numberOfDays;
  final String bibleVersionCode;

  /// Shape owned by the worker: introduction, main_passage, points, conclusion, key_takeaways.
  final Map<String, dynamic> summary;
  final SermonInfo sermon;
  final List<DevotionalDay> days;
  final String? centralMessage;
  final DateTime? publishedAt;

  /// Language the study was written in (`studies.output_language`).
  final String outputLanguage;

  /// Visible translations by language code. RLS already hides hidden and unpublished ones.
  final Map<String, StudyTranslation> translations;

  /// The original language when this is a translated copy, null on the original.
  final String? translatedFrom;

  /// This study in [language], or `this` when it is already in that language or has no translation.
  PublicStudy localizedTo(String language) {
    if (language == outputLanguage) return this;
    final t = translations[language];
    if (t == null) return this;
    return PublicStudy(
      id: id,
      slug: slug,
      title: t.title,
      numberOfDays: numberOfDays,
      bibleVersionCode: t.bibleVersionCode,
      summary: t.summary,
      sermon: sermon,
      days: t.days,
      centralMessage: t.centralMessage,
      publishedAt: publishedAt,
      outputLanguage: outputLanguage,
      translations: translations,
      translatedFrom: outputLanguage,
    );
  }
}

/// One row of `study_translations`: the study text in another language.
class StudyTranslation {
  const StudyTranslation({
    required this.language,
    required this.title,
    required this.summary,
    required this.days,
    required this.bibleVersionCode,
    this.centralMessage,
  });

  factory StudyTranslation.fromJson(Map<String, dynamic> json) => StudyTranslation(
        language: json['language'] as String,
        title: json['title'] as String,
        centralMessage: json['central_message'] as String?,
        summary: (json['summary'] as Map<String, dynamic>?) ?? const {},
        days: _sortedDays(json['days']),
        bibleVersionCode: json['bible_version_code'] as String,
      );

  final String language;
  final String title;
  final String? centralMessage;
  final Map<String, dynamic> summary;
  final List<DevotionalDay> days;
  final String bibleVersionCode;
}

List<DevotionalDay> _sortedDays(Object? raw) =>
    List<Map<String, dynamic>>.from(raw as List? ?? const []).map(DevotionalDay.fromJson).toList()
      ..sort((a, b) => a.number.compareTo(b.number));

class SermonInfo {
  const SermonInfo({required this.videoId, this.title, this.preacher, this.channel, this.thumbnailUrl, this.sermonDate});

  factory SermonInfo.fromJson(Map<String, dynamic> json) => SermonInfo(
        videoId: json['youtube_video_id'] as String,
        title: json['title'] as String?,
        preacher: json['preacher'] as String?,
        channel: json['channel'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        sermonDate: DateTime.tryParse(json['sermon_date'] as String? ?? ''),
      );

  final String videoId;
  final String? title;
  final String? preacher;
  final String? channel;
  final String? thumbnailUrl;
  final DateTime? sermonDate;
}

class DevotionalDay {
  const DevotionalDay({
    required this.number,
    required this.title,
    required this.questions,
    this.bibleReading,
    this.mainIdea,
    this.reflection,
    this.application,
    this.prayer,
    this.startSeconds,
    this.endSeconds,
  });

  factory DevotionalDay.fromJson(Map<String, dynamic> json) => DevotionalDay(
        number: json['day_number'] as int,
        title: json['title'] as String,
        questions: List<String>.from(json['questions'] as List? ?? const []),
        bibleReading: json['bible_reading'] as String?,
        mainIdea: json['main_idea'] as String?,
        reflection: json['reflection'] as String?,
        application: json['application'] as String?,
        prayer: json['prayer'] as String?,
        startSeconds: json['start_seconds'] as num?,
        endSeconds: json['end_seconds'] as num?,
      );

  final int number;
  final String title;
  final List<String> questions;
  final String? bibleReading;
  final String? mainIdea;
  final String? reflection;
  final String? application;
  final String? prayer;
  final num? startSeconds;
  final num? endSeconds;
}
