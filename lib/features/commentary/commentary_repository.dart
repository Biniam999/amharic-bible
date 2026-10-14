import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// One commentary source (Matthew Henry, Tyndale, ...).
class CommentarySource {
  final String id;
  final String name;
  final String shortName;
  final String? licenseUrl;
  const CommentarySource(this.id, this.name, this.shortName, this.licenseUrl);
}

/// A note for a verse. [fromVerse] is the verse the note was actually written
/// on — it can be earlier than the verse the reader tapped, because Matthew
/// Henry often writes one note covering several verses.
class CommentaryNote {
  final String sourceId;
  final String book;
  final int chapter;
  final int fromVerse;
  final String text;
  const CommentaryNote(this.sourceId, this.book, this.chapter, this.fromVerse, this.text);
}

/// A related passage. Book numbers are 1 (Genesis) … 66 (Revelation).
class CrossRef {
  final int book;
  final int chapter;
  final int verse;

  /// Last verse of a range (e.g. 1 John 4:9–10), or null.
  final int? endVerse;

  /// How many readers found it useful (OpenBible.info votes); higher first.
  final int score;
  const CrossRef(this.book, this.chapter, this.verse, this.endVerse, this.score);
}

class BibleProfile {
  final String id;
  final String subject;
  final String? refBook;
  final int? refChapter;
  final int? refVerse;
  final String text;
  const BibleProfile(this.id, this.subject, this.refBook, this.refChapter, this.refVerse, this.text);
}

/// Offline commentary data, read from assets/db/commentaries.db.
///
/// Uses the `sqlite3` package (the same SQLite that drift and
/// sqlite3_flutter_libs already ship, with FTS5), so no extra dependency.
/// It is a separate read-only file and does not touch your drift database.
///
/// Book ids are USFM codes (GEN, EXO, 1SA, MAT, JHN ...). If your Bible tables
/// use numbers 1–66, convert with [toUsfm].
class CommentaryRepository {
  CommentaryRepository._();
  static final CommentaryRepository instance = CommentaryRepository._();

  static const _assetPath = 'assets/db/commentaries.db';
  static const _fileName = 'commentaries.db';

  /// Bump this whenever you ship a rebuilt commentaries.db so phones copy the new one.
  static const _dbVersion = 3;

  Database? _db;
  Future<Database>? _opening;
  List<CommentarySource>? _sources;

  Future<Database> get _database {
    if (_db != null) return Future.value(_db!);
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, _fileName);
    final file = File(path);

