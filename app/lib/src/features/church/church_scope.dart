import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';

/// Loads the church named in the address and builds the page for it.
class ChurchScope extends ConsumerWidget {
  const ChurchScope({super.key, required this.slug, required this.builder});

  final String slug;
  final Widget Function(Church church) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return ref.watch(churchProvider(slug)).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => ChurchMessage(text: l.loadError, style: text.bodyLarge),
          data: (church) => church == null ? ChurchMessage(text: l.churchNotFound, style: text.bodyLarge) : builder(church),
        );
  }
}

/// A full-page message with a way back home.
class ChurchMessage extends StatelessWidget {
  const ChurchMessage({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: AppLocalizations.of(context)!.back,
            onPressed: () => context.go('/'),
          ),
        ),
        body: PageBody(children: [Text(text, style: style)]),
      );
}
