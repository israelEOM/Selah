import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/locale.dart';
import 'platform.dart';
import 'tokens.dart';

/// One illustration in `assets/art/manifest.json`. Its picture lives at `assets/art/<key>.webp`.
class ArtEntry {
  const ArtEntry({required this.key, required this.tags, required this.pickable, required this.alt});

  factory ArtEntry.fromJson(Map<String, dynamic> json) => ArtEntry(
        key: json['key'] as String,
        tags: List<String>.from(json['tags'] as List? ?? const []),
        pickable: json['pickable'] as bool? ?? false,
        alt: Map<String, String>.from(json['alt'] as Map? ?? const {}),
      );

  final String key;

  /// Theme words the worker matches a study or day against.
  final List<String> tags;

  /// False for the fixed scenes (welcome, empty states) that are never picked for a study.
  final bool pickable;

  /// A short description of the picture, by language code.
  final Map<String, String> alt;
}

/// The bundled illustration manifest.
final artLibraryProvider = FutureProvider<List<ArtEntry>>((ref) async {
  final json = jsonDecode(await rootBundle.loadString('assets/art/manifest.json')) as Map<String, dynamic>;
  return [for (final e in (json['images'] as List).cast<Map<String, dynamic>>()) ArtEntry.fromJson(e)];
});

/// 32-bit FNV-1a over the UTF-8 bytes of [text]. Unlike `String.hashCode` it never changes between runs or platforms.
int _fnv1a(String text) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(text)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// [key] when it names a pickable entry, otherwise a pickable entry chosen from [seed], the same one every time.
/// Returns an empty string when the library has nothing pickable (not loaded yet).
String resolveArtKey(String? key, String seed, List<ArtEntry> library) {
  final pickable = [for (final e in library) if (e.pickable) e];
  if (pickable.isEmpty) return '';
  if (key != null && pickable.any((e) => e.key == key)) return key;
  return pickable[_fnv1a(seed) % pickable.length].key;
}

/// Shared-element tag for a study's art, from its card to its page.
Object studyArtTag(String studyId) => 'study-art-$studyId';

/// Shared-element tag for a church's art.
Object churchArtTag(String churchId) => 'church-art-$churchId';

enum ArtShape { rounded, circle }

/// An illustration from the library. Shows [artKey], or a pick from [seed] when the key is missing or unknown, and a
/// calm generated placeholder while the picture is loading or when its file has not been added yet.
class SelahArt extends ConsumerWidget {
  const SelahArt({
    super.key,
    this.artKey,
    required this.seed,
    this.shape = ArtShape.rounded,
    this.width,
    this.height,
    this.heroTag,
    this.fixed = false,
    this.radius = Radii.card,
  });

  final String? artKey;
  final String seed;
  final ArtShape shape;
  final double? width;
  final double? height;

  /// Makes the art a [Hero] with this tag, unless Reduce Motion is on.
  final Object? heroTag;

  /// A fixed scene (welcome, empty states): [artKey] is used as given instead of being checked against the pickable
  /// library, so these scenes are never swapped for a study picture.
  final bool fixed;

  /// The corner radius of a [ArtShape.rounded] picture.
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(artLibraryProvider).value ?? const <ArtEntry>[];
    final resolved = fixed ? (artKey ?? '') : resolveArtKey(artKey, seed, library);
    final entry = library.where((e) => e.key == resolved).firstOrNull;
    final language = ref.watch(appLocaleProvider).languageCode;
    final placeholder = ArtPlaceholder(seed: seed);
    final label = entry?.alt[language] ?? entry?.alt['en'];
    // Only a picture that has really shown carries its alt text; the placeholder standing in for it says nothing.
    Widget labelled(Widget picture) =>
        label == null ? picture : Semantics(label: label, image: true, excludeSemantics: true, child: picture);

    Widget art = resolved.isEmpty
        ? placeholder
        : Image.asset(
            'assets/art/$resolved.webp',
            fit: BoxFit.cover,
            width: width,
            height: height,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => placeholder,
            frameBuilder: (context, child, frame, sync) => frame == null && !sync ? placeholder : labelled(child),
          );
    art = switch (shape) {
      ArtShape.circle => ClipOval(child: art),
      ArtShape.rounded => ClipRRect(borderRadius: BorderRadius.circular(radius), child: art),
    };
    art = SizedBox(width: width, height: height, child: art);
    if (heroTag != null && !reduceMotion(context)) art = Hero(tag: heroTag!, child: art);
    return art;
  }
}

// Pale paper, sage and sand tints, all close to the app's palette. Light and dark stay calm because they are soft.
const _placeholderColours = [
  Color(0xFFF3EEE2), // paper
  Color(0xFFE6EEE8), // sage tint
  Color(0xFFD3E2D8), // sage soft
  Color(0xFFEADFCB), // sand
  Color(0xFFE0D2B8), // deeper sand
  Color(0xFFC9D8CC), // sage
];

/// The picture shown until a library image exists: a two-colour gradient and a soft sun, the same for the same [seed].
class ArtPlaceholder extends StatelessWidget {
  const ArtPlaceholder({super.key, required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final hash = _fnv1a(seed);
    final from = _placeholderColours[hash % _placeholderColours.length];
    // Step by 1..5 so the second colour always differs from the first.
    final to = _placeholderColours[(hash % _placeholderColours.length + 1 + (hash >> 8) % (_placeholderColours.length - 1)) %
        _placeholderColours.length];
    final sun = Alignment(((hash >> 16) % 100) / 100 * 1.2 - 0.6, -0.45);
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [from, to]),
            ),
          ),
          Align(
            alignment: sun,
            child: FractionallySizedBox(
              widthFactor: 0.3,
              child: AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
