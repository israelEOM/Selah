import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/providers.dart';
import 'theme.dart';

/// Rebuilds [builder] whenever the app starts or stops showing saved data (see `OfflineStatus`).
class OfflineAware extends ConsumerWidget {
  const OfflineAware({super.key, required this.builder});

  final Widget Function(BuildContext context, bool offline) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(offlineStatusProvider);
    return ListenableBuilder(listenable: status, builder: (context, _) => builder(context, status.offline));
  }
}

/// A quiet line at the top while the app shows saved data because it can't reach the server; nothing otherwise.
/// In the app layout it sits under the status bar and takes the top inset itself.
class OfflineNote extends StatelessWidget {
  const OfflineNote({super.key});

  @override
  Widget build(BuildContext context) => OfflineAware(builder: (context, offline) {
        if (!offline) return const SizedBox.shrink();
        final tones = context.tones;
        return ColoredBox(
          color: tones.surface,
          child: SafeArea(
            top: !siteLayout(context),
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                AppLocalizations.of(context)!.offlineNote,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tones.muted),
              ),
            ),
          ),
        );
      });
}
