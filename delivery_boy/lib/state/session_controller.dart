import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/mock_data.dart';
import '../models/driver.dart';

/// Who is signed in, and whether they are accepting work right now.
class SessionController extends ChangeNotifier {
  SessionController({LocalStore? store}) : _store = store {
    _restore();
  }

  /// Optional. Without a store the session lives only for this run.
  final LocalStore? _store;

  Driver? _driver;
  bool _isOnline = false;
  bool _busy = false;
  String? _error;

  Driver? get driver => _driver;
  bool get isSignedIn => _driver != null;
  bool get isOnline => _isOnline;
  bool get busy => _busy;
  String? get error => _error;

  /// Demo sign-in: any registered phone with a 4-digit PIN is accepted.
  Future<bool> signIn({required String phone, required String pin}) async {
    _error = null;
    if (phone.trim().length < 6) {
      _error = 'Enter your full phone number.';
      notifyListeners();
      return false;
    }
    if (pin.length != 4 || int.tryParse(pin) == null) {
      _error = 'Your PIN is 4 digits.';
      notifyListeners();
      return false;
    }

    _busy = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 600));

    _driver = MockData.driver;
    _isOnline = true;
    _busy = false;
    notifyListeners();
    await _save();
    return true;
  }

  void signOut() {
    _driver = null;
    _isOnline = false;
    _error = null;
    notifyListeners();
    _save();
  }

  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
    _save();
  }

  /// Bring back the previous session, so a restart mid-shift does not sign
  /// the rider out.
  Future<void> _restore() async {
    final store = _store;
    if (store == null) return;
    final saved = await store.loadSession();
    if (!saved.signedIn || _driver != null) return;
    _driver = MockData.driver;
    _isOnline = saved.online;
    notifyListeners();
  }

  Future<void> _save() async =>
      _store?.saveSession(signedIn: _driver != null, online: _isOnline);
}
