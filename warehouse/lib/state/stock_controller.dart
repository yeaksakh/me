import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/warehouse_repository.dart';
import '../models/staff.dart';
import '../models/stock_count.dart';
import '../models/stock_item.dart';

/// Owns the catalogue, the search box over it, and the stock count in progress.
///
/// A count is a draft until it is submitted: entering numbers changes nothing on
/// the shelf, and the app keeps the draft on the device so a count spanning a
/// tea break, a dead battery or a shift change is not lost.
class StockController extends ChangeNotifier {
  StockController(this._repository, {LocalStore? store}) : _store = store;

  final WarehouseRepository _repository;
  final LocalStore? _store;

  List<StockItem> _items = const [];
  bool _loading = false;
  String? _error;
  String _query = '';
  StockCount? _count;

  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;
  List<StockItem> get all => List<StockItem>.unmodifiable(_items);

  /// The catalogue filtered by the search box, by name / SKU / bin / barcode.
  List<StockItem> get visible =>
      _items.where((item) => item.matchesQuery(_query)).toList();

  int get outOfStockCount => _items.where((item) => item.isOutOfStock).length;

  int get lowStockCount => _items.where((item) => item.isLow).length;

  /// Items needing attention, worst first: out of stock before merely low.
  List<StockItem> get needsAttention {
    final list =
        _items.where((item) => item.isOutOfStock || item.isLow).toList();
    list.sort((a, b) {
      if (a.isOutOfStock != b.isOutOfStock) return a.isOutOfStock ? -1 : 1;
      return a.available.compareTo(b.available);
    });
    return list;
  }

  int get totalUnits => _items.fold(0, (sum, item) => sum + item.onHand);

  /// The count in progress, or null when none is open.
  StockCount? get count => _count;

  bool get hasOpenCount => _count != null && !_count!.isSubmitted;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repository.fetchStock();
      _count ??= await _store?.loadCountDraft();
    } catch (_) {
      _error = 'Could not load stock. Pull to retry.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    if (_query == query) return;
    _query = query;
    notifyListeners();
  }

  StockItem? itemById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Find an item by scanned barcode or typed SKU.
  Future<StockItem?> findByCode(String code) => _repository.findByCode(code);

  /// Apply a manual correction. Guarded by role: writing stock numbers is not
  /// something every badge should be able to do.
  Future<bool> adjust(
    String stockItemId,
    int delta,
    StockChangeReason reason, {
    required Staff staff,
  }) async {
    if (!staff.role.canAdjustStock) {
      _error = 'Only a checker or supervisor can change stock numbers.';
      notifyListeners();
      return false;
    }
    if (delta == 0) return true;
    try {
      await _repository.adjustStock(stockItemId, delta, reason);
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'That adjustment could not be saved.';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Stock count
  // ---------------------------------------------------------------------------

  /// Open a count over [items], or the whole catalogue when none is given.
  ///
  /// Expected quantities are frozen into the lines here, so a variance means the
  /// shelf disagreed with the book when it was counted -- not that an order
  /// shipped while someone walked the aisle.
  StockCount startCount({List<StockItem>? items}) {
    final subject = items ?? _items;
    final count = StockCount(
      id: 'cnt-${DateTime.now().millisecondsSinceEpoch}',
      startedAt: DateTime.now(),
      lines: subject.map(CountLine.forItem).toList(),
    );
    _count = count;
    _saveDraft();
    notifyListeners();
    return count;
  }

  /// Throw away the count in progress without touching the shelf.
  void discardCount() {
    _count = null;
    _saveDraft();
    notifyListeners();
  }

  /// Enter what was found on one line. Passing null marks it uncounted again.
  void setCounted(String stockItemId, int? counted) {
    final line = _countLine(stockItemId);
    if (line == null) return;
    line.counted = counted == null ? null : (counted < 0 ? 0 : counted);
    _saveDraft();
    notifyListeners();
  }

  /// Add one to a line's counted figure -- what scanning the same shelf item
  /// repeatedly should do. An uncounted line starts from zero, so the first
  /// scan lands on 1.
  CountLine? applyScanToCount(String code) {
    final count = _count;
    if (count == null) return null;
    final line = count.lineForCode(code);
    if (line == null) return null;
    line.counted = (line.counted ?? 0) + 1;
    _saveDraft();
    notifyListeners();
    return line;
  }

  /// Write every counted line to the shelf and close the count.
  Future<bool> submitCount({required Staff staff}) async {
    final count = _count;
    if (count == null) return false;
    if (!staff.role.canAdjustStock) {
      _error = 'Only a checker or supervisor can submit a count.';
      notifyListeners();
      return false;
    }
    if (count.countedCount == 0) {
      _error = 'Count at least one item before submitting.';
      notifyListeners();
      return false;
    }
    try {
      _items = await _repository.submitCount(count);
      _error = null;
      _count = null;
      await _store?.saveCountDraft(null);
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'That count could not be submitted.';
      notifyListeners();
      return false;
    }
  }

  CountLine? _countLine(String stockItemId) {
    final count = _count;
    if (count == null) return null;
    for (final line in count.lines) {
      if (line.stockItemId == stockItemId) return line;
    }
    return null;
  }

  void _saveDraft() => _store?.saveCountDraft(_count);

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
