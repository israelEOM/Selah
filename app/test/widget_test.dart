import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/core/models.dart';

void main() {
  test('StudyCard reads the joined sermon and falls back to the channel name', () {
    final card = StudyCard.fromJson({
      'id': '1',
      'slug': 'confiando-en-dios',
      'title': 'Confiando en Dios',
      'number_of_days': 5,
      'published_at': '2026-10-11T10:00:00Z',
      'sermons': {'thumbnail_url': 'https://i.ytimg.com/vi/x/hqdefault.jpg', 'preacher': null, 'channel': 'Iglesia'},
    });
    expect(card.preacher, 'Iglesia');
    expect(card.numberOfDays, 5);
    expect(card.publishedAt, isNotNull);
  });
}
