import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';

/// All data access goes through here. Row-level security decides what each caller may see.
class SelahRepository {
  SelahRepository(this._client);

  final SupabaseClient _client;

  /// A church's published studies, newest first.
  Future<List<StudyCard>> publishedStudies(String churchId) async {
    final rows = await _client
        .from('studies')
        .select('id, slug, title, number_of_days, central_message, published_at, '
            'sermons!studies_sermon_id_fkey(thumbnail_url, preacher, channel, sermon_date), '
            'study_translations(language, title, central_message)')
        .eq('church_id', churchId)
        .eq('status', 'published')
        .order('published_at', ascending: false);
    return rows.map(StudyCard.fromJson).toList();
  }

  /// A published study with its sermon and days, or null when there is none to show.
  Future<PublicStudy?> studyBySlug(String churchId, String slug) async {
    final row = await _client
        .from('studies')
        .select('id, slug, title, number_of_days, bible_version_code, output_language, summary, central_message, published_at, '
            'sermons!studies_sermon_id_fkey(youtube_video_id, title, preacher, channel, thumbnail_url, sermon_date), devotional_days(*), study_translations(*)')
        .eq('church_id', churchId)
        .eq('slug', slug)
        .eq('status', 'published')
        .maybeSingle();
    return row == null ? null : PublicStudy.fromJson(row);
  }

