import 'package:flutter/material.dart';

import '../models/order.dart';

class AppTheme {
  static const seed = Color(0xFF00875A);
  static const surfaceGrey = Color(0xFFF4F6F8);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceGrey,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceGrey,
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
        fillColor: Colors.white,
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

  /// Colour used for a status chip anywhere in the app.
  static Color statusColor(OrderStatus status) => switch (status) {
        OrderStatus.pending => const Color(0xFF0B6BCB),
        OrderStatus.accepted => const Color(0xFF9A6700),
        OrderStatus.pickedUp => const Color(0xFF7A4DBF),
        OrderStatus.onTheWay => const Color(0xFF00875A),
        OrderStatus.delivered => const Color(0xFF1B7F4C),
        OrderStatus.cancelled => const Color(0xFFB3261E),
      };
}
