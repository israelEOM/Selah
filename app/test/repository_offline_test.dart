import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selah/src/data/offline.dart';
import 'package:selah/src/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _card(String id, String slug) => {
      'id': id,
      'slug': slug,
      'title': 'Study $slug',
      'number_of_days': 2,
      'published_at': '2026-10-18T10:00:00Z',
      'created_at': '2026-10-18T09:00:00Z',
      'sermons': {'thumbnail_url': null},
      'study_translations': <Map<String, dynamic>>[],
    };

Map<String, dynamic> _study(String slug) => {
      'id': 'study-$slug',
      'slug': slug,
      'title': 'Seguir a Jesús',
      'number_of_days': 2,
      'bible_version_code': 'RVR1960',
      'output_language': 'es',
      'published_at': '2026-10-18T10:00:00Z',
      'summary': <String, dynamic>{},
      'sermons': {'youtube_video_id': 'v'},
      'devotional_days': [
        for (var n = 1; n <= 2; n++) {'day_number': n, 'title': 'Día $n', 'questions': <String>[]},
      ],
      'study_translations': <Map<String, dynamic>>[],
    };

Map<String, dynamic> _event(String uid, String endsAt) => {
      'uid': uid,
      'title': 'Event $uid',
      'starts_at': '1999-01-01T10:00:00Z',
      'ends_at': endsAt,
      'local_starts_at': '1999-01-01T10:00:00',
      'local_ends_at': '1999-01-01T11:00:00',
    };

void main() {
  late bool online;
  late List<Uri> requests;

  /// What the server answers per table while [online].
  late Map<String, Object? Function(Uri)> tables;

  late OfflineStore store;
  late OfflineStatus status;
  late SelahRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    online = true;
    requests = [];
    tables = {};
    store = OfflineStore();
    status = OfflineStatus();
    final client = MockClient((request) async {
      requests.add(request.url);
      if (!online) throw http.ClientException('offline', request.url);
      final table = request.url.pathSegments.last;
      final answer = tables[table];
      if (answer == null) return http.Response('', 204, request: request);
      return http.Response(jsonEncode(answer(request.url)), 200,
          headers: {'content-type': 'application/json'}, request: request);
    });
    repo = SelahRepository(
      SupabaseClient('https://x.supabase.co', 'key',
          httpClient: client,
          authOptions: const AuthClientOptions(autoRefreshToken: false)),
      store: store,
      status: status,
    );
  });

  test('studies load offline after one online load', () async {
    tables['studies'] = (_) => [_card('s1', 'seguir')];
    expect((await repo.publishedStudies('A')).single.id, 's1');
    online = false;
    expect((await repo.publishedStudies('A')).single.id, 's1');
    expect(status.offline, isTrue);
  });

  test('an offline read falls back without retrying', () async {
    tables['studies'] = (_) => [_card('s1', 'seguir')];
    await repo.publishedStudies('A');
    online = false;
    requests.clear();
    await repo.publishedStudies('A');
    expect(requests, hasLength(1));
  });

  test('a study opens offline', () async {
    tables['studies'] = (_) => [_study('seguir')];
    expect((await repo.studyBySlug('A', 'seguir'))!.days, hasLength(2));
    online = false;
    expect((await repo.studyBySlug('A', 'seguir'))!.days, hasLength(2));
    expect(status.offline, isTrue);
  });

  test('null result removes saved copy', () async {
    tables['studies'] = (_) => [_study('seguir')];
    await repo.studyBySlug('A', 'seguir');
    tables['studies'] = (_) => <Object>[];
    expect(await repo.studyBySlug('A', 'seguir'), isNull);
    expect(await store.has('study:A:seguir'), isFalse);
    online = false;
    await expectLater(repo.studyBySlug('A', 'seguir'), throwsA(isA<http.ClientException>()));
  });

  test('offline events drop ended ones', () async {
    tables['church_events'] = (_) => [_event('old', '2000-01-01T00:00:00Z'), _event('new', '2100-01-01T00:00:00Z')];
    await repo.upcomingEvents('A');
    online = false;
    expect([for (final e in await repo.upcomingEvents('A')) e.uid], ['new']);
  });

  test('churches load offline', () async {
    tables['churches'] = (_) => [
          {'id': 'A', 'slug': 'vida', 'name': 'Vida'},
        ];
    await repo.churchBySlug('vida');
    await repo.publicChurches();
    online = false;
    expect((await repo.churchBySlug('vida'))!.id, 'A');
    expect((await repo.publicChurches()).single.slug, 'vida');
  });

  test('server errors do not fall back to the saved copy', () async {
    tables['studies'] = (_) => [_card('s1', 'seguir')];
    await repo.publishedStudies('A');
    tables.remove('studies');
    final failing = SelahRepository(
      SupabaseClient('https://x.supabase.co', 'key',
          httpClient: MockClient((request) async => http.Response('{"message":"denied","code":"42501"}', 401,
              headers: {'content-type': 'application/json'}, request: request)),
          postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
          authOptions: const AuthClientOptions(autoRefreshToken: false)),
      store: store,
      status: status,
    );
    await expectLater(failing.publishedStudies('A'), throwsA(isA<PostgrestException>()));
  });

  test('saves only missing studies', () async {
    tables['studies'] = (url) => url.queryParameters['slug'] == null
        ? [_card('s1', 'one'), _card('s2', 'two')]
        : [_study(url.queryParameters['slug']!.substring('eq.'.length))];
    await store.write('study:A:one', _study('one'));
    await repo.saveStudiesForOffline('A');
    expect([for (final u in requests) u.queryParameters['slug']].whereType<String>(), ['eq.two']);
    expect(await store.has('study:A:two'), isTrue);
  });

  test('saving offline does nothing and does not throw', () async {
    online = false;
    await repo.saveStudiesForOffline('A');
  });

  test('the website saves nothing ahead', () async {
    tables['studies'] = (_) => [_card('s1', 'one')];
    final web = SelahRepository(
      SupabaseClient('https://x.supabase.co', 'key',
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return http.Response(jsonEncode(tables['studies']!(request.url)), 200,
                headers: {'content-type': 'application/json'}, request: request);
          }),
          authOptions: const AuthClientOptions(autoRefreshToken: false)),
      store: store,
      status: status,
      saveAhead: false,
    );
    await web.saveStudiesForOffline('A');
    expect(requests, isEmpty);
  });

  test('an unpublished study is no longer kept', () async {
    await store.write('study:A:gone', _study('gone'));
    await store.write('study:A:kept', _study('kept'));
    await store.write('study:B:other', _study('other'));
    tables['studies'] = (_) => [_card('s1', 'kept')];
    await repo.publishedStudies('A');
    expect(await store.has('study:A:gone'), isFalse);
    expect(await store.has('study:A:kept'), isTrue);
    expect(await store.has('study:B:other'), isTrue);
  });

  test('the offline study list keeps every saved study', () async {
    tables['studies'] = (_) => [_card('s1', 'kept')];
    await repo.publishedStudies('A');
    await store.write('study:A:kept', _study('kept'));
    online = false;
    await repo.publishedStudies('A');
    expect(await store.has('study:A:kept'), isTrue);
  });

  test('signOut clears saved reads', () async {
    tables['studies'] = (_) => [_card('s1', 'seguir')];
    await repo.publishedStudies('A');
    await repo.signOut();
    expect(await store.has('studies:A'), isFalse);
  });
}
