import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/stock_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/scan_field.dart';
import '../widgets/stat_tile.dart';
import '../widgets/stock_row.dart';
import 'count_screen.dart';
import 'stock_detail_screen.dart';

/// The catalogue: search it, scan into it, tap through to adjust.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _searchController = TextEditingController();
  bool _scanning = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String code) async {
    final stock = context.read<StockController>();
    final item = await stock.findByCode(code);
    if (!mounted) return;

    if (item == null) {
      HapticFeedback.heavyImpact();
      showScanResult(
        context,
        outcome: ScanOutcome.unknown,
        message: 'Nothing in the catalogue matches $code.',
      );
      return;
    }

    HapticFeedback.selectionClick();
    // Jump straight to the item. Scanning something is a question about that
    // thing, and answering it with a filtered list would be one tap too many.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(stockItemId: item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockController>();
    final colors = context.appColors;
    final items = stock.visible;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text(
          'Stock',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _scanning = !_scanning),
            icon: Icon(_scanning ? Icons.close : Icons.qr_code_scanner),
            tooltip: _scanning ? 'Close scanner' : 'Scan',
          ),
          // The count lives here rather than on a tab: it is a rare job, and
          // the tab went to HR, which is a daily one.
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CountScreen()),
            ),
            icon: Icon(
              stock.hasOpenCount
                  ? Icons.checklist_rtl
                  : Icons.checklist_outlined,
            ),
            tooltip: 'Stock count',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<StockController>().load(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  if (_scanning) ...[
                    ScanField(
                      onScan: _handleScan,
                      hintText: 'Scan a product',
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _searchController,
                    onChanged: stock.search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search name, SKU or bin',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: stock.query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                stock.search('');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          icon: Icons.category_outlined,
                          label: 'Products',
                          value: '${stock.all.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          icon: Icons.trending_down,
                          label: 'Low',
                          value: '${stock.lowStockCount}',
                          tone: colors.lowStock,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          icon: Icons.remove_shopping_cart_outlined,
                          label: 'Out',
                          value: '${stock.outOfStockCount}',
                          tone: colors.outOfStock,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.4,
                          child: EmptyState(
                            icon: Icons.search_off,
                            title: stock.query.isEmpty
                                ? 'No stock yet'
                                : 'Nothing matches',
                            message: stock.query.isEmpty
                                ? 'Products appear here once the catalogue loads.'
                                : 'Try a different name, SKU or bin.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return StockRow(
                          item: item,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  StockDetailScreen(stockItemId: item.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
