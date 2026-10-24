import 'package:flutter/material.dart';

class QsColors {
  static const maroon = Color(0xFFC90000);
  static const maroonDark = Color(0xFF8B0000);
  static const cream = Color(0xFFFFF8EE);
  static const creamDeep = Color(0xFFF5E8D6);
  static const gold = Color(0xFFC9973A);
  static const charcoal = Color(0xFF2B2424);
  static const muted = Color(0xFF6E6262);
  static const border = Color(0xFFE8D9C7);
  static const green = Color(0xFF2E7D4F);
  static const danger = Color(0xFFB3261E);
}

const brandFont = 'Playfair';

/// Width from which the persistent bill panel is shown next to the catalog.
const tabletBreakpoint = 900.0;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: QsColors.maroon,
    primary: QsColors.maroon,
    onPrimary: Colors.white,
    secondary: QsColors.gold,
    surface: QsColors.cream,
    onSurface: QsColors.charcoal,
    error: QsColors.danger,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: QsColors.border),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'NotoSans',
    scaffoldBackgroundColor: QsColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: QsColors.maroon,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: QsColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: QsColors.maroon, width: 1.6)),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: QsColors.maroon,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: QsColors.maroon,
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: QsColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 46)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? QsColors.maroon : Colors.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : QsColors.charcoal,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: QsColors.border)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: QsColors.maroon.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? QsColors.maroon : QsColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? QsColors.maroon : QsColors.muted),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? QsColors.green : QsColors.border,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: QsColors.border, space: 1),
  );
}
