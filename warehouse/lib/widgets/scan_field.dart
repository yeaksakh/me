import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The scan box.
///
/// Built for a keyboard-wedge scanner -- the ring, sled or gun-style Android
/// terminal most warehouses actually run, which types the barcode into whatever
/// has focus and finishes with Enter. That means the primitive here is a focused
/// text field that submits on Enter and immediately clears itself, and it works
/// on day one with no camera permission, no plugin and no platform channel.
///
/// It doubles as manual entry, because the label on a crushed box is sometimes
/// the only readable thing left, and because the tests can drive it.
///
/// Camera scanning is a later addition rather than a rewrite: point a package
/// like `mobile_scanner` at [ScanField.onScan] and everything below stays put.
class ScanField extends StatefulWidget {
  const ScanField({
    super.key,
    required this.onScan,
    this.hintText = 'Scan or type a barcode',
    this.autofocus = true,
  });

  /// Called with the trimmed code each time one is entered.
  final ValueChanged<String> onScan;
  final String hintText;
  final bool autofocus;

  @override
  State<ScanField> createState() => _ScanFieldState();
}

class _ScanFieldState extends State<ScanField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final code = raw.trim();
    // Clear and refocus even on an empty submit: a scanner that fires Enter
    // twice must not leave the field holding half of the next barcode.
    _controller.clear();
    if (widget.autofocus) _focusNode.requestFocus();
    if (code.isEmpty) return;
    widget.onScan(code);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      // A barcode has no spaces; a wedge scanner that stumbles must not be able
      // to inject one into the middle of a code.
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      onSubmitted: _submit,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.qr_code_scanner),
        suffixIcon: IconButton(
          icon: const Icon(Icons.keyboard_return),
          tooltip: 'Enter code',
          onPressed: () => _submit(_controller.text),
        ),
      ),
    );
  }
}

/// What a scan did, so a screen can say so out loud.
///
/// Warehouse feedback has to survive not being looked at -- the person is
/// holding a box and watching the shelf, not the screen -- so every outcome
/// gets a distinct colour and a distinct sound/haptic at the call site.
enum ScanOutcome { accepted, alreadyComplete, unknown }

/// Shows the result of a scan as a snack bar.
void showScanResult(
  BuildContext context, {
  required ScanOutcome outcome,
  required String message,
}) {
  final scheme = Theme.of(context).colorScheme;
  final background = switch (outcome) {
    ScanOutcome.accepted => const Color(0xFF1B7F4C),
    ScanOutcome.alreadyComplete => const Color(0xFF9A6700),
    ScanOutcome.unknown => scheme.error,
  };
  final icon = switch (outcome) {
    ScanOutcome.accepted => Icons.check_circle,
    ScanOutcome.alreadyComplete => Icons.info,
    ScanOutcome.unknown => Icons.error,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        duration: const Duration(milliseconds: 1600),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
