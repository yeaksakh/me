import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/models/fulfilment_stage.dart';
import 'package:warehouse/state/tasks_controller.dart';

import 'fixtures.dart';

void main() {
  group('Tabs', () {
    test('each tab holds only its own status, with the server count', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1'),
        buildOrder(id: '2', stage: FulfilmentStage.packed),
        buildOrder(id: '3', stage: FulfilmentStage.audited),
        buildOrder(id: '4', stage: FulfilmentStage.audited),
      ]);

      expect(tasks.queue(FulfilmentStage.ordered).single.id, '1');
      expect(tasks.queue(FulfilmentStage.packed).single.id, '2');
      expect(tasks.queueCount(FulfilmentStage.audited), 2);
      expect(tasks.toPackCount, 1);
    });

    test('a tab is newest first, as the website lists shipments', () async {
      final tasks = await tasksWith([
        buildOrder(id: 'old', placedAt: DateTime(2026, 1, 1, 9)),
        buildOrder(id: 'new', placedAt: DateTime(2026, 1, 1, 11)),
      ]);

      expect(
        tasks.queue(FulfilmentStage.ordered).map((o) => o.id).toList(),
        ['new', 'old'],
      );
    });

    test('an expired session signs out instead of failing on every pull',
        () async {
      var signedOut = false;
      final tasks = TasksController(
        FakeShipmentsApi()..expired = true,
        onUnauthorized: () => signedOut = true,
      );

      await tasks.refreshAll();

      expect(signedOut, isTrue);
      expect(tasks.error, contains('expired'));
      expect(tasks.hasLoaded(FulfilmentStage.ordered), isFalse);
    });
  });

  group('Accepting', () {
    test('accepting makes it yours and keeps it in Ordered', () async {
      final tasks = await tasksWith([buildOrder(id: '1')]);

      expect(await tasks.accept('1'), isTrue);
      expect(tasks.orderById('1')!.isAcceptedBy(supervisor.id), isTrue);
      expect(tasks.queue(FulfilmentStage.ordered).single.id, '1');
    });

    test('one someone else holds is refused, naming them', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', preparedById: 'x9', preparedByName: 'Chan Vy'),
      ]);

      expect(await tasks.accept('1'), isFalse);
      expect(tasks.error, contains('Chan Vy'));
      expect(tasks.orderById('1')!.isAcceptedBy(supervisor.id), isFalse);
    });

    test('handing back works before packing, and not after', () async {
      final tasks = await tasksWith([
        buildOrder(
          id: '1',
          preparedById: supervisor.id,
          lines: [buildLine(id: 'a'), buildLine(id: 'b')],
        ),
      ]);

      await tasks.setLinePacked('1', 'a', packed: true);
      expect(await tasks.release('1'), isFalse);

      await tasks.setLinePacked('1', 'a', packed: false);
      expect(await tasks.release('1'), isTrue);
      expect(tasks.orderById('1')!.isAccepted, isFalse);
    });
  });

  group('Packing', () {
    test('an item cannot be ticked before the shipment is accepted', () async {
      final tasks = await tasksWith([buildOrder(id: '1')]);

      expect(await tasks.setLinePacked('1', 'ln-1', packed: true), isFalse);
      expect(tasks.error, contains('Accept'));
    });

    test('nor on a shipment someone else is packing', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', preparedById: 'x9', preparedByName: 'Chan Vy'),
      ]);

      expect(await tasks.setLinePacked('1', 'ln-1', packed: true), isFalse);
      expect(tasks.error, contains('Someone else'));
    });

    test('Packed waits for every item, then moves the shipment on', () async {
      final tasks = await tasksWith([
        buildOrder(
          id: '1',
          preparedById: supervisor.id,
          lines: [buildLine(id: 'a'), buildLine(id: 'b')],
        ),
      ]);

      await tasks.setLinePacked('1', 'a', packed: true);
      expect(tasks.orderById('1')!.packedCount, 1);
      expect(await tasks.markPacked('1'), isFalse);
      expect(tasks.error, contains('1 left'));

      await tasks.setLinePacked('1', 'b', packed: true);
      expect(await tasks.markPacked('1'), isTrue);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.packed);
      expect(tasks.queue(FulfilmentStage.ordered), isEmpty);
      expect(tasks.queueCount(FulfilmentStage.packed), 1);
    });

    test('a scan ticks the item with that SKU', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', preparedById: supervisor.id),
      ]);

      final line = await tasks.applyScan('1', 'sku-1');

      expect(line, isNotNull);
      expect(tasks.orderById('1')!.lines.single.packed, isTrue);
    });

    test('a code from another shipment is reported, not silently ignored',
        () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', preparedById: supervisor.id),
      ]);

      expect(await tasks.applyScan('1', 'NOPE'), isNull);
      expect(tasks.orderById('1')!.lines.single.packed, isFalse);
    });

    test('a scan prefers an unticked item over a ticked one with the same SKU',
        () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', preparedById: supervisor.id, lines: [
          buildLine(id: 'a', packed: true),
          buildLine(id: 'b'),
        ]),
      ]);

      final line = await tasks.applyScan('1', 'SKU-1');

      expect(line!.id, 'b');
      expect(tasks.orderById('1')!.isFullyPacked, isTrue);
    });
  });

  group('Auditing', () {
    test('a packer cannot mark a shipment audited', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', stage: FulfilmentStage.packed),
      ], staff: packer);

      expect(await tasks.markAudited('1', staff: packer), isFalse);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.packed);
    });

    test('a supervisor can', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', stage: FulfilmentStage.packed),
      ]);

      expect(await tasks.markAudited('1', staff: supervisor), isTrue);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.audited);
      expect(tasks.queueCount(FulfilmentStage.audited), 1);
    });

    test('the app never moves a shipment past Audited', () async {
      final tasks = await tasksWith([
        buildOrder(id: '1', stage: FulfilmentStage.audited),
      ]);

      expect(await tasks.markAudited('1', staff: supervisor), isFalse);
      expect(tasks.orderById('1')!.stage, FulfilmentStage.audited);
    });
  });
}
