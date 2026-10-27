import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/auth_redirect.dart';
import '../../core/user_agent.dart';
import '../../data/providers.dart';
import 'google_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  /// [landing] and [userAgent] default to the real page; tests pass their own.
  const LoginPage({super.key, this.landing, this.userAgent});

  final Uri? landing;
  final String? userAgent;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _message;
  String? get _next => (widget.landing ?? Uri.base).queryParameters['next'];
  late final bool _embedded = isEmbeddedBrowser(widget.userAgent ?? currentUserAgent());

  @override
  void initState() {
    super.initState();
    final error = oauthErrorFrom(widget.landing ?? Uri.base);
    if (error != null) _oauthError = error.cancelled;
    // Covers email sign-in, the return from Google, and someone who opens this page already signed in.
    ref.listenManual(userIdProvider, fireImmediately: true, (_, next) async {
      if (next.value == null) return;
      final churches = await ref.read(myChurchesProvider.future);
      final editable = churches.where((m) => m.role.canEdit).toList();
      final destination = safeNext(_next) ?? (editable.length == 1 ? '/c/${editable.first.church.slug}/admin' : '/');
      if (mounted) GoRouter.of(context).go(destination);
    });
  }

  /// True for a cancelled Google sign-in, false for any other provider error, null for none.
  bool? _oauthError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(repositoryProvider);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_creating) {
        final needsConfirmation = await repo.signUp(_email.text.trim(), _password.text);
        if (needsConfirmation) {
          setState(() {
            _message = l.confirmEmailSent;
            _creating = false;
          });
          return;
        }
      } else {
        await repo.signIn(_email.text.trim(), _password.text);
      }
      // Navigation happens in the userIdProvider listener in build.
    } on AuthException catch (e) {
      setState(() => _message = e.code == 'invalid_credentials' ? l.invalidCredentials : e.message);
    } catch (_) {
      setState(() => _message = l.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _message = null;
      _oauthError = null;
    });
    try {
      // On the web the page leaves for Google, so _busy stays set.
      await ref
          .read(repositoryProvider)
          .signInWithProvider(OAuthProvider.google, redirectTo: oauthReturnUrl(widget.landing ?? Uri.base, next: _next));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = l.genericError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: PageBody(
        maxWidth: 440,
        children: [
          Eyebrow('Selah'),
          const SizedBox(height: 8),
          Text(_creating ? l.createAccount : l.signIn, style: text.headlineMedium),
          const SizedBox(height: 24),
          if (_embedded) ...[Text(l.embeddedBrowserHint, style: text.bodyMedium), const SizedBox(height: 12)],
          if (_oauthError != null) ...[
            Text(
              _oauthError! ? l.oauthCancelled : l.oauthFailed,
              style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          GoogleButton(onPressed: _busy ? null : _signInWithGoogle),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l.orWithEmail, style: text.bodyMedium),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l.email),
                    validator: (v) => (v == null || !v.contains('@')) ? l.email : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                    decoration: InputDecoration(labelText: l.password, helperText: _creating ? l.passwordHint : null),
                    validator: (v) => (v == null || v.length < 8) ? l.passwordHint : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
          ),
          if (_message != null) ...[const SizedBox(height: 14), Text(_message!, style: text.bodyMedium)],
          const SizedBox(height: 22),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_creating ? l.createAccount : l.signIn)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _creating = !_creating),
            child: Text(_creating ? l.haveAccount : l.needAccount),
          ),
        ],
      ),
    );
  }
}
