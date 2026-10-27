import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// Links from before churches had their own addresses: `/studies/<slug>[/day/<n>]`.
/// Finds the church of the oldest study with that slug and moves there, or home when there is none.
class LegacyStudyRedirect extends ConsumerStatefulWidget {
  const LegacyStudyRedirect({super.key, required this.slug, this.dayNumber});

  final String slug;
  final String? dayNumber;

  @override
  ConsumerState<LegacyStudyRedirect> createState() => _LegacyStudyRedirectState();
}

class _LegacyStudyRedirectState extends ConsumerState<LegacyStudyRedirect> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    String? church;
    try {
      church = await ref.read(repositoryProvider).legacyStudyChurch(widget.slug);
    } catch (_) {
      church = null;
    }
    if (!mounted) return;
    final day = widget.dayNumber == null ? '' : '/day/${widget.dayNumber}';
    context.go(church == null ? '/' : '/c/$church/studies/${widget.slug}$day');
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// `/admin` from before churches: the first church the person can edit, or home.
class LegacyAdminRedirect extends ConsumerStatefulWidget {
  const LegacyAdminRedirect({super.key});

  @override
  ConsumerState<LegacyAdminRedirect> createState() => _LegacyAdminRedirectState();
}

class _LegacyAdminRedirectState extends ConsumerState<LegacyAdminRedirect> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    String target = '/';
    try {
      final churches = await ref.read(myChurchesProvider.future);
      for (final m in churches) {
        if (m.role.canEdit) {
          target = '/c/${m.church.slug}/admin';
          break;
        }
      }
    } catch (_) {
      // Home is the safe place to land.
    }
    if (mounted) context.go(target);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
