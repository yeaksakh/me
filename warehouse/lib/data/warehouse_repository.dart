import '../models/stock_count.dart';
import '../models/stock_item.dart';
import 'local_store.dart';
import 'mock_data.dart';

/// Stock, still standing in for the network layer.
///
/// Shipments are real now and live in `shipments_api.dart`. Stock is not yet:
/// the ERP has no stock endpoints for a Bearer token, so this keeps its seed data
/// and persists it on the device. Swap the bodies for HTTP calls and nothing
/// above this class has to change:
///
///   GET   /api/v2/warehouse/stock?q=
///   POST  /api/v2/warehouse/stock/{sku}/adjust     {"delta": -1, "reason": "damaged"}
///   POST  /api/v2/warehouse/counts                 {"lines": [...]}
class WarehouseRepository {
  WarehouseRepository({
    List<StockItem>? initialStock,
    LocalStore? store,
  })  : _stock = initialStock ?? MockData.seedStock(),
        _store = store;

  final List<StockItem> _stock;

  /// Optional. Without a store the repository is purely in-memory, which is
  /// what the tests use.
  final LocalStore? _store;
  bool _hydrated = false;

  /// Simulated latency, so loading states are exercised in the UI.
  Duration latency = const Duration(milliseconds: 400);

  Future<void> _pause() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  Future<List<StockItem>> fetchStock() async {
    await _hydrate();
    await _pause();
    return List<StockItem>.unmodifiable(_stock);
  }

  /// Change an item's on-hand by [delta], for a stated reason.
  ///
  /// A delta rather than an absolute: two people adjusting the same item from
  /// different handsets should both be applied, and last-write-wins on an
  /// absolute would silently drop one of them.
  Future<StockItem> adjustStock(
    String stockItemId,
    int delta,
    StockChangeReason reason,
  ) async {
    await _pause();
    final item = _findStock(stockItemId);
    item.onHand = (item.onHand + delta).clamp(0, 1 << 31);
    if (reason == StockChangeReason.count) item.countedAt = DateTime.now();
    await _persistStock();
    return item;
  }

  /// Set an item's on-hand outright. Used when submitting a count, where the
  /// counted number *is* the truth rather than a correction to it.
  Future<StockItem> setOnHand(String stockItemId, int onHand) async {
    final item = _findStock(stockItemId);
    item.onHand = onHand < 0 ? 0 : onHand;
    item.countedAt = DateTime.now();
    await _persistStock();
    return item;
  }

  /// Look an item up by barcode, falling back to SKU. Null when nothing matches
  /// -- which the scan sheet reports rather than silently doing nothing.
  Future<StockItem?> findByCode(String code) async {
    await _hydrate();
    for (final item in _stock) {
      if (item.matchesCode(code)) return item;
    }
    return null;
  }

  /// Apply a finished count: every counted line writes its number to the shelf.
  /// Uncounted lines are left alone -- skipping a line is not the same as
  /// finding nothing there.
  Future<List<StockItem>> submitCount(StockCount count) async {
    await _pause();
    for (final line in count.lines) {
      final counted = line.counted;
      if (counted == null) continue;
      final item = _findStockOrNull(line.stockItemId);
      if (item == null) continue;
      item.onHand = counted < 0 ? 0 : counted;
      item.countedAt = DateTime.now();
    }
    count.submittedAt = DateTime.now();
    await _persistStock();
    return List<StockItem>.unmodifiable(_stock);
  }

  /// Replaces the seed data with whatever was saved last run, once per session.
  Future<void> _hydrate() async {
    final store = _store;
    if (_hydrated || store == null) return;
    _hydrated = true;

    final savedStock = await store.loadStock();
    if (savedStock != null && savedStock.isNotEmpty) {
      _stock
        ..clear()
        ..addAll(savedStock);
    } else {
      await store.saveStock(_stock);
    }
  }

  Future<void> _persistStock() async => _store?.saveStock(_stock);

  StockItem _findStock(String stockItemId) => _stock.firstWhere(
        (item) => item.id == stockItemId,
        orElse: () => throw StateError('No stock item with id $stockItemId'),
      );

  StockItem? _findStockOrNull(String stockItemId) {
    for (final item in _stock) {
      if (item.id == stockItemId) return item;
    }
    return null;
  }
}
