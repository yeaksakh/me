import 'package:flutter/material.dart';

import '../models/order.dart';
import '../utils/formatters.dart';

/// What the rider confirms at the door before an order is closed out.
class DeliveryProof {
  const DeliveryProof({required this.cashCollected, this.note});

  final bool cashCollected;
  final String? note;
}

/// Bottom sheet shown on the final step of a delivery. For cash orders the
/// rider cannot confirm until they tick that they took the money.
class DeliveryConfirmSheet extends StatefulWidget {
  const DeliveryConfirmSheet({super.key, required this.order});

  final Order order;

  static Future<DeliveryProof?> show(BuildContext context, Order order) {
    return showModalBottomSheet<DeliveryProof>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DeliveryConfirmSheet(order: order),
    );
  }

  @override
  State<DeliveryConfirmSheet> createState() => _DeliveryConfirmSheetState();
}

class _DeliveryConfirmSheetState extends State<DeliveryConfirmSheet> {
  final _note = TextEditingController();
  bool _collected = false;

  bool get _isCash => widget.order.paymentMethod == PaymentMethod.cash;
  bool get _canConfirm => !_isCash || _collected;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = widget.order;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Close out ${order.code}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Handing over to ${order.dropoff.contactName ?? order.dropoff.label}.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          if (_isCash)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _collected,
              onChanged: (value) => setState(() => _collected = value ?? false),
              title: Text(
                'I collected ${money(order.amountToCollect)} in cash',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Required before this order can be closed.'),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: scheme.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Already paid online — collect nothing.'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Left with reception, customer not in...',
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _canConfirm
                ? () => Navigator.of(context).pop(
                      DeliveryProof(
                        cashCollected: _isCash ? _collected : false,
                        note: _note.text,
                      ),
                    )
                : null,
            child: const Text('Confirm delivery'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not yet'),
          ),
        ],
      ),
    );
  }
}
