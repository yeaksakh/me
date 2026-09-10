import 'package:flutter/foundation.dart';

import '../data/auth_api.dart';
import '../data/local_store.dart';
import '../models/staff.dart';

/// Who is signed in on this handset.
///
/// Warehouse handsets are shared -- one device, three shifts -- so signing out
/// has to be one tap away and signing back in has to be quick.
///
/// Staff sign in with the username and password of their yeaksa.com account,
/// and this owns the bearer token the server hands back.
class SessionController extends ChangeNotifier {
  SessionController({LocalStore? store, AuthApi? auth})
      : _store = store,
        _auth = auth ?? AuthApi() {
    _restore();
  }

  /// Optional. Without a store the session lives only for this run.
  final LocalStore? _store;
  final AuthApi _auth;

  Staff? _staff;
  String? _token;
  bool _busy = false;
  String? _error;

  Staff? get staff => _staff;
  String? get token => _token;
  bool get isSignedIn => _staff != null && _token != null;
  bool get busy => _busy;
  String? get error => _error;

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    _error = null;
    final name = username.trim();
    if (name.isEmpty) {
      _error = 'Enter your username.';
      notifyListeners();
      return false;
    }
    // Not trimmed: a space can be part of a password.
    if (password.isEmpty) {
      _error = 'Enter your password.';
      notifyListeners();
      return false;
    }

    _busy = true;
    notifyListeners();
    try {
      final result = await _auth.signIn(username: name, password: password);
      _staff = result.staff;
      _token = result.token;
      await _store?.saveSession(result.token, result.staff);
      return true;
    } on AuthException catch (failure) {
      _error = failure.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Ends the session on this handset.
  ///
  /// The local state is cleared whatever the server says: someone who taps
  /// sign out in a stockroom with no signal must still end up signed out, and
  /// the next person on the handset must not inherit their session.
  Future<void> signOut() async {
    final token = _token;
    _staff = null;
    _token = null;
    _error = null;
    notifyListeners();

    await _store?.saveSession(null, null);
    if (token == null) return;
    try {
      await _auth.signOut(token);
    } on AuthException {
      // Best effort. The token expires on its own.
    }
  }

  /// Bring back the previous session, so a restart mid-shift does not sign
  /// someone out in the middle of an aisle.
  Future<void> _restore() async {
    final store = _store;
    if (store == null) return;
    final saved = await store.loadSession();
    if (saved == null || _staff != null) return;
    _token = saved.token;
    _staff = saved.staff;
    notifyListeners();
  }
}
