import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/models/stock_count.dart';
import 'package:warehouse/models/stock_item.dart';

import 'fixtures.dart';

void main() {
  group('Stock figures', () {
    test('free to sell is on hand minus reserved', () {
      expect(buildStock(onHand: 10, reserved: 4).available, 6);
    });

    test('an item fully reserved is out of stock even with units on the shelf',
        () {
      final item = buildStock(onHand: 5, reserved: 5);
      expect(item.onHand, 5);
      expect(item.isOutOfStock, isTrue);
    });

    test('low and out never both fire for the same row', () {
      final out = buildStock(onHand: 0, reorderLevel: 10);
      expect(out.isOutOfStock, isTrue);
      expect(out.isLow, isFalse);

      final low = buildStock(onHand: 3, reorderLevel: 10);
      expect(low.isLow, isTrue);
      expect(low.isOutOfStock, isFalse);
    });

    test('no reorder level means never low', () {
      expect(buildStock(onHand: 1, reorderLevel: 0).isLow, isFalse);
    });

    test('search covers name, SKU, bin and barcode', () {
      final item = StockItem(
        id: '1',
        sku: 'YK-RICE-5',
        name: 'Jasmine rice',
        barcode: '8850001',
        location: 'A-01-1',
        onHand: 1,
      );

      expect(item.matchesQuery('jasmine'), isTrue);
      expect(item.matchesQuery('rice-5'), isTrue);
      expect(item.matchesQuery('a-01'), isTrue);
      expect(item.matchesQuery('88500'), isTrue);
      expect(item.matchesQuery('noodles'), isFalse);
      expect(item.matchesQuery(''), isTrue);
    });
  });

  group('Adjusting', () {
    test('a checker can adjust, a packer cannot', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);

      expect(
        await stock.adjust('stk-1', -2, StockChangeReason.damaged,
            staff: packer),
        isFalse,
      );
      expect(stock.itemById('stk-1')!.onHand, 10);

      expect(
        await stock.adjust('stk-1', -2, StockChangeReason.damaged,
            staff: checker),
        isTrue,
      );
      expect(stock.itemById('stk-1')!.onHand, 8);
    });

    test('a count adjustment stamps the counted date', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      expect(stock.itemById('stk-1')!.countedAt, isNull);

      await stock.adjust('stk-1', 1, StockChangeReason.count, staff: checker);
      expect(stock.itemById('stk-1')!.countedAt, isNotNull);
    });

    test('on hand never goes below zero', () async {
      final stock = await stockWith([buildStock(onHand: 3)]);

      await stock.adjust('stk-1', -50, StockChangeReason.correction,
          staff: checker);
      expect(stock.itemById('stk-1')!.onHand, 0);
    });

    test('needs attention puts out of stock before merely low', () async {
      final stock = await stockWith([
        buildStock(id: 'a', sku: 'A', onHand: 5, reorderLevel: 10),
        buildStock(id: 'b', sku: 'B', onHand: 0, reorderLevel: 10),
        buildStock(id: 'c', sku: 'C', onHand: 100, reorderLevel: 10),
      ]);

      expect(stock.needsAttention.map((i) => i.id).toList(), ['b', 'a']);
    });
  });

  group('Stock count', () {
    test('opening a count freezes expected at the current on hand', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      final count = stock.startCount();

      expect(count.lines.single.expected, 10);
      expect(count.lines.single.counted, isNull);
      expect(count.isComplete, isFalse);
    });

    test('nothing on the shelf moves until submit', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      stock.startCount();

      stock.setCounted('stk-1', 7);
      expect(stock.itemById('stk-1')!.onHand, 10);

      await stock.submitCount(staff: checker);
      expect(stock.itemById('stk-1')!.onHand, 7);
    });

    test('an uncounted line is left alone, a zero line writes the shelf down',
        () async {
      final stock = await stockWith([
        buildStock(id: 'a', sku: 'A', onHand: 10),
        buildStock(id: 'b', sku: 'B', onHand: 10),
      ]);
      stock.startCount();

      stock.setCounted('b', 0);
      await stock.submitCount(staff: checker);

      expect(stock.itemById('a')!.onHand, 10);
      expect(stock.itemById('b')!.onHand, 0);
    });

    test('variance is counted minus expected, and null while uncounted',
        () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      final count = stock.startCount();

      expect(count.lines.single.variance, isNull);
      stock.setCounted('stk-1', 12);
      expect(count.lines.single.variance, 2);
      stock.setCounted('stk-1', 8);
      expect(count.lines.single.variance, -2);
    });

    test('clearing a line makes it uncounted again, not zero', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      final count = stock.startCount();

      stock.setCounted('stk-1', 4);
      expect(count.lines.single.isCounted, isTrue);

      stock.setCounted('stk-1', null);
      expect(count.lines.single.isCounted, isFalse);
      expect(count.lines.single.variance, isNull);
    });

    test('net and absolute variance tell different stories', () async {
      final stock = await stockWith([
        buildStock(id: 'a', sku: 'A', onHand: 10),
        buildStock(id: 'b', sku: 'B', onHand: 10),
      ]);
      final count = stock.startCount();

      stock.setCounted('a', 15);
      stock.setCounted('b', 5);

      expect(count.netVariance, 0);
      expect(count.absoluteVariance, 10);
      expect(count.variances.length, 2);
    });

    test('a scan adds one, starting an uncounted line at one', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      final count = stock.startCount();

      stock.applyScanToCount('SKU-1');
      expect(count.lines.single.counted, 1);
      stock.applyScanToCount('SKU-1');
      expect(count.lines.single.counted, 2);
    });

    test('a scan for something not in this count is reported', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      stock.startCount();

      expect(stock.applyScanToCount('SKU-NOPE'), isNull);
    });

    test('a packer cannot submit a count', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      stock.startCount();
      stock.setCounted('stk-1', 3);

      expect(await stock.submitCount(staff: packer), isFalse);
      expect(stock.itemById('stk-1')!.onHand, 10);
    });

    test('an empty count is refused rather than submitted as a no-op',
        () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      stock.startCount();

      expect(await stock.submitCount(staff: checker), isFalse);
      expect(stock.error, contains('at least one'));
    });

    test('submitting closes the count', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      stock.startCount();
      stock.setCounted('stk-1', 9);

      await stock.submitCount(staff: checker);
      expect(stock.hasOpenCount, isFalse);
      expect(stock.count, isNull);
    });

    test('discarding leaves the shelf untouched', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      stock.startCount();
      stock.setCounted('stk-1', 1);

      stock.discardCount();
      expect(stock.hasOpenCount, isFalse);
      expect(stock.itemById('stk-1')!.onHand, 10);
    });

    test('a partial count can target only what needs attention', () async {
      final stock = await stockWith([
        buildStock(id: 'a', sku: 'A', onHand: 100, reorderLevel: 5),
        buildStock(id: 'b', sku: 'B', onHand: 0, reorderLevel: 5),
      ]);

      final count = stock.startCount(items: stock.needsAttention);
      expect(count.lines.map((line) => line.stockItemId).toList(), ['b']);
    });

    test('a count survives being rebuilt from JSON mid-walk', () async {
      final stock = await stockWith([buildStock(onHand: 10)]);
      final count = stock.startCount();
      stock.setCounted('stk-1', 6);

      final restored = StockCount.fromJson(count.toJson());
      expect(restored.lines.single.counted, 6);
      expect(restored.lines.single.expected, 10);
      expect(restored.netVariance, -4);
    });
  });
}
