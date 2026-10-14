/// Text normalization for search and reference lookup.
///
/// MUST produce the same output as `normalize_for_search` in
/// tools/build_bible_db.py, because the search index in bible.db was built
/// with that function. test/core/search_normalizer_test.dart checks both agree.
abstract final class SearchNormalizer {
  /// Amharic letters that sound the same, folded to one canonical letter.
  static final Map<int, int> charMap = _buildCharMap();

  static Map<int, int> _buildCharMap() {
    final m = <int, int>{};
    const ha = 0x1200, hha = 0x1210, xa = 0x1280; // ሀ ሐ ኀ
    const sa = 0x1230, sza = 0x1220; // ሰ ሠ
    const glottal = 0x12A0, pharyngeal = 0x12D0; // አ ዐ
    const tsa = 0x1338, tza = 0x1340; // ጸ ፀ

    for (var k = 0; k < 7; k++) {
      m[hha + k] = ha + k;
      m[xa + k] = ha + k;
      m[pharyngeal + k] = glottal + k;
      m[tza + k] = tsa + k;
    }
    for (var k = 0; k < 8; k++) {
      m[sza + k] = sa + k;
    }
    m[0x1288] = 0x1217; // ኈ -> ሗ
    m[0x128B] = 0x1217; // ኋ -> ሗ
    // 1st and 4th orders of ሀ and አ sound the same (ሀገር / ሃገር, ዓለም / አለም).
    m[ha + 3] = ha;
    m[glottal + 3] = glottal;

    // Resolve chains (ሓ -> ሃ -> ሀ) so one lookup is enough.
    for (final key in m.keys.toList()) {
      var value = m[key]!;
      while (m.containsKey(value) && m[value] != value) {
        value = m[value]!;
      }
      m[key] = value;
    }
    return Map.unmodifiable(m);
  }

  static final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final _dropped = RegExp(r'[\p{M}\p{Cf}]', unicode: true);

  static const _space = 0x20;
  static const _drop = -1;

  /// Folds Amharic homophones, lowercases, strips Latin accents, and turns
  /// punctuation/whitespace (incl. ፡ ። ፣ ፤) into spaces. One output character
  /// per input character, except combining marks, which are dropped.
  static String normalize(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      final c = _fold(rune);
      if (c != _drop) out.writeCharCode(c);
    }
    return out.toString();
  }

  /// Like [normalize], plus where each normalized character came from:
  /// `offsets[i]` is the index in [input] of normalized character `i`, and the
  /// last entry is `input.length`. Used to highlight matches in the original.
  static ({String text, List<int> offsets}) normalizeWithOffsets(String input) {
    final out = StringBuffer();
    final offsets = <int>[];
    var position = 0;
    for (final rune in input.runes) {
      final c = _fold(rune);
      if (c != _drop) {
        out.writeCharCode(c);
        offsets.add(position);
        if (c > 0xFFFF) offsets.add(position); // two UTF-16 units
      }
      position += rune > 0xFFFF ? 2 : 1;
    }
    offsets.add(position);
    return (text: out.toString(), offsets: offsets);
  }

  static int _fold(int rune) {
    final r = charMap[rune] ?? rune;

    // Fast paths for the two scripts in the app.
    if (r >= 0x1200 && r <= 0x139F) {
      if (r >= 0x1360 && r <= 0x1368) return _space; // Ethiopic punctuation
      if (r >= 0x135D && r <= 0x135F) return _drop; // Ethiopic combining marks
      return r;
    }
    if (r < 0x80) {
      if (r >= 0x41 && r <= 0x5A) return r + 0x20; // A-Z -> a-z
      if ((r >= 0x61 && r <= 0x7A) || (r >= 0x30 && r <= 0x39)) return r;
      return _space;
    }

    final ch = String.fromCharCode(r);
    if (_dropped.hasMatch(ch)) return _drop;
    if (!_letterOrDigit.hasMatch(ch)) return _space;
    if (r < 0x1200) {
      final lower = ch.toLowerCase();
      final base = _latinBase[lower] ?? lower;
      return base.runes.first;
    }
    return r;
  }

  /// Normalized words of [input], for building queries.
  static List<String> terms(String input) =>
      normalize(input).split(' ').where((t) => t.isNotEmpty).toList(growable: false);

  // Accented Latin letters -> base letter (what Python's NFD + first char gives).
  static final Map<String, String> _latinBase = {
    for (final e in const {
      'a': 'àáâãäåāăą',
      'c': 'çćĉċč',
      'd': 'ď',
      'e': 'èéêëēĕėęě',
      'g': 'ĝğġģ',
      'h': 'ĥ',
      'i': 'ìíîïĩīĭį',
      'j': 'ĵ',
      'k': 'ķ',
      'l': 'ĺļľ',
      'n': 'ñńņň',
      'o': 'òóôõöōŏő',
      'r': 'ŕŗř',
      's': 'śŝşš',
      't': 'ţť',
      'u': 'ùúûüũūŭůűų',
      'w': 'ŵ',
      'y': 'ýÿŷ',
      'z': 'źżž',
    }.entries)
      for (final ch in e.value.split('')) ch: e.key,
  };
}
