import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/fulfilment_stage.dart';
import '../models/order.dart';
import '../state/tasks_controller.dart';
import '../utils/formatters.dart';
import 'alerts.dart';

/// Watches for orders that have just arrived to be packed, and makes the phone
/// ring.
///
/// **Why polling.** The server can push to the rider app, but that needs a
/// Firebase service account the shop has not issued. Until it does, this is
/// what tells the floor about work: a refresh of the Ordered tab on a timer
/// while someone is signed in. It is strictly worse than push -- up to
/// [interval] late, and it only runs while the app is alive -- so when push is
/// configured this should be turned down to a slow safety net.
///
/// **It only alerts on orders it has not seen before.** The first load after
/// sign-in seeds the known set silently: someone opening the app to six
/// waiting orders should not get six alarms.
class OrderWatcher {
  OrderWatcher({
    required TasksController tasks,
    required Alerts alerts,
    this.interval = const Duration(seconds: 30),
  })  : _tasks = tasks,
        _alerts = alerts;

  final TasksController _tasks;
  final Alerts _alerts;

  /// How often to ask. Thirty seconds: an order is packed within the minute
  /// it arrives, and a phone on a belt all shift still lasts the day.
  final Duration interval;

  Timer? _timer;
  final Set<String> _known = {};
  bool _seeded = false;
  bool _polling = false;

  bool get running => _timer != null;

  /// Begin watching. Safe to call repeatedly.
  Future<void> start() async {
    if (_timer != null) return;
    await _alerts.init();
    // Seed from whatever is already loaded, so orders on screen at sign-in
    // are not announced as new.
    if (_tasks.hasLoaded(FulfilmentStage.ordered)) {
      _seed(_tasks.queue(FulfilmentStage.ordered));
    }
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _known.clear();
    _seeded = false;
  }

  void _seed(List<Order> orders) {
    _known
      ..clear()
      ..addAll(orders.map((o) => o.id));
    _seeded = true;
  }

  /// One refresh. Public so a test, or a pull-to-refresh, can reuse the same
  /// new-order detection rather than racing it.
  Future<void> poll() => _poll();

  Future<void> _poll() async {
    // Overlapping polls would double-alert on a slow connection.
    if (_polling) return;
    _polling = true;
    try {
      await _tasks.load(FulfilmentStage.ordered);
      if (!_tasks.hasLoaded(FulfilmentStage.ordered)) return;
      final current = _tasks.queue(FulfilmentStage.ordered);

      if (!_seeded) {
        _seed(current);
        return;
      }

      final fresh = current.where((o) => !_known.contains(o.id)).toList();
      _known
        ..clear()
        ..addAll(current.map((o) => o.id));

      for (final order in fresh) {
        await _alerts.showNewOrder(
          orderId: order.id,
          code: order.code,
          customer: order.customerName,
          summary: '${plural(order.lineCount, 'item')}, '
              '${plural(order.totalQuantity.round(), 'unit')}',
        );
      }
    } catch (error) {
      // A failed poll is normal under a tin roof. The next one catches up.
      debugPrint('Order poll failed: $error');
    } finally {
      _polling = false;
    }
  }

  void dispose() => stop();
}