  /// A church's most recently published study, or null when it has none.
  Future<PublicStudy?> newestStudy(String churchId) async {
    final row = await _client
        .from('studies')
        .select('id, slug, title, number_of_days, bible_version_code, output_language, summary, central_message, published_at, '
            'sermons!studies_sermon_id_fkey(youtube_video_id, title, preacher, channel, thumbnail_url, sermon_date), devotional_days(*), study_translations(*)')
        .eq('church_id', churchId)
        .eq('status', 'published')
        .order('published_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : PublicStudy.fromJson(row);
  }

  /// The slug of the church that owns the oldest study with [slug], for links made before churches existed.
  Future<String?> legacyStudyChurch(String slug) async {
    final row = await _client
        .from('studies')
        .select('churches(slug)')
        .eq('slug', slug)
        .eq('status', 'published')
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    return (row?['churches'] as Map<String, dynamic>?)?['slug'] as String?;
  }

  Future<bool> isPlatformAdmin(String userId) async {
    final row = await _client.from('profiles').select('is_platform_admin').eq('id', userId).maybeSingle();
    return row?['is_platform_admin'] == true;
  }

  Future<List<SermonRow>> sermons(String churchId) async {
    final rows = await _client
        .from('sermons')
        .select('id, title, youtube_url, thumbnail_url, studies!studies_sermon_id_fkey(status)')
        .eq('church_id', churchId)
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
  Future<String> createJob(String step, Map<String, dynamic> payload, {required String churchId, String? sermonId}) async {
    final row = await _client
        .from('jobs')
        .insert({
          'church_id': churchId,
          'step': step,
          'payload': payload,
          'sermon_id': sermonId,
          'created_by': _client.auth.currentUser!.id,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> saveSermon(String churchId, Map<String, dynamic> fields) async {
    final row = await _client
        .from('sermons')
        .upsert({...fields, 'church_id': churchId, 'created_by': _client.auth.currentUser!.id},
            onConflict: 'church_id,youtube_video_id')
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Channels a church imported from before, most recently used first.
  Future<List<Map<String, dynamic>>> recentChannels(String churchId) => _client
      .from('youtube_channels')
      .select()
      .eq('church_id', churchId)
      .order('last_used_at', ascending: false)
      .limit(8);

  Future<void> rememberChannel(String churchId, Map<String, dynamic> channel) => _client.from('youtube_channels').upsert({
        'church_id': churchId,
        'channel_id': channel['channel_id'],
        'title': channel['title'],
        'handle': channel['handle'],
        'thumbnail_url': channel['thumbnail_url'],
        'last_used_at': DateTime.now().toUtc().toIso8601String(),
      });

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

  // Churches ------------------------------------------------------------------

  Future<Church?> churchBySlug(String slug) async {
    final row = await _client.from('churches').select().eq('slug', slug).maybeSingle();
    return row == null ? null : Church.fromJson(row);
  }

  /// Churches the signed-in user belongs to.
  Future<List<Membership>> myChurches() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client.from('church_members').select('role, churches(*)').eq('user_id', userId);
    return rows.map(Membership.fromJson).toList();
  }

  /// Churches with at least one published study, by name.
  Future<List<Church>> publicChurches() async {
    final rows = await _client
        .from('churches')
        .select('*, studies!inner(id)')
        .eq('studies.status', 'published')
        .order('name', ascending: true);
    final seen = <String>{};
    return [
      for (final row in rows)
        if (seen.add(row['id'] as String)) Church.fromJson(row),
    ];
  }

  Future<ChurchRole?> roleIn(String churchId) async {
    if (_client.auth.currentUser == null) return null;
    final role = await _client.rpc('church_role_of', params: {'p_church': churchId});
    return ChurchRole.parse(role as String?);
  }

  Future<int> sermonsThisMonth(String churchId) async =>
      (await _client.rpc('sermons_this_month', params: {'p_church': churchId}) as num).toInt();

  Future<Church> createChurch(String name, String slug) async {
    final row = await _client.rpc('create_church', params: {'p_name': name, 'p_slug': slug});
    return Church.fromJson(row as Map<String, dynamic>);
  }

  Future<ChurchRequest> requestChurch(String name, String? note) async {
    final row = await _client.rpc('request_church', params: {'p_name': name, 'p_note': note});
    return ChurchRequest.fromJson(row as Map<String, dynamic>);
  }

  /// The signed-in user's newest request, or null.
  Future<ChurchRequest?> myLatestChurchRequest() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('church_requests')
        .select()
        .eq('requested_by', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : ChurchRequest.fromJson(row);
  }

  Future<List<ChurchRequest>> pendingChurchRequests() async {
    final rows = await _client.rpc('pending_church_requests') as List;
    return [for (final r in rows) ChurchRequest.fromJson(r as Map<String, dynamic>)];
  }

  Future<void> decideChurchRequest(String id, {required bool approve, String? slug}) =>
      _client.rpc('decide_church_request', params: {'p_request': id, 'p_approve': approve, 'p_slug': slug});

  Future<void> updateChurch(String churchId, Map<String, dynamic> fields) =>
      _client.from('churches').update(fields).eq('id', churchId);

  Future<String> createInvite(String churchId, ChurchRole role) async =>
      await _client.rpc('create_invite', params: {'p_church': churchId, 'p_role': role.name}) as String;

  Future<void> revokeInvite(String token) => _client.rpc('revoke_invite', params: {'p_token': token});

  /// Active invites (not revoked) for a church. Owners only.
  Future<List<Map<String, dynamic>>> invites(String churchId) => _client
      .from('church_invites')
      .select()
      .eq('church_id', churchId)
      .isFilter('revoked_at', null)
      .order('created_at', ascending: false);

  /// What an invite is for, or null when the link is no longer valid.
  Future<({String churchName, String churchSlug, ChurchRole role})?> inviteInfo(String token) async {
    final rows = await _client.rpc('invite_info', params: {'p_token': token}) as List;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return (
      churchName: row['church_name'] as String,
      churchSlug: row['church_slug'] as String,
      role: ChurchRole.parse(row['role'] as String?) ?? ChurchRole.member,
    );
  }

  /// Returns the slug of the church joined.
  Future<String> acceptInvite(String token) async =>
      await _client.rpc('accept_invite', params: {'p_token': token}) as String;

  Future<void> joinChurch(String churchId) => _client.rpc('join_church', params: {'p_church': churchId});

  Future<List<Person>> people(String churchId) async {
    final rows = await _client.rpc('church_people', params: {'p_church': churchId}) as List;
    return rows.cast<Map<String, dynamic>>().map(Person.fromJson).toList();
  }

  Future<void> setMemberRole(String churchId, String userId, ChurchRole role) =>
      _client.rpc('set_member_role', params: {'p_church': churchId, 'p_user': userId, 'p_role': role.name});

  Future<void> removeMember(String churchId, String userId) =>
      _client.rpc('remove_member', params: {'p_church': churchId, 'p_user': userId});

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
      _client.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
        // In the app, Safari carries the sign-in and hands back through the app's link.
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );

  Future<void> signOut() => _client.auth.signOut();
}
