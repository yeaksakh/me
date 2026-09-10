import 'package:flutter/material.dart';

import '../models/fulfilment_stage.dart';

/// Colours the Material scheme does not cover: the page/card split the app is
/// built on, the per-stage accents, and the three stock signals. Defined per
/// brightness so light and dark are both deliberate rather than derived.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.card,
    required this.ordered,
    required this.prepared,
    required this.checked,
    required this.pickedUp,
    required this.delivered,
    required this.cancelled,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });

  final Color page;
  final Color card;

  final Color ordered;
  final Color prepared;
  final Color checked;
  final Color pickedUp;
  final Color delivered;
  final Color cancelled;

  final Color inStock;
  final Color lowStock;
  final Color outOfStock;

  static const light = AppColors(
    page: Color(0xFFF4F6F8),
    card: Colors.white,
    ordered: Color(0xFF0B6BCB),
    prepared: Color(0xFF9A6700),
    checked: Color(0xFF00875A),
    pickedUp: Color(0xFF7A4DBF),
    delivered: Color(0xFF1B7F4C),
    cancelled: Color(0xFFB3261E),
    inStock: Color(0xFF1B7F4C),
    lowStock: Color(0xFF9A6700),
    outOfStock: Color(0xFFB3261E),
  );

  static const dark = AppColors(
    page: Color(0xFF101416),
    card: Color(0xFF1B2124),
    ordered: Color(0xFF6BA8F5),
    prepared: Color(0xFFE3B341),
    checked: Color(0xFF4ED6A0),
    pickedUp: Color(0xFFC39BF5),
    delivered: Color(0xFF5BC98C),
    cancelled: Color(0xFFF2857C),
    inStock: Color(0xFF5BC98C),
    lowStock: Color(0xFFE3B341),
    outOfStock: Color(0xFFF2857C),
  );

  Color forStage(FulfilmentStage stage) => switch (stage) {
        FulfilmentStage.ordered => ordered,
        FulfilmentStage.prepared => prepared,
        FulfilmentStage.checked => checked,
        FulfilmentStage.pickedUp => pickedUp,
        FulfilmentStage.delivered => delivered,
        FulfilmentStage.cancelled => cancelled,
      };

  @override
  AppColors copyWith({
    Color? page,
    Color? card,
    Color? ordered,
    Color? prepared,
    Color? checked,
    Color? pickedUp,
    Color? delivered,
    Color? cancelled,
    Color? inStock,
    Color? lowStock,
    Color? outOfStock,
  }) {
    return AppColors(
      page: page ?? this.page,
      card: card ?? this.card,
      ordered: ordered ?? this.ordered,
      prepared: prepared ?? this.prepared,
      checked: checked ?? this.checked,
      pickedUp: pickedUp ?? this.pickedUp,
      delivered: delivered ?? this.delivered,
      cancelled: cancelled ?? this.cancelled,
      inStock: inStock ?? this.inStock,
      lowStock: lowStock ?? this.lowStock,
      outOfStock: outOfStock ?? this.outOfStock,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      ordered: Color.lerp(ordered, other.ordered, t)!,
      prepared: Color.lerp(prepared, other.prepared, t)!,
      checked: Color.lerp(checked, other.checked, t)!,
      pickedUp: Color.lerp(pickedUp, other.pickedUp, t)!,
      delivered: Color.lerp(delivered, other.delivered, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
      inStock: Color.lerp(inStock, other.inStock, t)!,
      lowStock: Color.lerp(lowStock, other.lowStock, t)!,
      outOfStock: Color.lerp(outOfStock, other.outOfStock, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static const seed = Color(0xFF0B6BCB);

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
      // Tall targets throughout: this is used one-handed, at arm's length, often
      // by someone wearing a glove and holding a box with the other arm.
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
