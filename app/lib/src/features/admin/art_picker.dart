import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/design/art.dart';
import '../../app/design/tokens.dart';

/// Lets an admin choose an illustration. Returns the chosen key, or null when the sheet is dismissed.
Future<String?> showArtPicker(BuildContext context, {String? current}) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ArtPicker(current: current),
    );

class _ArtPicker extends ConsumerWidget {
  const _ArtPicker({this.current});

  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final library = ref.watch(artLibraryProvider).value ?? const <ArtEntry>[];
    final entries = [for (final e in library) if (e.pickable) e];
    final ring = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.pickImage, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.m),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: Space.s,
              crossAxisSpacing: Space.s,
              children: [
                for (final e in entries)
                  InkWell(
                    key: Key('art-tile-${e.key}'),
                    borderRadius: BorderRadius.circular(Radii.card),
                    onTap: () => Navigator.of(context).pop(e.key),
                    child: Container(
                      key: e.key == current ? const Key('art-current') : null,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.card + 3),
                        border: Border.all(color: e.key == current ? ring : Colors.transparent, width: 3),
                      ),
                      child: SelahArt(artKey: e.key, seed: e.key),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
