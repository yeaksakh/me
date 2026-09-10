import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../models/fulfilment_stage.dart';

/// Colours the Material scheme does not cover: the page/card split the app is
/// built on, the per-stage accents, the three stock signals, and an accent for
/// each area of the app so a screen is known by its colour. Defined per
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
    required this.orders,
    required this.stock,
    required this.hrm,
    required this.leave,
    required this.holiday,
    required this.pay,
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

  /// One colour per door, so the tabs and the HR doors read at a glance.
  final Color orders;
  final Color stock;
  final Color hrm;
  final Color leave;
  final Color holiday;
  final Color pay;

  static const light = AppColors(
    page: Color(0xFFF3F5FA),
    card: Colors.white,
    ordered: Color(0xFF2F5BEA),
    prepared: Color(0xFFE08A00),
    checked: Color(0xFF00A272),
    pickedUp: Color(0xFF8B5CF6),
    delivered: Color(0xFF16A34A),
    cancelled: Color(0xFFE11D48),
    inStock: Color(0xFF16A34A),
    lowStock: Color(0xFFE08A00),
    outOfStock: Color(0xFFE11D48),
    orders: Color(0xFF2F5BEA),
    stock: Color(0xFF0D9488),
    hrm: Color(0xFF7C3AED),
    leave: Color(0xFFF97316),
    holiday: Color(0xFFEC4899),
    pay: Color(0xFF059669),
  );

  static const dark = AppColors(
    page: Color(0xFF0F1220),
    card: Color(0xFF1B2033),
    ordered: Color(0xFF7FA1FF),
    prepared: Color(0xFFFFB84D),
    checked: Color(0xFF4EDDB0),
    pickedUp: Color(0xFFC4A8FF),
    delivered: Color(0xFF6EE39A),
    cancelled: Color(0xFFFF7A95),
    inStock: Color(0xFF6EE39A),
    lowStock: Color(0xFFFFB84D),
    outOfStock: Color(0xFFFF7A95),
    orders: Color(0xFF7FA1FF),
    stock: Color(0xFF5EDBCB),
    hrm: Color(0xFFB794FF),
    leave: Color(0xFFFFA25C),
    holiday: Color(0xFFFF8AC2),
    pay: Color(0xFF5DE0A8),
  );

  /// Packed keeps the amber and Audited the green the warehouse's two stages
  /// always had, so a colour means the same step it did before.
  Color forStage(FulfilmentStage stage) => switch (stage) {
        FulfilmentStage.ordered => ordered,
        FulfilmentStage.packed => prepared,
        FulfilmentStage.audited => checked,
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
    Color? orders,
    Color? stock,
    Color? hrm,
    Color? leave,
    Color? holiday,
    Color? pay,
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
      orders: orders ?? this.orders,
      stock: stock ?? this.stock,
      hrm: hrm ?? this.hrm,
      leave: leave ?? this.leave,
      holiday: holiday ?? this.holiday,
      pay: pay ?? this.pay,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      page: mix(page, other.page),
      card: mix(card, other.card),
      ordered: mix(ordered, other.ordered),
      prepared: mix(prepared, other.prepared),
      checked: mix(checked, other.checked),
      pickedUp: mix(pickedUp, other.pickedUp),
      delivered: mix(delivered, other.delivered),
      cancelled: mix(cancelled, other.cancelled),
      inStock: mix(inStock, other.inStock),
      lowStock: mix(lowStock, other.lowStock),
      outOfStock: mix(outOfStock, other.outOfStock),
      orders: mix(orders, other.orders),
      stock: mix(stock, other.stock),
      hrm: mix(hrm, other.hrm),
      leave: mix(leave, other.leave),
      holiday: mix(holiday, other.holiday),
      pay: mix(pay, other.pay),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// A two-stop gradient for a hero card, from [color] to a deeper cousin.
LinearGradient heroGradient(Color color) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color, Color.lerp(color, const Color(0xFF1B1B4B), 0.35)!],
    );

class AppTheme {
  /// The logo's blue.
  static const seed = Color(0xFF343DB9);

  static ThemeData light() => _build(Brightness.light, AppColors.light);
  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      primary: brightness == Brightness.light ? seed : const Color(0xFF9DA7FF),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.page,
      extensions: [colors],
      // A page slides in over a fade rather than zooming in from the middle:
      // quicker to read, and the same on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.page,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.card,
        indicatorColor: scheme.primary.withAlpha(36),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      // Tall targets throughout: this is used one-handed, at arm's length, often
      // by someone wearing a glove and holding a box with the other arm.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }
}
