import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/core/models.dart';

Map<String, dynamic> _day(int n, String title) => {
      'day_number': n,
      'title': title,
      'bible_reading': 'Psalm 27:$n',
      'questions': ['Question $n?'],
    };

Map<String, dynamic> _studyJson() => {
      'id': 'study-1',
      'slug': 'retiro-espiritual',
      'title': 'La necesidad del retiro espiritual',
      'central_message': 'Mensaje central',
      'number_of_days': 2,
      'bible_version_code': 'RVR1960',
      'output_language': 'es',
      'summary': {'introduction': 'Introducción'},
      'sermons': {'youtube_video_id': 'Bflib6PHb68'},
      'devotional_days': [
        {'day_number': 1, 'title': 'Día uno', 'questions': <String>[]},
      ],
      'study_translations': [
        {
          'id': 't-1',
          'study_id': 'study-1',
          'language': 'en',
          'title': 'The need for spiritual retreat',
          'central_message': 'Central message',
          'summary': {'introduction': 'Introduction'},
          'days': [_day(2, 'Day two'), _day(1, 'Day one')],
          'bible_version_code': 'NIV',
        },
      ],
    };

void main() {
  test('localizedTo returns the translation', () {
    final localized = PublicStudy.fromJson(_studyJson()).localizedTo('en');
    expect(localized.title, 'The need for spiritual retreat');
    expect(localized.centralMessage, 'Central message');
    expect(localized.summary['introduction'], 'Introduction');
    expect(localized.translatedFrom, 'es');
    expect(localized.bibleVersionCode, 'NIV');
    expect(localized.days.first.title, 'Day one');
    expect(localized.days.map((d) => d.number), [1, 2]);
    expect(localized.id, 'study-1');
    expect(localized.sermon.videoId, 'Bflib6PHb68');
  });

  test('localizedTo the original language returns the original', () {
    final study = PublicStudy.fromJson(_studyJson());
    expect(identical(study.localizedTo('es'), study), isTrue);
    expect(study.localizedTo('es').translatedFrom, isNull);
  });

  test('localizedTo a missing language returns the original', () {
    final study = PublicStudy.fromJson(_studyJson());
    expect(study.localizedTo('pt').translatedFrom, isNull);
    expect(study.localizedTo('pt').title, study.title);
  });

  test('rows without translations or output_language still parse', () {
    final json = _studyJson()
      ..remove('study_translations')
      ..remove('output_language');
    final study = PublicStudy.fromJson(json);
    expect(study.outputLanguage, 'es');
    expect(study.translations, isEmpty);
  });

  test('StudyCard.localizedTo swaps the title', () {
    final card = StudyCard.fromJson({
      'id': '1',
      'slug': 's',
      'title': 'Título',
      'number_of_days': 3,
      'study_translations': [
        {'language': 'en', 'title': 'Title', 'central_message': 'Msg'},
      ],
    });
    expect(card.localizedTo('en').title, 'Title');
    expect(card.localizedTo('pt').title, 'Título');
  });
}
