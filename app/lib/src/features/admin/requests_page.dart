import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import '../church/church_scope.dart';
import '../church/create_church_page.dart';

/// A platform admin approves (choosing the church's address) or rejects pending church requests.
class RequestsPage extends ConsumerWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final admin = ref.watch(isPlatformAdminProvider);
    if (!admin.hasValue) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!admin.value!) return ChurchMessage(text: l.createChurchAdminOnly, style: text.bodyLarge);
    final requests = ref.watch(pendingChurchRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.churchRequests, style: text.titleLarge)),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l.loadError, style: text.bodyLarge)),
        data: (items) => PageBody(
          children: [
            const SizedBox(height: 16),
            if (items.isEmpty) Text(l.noPendingRequests, style: text.bodyLarge),
            for (final r in items) _RequestCard(key: ValueKey(r.id), request: r),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({super.key, required this.request});

  final ChurchRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  final _form = GlobalKey<FormState>();
  late final _slug = TextEditingController(text: slugFromName(widget.request.churchName));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _slug.dispose();
    super.dispose();
  }

  Future<void> _decide({required bool approve}) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _error = null);
    if (approve && !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).decideChurchRequest(
            widget.request.id,
            approve: approve,
            slug: approve ? _slug.text.trim() : null,
          );
      ref.invalidate(pendingChurchRequestsProvider);
      messenger.showSnackBar(SnackBar(content: Text(approve ? l.churchCreated : l.requestRejectedNotice)));
    } catch (e) {
      final code = SelahError.fromException(e);
      if (code == 'request_not_pending') {
        // The card disappears with the refresh, so the message goes in a SnackBar.
        ref.invalidate(pendingChurchRequestsProvider);
        messenger.showSnackBar(SnackBar(content: Text(l.requestAlreadyDecided)));
      } else if (mounted) {
        setState(() {
          _busy = false;
          _error = switch (code) {
            'church_slug_taken' => l.slugTaken,
            'church_slug_invalid' => l.slugInvalid,
            'not_allowed' => l.createChurchAdminOnly,
            _ => l.loadError,
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final r = widget.request;
    final d = r.createdAt.toLocal();
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final note = r.note;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.tones.surface, borderRadius: BorderRadius.circular(12)),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.churchName, style: text.titleMedium),
              const SizedBox(height: 4),
              Text([if (r.requesterEmail != null) r.requesterEmail!, date].join(' · '), style: text.bodySmall),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(note, style: text.bodyMedium),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _slug,
                decoration: InputDecoration(labelText: l.churchAddress),
                onChanged: (_) => setState(() {}),
                validator: (v) => slugPattern.hasMatch((v ?? '').trim()) ? null : l.slugInvalid,
              ),
              const SizedBox(height: 8),
              Text('${Uri.base.host}/c/${_slug.text.trim()}', style: text.bodyMedium),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton(onPressed: _busy ? null : () => _decide(approve: true), child: Text(l.approve)),
                OutlinedButton(onPressed: _busy ? null : () => _decide(approve: false), child: Text(l.reject)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
