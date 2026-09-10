import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/services/alerts.dart';
import 'package:warehouse/services/order_watcher.dart';
import 'package:warehouse/state/tasks_controller.dart';

import 'fixtures.dart';

/// Records what would have rung, without a platform to ring on.
class FakeAlerts extends Alerts {
  final List<String> rung = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showNewOrder({
    required String orderId,
    required String code,
    required String customer,
    required String summary,
  }) async {
    rung.add('$code · $customer · $summary');
  }
}

void main() {
  test('the orders on screen at sign-in are not announced', () async {
    final api =
        FakeShipmentsApi(orders: [buildOrder(id: '1'), buildOrder(id: '2')]);
    final tasks = TasksController(api);
    await tasks.load(FulfilmentStage.ordered);
    final alerts = FakeAlerts();
    final watcher = OrderWatcher(tasks: tasks, alerts: alerts);

    await watcher.start();
    await watcher.poll();
    watcher.stop();

    expect(alerts.rung, isEmpty);
  });

  test('an order that arrives after that rings once, with what it is',
      () async {
    final api = FakeShipmentsApi(orders: [buildOrder(id: '1')]);
    final tasks = TasksController(api);
    await tasks.load(FulfilmentStage.ordered);
    final alerts = FakeAlerts();
    final watcher = OrderWatcher(tasks: tasks, alerts: alerts);
    await watcher.start();

    final fresh = buildOrder(id: '9', lines: [buildLine(quantity: 3)]);
    // Arrives on the server between two polls.
    api.add(fresh);
    await watcher.poll();
    await watcher.poll();
    watcher.stop();

    expect(alerts.rung, ['YK-9 · Customer 9 · 1 item, 3 units']);
  });

  test('the first poll seeds silently when nothing was loaded at start',
      () async {
    final api = FakeShipmentsApi(orders: [buildOrder(id: '1')]);
    final tasks = TasksController(api);
    final alerts = FakeAlerts();
    final watcher = OrderWatcher(tasks: tasks, alerts: alerts);

    await watcher.start();
    await watcher.poll();
    api.add(buildOrder(id: '2'));
    await watcher.poll();
    watcher.stop();

    expect(alerts.rung.length, 1);
    expect(alerts.rung.single, startsWith('YK-2'));
  });

  test('stopping forgets what it knew, so the next shift is seeded afresh',
      () async {
    final api = FakeShipmentsApi(orders: [buildOrder(id: '1')]);
    final tasks = TasksController(api);
    await tasks.load(FulfilmentStage.ordered);
    final alerts = FakeAlerts();
    final watcher = OrderWatcher(tasks: tasks, alerts: alerts);
    await watcher.start();
    watcher.stop();
    expect(watcher.running, isFalse);

    api.add(buildOrder(id: '2'));
    await tasks.load(FulfilmentStage.ordered);
    await watcher.start();
    await watcher.poll();
    watcher.stop();

    // Order 2 was on screen when the watcher restarted: not news.
    expect(alerts.rung, isEmpty);
  });
}
