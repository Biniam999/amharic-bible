import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/script_utils.dart';

/// A verse position, independent of translation. Book ids are 1–66.
@immutable
class VerseRef implements Comparable<VerseRef> {
  const VerseRef(this.bookId, this.chapter, this.verse);

  final int bookId;
  final int chapter;
  final int verse;

  bool get isNewTestament => bookId >= AppConstants.firstNtBookId;

  @override
  int compareTo(VerseRef other) {
    if (bookId != other.bookId) return bookId.compareTo(other.bookId);
    if (chapter != other.chapter) return chapter.compareTo(other.chapter);
    return verse.compareTo(other.verse);
  }

  @override
  bool operator ==(Object other) =>
      other is VerseRef && other.bookId == bookId && other.chapter == chapter && other.verse == verse;

  @override
  int get hashCode => Object.hash(bookId, chapter, verse);

  @override
  String toString() => 'VerseRef($bookId $chapter:$verse)';
}

@immutable
class Translation {
  const Translation({
    required this.id,
    required this.ordinal,
    required this.name,
    required this.abbreviation,
    required this.language,
    required this.copyright,
  });

  final String id;

  /// Position in bible.db; used to address this translation in the search index.
  final int ordinal;
  final String name;
  final String abbreviation;
  final String language;
  final String copyright;

  bool get isEthiopic => ScriptUtils.isEthiopicLanguage(language);

  @override
  bool operator ==(Object other) => other is Translation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class Book {
  const Book({
    required this.id,
    required this.translationId,
    required this.osis,
    required this.name,
    required this.shortName,
    required this.abbrev,
    required this.chapters,
  });

  final int id;
  final String translationId;

  /// Standard English code ("Gen", "1Sam", "John"), the same in every translation.
  final String osis;
  final String name;
  final String shortName;
  final String abbrev;
  final int chapters;

  bool get isNewTestament => id >= AppConstants.firstNtBookId;

  @override
  bool operator ==(Object other) =>
      other is Book && other.id == id && other.translationId == translationId;

  @override
  int get hashCode => Object.hash(id, translationId);
}

@immutable
class Verse {
  const Verse({required this.ref, required this.text});

  final VerseRef ref;
  final String text;

  int get number => ref.verse;
}

/// One chapter of one translation, ready to display.
@immutable
class ChapterContent {
  const ChapterContent({
    required this.translationId,
    required this.book,
    required this.chapter,
    required this.verses,
    required this.verseCount,
  });

  final String translationId;
  final Book book;
  final int chapter;

  /// Verses that have text, in order.
  final List<Verse> verses;

  /// Highest verse number in this chapter. Can be greater than [verses].length
  /// where the edition prints two verses together (e.g. 1–2) and one number has no text.
  final int verseCount;

  bool get isEmpty => verses.isEmpty;

  /// Verse number(s) to print before verse [index]. Where the edition prints
  /// verses together, the numbers without their own text are folded into the
  /// verse before them ("22–23"), or the one after if the gap opens the chapter.
  String labelAt(int index) {
    final first = index == 0 ? 1 : verses[index].number;
    final last = index + 1 < verses.length
        ? verses[index + 1].number - 1
        : math.max(verseCount, verses[index].number);
    return last > first ? '$first–$last' : '$first';
  }

  /// Index of the verse whose label covers [verse] (for jumps and restore).
  int indexForVerse(int verse) {
    for (var i = verses.length - 1; i >= 0; i--) {
      if (verses[i].number <= verse) return i;
    }
    return 0;
  }
  bool get hasPrevious => chapter > 1 || book.id > 1;
  bool get hasNext => chapter < book.chapters || book.id < AppConstants.bookCount;
}

// --------------------------------------------------------------------------- //
// User data (user.db). Stored by book/chapter/verse, without the translation,
// so a highlight or note shows in every translation.
// --------------------------------------------------------------------------- //

/// Order matches ReadingTheme.highlightSwatches; the index is stored in
/// user.db, so new colours are only ever added at the end.
enum HighlightColor { yellow, green, blue, pink, orange, red, purple, teal, indigo, lime, brown, gray }

@immutable
class Bookmark {
  const Bookmark({required this.id, required this.translationId, required this.ref, required this.createdAt});

  final int id;

  /// Translation that was open when bookmarked, so the library can reopen it.
  final String translationId;
  final VerseRef ref;
  final DateTime createdAt;
}

@immutable
class Highlight {
  const Highlight({required this.id, required this.ref, required this.color, required this.createdAt});

  final int id;
  final VerseRef ref;
  final HighlightColor color;
  final DateTime createdAt;
}

@immutable
class Note {
  const Note({
    required this.id,
    required this.ref,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final VerseRef ref;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Everything the reader needs to decorate one verse.
@immutable
class VerseAnnotations {
  const VerseAnnotations({this.bookmarked = false, this.highlight, this.note});

  static const empty = VerseAnnotations();

  final bool bookmarked;
  final HighlightColor? highlight;
  final String? note;

  bool get hasNote => note != null;

  VerseAnnotations copyWith({bool? bookmarked, HighlightColor? highlight, String? note}) => VerseAnnotations(
        bookmarked: bookmarked ?? this.bookmarked,
        highlight: highlight ?? this.highlight,
        note: note ?? this.note,
      );

  @override
  bool operator ==(Object other) =>
      other is VerseAnnotations &&
      other.bookmarked == bookmarked &&
      other.highlight == highlight &&
      other.note == note;

  @override
  int get hashCode => Object.hash(bookmarked, highlight, note);
}

class BibleDataException implements Exception {
  BibleDataException(this.message);

  final String message;

  @override
  String toString() => 'BibleDataException: $message';
}
