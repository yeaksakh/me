import '../models/stock_item.dart';

/// Seed data for stock, so the Stock and Count tabs are explorable before the
/// ERP has stock endpoints.
///
/// A catalogue with a couple of deliberately awkward rows -- one out of stock,
/// one below its reorder level, one never counted -- because those are the rows
/// that show whether a screen was designed or just laid out.
///
/// Shipments and who is signed in are NOT seeded: both come from yeaksa.com.
class MockData {
  static DateTime _minutesAgo(int minutes) =>
      DateTime.now().subtract(Duration(minutes: minutes));

  static List<StockItem> seedStock() => [
        StockItem(
          id: 'stk-1',
          sku: 'YK-RICE-5',
          name: 'Jasmine rice',
          variant: '5 kg',
          barcode: '8850001000015',
          location: 'A-01-1',
          onHand: 120,
          reserved: 18,
          reorderLevel: 40,
          countedAt: _minutesAgo(60 * 24 * 3),
        ),
        StockItem(
          id: 'stk-2',
          sku: 'YK-FISH-1',
          name: 'Fish sauce',
          variant: '700 ml',
          barcode: '8850001000022',
          location: 'A-02-4',
          onHand: 64,
          reserved: 6,
          reorderLevel: 24,
          countedAt: _minutesAgo(60 * 24 * 9),
        ),
        StockItem(
          id: 'stk-3',
          sku: 'YK-TEA-20',
          name: 'Green tea',
          variant: '20 bags',
          barcode: '8850001000039',
          location: 'B-04-2',
          onHand: 9,
          reserved: 6,
          reorderLevel: 20,
          countedAt: _minutesAgo(60 * 30),
        ),
        StockItem(
          id: 'stk-4',
          sku: 'YK-SOAP-3',
          name: 'Hand soap',
          variant: '3 pack',
          barcode: '8850001000046',
          location: 'B-01-1',
          onHand: 4,
          reserved: 4,
          reorderLevel: 12,
        ),
        StockItem(
          id: 'stk-5',
          sku: 'YK-OIL-1',
          name: 'Cooking oil',
          variant: '1 L',
          barcode: '8850001000053',
          location: 'A-03-2',
          onHand: 51,
          reserved: 9,
          reorderLevel: 20,
          countedAt: _minutesAgo(60 * 24 * 1),
        ),
        StockItem(
          id: 'stk-6',
          sku: 'YK-NOOD-30',
          name: 'Instant noodles',
          variant: 'Carton of 30',
          barcode: '8850001000060',
          location: 'C-02-1',
          onHand: 37,
          reserved: 12,
          reorderLevel: 15,
          countedAt: _minutesAgo(60 * 24 * 5),
        ),
        StockItem(
          id: 'stk-7',
          sku: 'YK-SUGAR-1',
          name: 'Palm sugar',
          variant: '1 kg',
          location: 'C-05-3',
          onHand: 28,
          reserved: 2,
          reorderLevel: 10,
        ),
      ];
}
