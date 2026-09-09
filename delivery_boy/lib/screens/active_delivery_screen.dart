import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/orders_controller.dart';
import '../utils/formatters.dart';
import '../widgets/delivery_confirm_sheet.dart';
import '../widgets/section_card.dart';
import '../widgets/status_timeline.dart';
import 'order_detail_screen.dart';

/// The screen a rider lives on while a delivery is in progress.
class ActiveDeliveryScreen extends StatelessWidget {
  const ActiveDeliveryScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersController>();
    final order = orders.orderById(orderId);

    if (order == null) {
      return const Scaffold(body: Center(child: Text('Order not found.')));
    }

    final finished = order.status.isFinished;

    return Scaffold(
      appBar: AppBar(
        title: Text(order.code),
        actions: [
          if (!finished)
            TextButton(
              onPressed: () => _confirmCancel(context, orders),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                StatusTimeline(current: order.status),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OrderRouteCard(order: order),
          const SizedBox(height: 12),
          OrderItemsCard(order: order),
          const SizedBox(height: 12),
          OrderPayoutCard(order: order),
        ],
      ),
      bottomNavigationBar: finished
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ElevatedButton(
                  onPressed: () => _advance(context, orders, order),
                  child: Text(order.status.actionLabel),
                ),
              ),
            ),
    );
  }

  Future<void> _advance(
    BuildContext context,
    OrdersController orders,
    Order order,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // The last step needs proof at the door, so it runs through the sheet.
    if (order.status == OrderStatus.onTheWay) {
      final proof = await DeliveryConfirmSheet.show(context, order);
      if (proof == null) return;

      final closed = await orders.completeDelivery(
        order.id,
        cashCollected: proof.cashCollected,
        note: proof.note,
      );
      if (!closed) {
        messenger.showSnackBar(
          SnackBar(content: Text(orders.error ?? 'Could not close that order.')),
        );
        orders.clearError();
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('Delivered. You earned ${money(order.riderEarnings)}.'),
        ),
      );
      if (navigator.canPop()) navigator.pop();
      return;
    }

    await orders.advance(order.id);
  }

  Future<void> _confirmCancel(
    BuildContext context,
    OrdersController orders,
  ) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this delivery?'),
        content: const Text(
          'The order goes back to the dispatcher and may affect your rating.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await orders.cancelActive();
    if (navigator.canPop()) navigator.pop();
  }
}
