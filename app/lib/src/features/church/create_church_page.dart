import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'church_scope.dart';

final _slugPattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$');

const _accents = {
  'àáâãäå': 'a',
  'ç': 'c',
  'èéêë': 'e',
  'ìíîï': 'i',
  'ñ': 'n',
  'òóôõö': 'o',
  'ùúûü': 'u',
  'ýÿ': 'y',
};

/// "Iglesia Vida Nueva — São Paulo" becomes "iglesia-vida-nueva-sao-paulo".
String slugFromName(String name) {
  var s = name.toLowerCase();
  _accents.forEach((from, to) {
    for (final c in from.split('')) {
      s = s.replaceAll(c, to);
    }
  });
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.length > 40) s = s.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  return s;
}

/// A platform admin names a church and picks its address.
class CreateChurchPage extends ConsumerStatefulWidget {
  const CreateChurchPage({super.key});

  @override
  ConsumerState<CreateChurchPage> createState() => _CreateChurchPageState();
}

class _CreateChurchPageState extends ConsumerState<CreateChurchPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  bool _slugEdited = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final slug = _slug.text.trim();
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).createChurch(_name.text.trim(), slug);
      ref.invalidate(myChurchesProvider);
      if (mounted) context.go('/c/$slug/admin/settings');
    } catch (e) {
      final code = SelahError.fromException(e);
      if (mounted) {
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
    final user = ref.watch(userIdProvider);
    if (user.hasValue && user.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login?next=${Uri.encodeQueryComponent('/churches/new')}');
      });
    }
    final admin = ref.watch(isPlatformAdminProvider);
    if (user.value == null || !admin.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!admin.value!) return ChurchMessage(text: l.createChurchAdminOnly, style: text.bodyLarge);
    return Scaffold(
      appBar: AppBar(title: Text(l.createChurchTitle, style: text.titleLarge)),
      body: PageBody(
        children: [
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.churchName),
                  textInputAction: TextInputAction.next,
                  onChanged: (v) {
                    if (!_slugEdited) setState(() => _slug.text = slugFromName(v));
                  },
                  validator: (v) {
                    final n = (v ?? '').trim().length;
                    return n < 2 || n > 80 ? l.churchNameInvalid : null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _slug,
                  decoration: InputDecoration(labelText: l.churchAddress),
                  onChanged: (_) => setState(() => _slugEdited = true),
                  validator: (v) => _slugPattern.hasMatch((v ?? '').trim()) ? null : l.slugInvalid,
                ),
                const SizedBox(height: 8),
                Text('${Uri.base.host}/c/${_slug.text.trim()}', style: text.bodyMedium),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l.createChurch),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
