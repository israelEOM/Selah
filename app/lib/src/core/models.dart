import 'package:supabase_flutter/supabase_flutter.dart';

enum ChurchRole {
  owner,
  editor,
  member;

  bool get canEdit => this == owner || this == editor;

  /// Owner > editor > member.
  bool isAtLeast(ChurchRole other) => index <= other.index;

  static ChurchRole? parse(String? value) {
    for (final r in values) {
      if (r.name == value) return r;
    }
    return null;
  }
}

class Church {
  const Church({
    required this.id,
    required this.slug,
    required this.name,
    this.defaultSermonLanguage,
    this.defaultOutputLanguage,
    this.defaultBibleVersionCode,
    this.defaultDevotionalDays,
    this.monthlySermonLimit,
    this.eventsCalendarUrl,
    this.timezone = 'Europe/Madrid',
    this.eventsSyncedAt,
    this.eventsSyncError,
  });

  factory Church.fromJson(Map<String, dynamic> json) => Church(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        defaultSermonLanguage: json['default_sermon_language'] as String?,
        defaultOutputLanguage: json['default_output_language'] as String?,
        defaultBibleVersionCode: json['default_bible_version_code'] as String?,
        defaultDevotionalDays: json['default_devotional_days'] as int?,
        monthlySermonLimit: json['monthly_sermon_limit'] as int?,
        eventsCalendarUrl: json['events_calendar_url'] as String?,
        timezone: json['timezone'] as String? ?? 'Europe/Madrid',
        eventsSyncedAt: DateTime.tryParse(json['events_synced_at'] as String? ?? ''),
        eventsSyncError: json['events_sync_error'] as String?,
      );

  final String id;
  final String slug;
  final String name;
  final String? defaultSermonLanguage;
  final String? defaultOutputLanguage;
  final String? defaultBibleVersionCode;
  final int? defaultDevotionalDays;
  final int? monthlySermonLimit;

  /// The church's calendar feed; null when the Eventos tab is off.
  final String? eventsCalendarUrl;

  /// IANA zone for calendar times that don't name one.
  final String timezone;
  final DateTime? eventsSyncedAt;

  /// Why the last calendar refresh failed: blocked, unreachable or not_calendar.
  final String? eventsSyncError;
}

/// An upcoming event from a church's calendar.
class ChurchEvent {
  const ChurchEvent({
    required this.uid,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.localStart,
    required this.localEnd,
    this.allDay = false,
    this.location,
    this.url,
  });

  factory ChurchEvent.fromJson(Map<String, dynamic> json) => ChurchEvent(
        uid: json['uid'] as String,
        title: json['title'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        // Stored without an offset, so these parse as the church's wall clock and are shown as they are.
        localStart: DateTime.parse(json['local_starts_at'] as String),
        localEnd: DateTime.parse(json['local_ends_at'] as String),
        allDay: json['all_day'] as bool? ?? false,
        location: json['location'] as String?,
        url: Uri.tryParse(json['url'] as String? ?? '')?.hasScheme == true ? Uri.parse(json['url'] as String) : null,
      );

  final String uid;
  final String title;
  final DateTime startsAt, endsAt;

  /// The church's wall-clock times.
  final DateTime localStart, localEnd;
  final bool allDay;
  final String? location;

  /// The event's page on the church's site.
  final Uri? url;
}

/// What checking a church's calendar found.
sealed class EventsSyncResult {
  const EventsSyncResult();
}

class EventsSynced extends EventsSyncResult {
  const EventsSynced(this.count);
  final int count;
}

class EventsSyncFailed extends EventsSyncResult {
  const EventsSyncFailed(this.error);

  /// blocked, unreachable or not_calendar.
  final String error;
}

/// A church the signed-in user belongs to, with their role there.
class Membership {
  const Membership({required this.church, required this.role});

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        church: Church.fromJson(json['churches'] as Map<String, dynamic>),
        role: ChurchRole.parse(json['role'] as String?) ?? ChurchRole.member,
      );

  final Church church;
  final ChurchRole role;
}

/// A member as listed by the `church_people` function.
class Person {
  const Person({required this.userId, required this.name, required this.email, required this.role, this.joinedAt});

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        userId: json['user_id'] as String,
        name: json['name'] as String?,
        email: json['email'] as String?,
        role: ChurchRole.parse(json['role'] as String?) ?? ChurchRole.member,
        joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? ''),
      );

  final String userId;
  final String? name;
  final String? email;
  final ChurchRole role;
  final DateTime? joinedAt;
}

enum ChurchRequestStatus { pending, approved, rejected }

/// A pastor's request to bring a church to Selah. Table and RPC rows carry no requester email; `pending_church_requests` rows do.
class ChurchRequest {
  const ChurchRequest({
    required this.id,
    required this.churchName,
    required this.status,
    required this.createdAt,
    this.note,
    this.requesterEmail,
  });

  factory ChurchRequest.fromJson(Map<String, dynamic> json) => ChurchRequest(
        id: json['id'] as String,
        churchName: json['church_name'] as String,
        note: json['note'] as String?,
        status: ChurchRequestStatus.values.byName(json['status'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        requesterEmail: json['requester_email'] as String?,
      );

  final String id;
  final String churchName;
  final String? note;
  final ChurchRequestStatus status;
  final DateTime createdAt;
  final String? requesterEmail;
}

/// Error codes the database raises on purpose.
class SelahError {
  static const codes = [
    'church_slug_taken',
    'church_slug_invalid',
    'invite_invalid',
    'last_owner',
    'monthly_limit_reached',
    'not_allowed',
    'request_pending_exists',
    'request_not_pending',
  ];

  /// The known code in a [PostgrestException]'s message, or null.
  static String? fromException(Object e) {
    if (e is! PostgrestException) return null;
    for (final code in codes) {
      if (e.message.contains(code)) return code;
    }
    return null;
  }
}

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
    this.artKey,
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
      artKey: json['art_key'] as String?,
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
  final String? artKey;

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
      artKey: artKey,
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
    this.artKey,
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
      artKey: json['art_key'] as String?,
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

  /// A key from the art manifest, or null to fall back to a pick from the study's id.
  final String? artKey;

  /// Language the study was written in (`studies.output_language`).
  final String outputLanguage;

  /// Visible translations by language code. RLS already hides hidden and unpublished ones.
  final Map<String, StudyTranslation> translations;

  /// The original language when this is a translated copy, null on the original.
  final String? translatedFrom;

  String? _artKeyOfDay(int number) {
    for (final d in days) {
      if (d.number == number) return d.artKey;
    }
    return null;
  }

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
      // Translations carry no art: the original's day art follows the day number.
      days: [for (final d in t.days) d.withArtKey(_artKeyOfDay(d.number))],
      centralMessage: t.centralMessage,
      publishedAt: publishedAt,
      artKey: artKey,
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
    this.artKey,
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
        artKey: json['art_key'] as String?,
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

  /// A key from the art manifest, or null to fall back to a pick from the study.
  final String? artKey;

  /// This day with [artKey] set.
  DevotionalDay withArtKey(String? artKey) => DevotionalDay(
        number: number,
        title: title,
        questions: questions,
        bibleReading: bibleReading,
        mainIdea: mainIdea,
        reflection: reflection,
        application: application,
        prayer: prayer,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
        artKey: artKey,
      );
}
