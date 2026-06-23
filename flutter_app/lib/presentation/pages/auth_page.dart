import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  bool _obscure = true;
  bool _loggedIn = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final cloud = ref.read(cloudApiProvider);
    await cloud.init();
    if (mounted) {
      setState(() {
        _loggedIn = cloud.session.isLoggedIn;
        _email = cloud.session.email;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailCtrl.text.trim();
    final password = _pwdCtrl.text;
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.emailPasswordHint)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final cloud = ref.read(cloudApiProvider);
      if (_isRegister) {
        await cloud.registerEmail(email: email, password: password);
      } else {
        await cloud.loginEmail(email: email, password: password);
      }
      await cloud.registerDevice();
      ref.invalidate(bootstrapProvider);
      await ref.read(bootstrapProvider.future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isRegister ? l10n.registerSuccess : l10n.loginSuccess)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(cloudApiProvider).logout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loggedOut)));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(_loggedIn ? l10n.account : (_isRegister ? l10n.register : l10n.registerLogin))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.authHint,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (_loggedIn) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.loggedIn),
              subtitle: Text(_email ?? ''),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _loading ? null : _logout, child: Text(l10n.logout)),
          ] else ...[
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.email,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwdCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.password,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isRegister ? l10n.registerAndLink : l10n.registerLogin),
            ),
            TextButton(
              onPressed: _loading ? null : () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister ? l10n.hasAccountLogin : l10n.noAccountRegister),
            ),
          ],
        ],
      ),
    );
  }
}
