import 'package:flutter/material.dart';

import '../models/order.dart';

/// Colours the Material scheme does not cover: the page/card split the app is
/// built on, and the per-status accents. Defined per brightness so light and
/// dark are both deliberate rather than derived.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.card,
    required this.pending,
    required this.accepted,
    required this.pickedUp,
    required this.onTheWay,
    required this.delivered,
    required this.cancelled,
  });

  final Color page;
  final Color card;
  final Color pending;
  final Color accepted;
  final Color pickedUp;
  final Color onTheWay;
  final Color delivered;
  final Color cancelled;

  static const light = AppColors(
    page: Color(0xFFF4F6F8),
    card: Colors.white,
    pending: Color(0xFF0B6BCB),
    accepted: Color(0xFF9A6700),
    pickedUp: Color(0xFF7A4DBF),
    onTheWay: Color(0xFF00875A),
    delivered: Color(0xFF1B7F4C),
    cancelled: Color(0xFFB3261E),
  );

  static const dark = AppColors(
    page: Color(0xFF101416),
    card: Color(0xFF1B2124),
    pending: Color(0xFF6BA8F5),
    accepted: Color(0xFFE3B341),
    pickedUp: Color(0xFFC39BF5),
    onTheWay: Color(0xFF4ED6A0),
    delivered: Color(0xFF5BC98C),
    cancelled: Color(0xFFF2857C),
  );

  Color forStatus(OrderStatus status) => switch (status) {
        OrderStatus.pending => pending,
        OrderStatus.accepted => accepted,
        OrderStatus.pickedUp => pickedUp,
        OrderStatus.onTheWay => onTheWay,
        OrderStatus.delivered => delivered,
        OrderStatus.cancelled => cancelled,
      };

  @override
  AppColors copyWith({
    Color? page,
    Color? card,
    Color? pending,
    Color? accepted,
    Color? pickedUp,
    Color? onTheWay,
    Color? delivered,
    Color? cancelled,
  }) {
    return AppColors(
      page: page ?? this.page,
      card: card ?? this.card,
      pending: pending ?? this.pending,
      accepted: accepted ?? this.accepted,
      pickedUp: pickedUp ?? this.pickedUp,
      onTheWay: onTheWay ?? this.onTheWay,
      delivered: delivered ?? this.delivered,
      cancelled: cancelled ?? this.cancelled,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      accepted: Color.lerp(accepted, other.accepted, t)!,
      pickedUp: Color.lerp(pickedUp, other.pickedUp, t)!,
      onTheWay: Color.lerp(onTheWay, other.onTheWay, t)!,
      delivered: Color.lerp(delivered, other.delivered, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static const seed = Color(0xFF00875A);

  static ThemeData light() => _build(Brightness.light, AppColors.light);
  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.page,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.page,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
