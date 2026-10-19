import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';

/// All data access goes through here. Row-level security decides what each caller may see.
class SelahRepository {
  SelahRepository(this._client);

  final SupabaseClient _client;

  Future<List<StudyCard>> publishedStudies() async {
    final rows = await _client
        .from('studies')
        .select('id, slug, title, number_of_days, central_message, published_at, '
            'sermons(thumbnail_url, preacher, channel, sermon_date), '
            'study_translations(language, title, central_message)')
        .eq('status', 'published')
        .order('published_at', ascending: false);
    return rows.map(StudyCard.fromJson).toList();
  }

  /// A published study with its sermon and days, or null when there is none to show.
  Future<PublicStudy?> studyBySlug(String slug) async {
    final row = await _client
        .from('studies')
        .select('id, slug, title, number_of_days, bible_version_code, output_language, summary, central_message, published_at, '
            'sermons(youtube_video_id, title, preacher, channel, thumbnail_url, sermon_date), devotional_days(*), study_translations(*)')
        .eq('slug', slug)
        .eq('status', 'published')
        .maybeSingle();
    return row == null ? null : PublicStudy.fromJson(row);
  }

  Future<bool> isAdmin(String userId) async {
    final row = await _client.from('profiles').select('role').eq('id', userId).maybeSingle();
    return row?['role'] == 'admin';
  }

  Future<List<SermonRow>> sermons() async {
    final rows = await _client
        .from('sermons')
        .select('id, title, youtube_url, thumbnail_url, studies(status)')
        .order('created_at', ascending: false);
    return rows.map(SermonRow.fromJson).toList();
  }

  // Admin ---------------------------------------------------------------------

  Future<SermonDetail> sermonDetail(String id) async {
    final sermon = await _client.from('sermons').select().eq('id', id).single();
    final results = await Future.wait<dynamic>([
      _client.from('transcripts').select('id').eq('sermon_id', id).maybeSingle(),
      _client.from('sermon_analyses').select('content').eq('sermon_id', id).maybeSingle(),
      _client.from('bible_references').select().eq('sermon_id', id).order('position', ascending: true),
      _client.from('studies').select().eq('sermon_id', id).maybeSingle(),
    ]);
    final study = results[3] as Map<String, dynamic>?;
    final days = study == null
        ? const <Map<String, dynamic>>[]
        : await _client.from('devotional_days').select().eq('study_id', study['id'] as String).order('day_number', ascending: true);
    return SermonDetail(
      sermon: sermon,
      hasTranscript: results[0] != null,
      analysis: (results[1] as Map<String, dynamic>?)?['content'] as Map<String, dynamic>?,
      references: List<Map<String, dynamic>>.from(results[2] as List),
      study: study,
      days: days,
    );
  }

  /// Latest job for each step of a sermon.
  Future<Map<String, Job>> latestJobs(String sermonId) async {
    final rows = await _client
        .from('jobs')
        .select('id, step, status, payload, result, error, created_at')
        .eq('sermon_id', sermonId)
        .order('created_at', ascending: false)
        .limit(40);
    final latest = <String, Job>{};
    for (final job in rows.map(Job.fromJson)) {
      latest.putIfAbsent(job.step, () => job);
    }
    return latest;
  }

  Future<Job> job(String id) async => Job.fromJson(await _client.from('jobs').select().eq('id', id).single());

  /// Queues work for the worker. The database allows one active job per sermon and step.
  Future<String> createJob(String step, Map<String, dynamic> payload, {String? sermonId}) async {
    final row = await _client
        .from('jobs')
        .insert({'step': step, 'payload': payload, 'sermon_id': sermonId, 'created_by': _client.auth.currentUser!.id})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> saveSermon(Map<String, dynamic> fields) async {
    final row = await _client
        .from('sermons')
        .upsert({...fields, 'created_by': _client.auth.currentUser!.id}, onConflict: 'youtube_video_id')
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<Map<String, dynamic>> churchSettings() => _client.from('church_settings').select().single();

  Future<List<Map<String, dynamic>>> bibleVersions() =>
      _client.from('bible_versions').select('code, name, language').eq('active', true).order('name', ascending: true);

  Future<void> setStudyPublished(String studyId, bool published) => _client.from('studies').update({
        'status': published ? 'published' : 'review',
        'published_at': published ? DateTime.now().toUtc().toIso8601String() : null,
      }).eq('id', studyId);

  /// Admin view of a study's translations, hidden ones included.
  Future<List<Map<String, dynamic>>> translations(String studyId) =>
      _client.from('study_translations').select().eq('study_id', studyId).order('language', ascending: true);

  Future<void> setTranslationHidden(String id, bool hidden) =>
      _client.from('study_translations').update({'hidden': hidden}).eq('id', id);

  Future<void> setReferenceApproved(String referenceId, bool approved) =>
      _client.from('bible_references').update({'approved': approved}).eq('id', referenceId);

  // Auth ----------------------------------------------------------------------

  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// Returns true when the account still needs email confirmation.
  Future<bool> signUp(String email, String password) async {
    final response = await _client.auth.signUp(email: email, password: password);
    return response.session == null;
  }

  /// On the web this leaves the page; Supabase brings the person back to [redirectTo].
  Future<void> signInWithProvider(OAuthProvider provider, {required String redirectTo}) =>
      _client.auth.signInWithOAuth(provider, redirectTo: redirectTo);

  Future<void> signOut() => _client.auth.signOut();
}
