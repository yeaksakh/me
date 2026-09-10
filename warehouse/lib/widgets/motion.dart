import 'package:flutter/material.dart';

/// The app's motion, in three small pieces. Every one of them is finite: a
/// looping animation never lets a screen settle, which the tests need and a
/// battery prefers.

/// How long a state change takes to show. One number, so the whole app moves
/// at one pace.
const kMotion = Duration(milliseconds: 260);

/// Fades and lifts its child into place the first time it is built.
///
/// Give list items an [index] and each arrives a beat after the one above it,
/// so a list loading reads as a list and not as a flash. The stagger is capped:
/// the twentieth card must not arrive a second late.
class Appear extends StatelessWidget {
  const Appear({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 45 * index.clamp(0, 8));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: kMotion + delay,
      curve: Interval(
        delay.inMilliseconds / (kMotion + delay).inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// A number that counts up to its value rather than appearing on it, and
/// counts again whenever the value changes.
///
/// Anything that is not a whole number -- "8h 30m", "$412.75" -- is shown as
/// it is; the counting is for the badges and the tiles.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(this.value, {super.key, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final target = int.tryParse(value);
    if (target == null) return Text(value, style: style);
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Text('$shown', style: style),
    );
  }
}

/// Swaps one child for another with a fade and a small scale, keyed on
/// whatever [child] carries -- the way a status word or an icon should change.
class Morph extends StatelessWidget {
  const Morph({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: kMotion,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: child,
      );
}
