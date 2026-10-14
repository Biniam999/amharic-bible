import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'reading_fonts.dart';

export 'reading_fonts.dart';
import 'reading_theme.dart';

enum AppThemeMode { system, light, dark, sepia }


/// Futuristic brand palette: deep navy, electric blue, ice cyan and white.
abstract final class BrandColors {
  static const navy = Color(0xFF070D1F);
  static const obsidian = Color(0xFF020409); //   OLED app background in dark mode
  static const midnight = Color(0xFF0C1530);
  static const deepBlue = Color(0xFF12306A);
  static const blue = Color(0xFF1A5FD0); //       main accent in light mode
  static const electric = Color(0xFF5AA9FF); //   main accent in dark mode
  static const cyan = Color(0xFF7FD3FF); //       glow / secondary accent
  static const ice = Color(0xFFEAF1FF);
  static const white = Color(0xFFFFFFFF);

  /// Hero gradient used on the welcome screen, home header and share images.
  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1633), Color(0xFF14336E), Color(0xFF3B6FB6)],
  );
}

abstract final class AppTheme {
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: BrandColors.blue, //                    5.9:1 on white
    onPrimary: BrandColors.white,
    primaryContainer: Color(0xFFE3EEFF),
    onPrimaryContainer: Color(0xFF0A2A63),
    secondary: Color(0xFF2F6FB8),
    onSecondary: BrandColors.white,
    secondaryContainer: Color(0xFFD5E6FF),
    onSecondaryContainer: Color(0xFF0A2A63), //       10.9:1
    tertiary: Color(0xFF0E7FA8),
    onTertiary: BrandColors.white,
    tertiaryContainer: Color(0xFFD3F1FF),
    onTertiaryContainer: Color(0xFF00344A),
    error: Color(0xFFB3261E),
    onError: BrandColors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: BrandColors.white,
    onSurface: Color(0xFF0E1A33), //                 17:1 on white
    surfaceContainerLowest: BrandColors.white,
    surfaceContainerLow: Color(0xFFF7FAFF),
    surfaceContainer: Color(0xFFF0F5FE),
    surfaceContainerHigh: Color(0xFFE9F0FC),
    surfaceContainerHighest: Color(0xFFE1EAF9),
    onSurfaceVariant: Color(0xFF4E5F80),
    outline: Color(0xFF9DB3D9),
    outlineVariant: Color(0xFFDCE6F5),
    inverseSurface: Color(0xFF0E1A33),
    onInverseSurface: BrandColors.white,
    inversePrimary: BrandColors.electric,
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: BrandColors.electric, //                7.9:1 on navy
    onPrimary: Color(0xFF04122B),
    primaryContainer: BrandColors.deepBlue,
    onPrimaryContainer: Color(0xFFD8E8FF),
    secondary: BrandColors.cyan,
    onSecondary: Color(0xFF02202E),
    secondaryContainer: Color(0xFF173A75),
    onSecondaryContainer: Color(0xFFD8E8FF),
    tertiary: Color(0xFF9FE6FF),
    onTertiary: Color(0xFF02202E),
    tertiaryContainer: Color(0xFF0F3A52),
    onTertiaryContainer: Color(0xFFCDEFFF),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    // OLED obsidian: true black-blue, so pixels are nearly off and glows pop.
    surface: BrandColors.obsidian,
    onSurface: BrandColors.ice,
    surfaceContainerLowest: Color(0xFF000000),
    surfaceContainerLow: Color(0xFF070B16),
    surfaceContainer: Color(0xFF0B1222),
    surfaceContainerHigh: Color(0xFF101A30),
    surfaceContainerHighest: Color(0xFF16223D),
    onSurfaceVariant: Color(0xFF9DB0D3),
    outline: Color(0xFF2E4270),
    outlineVariant: Color(0xFF172238),
    inverseSurface: BrandColors.ice,
    onInverseSurface: Color(0xFF0E1A33),
    inversePrimary: BrandColors.blue,
    surfaceTint: Colors.transparent,
  );

  static const _sepiaScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF7A4E2D),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEBD9C3),
    onPrimaryContainer: Color(0xFF2E1A0B),
    secondary: Color(0xFF6E5B48),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8DCCB),
    onSecondaryContainer: Color(0xFF261A0E),
    tertiary: Color(0xFF55633A),
    onTertiary: Color(0xFFFFFFFF),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFF4ECD8),
    onSurface: Color(0xFF3B2F22),
    surfaceContainerLowest: Color(0xFFF9F3E4),
    surfaceContainerLow: Color(0xFFF0E6CF),
    surfaceContainer: Color(0xFFEBE0C6),
    surfaceContainerHigh: Color(0xFFE5D9BD),
    surfaceContainerHighest: Color(0xFFDFD2B4),
    onSurfaceVariant: Color(0xFF5C4D3C),
    outline: Color(0xFF8C7B66),
    outlineVariant: Color(0xFFCDBFA6),
  );

  static ThemeData light({ReadingFont font = ReadingFont.fallback}) => _build(_lightScheme, font);

  static ThemeData dark({ReadingFont font = ReadingFont.fallback}) => _build(_darkScheme, font);

  static ThemeData sepia({ReadingFont font = ReadingFont.fallback}) =>
      _build(_sepiaScheme, font);

  /// Resolves the light/dark pair for MaterialApp. Sepia is a light theme,
  /// so it's returned as `theme` with ThemeMode.light forced.
  static (ThemeData theme, ThemeData darkTheme, ThemeMode mode) resolve(
    AppThemeMode mode, {
    ReadingFont font = ReadingFont.fallback,
  }) {
    return switch (mode) {
      AppThemeMode.system => (light(font: font), dark(font: font), ThemeMode.system),
      AppThemeMode.light => (light(font: font), dark(font: font), ThemeMode.light),
      AppThemeMode.dark => (light(font: font), dark(font: font), ThemeMode.dark),
      AppThemeMode.sepia => (sepia(font: font), dark(font: font), ThemeMode.light),
    };
  }

  static ThemeData _build(ColorScheme scheme, ReadingFont font) {
    // UI chrome always uses sans; the reading font only affects verse text.
    const uiFamily = AppFonts.sansEthiopic;
    const uiFallback = [AppFonts.sansLatin];

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: uiFamily,
      fontFamilyFallback: uiFallback,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      // Ge'ez glyphs are taller than Latin; give UI text a little more room.
      textTheme: base.textTheme.apply(
        fontFamily: uiFamily,
        fontFamilyFallback: uiFallback,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
        heightFactor: 1.0,
        heightDelta: 0.15,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 0.5),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [
        ReadingTheme.fromScheme(scheme, font: font),
      ],
    );
  }
}
