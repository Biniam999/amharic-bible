import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'reading_fonts.dart';

/// Typography and colors for Bible text, kept separate from the UI theme so
/// font size / spacing changes don't rebuild the whole app theme.
@immutable
class ReadingTheme extends ThemeExtension<ReadingTheme> {
  const ReadingTheme({
    required this.font,
    required this.textColor,
    required this.verseNumberColor,
    required this.selectionColor,
    required this.highlightColors,
  });

  factory ReadingTheme.fromScheme(ColorScheme scheme, {required ReadingFont font}) {
    final dark = scheme.brightness == Brightness.dark;
    return ReadingTheme(
      font: font,
      textColor: scheme.onSurface,
      verseNumberColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.12),
      // The same bold colours as the dots, made see-through so the verse
      // text stays readable on light, sepia and dark backgrounds.
      highlightColors: [
        for (final c in highlightSwatches) c.withValues(alpha: dark ? 0.45 : 0.40),
      ],
    );
  }

  final ReadingFont font;
  final Color textColor;
  final Color verseNumberColor;
  final Color selectionColor;

  /// Verse background for each highlight; index = HighlightColor.index.
  final List<Color> highlightColors;

  /// Full-strength colour of each highlight, for the colour dots and the
  /// library. Index = HighlightColor.index (stored in user.db).
  static const highlightSwatches = <Color>[
    Color(0xFFFFCC00), // yellow
    Color(0xFF2ECC40), // green
    Color(0xFF1E88FF), // blue
    Color(0xFFFF2D78), // pink
    Color(0xFFFF8A00), // orange
    Color(0xFFFF3B30), // red
    Color(0xFF9B4DFF), // purple
    Color(0xFF00BFA5), // teal
    Color(0xFF3D5AFE), // indigo
    Color(0xFFA6D608), // lime
    Color(0xFFA1673F), // brown
    Color(0xFF8E8E93), // gray
  ];

  // Ge'ez needs more vertical room than Latin.
  static const double ethiopicBaseHeight = 1.75;
  static const double latinBaseHeight = 1.5;

  /// Verse text style for the given script, user font size and spacing.
  TextStyle verseStyle({
    required bool ethiopic,
    required double fontSize,
    double lineSpacing = AppConstants.defaultLineSpacing,
  }) {
    final family = ethiopic ? font.ethiopicFamily : font.latinFamily;
    // Each script falls back to the other, so mixed text still renders.
    final fallback = ethiopic ? [font.latinFamily] : [font.ethiopicFamily, AppFonts.sansEthiopic];
    final baseHeight = ethiopic ? ethiopicBaseHeight : latinBaseHeight;

    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: ethiopic ? fontSize * font.ethiopicSizeFactor : fontSize,
      height: baseHeight * lineSpacing,
      color: textColor,
      letterSpacing: ethiopic ? 0.2 : 0,
      // Even leading keeps Ge'ez glyphs vertically centered on taller lines.
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  TextStyle verseNumberStyle({required double fontSize}) => TextStyle(
        fontFamily: AppFonts.sansLatin,
        // Ge'ez numerals (፩ ፪ ፫) come from the Ethiopic font.
        fontFamilyFallback: const [AppFonts.sansEthiopic],
        fontSize: fontSize * 0.62,
        fontWeight: FontWeight.w700,
        color: verseNumberColor,
        fontFeatures: const [FontFeature.superscripts()],
      );

  @override
  ReadingTheme copyWith({
    ReadingFont? font,
    Color? textColor,
    Color? verseNumberColor,
    Color? selectionColor,
    List<Color>? highlightColors,
  }) =>
      ReadingTheme(
        font: font ?? this.font,
        textColor: textColor ?? this.textColor,
        verseNumberColor: verseNumberColor ?? this.verseNumberColor,
        selectionColor: selectionColor ?? this.selectionColor,
        highlightColors: highlightColors ?? this.highlightColors,
      );

  @override
  ReadingTheme lerp(ReadingTheme? other, double t) {
    if (other == null) return this;
    return ReadingTheme(
      font: t < 0.5 ? font : other.font,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      verseNumberColor: Color.lerp(verseNumberColor, other.verseNumberColor, t)!,
      selectionColor: Color.lerp(selectionColor, other.selectionColor, t)!,
      highlightColors: List.generate(
        highlightColors.length,
        (i) => Color.lerp(highlightColors[i], other.highlightColors[i], t)!,
      ),
    );
  }
}

extension ReadingThemeX on BuildContext {
  ReadingTheme get reading => Theme.of(this).extension<ReadingTheme>()!;
}
