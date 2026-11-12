import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/design/art.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/l10n/locale.dart';

const _lib = [
  ArtEntry(key: 'hillside-dawn', tags: ['dawn'], pickable: true, alt: {'en': 'Hills', 'es': 'Colinas', 'pt': 'Colinas'}),
  ArtEntry(key: 'vine-grapes', tags: ['vine'], pickable: true, alt: {'en': 'A vine', 'es': 'Una vid', 'pt': 'Uma videira'}),
  ArtEntry(key: 'oil-lamp', tags: ['lamp'], pickable: true, alt: {'en': 'A lamp', 'es': 'Una lámpara', 'pt': 'Uma lâmpada'}),
  ArtEntry(key: 'scene-welcome', tags: [], pickable: false, alt: {'en': 'Welcome', 'es': 'Bienvenida', 'pt': 'Boas-vindas'}),
];

/// A 1x1 PNG, served for every library picture, so a picture can really load in a test.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

class _PicturesBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      key.endsWith('.webp') ? ByteData.sublistView(Uint8List.fromList(_png)) : rootBundle.load(key);
}

/// Pumps [child] with the library's pictures available, and lets one decode.
Future<void> _pumpLoaded(WidgetTester tester, Widget child, {String language = 'en'}) async {
  await _pump(tester, DefaultAssetBundle(bundle: _PicturesBundle(), child: child), language: language);
  await tester.pumpAndSettle();
  for (var i = 0; i < 5 && find.byType(ArtPlaceholder).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

Future<void> _pump(WidgetTester tester, Widget child, {String language = 'en', bool reduceMotion = false}) =>
    tester.pumpWidget(ProviderScope(
      overrides: [
        artLibraryProvider.overrideWith((ref) async => _lib),
        savedLanguageProvider.overrideWithValue(language),
      ],
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
        home: Scaffold(body: Center(child: child)),
      ),
    ));

void main() {
  test('a known pickable key resolves to itself', () => expect(resolveArtKey('vine-grapes', 's', _lib), 'vine-grapes'));

  test('an unknown or null key resolves to the same pickable key for the same seed', () {
    expect(resolveArtKey('nope', 'study-1', _lib), resolveArtKey(null, 'study-1', _lib));
    expect(resolveArtKey('', 'study-1', _lib), resolveArtKey(null, 'study-1', _lib));
    expect(_lib.where((e) => e.pickable).map((e) => e.key), contains(resolveArtKey(null, 'study-1', _lib)));
  });

  test('the pick is a stable FNV-1a hash of the seed', () {
    // FNV-1a 32-bit of "a" is 0xE40C292C; 3 pickable entries.
    expect(resolveArtKey(null, 'a', _lib), _lib[0xE40C292C % 3].key);
  });

  test('a fixed scene is never picked for a study', () => expect(resolveArtKey('scene-welcome', 'x', _lib), isNot('scene-welcome')));

  test('an empty library resolves to an empty key', () => expect(resolveArtKey(null, 'x', const []), ''));

  test('the bundled manifest parses and every entry has alt text in en, es and pt', () {
    final json = jsonDecode(File('assets/art/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    expect((json['style'] as String).trim(), isNotEmpty);
    final entries = [for (final e in json['images'] as List) ArtEntry.fromJson(e as Map<String, dynamic>)];
    expect(entries.where((e) => e.pickable).length, inInclusiveRange(30, 40));
    expect(entries.map((e) => e.key).toSet().length, entries.length);
    for (final key in ['scene-welcome', 'scene-signin', 'scene-invite', 'scene-churches', 'scene-empty-studies', 'scene-empty-events']) {
      expect(entries.singleWhere((e) => e.key == key).pickable, isFalse);
    }
    for (final e in entries) {
      for (final lang in ['en', 'es', 'pt']) {
        expect(e.alt[lang]?.trim(), isNotEmpty, reason: '${e.key} lacks $lang alt text');
      }
      if (e.pickable) expect(e.tags, isNotEmpty, reason: '${e.key} has no tags');
    }
  });

  testWidgets('SelahArt shows a placeholder when the image file is missing', (tester) async {
    await _pump(tester, const SelahArt(artKey: 'vine-grapes', seed: 's', width: 100, height: 80));
    await tester.pumpAndSettle();
    expect(find.byType(ArtPlaceholder), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decorative SelahArt shows nothing, not a placeholder, until its file exists', (tester) async {
    await _pump(tester, const SelahArt(artKey: 'vine-grapes', seed: 's', width: 100, height: 80, placeholder: false));
    await tester.pumpAndSettle();
    expect(find.byType(ArtPlaceholder), findsNothing);
    expect(find.byType(RawImage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SelahArt falls back for an unknown key and a null key', (tester) async {
    await _pump(tester, const Column(children: [
      SelahArt(artKey: 'nope', seed: 's', width: 50, height: 50),
      SelahArt(seed: 's', width: 50, height: 50),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(ArtPlaceholder), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SelahArt labels itself with the alt text in the app language once the picture shows', (tester) async {
    await _pumpLoaded(tester, const SelahArt(artKey: 'vine-grapes', seed: 's', width: 100, height: 80), language: 'es');
    expect(find.byType(ArtPlaceholder), findsNothing);
    expect(find.bySemanticsLabel('Una vid'), findsOneWidget);
  });

  testWidgets('a placeholder standing in for a missing picture has no alt text', (tester) async {
    await _pump(tester, const SelahArt(artKey: 'vine-grapes', seed: 's', width: 100, height: 80), language: 'es');
    await tester.pumpAndSettle();
    expect(find.byType(ArtPlaceholder), findsOneWidget);
    expect(find.bySemanticsLabel('Una vid'), findsNothing);
  });

  testWidgets('SelahArt is a Hero only when given a tag and Reduce Motion is off', (tester) async {
    await _pump(tester, const SelahArt(seed: 's', width: 50, height: 50, heroTag: 'tag'));
    await tester.pumpAndSettle();
    expect(find.byType(Hero), findsOneWidget);
    await _pump(tester, const SelahArt(seed: 's', width: 50, height: 50, heroTag: 'tag'), reduceMotion: true);
    await tester.pumpAndSettle();
    expect(find.byType(Hero), findsNothing);
    await _pump(tester, const SelahArt(seed: 's', width: 50, height: 50));
    await tester.pumpAndSettle();
    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('a fixed scene keeps its key instead of being swapped for a pickable one', (tester) async {
    await _pumpLoaded(tester, const SelahArt(artKey: 'scene-welcome', fixed: true, seed: 's', width: 100, height: 80), language: 'es');
    expect(find.bySemanticsLabel('Bienvenida'), findsOneWidget);
    await _pumpLoaded(tester, const SelahArt(artKey: 'scene-welcome', seed: 's', width: 100, height: 80), language: 'es');
    expect(find.bySemanticsLabel('Bienvenida'), findsNothing);
  });

  testWidgets('the circle shape clips round', (tester) async {
    await _pump(tester, const SelahArt(seed: 's', width: 50, height: 50, shape: ArtShape.circle));
    await tester.pumpAndSettle();
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('the placeholder is the same for the same seed', (tester) async {
    List<Color> colours() {
      final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(ArtPlaceholder), matching: find.byType(DecoratedBox)).first);
      return ((box.decoration as BoxDecoration).gradient as LinearGradient).colors;
    }

    await _pump(tester, const ArtPlaceholder(seed: 'abc'));
    final first = colours();
    await _pump(tester, const ArtPlaceholder(seed: 'abc'));
    expect(colours(), first);
  });

  test('art tags differ by kind and match by id', () {
    expect(studyArtTag('1'), studyArtTag('1'));
    expect(studyArtTag('1'), isNot(churchArtTag('1')));
  });

  test('models read art_key', () {
    final study = PublicStudy.fromJson({
      'id': 's',
      'slug': 'x',
      'title': 'T',
      'number_of_days': 1,
      'bible_version_code': 'NIV',
      'art_key': 'vine-grapes',
      'sermons': {'youtube_video_id': 'v'},
      'devotional_days': [
        {'day_number': 1, 'title': 'D', 'art_key': 'oil-lamp', 'questions': <String>[]},
      ],
    });
    expect(study.artKey, 'vine-grapes');
    expect(study.days.single.artKey, 'oil-lamp');
    final card = StudyCard.fromJson({'id': 's', 'slug': 'x', 'title': 'T', 'number_of_days': 1, 'art_key': 'dove'});
    expect(card.artKey, 'dove');
    expect(StudyCard.fromJson({'id': 's', 'slug': 'x', 'title': 'T', 'number_of_days': 1}).artKey, isNull);
  });
}
