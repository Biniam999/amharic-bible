import '../constants/app_constants.dart';

/// Fonts offered for Bible text. Each pairs an Ethiopic font (Amharic text)
/// with a Latin one (KJV). All are SIL Open Font License, bundled in assets/fonts.
enum ReadingFont {
  /// Traditional Ge'ez book style, like printed Ethiopian Bibles.
  abyssinica(
    label: 'Abyssinica SIL',
    ethiopicFamily: AppFonts.abyssinica,
    latinFamily: AppFonts.serifLatin,
    ethiopicSizeFactor: 1.0,
  ),
  notoSerif(
    label: 'Noto Serif',
    ethiopicFamily: AppFonts.serifEthiopic,
    latinFamily: AppFonts.serifLatin,
    ethiopicSizeFactor: 1.05,
  ),
  notoSans(
    label: 'Noto Sans',
    ethiopicFamily: AppFonts.sansEthiopic,
    latinFamily: AppFonts.sansLatin,
    ethiopicSizeFactor: 1.05,
  ),

  /// Modern, soft and rounded.
  menbere(
    label: 'Menbere',
    ethiopicFamily: AppFonts.menbere,
    latinFamily: AppFonts.sansLatin,
    ethiopicSizeFactor: 1.0,
  );

  const ReadingFont({
    required this.label,
    required this.ethiopicFamily,
    required this.latinFamily,
    required this.ethiopicSizeFactor,
  });

  final String label;
  final String ethiopicFamily;
  final String latinFamily;

  /// Some Ethiopic fonts draw smaller than others at the same size.
  final double ethiopicSizeFactor;

  static const fallback = ReadingFont.abyssinica;

  /// Reads a saved value, including the older "serif"/"sans" setting.
  static ReadingFont fromName(String? name) => switch (name) {
        'serif' => ReadingFont.notoSerif,
        'sans' => ReadingFont.notoSans,
        _ => ReadingFont.values.where((f) => f.name == name).firstOrNull ?? fallback,
      };
}
