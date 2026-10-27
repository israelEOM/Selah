import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import '../church/role_label.dart';
import 'admin_gate.dart';

/// Owners invite people with links and manage who has which role.
class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key, required this.church});

  final Church church;

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  // Only editor and member links exist; an owner is made by changing a role.
  static const _inviteRoles = [ChurchRole.editor, ChurchRole.member];

  late Future<List<Map<String, dynamic>>> _invites = _loadInvites();
  late Future<List<Person>> _people = _loadPeople();
  String? _error;

  Future<List<Map<String, dynamic>>> _loadInvites() async {
    final rows = await ref.read(repositoryProvider).invites(widget.church.id);
    return rows.where((r) => r['revoked_at'] == null).toList();
  }

  Future<List<Person>> _loadPeople() => ref.read(repositoryProvider).people(widget.church.id);

  /// Runs [action], reloads both lists and shows the database's reason when it refuses.
  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _error = null);
    String? error;
    try {
      await action();
    } catch (e) {
      error = switch (SelahError.fromException(e)) {
        'last_owner' => l.lastOwner,
        'not_allowed' => l.churchAdminOnly,
        _ => l.genericError,
      };
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      _invites = _loadInvites();
      _people = _loadPeople();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final repo = ref.read(repositoryProvider);
    final userId = ref.watch(userIdProvider).value;
    final church = widget.church;
    return AdminPage(
      church: church,
      minRole: ChurchRole.owner,
      backTo: '/c/${church.slug}/admin',
      children: [
        Eyebrow(l.admin),
        const SizedBox(height: 8),
        Text(l.people, style: text.headlineMedium),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        Text(l.inviteLinks, style: text.titleLarge),
        const SizedBox(height: 12),
        FutureBuilder(
          future: _invites,
          builder: (context, snap) {
            if (snap.hasError) return Text(l.loadError, style: text.bodyMedium);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snap.data!;
            return Column(children: [
              for (final role in _inviteRoles)
                _InviteRow(
                  role: role,
                  token: rows.where((r) => r['role'] == role.name).map((r) => r['token'] as String).firstOrNull,
                  onCreate: () => _run(() => repo.createInvite(church.id, role)),
                  onRevoke: (token) => _run(() => repo.revokeInvite(token)),
                ),
            ]);
          },
        ),
        const SizedBox(height: 32),
        Text(l.people, style: text.titleLarge),
        const SizedBox(height: 12),
        FutureBuilder(
          future: _people,
          builder: (context, snap) {
            if (snap.hasError) return Text(l.loadError, style: text.bodyMedium);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return Column(children: [
              for (final person in snap.data!)
                _PersonRow(
                  person: person,
                  isMe: person.userId == userId,
                  onRole: (role) => _run(() => repo.setMemberRole(church.id, person.userId, role)),
                  onRemove: () => _run(() => repo.removeMember(church.id, person.userId)),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

/// The shareable link for an invite. [Uri.base] has no origin outside a browser (tests), so
/// there the link is just the path.
String joinUrl(String token) => '${Uri.base.scheme.startsWith('http') ? Uri.base.origin : ''}/join/$token';

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.role, required this.token, required this.onCreate, required this.onRevoke});

  final ChurchRole role;
  final String? token;
  final VoidCallback onCreate;
  final ValueChanged<String> onRevoke;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final token = this.token;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(roleLabel(l, role)),
            const SizedBox(height: 8),
            if (token == null)
              Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: onCreate, child: Text(l.createLink)))
            else ...[
              SelectableText(joinUrl(token), style: text.bodyMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l.copyLink),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: joinUrl(token)));
                    messenger.showSnackBar(SnackBar(content: Text(l.linkCopied)));
                  },
                ),
                TextButton(onPressed: () => onRevoke(token), child: Text(l.revokeLink)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.isMe, required this.onRole, required this.onRemove});

  final Person person;
  final bool isMe;
  final ValueChanged<ChurchRole> onRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final name = (person.name?.trim().isNotEmpty ?? false) ? person.name! : (person.email ?? person.userId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: text.titleMedium),
                if (person.email != null && person.email != name) Text(person.email!, style: text.bodyMedium),
              ]),
            ),
            DropdownButton<ChurchRole>(
              value: person.role,
              underline: const SizedBox.shrink(),
              items: [
                for (final role in ChurchRole.values)
                  DropdownMenuItem(value: role, child: Text(roleLabel(l, role))),
              ],
              onChanged: (role) {
                if (role != null && role != person.role) onRole(role);
              },
            ),
            TextButton(onPressed: onRemove, child: Text(l.removePerson)),
          ]),
        ),
      ),
    );
  }
}
