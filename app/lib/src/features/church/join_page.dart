import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'role_label.dart';

typedef InviteInfo = ({String churchName, String churchSlug, ChurchRole role});

final inviteInfoProvider = FutureProvider.autoDispose.family<InviteInfo?, String>(
    (ref, token) => ref.watch(repositoryProvider).inviteInfo(token));

/// Where an invite link lands. Signed-in people join straight away; everyone else signs in first
/// and comes back here.
class JoinPage extends ConsumerStatefulWidget {
  const JoinPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends ConsumerState<JoinPage> {
  bool _accepting = false;
  bool _failed = false;
  bool _inviteGone = false;

  Future<void> _accept(InviteInfo info) async {
    try {
      final slug = await ref.read(repositoryProvider).acceptInvite(widget.token);
      ref.invalidate(myChurchesProvider);
      if (mounted) context.go(info.role.canEdit ? '/c/$slug/admin' : '/c/$slug');
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _inviteGone = SelahError.fromException(e) == 'invite_invalid';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final info = ref.watch(inviteInfoProvider(widget.token));
    final user = ref.watch(userIdProvider);

    Widget body;
    if (info.isLoading || user.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (info.value == null || (_failed && _inviteGone)) {
      body = Text(l.inviteInvalid, style: text.bodyLarge);
    } else if (info.hasError || _failed) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.genericError, style: text.bodyLarge),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            setState(() {
              _accepting = false;
              _failed = false;
              _inviteGone = false;
            });
            ref.invalidate(inviteInfoProvider(widget.token));
          },
          child: Text(l.retry),
        ),
      ]);
    } else {
      final invite = info.value!;
      if (user.value != null) {
        if (!_accepting) {
          _accepting = true; // set before scheduling so a rebuild can't schedule it twice
          WidgetsBinding.instance.addPostFrameCallback((_) => _accept(invite));
        }
        body = const Center(child: CircularProgressIndicator());
      } else {
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.joinChurchAs(invite.churchName, roleLabel(l, invite.role)), style: text.headlineMedium),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/login?next=${Uri.encodeQueryComponent('/join/${widget.token}')}'),
            child: Text(l.signInToJoin),
          ),
        ]);
      }
    }
    return Scaffold(appBar: AppBar(), body: PageBody(maxWidth: 440, children: [body]));
  }
}
