import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/core/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Church.fromJson reads the columns', () {
    final c = Church.fromJson({
      'id': 'c1',
      'slug': 'grace',
      'name': 'Grace Church',
      'default_sermon_language': 'ko',
      'default_output_language': 'en',
      'default_bible_version_code': 'NIV',
      'default_devotional_days': 5,
      'monthly_sermon_limit': 8,
    });
    expect(c.id, 'c1');
    expect(c.slug, 'grace');
    expect(c.name, 'Grace Church');
    expect(c.defaultSermonLanguage, 'ko');
    expect(c.defaultOutputLanguage, 'en');
    expect(c.defaultBibleVersionCode, 'NIV');
    expect(c.defaultDevotionalDays, 5);
    expect(c.monthlySermonLimit, 8);
  });

  test('ChurchRole.parse and canEdit', () {
    expect(ChurchRole.parse('editor')!.canEdit, isTrue);
    expect(ChurchRole.parse('owner')!.canEdit, isTrue);
    expect(ChurchRole.parse('member')!.canEdit, isFalse);
    expect(ChurchRole.parse('x'), isNull);
    expect(ChurchRole.parse(null), isNull);
  });

  test('Membership and Person parse rows', () {
    final m = Membership.fromJson({
      'role': 'owner',
      'churches': {'id': 'c1', 'slug': 'g', 'name': 'G'},
    });
    expect(m.role, ChurchRole.owner);
    expect(m.church.slug, 'g');
    final p = Person.fromJson({
      'user_id': 'u1',
      'name': 'Ann',
      'email': 'a@b.c',
      'role': 'member',
      'joined_at': '2026-01-02T03:04:05Z',
    });
    expect(p.userId, 'u1');
    expect(p.role, ChurchRole.member);
    expect(p.joinedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
  });

  test('SelahError.fromException finds known codes', () {
    expect(SelahError.fromException(const PostgrestException(message: 'monthly_limit_reached')), 'monthly_limit_reached');
    expect(SelahError.fromException(const PostgrestException(message: 'boom')), isNull);
    expect(SelahError.fromException(Exception('x')), isNull);
  });

  test('ChurchRequest.fromJson parses each status and a null note', () {
    for (final status in ChurchRequestStatus.values) {
      final r = ChurchRequest.fromJson({
        'id': 'r1',
        'church_name': 'Grace Church',
        'note': null,
        'status': status.name,
        'created_at': '2026-10-30T12:00:00Z',
      });
      expect(r.status, status);
      expect(r.note, isNull);
      expect(r.requesterEmail, isNull);
      expect(r.churchName, 'Grace Church');
      expect(r.createdAt, DateTime.utc(2026, 10, 30, 12));
    }
  });

  test('ChurchRequest.fromJson reads the requester email of pending rows', () {
    final r = ChurchRequest.fromJson({
      'id': 'r2',
      'church_name': 'Hope',
      'note': 'We meet on Sundays',
      'status': 'pending',
      'created_at': '2026-10-30T12:00:00Z',
      'requester_email': 'pastor@example.com',
    });
    expect(r.note, 'We meet on Sundays');
    expect(r.requesterEmail, 'pastor@example.com');
  });

  test('SelahError reads the request codes', () {
    expect(SelahError.fromException(const PostgrestException(message: 'request_pending_exists')), 'request_pending_exists');
    expect(SelahError.fromException(const PostgrestException(message: 'request_not_pending')), 'request_not_pending');
  });

  test('Church.fromJson reads the calendar columns and defaults the timezone', () {
    final bare = Church.fromJson({'id': 'c1', 'slug': 'grace', 'name': 'Grace Church'});
    expect(bare.eventsCalendarUrl, isNull);
    expect(bare.timezone, 'Europe/Madrid');
    expect(bare.eventsSyncedAt, isNull);
    expect(bare.eventsSyncError, isNull);
    final c = Church.fromJson({
      'id': 'c1',
      'slug': 'grace',
      'name': 'Grace Church',
      'events_calendar_url': 'https://grace.org/cal.ics',
      'timezone': 'Europe/Lisbon',
      'events_synced_at': '2026-11-05T09:00:00+00:00',
      'events_sync_error': 'blocked',
    });
    expect(c.eventsCalendarUrl, 'https://grace.org/cal.ics');
    expect(c.timezone, 'Europe/Lisbon');
    expect(c.eventsSyncedAt, DateTime.utc(2026, 11, 5, 9));
    expect(c.eventsSyncError, 'blocked');
  });

  test('ChurchEvent.fromJson keeps the church wall clock', () {
    final e = ChurchEvent.fromJson({
      'uid': 'u1',
      'title': 'Reunión de Mujeres',
      'starts_at': '2026-11-14T16:30:00+00:00',
      'ends_at': '2026-11-14T18:30:00+00:00',
      'all_day': false,
      'local_starts_at': '2026-11-14T17:30:00',
      'local_ends_at': '2026-11-14T19:30:00',
      'location': 'ICP Alcorcón',
      'url': 'https://icpresbiteriana.com/event/x/',
      'timezone': 'Europe/Madrid',
    });
    expect(e.uid, 'u1');
    expect(e.title, 'Reunión de Mujeres');
    expect(e.startsAt, DateTime.utc(2026, 11, 14, 16, 30));
    expect(e.localStart, DateTime(2026, 11, 14, 17, 30));
    expect(e.localStart.isUtc, isFalse);
    expect(e.localEnd, DateTime(2026, 11, 14, 19, 30));
    expect(e.allDay, isFalse);
    expect(e.location, 'ICP Alcorcón');
    expect(e.url, Uri.parse('https://icpresbiteriana.com/event/x/'));
  });

  test('ChurchEvent.fromJson without a url or location', () {
    final e = ChurchEvent.fromJson({
      'uid': 'u2',
      'title': 'Retiro',
      'starts_at': '2026-11-19T23:00:00+00:00',
      'ends_at': '2026-11-20T23:00:00+00:00',
      'all_day': true,
      'local_starts_at': '2026-11-20T00:00:00',
      'local_ends_at': '2026-11-21T00:00:00',
      'location': null,
      'url': null,
      'timezone': 'Europe/Madrid',
    });
    expect(e.url, isNull);
    expect(e.location, isNull);
    expect(e.allDay, isTrue);
  });
}
