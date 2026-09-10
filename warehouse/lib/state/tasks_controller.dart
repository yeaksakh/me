import 'package:flutter/foundation.dart';

import '../data/warehouse_repository.dart';
import '../models/fulfilment_stage.dart';
import '../models/order.dart';
import '../models/staff.dart';
import '../utils/formatters.dart';

/// Owns the order book and the rules for moving an order through the warehouse.
///
/// The rules are the point of this class. Anyone can draw three lists; what
/// stops a half-picked order reaching the loading bay is that [advance] refuses
/// it.
class TasksController extends ChangeNotifier {
  TasksController(this._repository);

  final WarehouseRepository _repository;

  List<Order> _orders = const [];
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  List<Order> get all => List<Order>.unmodifiable(_orders);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _repository.fetchOrders();
    } catch (_) {
      _error = 'Could not load orders. Pull to retry.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Orders sitting at [stage], oldest first.
  ///
  /// Oldest first is deliberate and the opposite of the rider app's feed: a
  /// queue of work is worked front to back, so the order that has been waiting
  /// longest is the one at the top of the screen.
  List<Order> queue(FulfilmentStage stage) {
    final list = _orders.where((order) => order.stage == stage).toList()
      ..sort((a, b) => a.placedAt.compareTo(b.placedAt));
    return list;
  }

  int queueCount(FulfilmentStage stage) =>
      _orders.where((order) => order.stage == stage).length;

  /// Everything still in the building, across all three queues.
  int get openCount => _orders.where((order) => order.stage.isOpen).length;

  /// Orders this app got as far as `checked` today -- the day's output.
  int get checkedToday {
    final now = DateTime.now();
    return _orders
        .where((order) =>
            order.checkedAt != null && isSameDay(order.checkedAt!, now))
        .length;
  }

  int get preparedToday {
    final now = DateTime.now();
    return _orders
        .where((order) =>
            order.preparedAt != null && isSameDay(order.preparedAt!, now))
        .length;
  }

  /// Waiting on a driver: packed, checked, and still here.
  int get awaitingDriver => queueCount(FulfilmentStage.checked);

  /// The oldest order still unprepared, if the floor is behind.
  Order? get oldestWaiting {
    final waiting = queue(FulfilmentStage.ordered);
    return waiting.isEmpty ? null : waiting.first;
  }

  Order? orderById(String orderId) {
    for (final order in _orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  /// Record progress on one line, then republish.
  Future<bool> setLinePicked(
    String orderId,
    String lineId,
    int picked,
  ) async {
    try {
      await _repository.setLinePicked(orderId, lineId, picked);
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'That line could not be updated.';
      notifyListeners();
      return false;
    }
  }

  /// Fill a line to its ordered quantity, or empty it. What a checkbox does.
  Future<bool> setLineComplete(
    String orderId,
    String lineId, {
    required bool complete,
  }) async {
    final line = orderById(orderId)?.lineById(lineId);
    if (line == null) return false;
    return setLinePicked(orderId, lineId, complete ? line.quantity : 0);
  }

  /// Add one unit to the line a scanned code belongs to.
  ///
  /// Returns the line it landed on, or null when the code is not on this order
  /// -- the caller turns that into "wrong item for this order", which is the
  /// single most useful thing a warehouse scanner can tell someone.
  Future<OrderLine?> applyScan(String orderId, String code) async {
    final order = orderById(orderId);
    if (order == null) return null;
    final line = order.lineForCode(code);
    if (line == null) return null;
    if (line.isComplete) return line;
    await setLinePicked(orderId, line.id, line.picked + 1);
    return line;
  }

  Future<bool> setNote(String orderId, String? note) async {
    try {
      await _repository.setStaffNote(orderId, note);
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'That note could not be saved.';
      notifyListeners();
      return false;
    }
  }

  /// Move an order to the next stage this app owns.
  ///
  /// Refuses when:
  ///  - the order is not in a stage staff can advance (it is with the driver);
  ///  - [staff] does not hold the role for the next stage;
  ///  - the pick is short and nobody has written down why.
  ///
  /// That last one is the important one. A short pick is a real and normal
  /// event -- the shelf was wrong, the item was damaged -- but it must not leave
  /// the building unremarked, or the customer finds out instead of the shop.
  Future<bool> advance(String orderId, {required Staff staff}) async {
    final order = orderById(orderId);
    if (order == null) return false;

    final next = order.stage.nextForStaff;
    if (next == null) {
      _error = order.stage == FulfilmentStage.checked
          ? 'This order is packed and waiting for the driver to collect it.'
          : 'This order has left the warehouse.';
      notifyListeners();
      return false;
    }

    if (!_roleAllows(staff, next)) {
      _error = 'Only a checker or supervisor can sign off a check.';
      notifyListeners();
      return false;
    }

    if (order.hasShortage && (order.staffNote?.isEmpty ?? true)) {
      _error = 'Some items are short. Add a note saying why before continuing.';
      notifyListeners();
      return false;
    }

    try {
      await _repository.setStage(orderId, next);
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'That order could not be updated.';
      notifyListeners();
      return false;
    }
  }

  bool _roleAllows(Staff staff, FulfilmentStage next) => switch (next) {
        FulfilmentStage.prepared => staff.role.canPrepare,
        FulfilmentStage.checked => staff.role.canCheck,
        _ => false,
      };

  /// Send an order back a stage, for when a check fails.
  ///
  /// The checker finding a mistake is the system working, so there has to be a
  /// way back to the packer that is not "cancel the order".
  Future<bool> sendBack(String orderId, {required Staff staff}) async {
    final order = orderById(orderId);
    if (order == null) return false;
    if (order.stage != FulfilmentStage.prepared) {
      _error = 'Only an order waiting to be checked can go back.';
      notifyListeners();
      return false;
    }
    if (!staff.role.canCheck) {
      _error = 'Only a checker or supervisor can send an order back.';
      notifyListeners();
      return false;
    }
    try {
      await _repository.setStage(orderId, FulfilmentStage.ordered);
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'That order could not be updated.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
