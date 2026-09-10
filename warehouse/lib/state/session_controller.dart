import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/mock_data.dart';
import '../models/staff.dart';

/// Who is signed in on this handset.
///
/// Warehouse handsets are shared -- one device, three shifts -- so signing out
/// has to be one tap away and signing back in has to be quick.
class SessionController extends ChangeNotifier {
  SessionController({LocalStore? store}) : _store = store {
    _restore();
  }

  /// Optional. Without a store the session lives only for this run.
  final LocalStore? _store;

  Staff? _staff;
  bool _busy = false;
  String? _error;

  Staff? get staff => _staff;
  bool get isSignedIn => _staff != null;
  bool get busy => _busy;
  String? get error => _error;

  /// Demo sign-in: any staff code with a 4-digit PIN is accepted.
  ///
  /// The real one posts to the same `/auth/login` the other Yeaksa apps use and
  /// keeps the Bearer token; the shape of this method does not change.
  Future<bool> signIn({required String staffCode, required String pin}) async {
    _error = null;
    if (staffCode.trim().length < 3) {
      _error = 'Enter your staff code.';
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

    _staff = MockData.staff;
    _busy = false;
    notifyListeners();
    await _save();
    return true;
  }

  void signOut() {
    _staff = null;
    _error = null;
    notifyListeners();
    _save();
  }

  /// Bring back the previous session, so a restart mid-shift does not sign
  /// someone out in the middle of an aisle.
  Future<void> _restore() async {
    final store = _store;
    if (store == null) return;
    final saved = await store.loadStaff();
    if (saved == null || _staff != null) return;
    _staff = saved;
    notifyListeners();
  }

  Future<void> _save() async => _store?.saveStaff(_staff);
}
