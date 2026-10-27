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
}
