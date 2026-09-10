import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The rounded panel the app is built out of.
///
/// [accent] paints a stripe down the left edge, so a list of cards shows its
/// colours -- a shipment's stage, a request's status -- before a word is read.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final stripe = accent;
    return Material(
      color: context.appColors.card,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        // A border rather than a sibling box: a stripe that must match the
        // card's height needs one, and a list item has no height to give.
        child: Container(
          decoration: stripe == null
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(color: stripe, width: 5)),
                ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// A card painted in a gradient of one colour, with white text on it -- the
/// headline of a screen.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        // Animated, so a card whose colour follows a state -- the clock's
        // amber and blue -- slides between them rather than snapping.
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        padding: padding,
        decoration: BoxDecoration(
          gradient: heroGradient(color),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(70),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white),
            child: child,
          ),
        ),
      );
}
