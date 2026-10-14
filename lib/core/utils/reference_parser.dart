import 'package:flutter/foundation.dart';

import '../../data/models/bible_models.dart';
import 'search_normalizer.dart';

@immutable
class ParsedReference {
  const ParsedReference(this.bookId, this.chapter, [this.verse]);

  final int bookId;
  final int chapter;
  final int? verse;

  @override
  bool operator ==(Object other) =>
      other is ParsedReference && other.bookId == bookId && other.chapter == chapter && other.verse == verse;

  @override
  int get hashCode => Object.hash(bookId, chapter, verse);

  @override
  String toString() => 'ParsedReference($bookId $chapter${verse == null ? '' : ':$verse'})';
}

/// Turns typed references into book/chapter/verse.
///
/// Accepts Amharic or English names and abbreviations, with or without
/// spaces, and `:` `.` `፡` `፥` between chapter and verse:
/// "ዮሐንስ 3:16", "ዮሐ 3፡16", "1ኛ ሳሙኤል 2", "John 3:16", "jn 3", "1 John 4:8", "Jude 5".
class ReferenceParser {
  ReferenceParser(Iterable<Book> books) {
    for (final b in books) {
      _chapters[b.id] = b.chapters;
      for (final alias in [b.name, b.shortName, b.abbrev, b.osis]) {
        _add(alias, b.id);
      }
    }
    _extraAliases.forEach((id, aliases) {
      for (final a in aliases) {
        _add(a, id);
      }
    });
  }

  final Map<String, int> _aliases = {};
  final Map<int, int> _chapters = {};

  static final _pattern = RegExp(r'^\s*(.*?)\s*(\d+)(?:\s*[:.,፡፥፦]\s*(\d+))?\s*$');

  void _add(String alias, int bookId) {
    final key = _key(alias);
    if (key.isNotEmpty) _aliases.putIfAbsent(key, () => bookId);
  }

  static String _key(String s) => SearchNormalizer.normalize(s).replaceAll(' ', '');

  /// Returns null if no book matches. Chapter/verse ranges are not checked
  /// here except that one-chapter books read "Jude 5" as verse 5.
  ParsedReference? parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final match = _pattern.firstMatch(text);
    if (match == null || match.group(1)!.isEmpty) {
      // Only a book name ("ዮሐንስ", "Genesis"): open chapter 1.
      final book = _findBook(text);
      return book == null ? null : ParsedReference(book, 1);
    }

    final book = _findBook(match.group(1)!);
    if (book == null) return null;
    final first = int.parse(match.group(2)!);
    final second = match.group(3) == null ? null : int.parse(match.group(3)!);

    if (second == null && _chapters[book] == 1) {
      return ParsedReference(book, 1, first);
    }
    return ParsedReference(book, first, second);
  }

  int? _findBook(String name) {
    final key = _key(name);
    if (key.isEmpty) return null;
    final exact = _aliases[key];
    if (exact != null) return exact;
    if (key.length < 2) return null;

    // Prefix match: "joh" -> John, "ዘፍጥ" -> Genesis. Prefer the shortest
    // alias, then the earlier book, so "jo" picks Job rather than Jonah.
    String? bestAlias;
    int? bestBook;
    _aliases.forEach((alias, book) {
      if (!alias.startsWith(key)) return;
      final better = bestAlias == null ||
          alias.length < bestAlias!.length ||
          (alias.length == bestAlias!.length && book < bestBook!);
      if (better) {
        bestAlias = alias;
        bestBook = book;
      }
    });
    return bestBook;
  }

  /// Common abbreviations not stored in bible.db.
  static const Map<int, List<String>> _extraAliases = {
    1: ['gn', 'ge', 'ዘፍጥረት'],
    2: ['ex', 'exo'],
    3: ['lv', 'le'],
    4: ['nm', 'nu', 'ዘኁልቁ'],
    5: ['dt', 'de'],
    7: ['jdg', 'jg'],
    19: ['psalm', 'psa', 'pss', 'መዝሙር'],
    20: ['pr', 'prv'],
    21: ['ec', 'qoh'],
    22: ['songofsongs', 'sos', 'song', 'canticles'],
    23: ['is'],
    26: ['ez'],
    40: ['mt'],
    41: ['mk', 'mr'],
    42: ['lk'],
    43: ['jn', 'jhn'],
    44: ['ac', 'ሐዋርያት'],
    45: ['ro', 'rm'],
    62: ['1jn'],
    63: ['2jn'],
    64: ['3jn'],
    65: ['jud'],
    66: ['rv', 'revelations', 'ራዕይ'],
  };
}
