import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';

/// On-device persistence, so an in-progress delivery survives an app restart.
///
/// Every read is defensive: a corrupt or outdated payload is discarded rather
/// than crashing the app on launch.
class LocalStore {
  static const _ordersKey = 'orders_v1';
  static const _onlineKey = 'session_online_v1';
  static const _signedInKey = 'session_signed_in_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Order>?> loadOrders() async {
    final raw = (await _prefs).getString(_ordersKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => Order.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await (await _prefs).remove(_ordersKey);
      return null;
    }
  }

  Future<void> saveOrders(List<Order> orders) async {
    final raw = jsonEncode(orders.map((order) => order.toJson()).toList());
    await (await _prefs).setString(_ordersKey, raw);
  }

  Future<({bool signedIn, bool online})> loadSession() async {
    final prefs = await _prefs;
    return (
      signedIn: prefs.getBool(_signedInKey) ?? false,
      online: prefs.getBool(_onlineKey) ?? false,
    );
  }

  Future<void> saveSession({
    required bool signedIn,
    required bool online,
  }) async {
    final prefs = await _prefs;
    await prefs.setBool(_signedInKey, signedIn);
    await prefs.setBool(_onlineKey, online);
  }
}
