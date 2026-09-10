import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/staff.dart';
import '../models/stock_count.dart';
import '../models/stock_item.dart';

/// On-device persistence.
///
/// A warehouse handset gets dropped, runs out of battery mid-aisle, and works in
/// a stockroom with no signal. What a person has done but not yet finished -- a
/// half-walked stock count, the signed-in session -- is kept here so none of that
/// costs them the work. Shipments are not: the server is their record, and every
/// tick is saved there the moment it is made.
///
/// Every read is defensive: a corrupt or outdated payload is discarded rather
/// than crashing the app on launch.
class LocalStore {
  static const _stockKey = 'wh_stock_v1';
  static const _countKey = 'wh_count_draft_v1';
  static const _serverUrlKey = 'wh_server_url_v1';

  /// v2 carries the bearer token. The v1 key held a demo sign-in with no token,
  /// which is not a session, so it is not read.
  static const _sessionKey = 'wh_session_v2';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Reads [key], decodes it with [parse], and drops the entry if it no longer
  /// makes sense. Every loader in this class is this shape.
  Future<T?> _read<T>(String key, T Function(Object?) parse) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return parse(jsonDecode(raw));
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> _write(String key, Object? value) async =>
      (await _prefs).setString(key, jsonEncode(value));

  Future<List<StockItem>?> loadStock() => _read(_stockKey, (decoded) {
        return (decoded as List<dynamic>)
            .map((item) => StockItem.fromJson(item as Map<String, dynamic>))
            .toList();
      });

  Future<void> saveStock(List<StockItem> stock) =>
      _write(_stockKey, stock.map((item) => item.toJson()).toList());

  /// The count in progress, if there is one.
  Future<StockCount?> loadCountDraft() => _read(_countKey, (decoded) {
        return StockCount.fromJson(decoded as Map<String, dynamic>);
      });

  Future<void> saveCountDraft(StockCount? count) async {
    if (count == null) {
      await (await _prefs).remove(_countKey);
      return;
    }
    await _write(_countKey, count.toJson());
  }

  /// Who is signed in and their bearer token, or null when nobody is.
  Future<({String token, Staff staff})?> loadSession() =>
      _read(_sessionKey, (decoded) {
        final map = decoded as Map<String, dynamic>;
        return (
          token: map['token'] as String,
          staff: Staff.fromJson(map['staff'] as Map<String, dynamic>),
        );
      });

  /// Saves the session, or clears it when either half is null.
  Future<void> saveSession(String? token, Staff? staff) async {
    if (token == null || staff == null) {
      await (await _prefs).remove(_sessionKey);
      return;
    }
    await _write(_sessionKey, {'token': token, 'staff': staff.toJson()});
  }

  /// Null when nobody has pointed this handset at another server.
  Future<String?> loadServerUrl() async =>
      (await _prefs).getString(_serverUrlKey);

  Future<void> saveServerUrl(String url) async =>
      (await _prefs).setString(_serverUrlKey, url);

  /// Forgets a server override entirely. Used by release builds, which must
  /// not merely ignore one left behind by a debug build on the same handset.
  Future<void> clearServerUrl() async => (await _prefs).remove(_serverUrlKey);
}
