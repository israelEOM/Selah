// Runs the app on a made-up church with no backend, for the landing page's screenshots. Never part of the app build.
//
//   flutter build web -t tool/demo_main.dart -o build/demo
//   (then copy tool/demo_assets/*.png to build/demo/demo/ and index.html to app.html, and serve it with
//   tool/serve.py 3200 build/demo; add ?theme=light or ?theme=dark to an address to pin the look)
//
// Everything here is invented for the demo: the church, the studies and the events are not a real church's.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/app/theme_mode.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';

const _church = Church(id: 'demo', slug: 'esperanza', name: 'Iglesia Esperanza');

Map<String, dynamic> _day(int n, String title, String reading, String idea, String reflection) => {
      'day_number': n,
      'title': title,
      'bible_reading': reading,
      'main_idea': idea,
      'reflection': reflection,
      'application': 'Esta semana, aparta unos minutos cada mañana para leer el pasaje despacio y escribir una frase que quieras recordar.',
      'questions': ['¿Qué te dice este pasaje sobre quién es Dios?', '¿Qué paso concreto puedes dar hoy?'],
      'prayer': 'Señor, gracias por tu Palabra. Enséñame a escucharte y a seguirte hoy. Amén.',
      'start_seconds': null,
      'end_seconds': null,
    };

Map<String, dynamic> _study(String id, String slug, String title, String message, String thumb, List<Map<String, dynamic>> days) => {
      'id': id,
      'slug': slug,
      'title': title,
      'central_message': message,
      'number_of_days': days.length,
      'bible_version_code': 'RVR1960',
      'published_at': '2026-11-01T10:00:00Z',
      'summary': {
        'introduction': message,
        'main_passage': days.first['bible_reading'],
        'points': <Map<String, dynamic>>[],
        'key_takeaways': ['Dios habla por su Palabra.', 'Leerla cada día nos forma.'],
      },
      'sermons': {
        'youtube_video_id': 'demo',
        'title': title,
        'preacher': 'Equipo pastoral',
        'channel': 'Iglesia Esperanza',
        'thumbnail_url': thumb,
        'sermon_date': null,
      },
      'devotional_days': days,
    };

final _studies = [
  _study('s1', 'el-buen-pastor', 'El Señor es mi pastor', 'Dios cuida, guía y acompaña a los suyos en cada estación de la vida.', '/demo/thumb-1.png', [
    _day(1, 'Nada me faltará', 'Salmos 23:1-3', 'Quien tiene al Señor como pastor tiene lo que de verdad necesita.',
        'El salmista no describe una vida sin dificultades, sino una vida acompañada. Antes de pedir, reconoce quién lo guía. Hoy podemos empezar igual: recordando que no caminamos solos.'),
    _day(2, 'Aunque ande en valle de sombra', 'Salmos 23:4', 'La presencia de Dios no evita el valle, pero lo cambia.',
        'El tono del salmo cambia en el valle: deja de hablar de Dios y empieza a hablarle a Él. En los días difíciles, la oración se vuelve más cercana.'),
    _day(3, 'El bien y la misericordia me seguirán', 'Salmos 23:5-6', 'La historia del pueblo de Dios termina en su casa.',
        'El salmo termina con una certeza que mira hacia adelante. Lo que Dios empezó, lo termina.'),
  ]),
  _study('s2', 'permaneced-en-mi', 'Permaneced en mí', 'Una vida fructífera nace de estar unidos a Cristo.', '/demo/thumb-2.png', [
    _day(1, 'La vid verdadera', 'Juan 15:1-4', 'El fruto no se fabrica; crece cuando permanecemos.', 'Jesús usa una imagen sencilla: una rama vive mientras está unida a la vid.'),
    _day(2, 'Separados de mí', 'Juan 15:5-8', 'Sin Cristo no podemos dar fruto que permanezca.', 'Reconocer nuestra dependencia no es debilidad, es el comienzo del fruto.'),
  ]),
  _study('s3', 'la-paz-de-dios', 'La paz que sobrepasa todo entendimiento', 'La oración cambia nuestra manera de cargar las preocupaciones.', '/demo/thumb-3.png', [
    _day(1, 'Por nada estéis afanosos', 'Filipenses 4:6-7', 'La ansiedad se convierte en oración.', 'Pablo escribe desde una prisión y aun así habla de paz.'),
  ]),
];

StudyCard _card(Map<String, dynamic> s) => StudyCard(
      id: s['id'] as String,
      slug: s['slug'] as String,
      title: s['title'] as String,
      numberOfDays: s['number_of_days'] as int,
      centralMessage: s['central_message'] as String,
      thumbnailUrl: (s['sermons'] as Map)['thumbnail_url'] as String,
      preacher: 'Equipo pastoral',
    );

ChurchEvent _event(String title, DateTime start, int hours, String location) => ChurchEvent(
      uid: title,
      title: title,
      startsAt: start.toUtc(),
      endsAt: start.add(Duration(hours: hours)).toUtc(),
      localStart: start,
      localEnd: start.add(Duration(hours: hours)),
      allDay: false,
      location: location,
    );

class _DemoRepository implements SelahRepository {
  @override
  Future<Church?> churchBySlug(String slug) async => slug == _church.slug ? _church : null;

  @override
  Future<List<Church>> publicChurches() async => const [_church];

  @override
  Future<List<StudyCard>> publishedStudies(String churchId) async => [for (final s in _studies) _card(s)];

  @override
  Future<PublicStudy?> studyBySlug(String churchId, String slug) async {
    for (final s in _studies) {
      if (s['slug'] == slug) return PublicStudy.fromJson(s);
    }
    return null;
  }

  @override
  Future<PublicStudy?> newestStudy(String churchId) async => PublicStudy.fromJson(_studies.first);

  @override
  Future<List<ChurchEvent>> upcomingEvents(String churchId) async => [
        _event('Estudio bíblico en casas', DateTime(2026, 11, 11, 19), 2, 'Varias casas'),
        _event('Culto de oración', DateTime(2026, 11, 13, 20), 1, 'Templo'),
      ];

  @override
  Future<List<Map<String, dynamic>>> translations(String studyId) async => const [];

  @override
  Future<ChurchRole?> roleIn(String churchId) async => null;

  @override
  Future<List<Membership>> myChurches() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_DemoRepository()),
      userIdProvider.overrideWith((ref) => Stream.value(null)),
      currentChurchProvider.overrideWith((ref) async => _church),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 10, 8, 30)),
      // ?theme=light or ?theme=dark pins the look for screenshots, whatever the capturing browser prefers.
      savedThemeModeProvider.overrideWithValue(Uri.base.queryParameters['theme']),
    ],
    child: const SelahApp(),
  ));
}
