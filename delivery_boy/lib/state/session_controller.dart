import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/driver.dart';

/// Who is signed in, and whether they are accepting work right now.
class SessionController extends ChangeNotifier {
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
    return true;
  }

  void signOut() {
    _driver = null;
    _isOnline = false;
    _error = null;
    notifyListeners();
  }

  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
  }
}
