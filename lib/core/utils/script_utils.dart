/// Helpers for dealing with Ge'ez (Ethiopic) script vs Latin text.
abstract final class ScriptUtils {
  // Ethiopic, Ethiopic Supplement, Ethiopic Extended and Extended-A blocks.
  static bool isEthiopicRune(int r) =>
      (r >= 0x1200 && r <= 0x139F) ||
      (r >= 0x2D80 && r <= 0x2DDF) ||
      (r >= 0xAB00 && r <= 0xAB2F);

  /// True if the first letter-like character in [text] is Ethiopic.
  /// Only scans a short prefix so it stays cheap inside list item builds.
  static bool isEthiopic(String text) {
    var checked = 0;
    for (final r in text.runes) {
      if (isEthiopicRune(r)) return true;
      final isAsciiLetter = (r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A);
      if (isAsciiLetter) return false;
      if (++checked > 40) break;
    }
    return false;
  }

  /// Translation language codes that use Ge'ez script.
  static bool isEthiopicLanguage(String languageCode) =>
      const {'am', 'amh', 'ti', 'tir', 'gez'}.contains(languageCode);
}
