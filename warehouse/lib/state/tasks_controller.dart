import 'package:flutter/foundation.dart';

import '../data/shipments_api.dart';
import '../models/fulfilment_stage.dart';
import '../models/order.dart';
import '../models/staff.dart';

/// The shipments, as the website's /shipments page has them, and the moves staff
/// make on them: accept, tick each item into the box, mark packed, mark audited.
///
/// The server is the record and enforces every rule
/// (`core/api/views_shipments.py`). The few this class checks first -- every item
/// ticked before Packed, only a supervisor audits -- are there so a button can
/// say why it is waiting, instead of sending a request it knows will be refused.
class TasksController extends ChangeNotifier {
  TasksController(this._api, {this.onUnauthorized});

  final ShipmentsApi _api;

  /// Called when the server says the session is gone, so the app signs out
  /// rather than failing on every pull.
  final VoidCallback? onUnauthorized;

  final Map<FulfilmentStage, List<Order>> _queues = {};
  final Map<FulfilmentStage, int> _counts = {};
  final Map<String, Order> _details = {};
  final Set<FulfilmentStage> _loading = {};
  bool _busy = false;
  String? _error;

  /// True while a change is on its way to the server. Buttons wait on it, so a
  /// double tap cannot send the same move twice.
  bool get busy => _busy;
  String? get error => _error;

  bool isLoading(FulfilmentStage stage) => _loading.contains(stage);
  bool hasLoaded(FulfilmentStage stage) => _queues.containsKey(stage);

  /// Shipments at [stage], newest first, as the website lists them.
  List<Order> queue(FulfilmentStage stage) =>
      List<Order>.unmodifiable(_queues[stage] ?? const <Order>[]);

  /// The server's count for [stage], which covers the whole status rather than
  /// only the loaded page.
  int queueCount(FulfilmentStage stage) =>
      _counts[stage] ?? _queues[stage]?.length ?? 0;

  int get toPackCount => queueCount(FulfilmentStage.ordered);
  int get packedCount => queueCount(FulfilmentStage.packed);

  /// The freshest copy of a shipment: the opened one when there is one.
  Order? orderById(String id) {
    final opened = _details[id];
    if (opened != null) return opened;
    for (final list in _queues.values) {
      for (final order in list) {
        if (order.id == id) return order;
      }
    }
    return null;
  }

  Future<void> load(FulfilmentStage stage) async {
    _loading.add(stage);
    _error = null;
    notifyListeners();
    try {
      final page = await _api.list(stage);
      _queues[stage] = page.orders;
      _counts
        ..clear()
        ..addAll(page.counts);
    } on ShipmentsException catch (failure) {
      _fail(failure);
    } finally {
      _loading.remove(stage);
      notifyListeners();
    }
  }

  /// Every tab, fresh. Opened shipments are forgotten too: they may belong to
  /// whoever used the handset before.
  Future<void> refreshAll() async {
    _details.clear();
    for (final stage in kStaffQueues) {
      await load(stage);
    }
  }

  /// Fetches a shipment's items and photos, which a list row does not carry.
  Future<Order?> openDetail(String id) async {
    try {
      final order = await _api.detail(id);
      _put(order);
      return order;
    } on ShipmentsException catch (failure) {
      _fail(failure);
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> accept(String id) => _write(() => _api.accept(id));

  Future<bool> release(String id) => _write(() => _api.release(id));

  Future<bool> setLinePacked(String id, String lineId,
          {required bool packed}) =>
      _write(() => _api.packLine(id, lineId, packed: packed),
          reloadQueues: false);

  /// Refused here while an item is unticked, with how many are left -- the rule
  /// the website's Packed button enforces, and the server after it.
  Future<bool> markPacked(String id) async {
    final order = orderById(id);
    if (order == null) return false;
    if (!order.isFullyPacked) {
      _error = 'Tick every item first (${order.unpackedCount} left).';
      notifyListeners();
      return false;
    }
    return _write(() => _api.setStatus(id, FulfilmentStage.packed));
  }

  /// A second pair of eyes on a packed shipment, so it is a supervisor's.
  Future<bool> markAudited(String id, {required Staff staff}) async {
    if (!staff.role.canCheck) {
      _error = 'Only a supervisor can mark a shipment audited.';
      notifyListeners();
      return false;
    }
    return _write(() => _api.setStatus(id, FulfilmentStage.audited));
  }

  /// Ticks the item a scanned SKU belongs to.
  ///
  /// Returns the item it landed on, or null when the code is not on this
  /// shipment -- which the screen reports as "wrong item", the single most
  /// useful thing a warehouse scanner can say.
  Future<OrderLine?> applyScan(String id, String code) async {
    final order = orderById(id);
    final line = order?.lineForCode(code);
    if (order == null || line == null) return null;
    if (!line.packed) await setLinePacked(id, line.id, packed: true);
    return line;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _write(
    Future<Order> Function() send, {
    bool reloadQueues = true,
  }) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _put(await send());
      // A move changes every tab's count, so they are re-read rather than
      // guessed. A tick changes none of them.
      if (reloadQueues) {
        for (final stage in kStaffQueues) {
          if (hasLoaded(stage)) await load(stage);
        }
      }
      return true;
    } on ShipmentsException catch (failure) {
      _fail(failure);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Keeps the answer as the opened copy, and moves it between the loaded tabs
  /// so the lists are right before the reload lands.
  void _put(Order order) {
    _details[order.id] = order;
    for (final stage in _queues.keys.toList()) {
      final list =
          _queues[stage]!.where((existing) => existing.id != order.id).toList();
      if (stage == order.stage) {
        list
          ..add(order)
          ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
      }
      _queues[stage] = list;
    }
  }

  void _fail(ShipmentsException failure) {
    _error = failure.message;
    if (failure.isUnauthorized) onUnauthorized?.call();
  }
}
