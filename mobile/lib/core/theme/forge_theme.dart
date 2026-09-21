import 'package:flutter/material.dart';

abstract final class ForgeColors {
  // Core backgrounds
  static const background = Color(0xFF090B0A);
  static const surface = Color(0xFF121512);
  static const surfaceRaised = Color(0xFF1A1F1B);
  static const surfaceSoft = Color(0xFF202620);

  // Brand
  static const primary = Color(0xFFB7FF00);
  static const primarySoft = Color(0xFFD8FF7A);
  static const primaryMuted = Color(0xFF759B22);

  // Typography
  static const textPrimary = Color(0xFFF7F7F2);
  static const textSecondary = Color(0xFFA9B0A9);
  static const textMuted = Color(0xFF737B74);

  // Structure
  static const outline = Color(0xFF293029);
  static const outlineStrong = Color(0xFF3A433B);

  // Semantic states
  static const success = Color(0xFF66E38C);
  static const warning = Color(0xFFF3C969);
  static const error = Color(0xFFFF6B6B);
}

abstract final class ForgeSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class ForgeRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class ForgeTheme {
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: ForgeColors.primary,
      onPrimary: Colors.black,

      primaryContainer: ForgeColors.surfaceSoft,
      onPrimaryContainer: ForgeColors.primary,

      secondary: ForgeColors.primarySoft,
      onSecondary: Colors.black,

      secondaryContainer: ForgeColors.surfaceRaised,
      onSecondaryContainer: ForgeColors.primarySoft,

      surface: ForgeColors.surface,
      onSurface: ForgeColors.textPrimary,

      error: ForgeColors.error,
      onError: Colors.black,

      outline: ForgeColors.outline,
      outlineVariant: ForgeColors.outlineStrong,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ForgeColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          color: ForgeColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          color: ForgeColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: ForgeColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: ForgeColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: ForgeColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: ForgeColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          color: ForgeColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: ForgeColors.textPrimary,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: ForgeColors.textSecondary,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: ForgeColors.textSecondary,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: ForgeColors.background,
        foregroundColor: ForgeColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        color: ForgeColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ForgeRadius.lg),
          side: const BorderSide(color: ForgeColors.outline),
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ForgeColors.surface,
        indicatorColor: ForgeColors.surfaceRaised,
        elevation: 0,
        height: 72,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ForgeColors.surface,
        hintStyle: const TextStyle(color: ForgeColors.textMuted),
        labelStyle: const TextStyle(color: ForgeColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ForgeRadius.md),
          borderSide: const BorderSide(color: ForgeColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ForgeRadius.md),
          borderSide: const BorderSide(color: ForgeColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ForgeRadius.md),
          borderSide: const BorderSide(color: ForgeColors.primary, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ForgeColors.primary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ForgeRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ForgeColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: ForgeColors.outlineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ForgeRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ForgeColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: ForgeColors.surfaceRaised,
        selectedColor: ForgeColors.primary,
        disabledColor: ForgeColors.surface,
        side: const BorderSide(color: ForgeColors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ForgeRadius.sm),
        ),
        labelStyle: const TextStyle(
          color: ForgeColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ForgeColors.primary,
        linearTrackColor: ForgeColors.surfaceRaised,
      ),

      dividerTheme: const DividerThemeData(
        color: ForgeColors.outline,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ForgeColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: ForgeColors.surfaceRaised,
        showDragHandle: true,
        dragHandleColor: ForgeColors.outlineStrong,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ForgeColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: ForgeColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ForgeRadius.md),
        ),
      ),
    );
  }
}
