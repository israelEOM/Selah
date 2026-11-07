import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../shell.dart';
import 'responsive.dart';
import 'site_header.dart';

/// Puts the website header above a page that sits outside the shell (the study page and reader), with
/// [selectedBranch] highlighted. Below the website layout it adds nothing.
class SiteFrame extends ConsumerWidget {
  const SiteFrame({super.key, required this.child, this.selectedBranch = 1});

  final Widget child;
  final int selectedBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!siteLayout(context)) return child;
    final visible = visibleTabs(ref, AppLocalizations.of(context)!, current: selectedBranch);
    final branches = [for (final (b, _) in visible) b];
    return Column(
      children: [
        SiteHeader(
          tabs: [for (final (_, tab) in visible) tab],
          selected: branches.indexOf(selectedBranch),
          onSelect: (i) => goToBranch(context, ref, branches[i]),
          trailing: const SiteHeaderTrailing(),
        ),
        Expanded(child: child),
      ],
    );
  }
}
