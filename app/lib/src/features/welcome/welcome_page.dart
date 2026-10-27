import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/current_church.dart';
import '../../data/providers.dart';
import '../home/church_picker_page.dart';
import 'welcome_state.dart';

enum _Step { choice, member, leader }

/// After a new account's first sign-in: join a church as a member, or ask to bring one to Selah.
/// [step] (`member` or `leader`, from `?step=`) opens that part directly.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key, this.step});

  final String? step;

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  late _Step _step = switch (widget.step) {
    'member' => _Step.member,
    'leader' => _Step.leader,
    _ => _Step.choice,
  };
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // However they got here, don't send them here again from the tab bar in this app session.
    ref.listenManual(userIdProvider, fireImmediately: true, (_, user) {
      final userId = user.value;
      if (userId != null) Future.microtask(() => mounted ? markWelcomeShown(ref, userId) : null);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _show(_Step step) => setState(() {
        _step = step;
        _error = null;
      });

  Future<void> _skip() async {
    await skipWelcome(ref);
    if (mounted) context.go('/');
  }

  Future<void> _join(Church church) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).joinChurch(church.id);
      await ref.read(chosenChurchSlugProvider.notifier).choose(church.slug);
      ref.invalidate(myChurchesProvider);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context)!.genericError;
        });
      }
    }
  }

  Future<void> _sendRequest() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final note = _note.text.trim();
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).requestChurch(_name.text.trim(), note.isEmpty ? null : note);
      ref.invalidate(myChurchRequestProvider);
      if (mounted) {
        setState(() {
          _busy = false;
          _sent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = SelahError.fromException(e) == 'request_pending_exists' ? l.requestPendingExists : l.genericError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(userIdProvider);
    if (user.hasValue && user.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
    }
    final children = switch (_step) {
      _Step.choice => _choice(l, text),
      _Step.member => [
          Text(l.joinAChurch, style: text.headlineMedium),
          const SizedBox(height: 24),
          ChurchList(onPick: _join),
        ],
      _Step.leader => _sent ? _sentMessage(l, text) : _leaderForm(l, text),
    };
    return Scaffold(
      appBar: AppBar(
        leading: _step == _Step.choice || widget.step != null
            ? null
            : BackButton(onPressed: () => _show(_Step.choice)),
      ),
      body: PageBody(
        maxWidth: 560,
        children: [
          ...children,
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  List<Widget> _choice(AppLocalizations l, TextTheme text) => [
        Eyebrow('Selah'),
        const SizedBox(height: 8),
        Text(l.welcomeTitle, style: text.headlineMedium),
        const SizedBox(height: 24),
        _ChoiceCard(icon: Icons.people_outline, label: l.welcomeMember, onTap: () => _show(_Step.member)),
        const SizedBox(height: 12),
        _ChoiceCard(icon: Icons.church_outlined, label: l.welcomeLeader, onTap: () => _show(_Step.leader)),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _skip, child: Text(l.notNow))),
      ];

  List<Widget> _leaderForm(AppLocalizations l, TextTheme text) => [
        Text(l.bringMyChurch, style: text.headlineMedium),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l.churchNameLabel),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final n = (v ?? '').trim().length;
                  return n < 2 || n > 80 ? l.churchNameInvalid : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                decoration: InputDecoration(labelText: l.churchNoteLabel),
                minLines: 3,
                maxLines: 6,
                validator: (v) => (v ?? '').trim().length > 500 ? l.churchNoteTooLong : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _busy ? null : _sendRequest, child: Text(l.sendRequest)),
        ),
      ];

  List<Widget> _sentMessage(AppLocalizations l, TextTheme text) => [
        Text(l.requestSent, style: text.titleLarge),
        const SizedBox(height: 24),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: () => _show(_Step.member), child: Text(l.joinMeanwhile)),
          OutlinedButton(onPressed: () => context.go('/'), child: Text(l.goToToday)),
        ]),
      ];
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(label, style: Theme.of(context).textTheme.titleMedium),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
