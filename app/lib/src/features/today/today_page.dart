import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/current_church.dart';
import '../home/church_picker_page.dart';

/// The Hoy tab. A placeholder with the church's name until the Today page lands; with no church
/// yet, the church list so the person can pick one.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return ref.watch(currentChurchProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(body: PageBody(children: [Text(l.loadError, style: text.bodyLarge)])),
          data: (church) => church == null
              ? Scaffold(
                  appBar: AppBar(title: Text(l.pickChurch)),
                  body: RefreshIndicator(
                    onRefresh: () => refreshChurches(ref),
                    child: const PageBody(children: [ChurchList()]),
                  ),
                )
              : Scaffold(body: PageBody(children: [Text(church.name, style: text.headlineMedium)])),
        );
  }
}