    var needsCopy = !file.existsSync();
    if (!needsCopy) {
      final existing = sqlite3.open(path, mode: OpenMode.readOnly);
      needsCopy = existing.userVersion < _dbVersion;
      existing.dispose();
    }
    if (needsCopy) {
      await dir.create(recursive: true);
      final data = await rootBundle.load(_assetPath);
      final tmp = File('$path.tmp');
      await tmp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await tmp.rename(path); // atomic: never leaves a half-copied database
    }
    return _db = sqlite3.open(path, mode: OpenMode.readOnly);
  }

  Future<List<CommentarySource>> sources() async {
    if (_sources != null) return _sources!;
    final rows = (await _database).select(
        'SELECT id, name, short_name, license_url FROM commentaries ORDER BY sort_order');
    return _sources = [
      for (final r in rows)
        CommentarySource(r['id'] as String, r['name'] as String,
            r['short_name'] as String, r['license_url'] as String?),
    ];
  }

  /// The note for a verse. If a source has no note on that exact verse, the
  /// nearest earlier note in the same chapter is returned (it usually covers
  /// the tapped verse).
  Future<CommentaryNote?> noteFor(String sourceId, String book, int chapter, int verse) async {
    final rows = (await _database).select(
      'SELECT verse, text FROM notes '
      'WHERE source = ? AND book = ? AND chapter = ? AND verse <= ? '
      'ORDER BY verse DESC LIMIT 1',
      [sourceId, book, chapter, verse],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return CommentaryNote(sourceId, book, chapter, r['verse'] as int, r['text'] as String);
  }

  /// Verse numbers in a chapter that have a note in any source —
  /// use it to draw the small "has commentary" dot.
  Future<Set<int>> versesWithNotes(String book, int chapter) async {
    final rows = (await _database).select(
      'SELECT DISTINCT verse FROM notes WHERE book = ? AND chapter = ?',
      [book, chapter],
    );
    return {for (final r in rows) r['verse'] as int};
  }

  /// Every note in a chapter for one source, in verse order.
  Future<List<CommentaryNote>> notesForChapter(String sourceId, String book, int chapter) async {
    final rows = (await _database).select(
      'SELECT verse, text FROM notes WHERE source = ? AND book = ? AND chapter = ? ORDER BY verse',
      [sourceId, book, chapter],
    );
    return [
      for (final r in rows) CommentaryNote(sourceId, book, chapter, r['verse'] as int, r['text'] as String),
    ];
  }

  Future<String?> bookIntro(String sourceId, String book) async {
    final rows = (await _database).select(
        'SELECT text FROM book_intros WHERE source = ? AND book = ?', [sourceId, book]);
    return rows.isEmpty ? null : rows.first['text'] as String;
  }

  Future<String?> chapterIntro(String sourceId, String book, int chapter) async {
    final rows = (await _database).select(
        'SELECT text FROM chapter_intros WHERE source = ? AND book = ? AND chapter = ?',
        [sourceId, book, chapter]);
    return rows.isEmpty ? null : rows.first['text'] as String;
  }

  Future<List<BibleProfile>> profiles() async {
    final rows = (await _database).select(
        'SELECT id, subject, ref_book, ref_chapter, ref_verse, text '
        'FROM profiles ORDER BY subject COLLATE NOCASE');
    return [
      for (final r in rows)
        BibleProfile(
          r['id'] as String,
          r['subject'] as String,
          r['ref_book'] as String?,
          r['ref_chapter'] as int?,
          r['ref_verse'] as int?,
          r['text'] as String,
        ),
    ];
  }

  /// Full-text search over all notes (English words).
  /// Returns an empty list if the database was built with --no-fts.
  Future<List<CommentaryNote>> search(String query, {int limit = 100}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final escaped = q.replaceAll('"', '""');
    try {
      final rows = (await _database).select(
        'SELECT n.source, n.book, n.chapter, n.verse, n.text '
        'FROM notes_fts f JOIN notes n ON n.rowid = f.rowid '
        'WHERE notes_fts MATCH ? LIMIT ?',
        ['"$escaped"', limit],
      );
      return [
        for (final r in rows)
          CommentaryNote(r['source'] as String, r['book'] as String,
              r['chapter'] as int, r['verse'] as int, r['text'] as String),
      ];
    } on SqliteException {
      return [];
    }
  }

  /// Related passages for a verse, strongest first. Empty if the database
  /// was built without cross references.
  Future<List<CrossRef>> crossRefs(int bookId, int chapter, int verse) async {
    try {
      final rows = (await _database).select(
        'SELECT to_book, to_chapter, to_verse, to_end, score FROM cross_refs '
        'WHERE book_id = ? AND chapter = ? AND verse = ? ORDER BY score DESC',
        [bookId, chapter, verse],
      );
      return [
        for (final r in rows)
          CrossRef(r['to_book'] as int, r['to_chapter'] as int, r['to_verse'] as int, r['to_end'] as int?,
              r['score'] as int),
      ];
    } on SqliteException {
      return const [];
    }
  }

  /// Verse numbers in a chapter that have at least one cross-reference
  /// (one indexed query per chapter; used to place the reader's ✱ markers).
  Future<Set<int>> crossRefVerses(int bookId, int chapter) async {
    try {
      final rows = (await _database).select(
        'SELECT DISTINCT verse FROM cross_refs WHERE book_id = ? AND chapter = ?',
        [bookId, chapter],
      );
      return {for (final r in rows) r['verse'] as int};
    } on SqliteException {
      return const {};
    }
  }

  /// Converts a 1-based book number (Genesis = 1 ... Revelation = 66) to USFM.
  static String toUsfm(int bookNumber) => _usfm[bookNumber - 1];

  /// The reverse of [toUsfm]: 'JHN' → 43. Null for unknown codes.
  static int? fromUsfm(String code) {
    final i = _usfm.indexOf(code.toUpperCase());
    return i < 0 ? null : i + 1;
  }

  static const _usfm = [
    'GEN', 'EXO', 'LEV', 'NUM', 'DEU', 'JOS', 'JDG', 'RUT', '1SA', '2SA',
    '1KI', '2KI', '1CH', '2CH', 'EZR', 'NEH', 'EST', 'JOB', 'PSA', 'PRO',
    'ECC', 'SNG', 'ISA', 'JER', 'LAM', 'EZK', 'DAN', 'HOS', 'JOL', 'AMO',
    'OBA', 'JON', 'MIC', 'NAM', 'HAB', 'ZEP', 'HAG', 'ZEC', 'MAL',
    'MAT', 'MRK', 'LUK', 'JHN', 'ACT', 'ROM', '1CO', '2CO', 'GAL', 'EPH',
    'PHP', 'COL', '1TH', '2TH', '1TI', '2TI', 'TIT', 'PHM', 'HEB', 'JAS',
    '1PE', '2PE', '1JN', '2JN', '3JN', 'JUD', 'REV',
  ];
}
