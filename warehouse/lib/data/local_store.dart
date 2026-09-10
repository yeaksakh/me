import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../models/staff.dart';
import '../models/stock_count.dart';
import '../models/stock_item.dart';

/// On-device persistence.
///
/// A warehouse handset gets dropped, runs out of battery mid-aisle, and works in
/// a stockroom with no signal. Everything a person has done but not yet finished
/// -- a part-picked order, a half-walked stock count, the signed-in session --
/// is kept here so none of that costs them the work.
///
/// Every read is defensive: a corrupt or outdated payload is discarded rather
/// than crashing the app on launch.
class LocalStore {
  static const _ordersKey = 'wh_orders_v1';
  static const _stockKey = 'wh_stock_v1';
  static const _countKey = 'wh_count_draft_v1';
  static const _staffKey = 'wh_session_staff_v1';

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

  Future<List<Order>?> loadOrders() => _read(_ordersKey, (decoded) {
        return (decoded as List<dynamic>)
            .map((item) => Order.fromJson(item as Map<String, dynamic>))
            .toList();
      });

  Future<void> saveOrders(List<Order> orders) =>
      _write(_ordersKey, orders.map((order) => order.toJson()).toList());

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

  Future<Staff?> loadStaff() => _read(_staffKey, (decoded) {
        return Staff.fromJson(decoded as Map<String, dynamic>);
      });

  Future<void> saveStaff(Staff? staff) async {
    if (staff == null) {
      await (await _prefs).remove(_staffKey);
      return;
    }
    await _write(_staffKey, staff.toJson());
  }
}
