abstract final class AppConstants {
  static const appName = 'Amharic Bible';

  // Shown under Settings → About. Change these to what you want people to see.
  static const developerName = 'Biniam Kindie';
  static const developerEmail = 'biniamkindie9@gmail.com';

  // Translation ids — must match `translations.id` in bible.db.
  static const amharicTranslation = 'amh';
  static const kjvTranslation = 'kjv';
  static const defaultTranslation = amharicTranslation;

  // Database file names.
  static const bibleDbAsset = 'assets/db/bible.db';
  static const bibleDbFile = 'bible.db';
  static const userDbFile = 'user.db';

  /// Bump whenever a new bible.db is shipped so the app re-copies it.
  static const bibleDbVersion = 1;

  // Book ids 1–39 are the Old Testament, 40–66 the New Testament.
  static const firstNtBookId = 40;
  static const bookCount = 66;

  // Reading defaults.
  static const defaultFontSize = 18.0;
  static const minFontSize = 12.0;
  static const maxFontSize = 34.0;
  static const defaultLineSpacing = 1.0; // multiplier on the script's base height
  static const minLineSpacing = 0.8;
  static const maxLineSpacing = 1.6;

  static const searchDebounce = Duration(milliseconds: 300);
}

/// Font family names — must match `pubspec.yaml`.
abstract final class AppFonts {
  static const serifEthiopic = 'NotoSerifEthiopic';
  static const sansEthiopic = 'NotoSansEthiopic';
  static const serifLatin = 'NotoSerif';
  static const sansLatin = 'NotoSans';
  static const abyssinica = 'AbyssinicaSIL';
  static const menbere = 'Menbere';
}
