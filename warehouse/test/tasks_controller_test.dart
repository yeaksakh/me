import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/models/order.dart';

import 'fixtures.dart';

void main() {
  group('Queues', () {
    test('a queue holds only orders at that stage', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1'),
        buildOrder(id: '2', stage: FulfilmentStage.prepared),
        buildOrder(id: '3', stage: FulfilmentStage.checked),
      ]);

      expect(tasks.queue(FulfilmentStage.ordered).single.id, '1');
      expect(tasks.queue(FulfilmentStage.prepared).single.id, '2');
      expect(tasks.queue(FulfilmentStage.checked).single.id, '3');
    });

    test('a queue is oldest first, so the longest wait is worked next',
        () async {
      final tasks = await tasksWith([
        buildOrder(id: 'new', placedAt: DateTime(2026, 1, 1, 11)),
        buildOrder(id: 'old', placedAt: DateTime(2026, 1, 1, 9)),
      ]);

      expect(
        tasks.queue(FulfilmentStage.ordered).map((o) => o.id).toList(),
        ['old', 'new'],
      );
    });

    test('open count spans the three warehouse queues but not the driver',
        () async {
      final tasks = await tasksWith([
        buildOrder(id: '1'),
        buildOrder(id: '2', stage: FulfilmentStage.prepared),
        buildOrder(id: '3', stage: FulfilmentStage.checked),
        buildOrder(id: '4', stage: FulfilmentStage.pickedUp),
        buildOrder(id: '5', stage: FulfilmentStage.delivered),
      ]);

      expect(tasks.openCount, 3);
      expect(tasks.awaitingDriver, 1);
    });
  });

  group('Advancing', () {
    test('a fully picked order goes ordered -> prepared', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 2, picked: 2)]),
      ]);

      expect(await tasks.advance('1', staff: packer), isTrue);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.prepared);
    });

    test('preparing stamps preparedAt', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 1, picked: 1)]),
      ]);

      await tasks.advance('1', staff: packer);
      expect(tasks.orderById('1')!.preparedAt, isNotNull);
    });

    test('a packer cannot sign off their own check', () async {
      final tasks = await tasksWith([
        buildOrder(
          id: '1',
          stage: FulfilmentStage.prepared,
          lines: [buildLine(quantity: 1, picked: 1)],
        ),
      ]);

      expect(await tasks.advance('1', staff: packer), isFalse);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.prepared);
      expect(tasks.error, contains('checker'));
    });

    test('a checker can', () async {
      final tasks = await tasksWith([
        buildOrder(
          id: '1',
          stage: FulfilmentStage.prepared,
          lines: [buildLine(quantity: 1, picked: 1)],
        ),
      ]);

      expect(await tasks.advance('1', staff: checker), isTrue);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.checked);
      expect(tasks.orderById('1')!.checkedAt, isNotNull);
    });

    test('a short pick is refused while nobody has said why', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 3, picked: 1)]),
      ]);

      expect(await tasks.advance('1', staff: packer), isFalse);
      expect(tasks.error, contains('short'));
      expect(tasks.orderById('1')!.stage, FulfilmentStage.ordered);
    });

    test('a short pick with a note is allowed through', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 3, picked: 1)]),
      ]);

      await tasks.setNote('1', 'Shelf was empty, two owed.');
      expect(await tasks.advance('1', staff: packer), isTrue);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.prepared);
    });

    test('a whitespace-only note does not count as an explanation', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 3, picked: 1)]),
      ]);

      await tasks.setNote('1', '   ');
      expect(await tasks.advance('1', staff: packer), isFalse);
    });

    test('staff cannot hand an order to the driver on the driver\'s behalf',
        () async {
      final tasks = await tasksWith([
        buildOrder(
          id: '1',
          stage: FulfilmentStage.checked,
          lines: [buildLine(quantity: 1, picked: 1)],
        ),
      ]);

      expect(await tasks.advance('1', staff: checker), isFalse);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.checked);
      expect(tasks.error, contains('driver'));
    });

    test('an order already gone cannot be advanced', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', stage: FulfilmentStage.delivered),
      ]);

      expect(await tasks.advance('1', staff: checker), isFalse);
    });
  });

  group('Sending back', () {
    test('a checker can return a prepared order to packing', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', stage: FulfilmentStage.prepared),
      ]);

      expect(await tasks.sendBack('1', staff: checker), isTrue);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.ordered);
    });

    test('a packer cannot', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', stage: FulfilmentStage.prepared),
      ]);

      expect(await tasks.sendBack('1', staff: packer), isFalse);
    });

    test('only an order waiting to be checked can go back', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', stage: FulfilmentStage.checked),
      ]);

      expect(await tasks.sendBack('1', staff: checker), isFalse);
    });
  });

  group('Picking', () {
    test('picked is clamped to the ordered quantity', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 2)]),
      ]);

      await tasks.setLinePicked('1', 'ln-1', 99);
      expect(tasks.orderById('1')!.lines.single.picked, 2);

      await tasks.setLinePicked('1', 'ln-1', -5);
      expect(tasks.orderById('1')!.lines.single.picked, 0);
    });

    test('a scan adds one to the matching line', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 3)]),
      ]);

      final line = await tasks.applyScan('1', 'BC-1');
      expect(line, isNotNull);
      expect(tasks.orderById('1')!.lines.single.picked, 1);
    });

    test('a scan matches the SKU too, for shops without barcodes', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(barcode: null, quantity: 2)]),
      ]);

      await tasks.applyScan('1', 'sku-1');
      expect(tasks.orderById('1')!.lines.single.picked, 1);
    });

    test('a code from another order is reported, not silently ignored',
        () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 1)]),
      ]);

      expect(await tasks.applyScan('1', 'BC-NOPE'), isNull);
      expect(tasks.orderById('1')!.lines.single.picked, 0);
    });

    test('scanning a finished line does not overfill it', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 1, picked: 1)]),
      ]);

      final line = await tasks.applyScan('1', 'BC-1');
      expect(line, isNotNull);
      expect(tasks.orderById('1')!.lines.single.picked, 1);
    });

    test('a repeated scan fills the second unit of the same line', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 2)]),
      ]);

      await tasks.applyScan('1', 'BC-1');
      await tasks.applyScan('1', 'BC-1');
      expect(tasks.orderById('1')!.lines.single.picked, 2);
      expect(tasks.orderById('1')!.isFullyPicked, isTrue);
    });

    test('a scan prefers an unfinished line over a finished duplicate',
        () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [
          buildLine(id: 'a', quantity: 1, picked: 1),
          buildLine(id: 'b', quantity: 2),
        ]),
      ]);

      final line = await tasks.applyScan('1', 'BC-1');
      expect(line!.id, 'b');
    });

    test('ticking a line complete fills it, unticking empties it', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', lines: [buildLine(quantity: 4)]),
      ]);

      await tasks.setLineComplete('1', 'ln-1', complete: true);
      expect(tasks.orderById('1')!.lines.single.picked, 4);

      await tasks.setLineComplete('1', 'ln-1', complete: false);
      expect(tasks.orderById('1')!.lines.single.picked, 0);
    });
  });

  group('Day figures', () {
    test('today counts only what was stamped today', () async {
      final now = DateTime.now();
      final tasks = await tasksWith([
        buildOrder(
          id: '1',
          stage: FulfilmentStage.checked,
          preparedAt: now,
          checkedAt: now,
        ),
        buildOrder(
          id: '2',
          stage: FulfilmentStage.delivered,
          preparedAt: now.subtract(const Duration(days: 2)),
          checkedAt: now.subtract(const Duration(days: 2)),
        ),
      ]);

      expect(tasks.checkedToday, 1);
      expect(tasks.preparedToday, 1);
    });
  });

  group('Order maths', () {
    test('progress is by units, not lines', () {
      final order = buildOrder(id: '1', lines: [
        buildLine(id: 'a', quantity: 1, picked: 1),
        buildLine(id: 'b', quantity: 3),
      ]);

      expect(order.unitCount, 4);
      expect(order.pickedCount, 1);
      expect(order.pickProgress, 0.25);
      expect(order.hasShortage, isTrue);
    });

    test('cash on delivery is the unpaid orders', () {
      expect(
        buildOrder(id: '1', payment: PaymentStatus.unpaid).isCashOnDelivery,
        isTrue,
      );
      expect(
        buildOrder(id: '2', payment: PaymentStatus.paid).isCashOnDelivery,
        isFalse,
      );
    });

    test('an order survives a JSON round trip, part-picked and all', () {
      final order = buildOrder(
        id: '1',
        stage: FulfilmentStage.prepared,
        staffNote: 'One short',
        lines: [buildLine(quantity: 3, picked: 2)],
      );

      final restored = Order.fromJson(order.toJson());
      expect(restored.stage, FulfilmentStage.prepared);
      expect(restored.lines.single.picked, 2);
      expect(restored.staffNote, 'One short');
      expect(restored.hasShortage, isTrue);
    });
  });
}
