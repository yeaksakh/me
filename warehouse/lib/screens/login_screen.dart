import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/server_config.dart';
import '../state/session_controller.dart';

/// Username and password of the person's yeaksa.com staff account -- the same
/// one they use on the website, so there is no second login to hand out.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  /// The logo, which three quick taps turn into the server picker.
  static const logoKey = Key('login-logo');

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Taps on the logo needed to reach the server picker.
  static const _tapsToReveal = 3;

  /// How long a tap keeps counting towards the sequence.
  static const _tapWindow = Duration(seconds: 2);

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  int _logoTaps = 0;
  Timer? _tapWindowTimer;

  @override
  void dispose() {
    _tapWindowTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    if (session.busy) return;
    await session.signIn(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }

  /// Deliberately undiscoverable: three quick taps on the logo open the server
  /// picker, so testers can point a build at staging or an on-site server
  /// without a settings screen staff might wander into.
  void _onLogoTap() {
    // Nothing to reveal in a release build: the server is fixed there, so
    // opening a picker that cannot save would read as broken.
    if (!ServerConfig.canOverride) return;

    _tapWindowTimer?.cancel();
    _logoTaps++;

    if (_logoTaps >= _tapsToReveal) {
      _logoTaps = 0;
      _openServerPicker();
      return;
    }

    _tapWindowTimer = Timer(_tapWindow, () => _logoTaps = 0);
  }

  Future<void> _openServerPicker() async {
    // Resolved before the dialog: after it closes this context may be gone,
    // and looking it up then is the classic async-gap bug.
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => const _ServerDialog(),
    );
    if (saved == null) return;
    messenger.showSnackBar(SnackBar(content: Text('Server set to $saved')));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final server = context.watch<ServerConfig>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    key: LoginScreen.logoKey,
                    onTap: _onLogoTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.warehouse,
                        color: Colors.white,
                        size: 32,
                        semanticLabel: 'WareHouseMgt',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Warehouse',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in with your yeaksa.com staff account.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _usernameController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip:
                            _showPassword ? 'Hide password' : 'Show password',
                        icon: Icon(_showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),
                  if (session.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      session.error!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: session.busy ? null : _submit,
                    child: session.busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  // Only worth the space once someone has moved off
                  // yeaksa.com, where signing in to the wrong server is easy
                  // to forget.
                  if (!server.isDefault) ...[
                    const SizedBox(height: 12),
                    Text(
                      server.baseUrl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Edits the server address. Pops the saved URL, or null if nothing changed.
class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final TextEditingController _url =
      TextEditingController(text: context.read<ServerConfig>().baseUrl);
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = context.read<ServerConfig>();
    final problem = await config.setBaseUrl(_url.text);
    if (!mounted) return;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(config.baseUrl);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Server address',
              errorText: _error,
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() {
              _url.text = ServerConfig.defaultUrl;
              _error = null;
            }),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Use default'),
          ),
          Text(
            'Default is ${ServerConfig.defaultUrl}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
