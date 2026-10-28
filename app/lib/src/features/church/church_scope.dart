import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/current_church.dart';
import '../../data/providers.dart';

/// Loads the church named in the address and builds the page for it. The first church opened
/// on a device with none chosen becomes the app's church.
class ChurchScope extends ConsumerStatefulWidget {
  const ChurchScope({super.key, required this.slug, required this.builder});

  final String slug;
  final Widget Function(Church church) builder;

  @override
  ConsumerState<ChurchScope> createState() => _ChurchScopeState();
}

class _ChurchScopeState extends ConsumerState<ChurchScope> {
  void _chooseIfNone(Church church) {
    if (ref.read(chosenChurchSlugProvider) != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(chosenChurchSlugProvider) == null) {
        ref.read(chosenChurchSlugProvider.notifier).choose(church.slug);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return ref.watch(churchProvider(widget.slug)).when(
          loading: () => const SelahPage(backTo: '/', children: [SkeletonList(rows: 4)]),
          error: (_, _) => ChurchMessage(text: l.loadError, style: text.bodyLarge),
          data: (church) {
            if (church == null) return ChurchMessage(text: l.churchNotFound, style: text.bodyLarge);
            _chooseIfNone(church);
            return widget.builder(church);
          },
        );
  }
}

/// A full-page message with a way back home.
class ChurchMessage extends StatelessWidget {
  const ChurchMessage({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => SelahPage(
        backTo: '/',
        children: [Text(text, style: style)],
      );
}
