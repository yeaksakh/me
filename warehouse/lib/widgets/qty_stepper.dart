import 'package:flutter/material.dart';

/// Minus / number / plus, sized for a thumb.
///
/// The number itself is a button: tapping it opens a keypad, because correcting
/// a count of 60 to 6 by pressing minus is not a thing anyone should have to do.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.onTapValue,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final VoidCallback? onTapValue;

  bool get _canDecrease => value > min;
  bool get _canIncrease => max == null || value < max!;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: _canDecrease ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
          tooltip: 'One less',
        ),
        InkWell(
          onTap: onTapValue,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 52),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: _canIncrease ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
          tooltip: 'One more',
        ),
      ],
    );
  }
}
