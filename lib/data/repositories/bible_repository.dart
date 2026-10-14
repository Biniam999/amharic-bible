import 'package:drift/drift.dart';

import '../database/bible_database.dart';
import '../models/bible_models.dart';
import '../../core/utils/verse_clean.dart';

/// Read access to Bible text. Translations and book lists are small and
/// asked for constantly, so they are cached after the first load.
class BibleRepository {
  BibleRepository(this._db);

  final BibleDatabase _db;

  List<Translation>? _translations;
  final Map<String, List<Book>> _books = {};

  Future<List<Translation>> translations() async {
    return _translations ??= (await _db
            .customSelect(
              'SELECT id, ordinal, name, abbreviation, language, copyright '
              'FROM translations ORDER BY ordinal',
            )
            .get())
        .map(
          (r) => Translation(
            id: r.read<String>('id'),
            ordinal: r.read<int>('ordinal'),
            name: r.read<String>('name'),
            abbreviation: r.read<String>('abbreviation'),
            language: r.read<String>('language'),
            copyright: r.read<String>('copyright'),
          ),
        )
        .toList(growable: false);
  }

  Future<Translation> translation(String id) async {
    final all = await translations();
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => throw BibleDataException('Unknown translation "$id"'),
    );
  }

  /// All books of [translationId] in canonical order (Genesis first).
  Future<List<Book>> books(String translationId) async {
    final cached = _books[translationId];
    if (cached != null) return cached;
    final rows = await _db.customSelect(
      'SELECT id, osis, name, short_name, abbrev, chapters FROM books '
      'WHERE translation_id = ? ORDER BY id',
      variables: [Variable.withString(translationId)],
    ).get();
    return _books[translationId] = rows
        .map(
          (r) => Book(
            id: r.read<int>('id'),
            translationId: translationId,
            osis: r.read<String>('osis'),
            name: r.read<String>('name'),
            shortName: r.read<String>('short_name'),
            abbrev: r.read<String>('abbrev'),
            chapters: r.read<int>('chapters'),
          ),
        )
        .toList(growable: false);
  }

  Future<Book> book(String translationId, int bookId) async {
    final all = await books(translationId);
    for (final b in all) {
      if (b.id == bookId) return b;
    }
    throw BibleDataException('Book $bookId not found in "$translationId"');
  }

  Future<ChapterContent> chapter(String translationId, int bookId, int chapter) async {
    final book = await this.book(translationId, bookId);
    if (chapter < 1 || chapter > book.chapters) {
      throw BibleDataException('${book.osis} has no chapter $chapter');
    }
    final rows = await _db.customSelect(
      'SELECT verse, text FROM verses '
      'WHERE translation_id = ? AND book_id = ? AND chapter = ? ORDER BY verse',
      variables: [Variable.withString(translationId), Variable.withInt(bookId), Variable.withInt(chapter)],
    ).get();
    final verses = rows
        .map(
          (r) => Verse(
            ref: VerseRef(bookId, chapter, r.read<int>('verse')),
            text: cleanVerseText(r.read<String>('text')),
          ),
        )
        .toList(growable: false);
    final count = await verseCount(translationId, bookId, chapter);
    return ChapterContent(
      translationId: translationId,
      book: book,
      chapter: chapter,
      verses: verses,
      verseCount: count > 0 ? count : (verses.isEmpty ? 0 : verses.last.number),
    );
  }

  /// Verse count of every chapter, keyed by (book, chapter). Used to give
  /// each day of a reading plan a similar amount to read.
  Future<Map<(int, int), int>> chapterVerseCounts(String translationId) async {
    final rows = await _db.customSelect(
      'SELECT book_id, chapter, verse_count FROM chapters WHERE translation_id = ?',
      variables: [Variable.withString(translationId)],
    ).get();
    return {
      for (final r in rows) (r.read<int>('book_id'), r.read<int>('chapter')): r.read<int>('verse_count'),
    };
  }

  /// Highest verse number in a chapter (0 if the chapter has no text).
  Future<int> verseCount(String translationId, int bookId, int chapter) async {
    final row = await _db.customSelect(
      'SELECT verse_count FROM chapters WHERE translation_id = ? AND book_id = ? AND chapter = ?',
      variables: [Variable.withString(translationId), Variable.withInt(bookId), Variable.withInt(chapter)],
    ).getSingleOrNull();
    return row?.read<int>('verse_count') ?? 0;
  }

  /// Text of specific verses (for sharing, the library, search results),
  /// returned in Bible order. Refs without text are skipped.
  Future<List<Verse>> verses(String translationId, Iterable<VerseRef> refs) async {
    final unique = refs.toSet().toList()..sort();
    if (unique.isEmpty) return const [];
    final result = <Verse>[];
    // Batches stay well under SQLite's limit on bound variables.
    const batchSize = 200;
    for (var i = 0; i < unique.length; i += batchSize) {
      final batch = unique.sublist(i, i + batchSize > unique.length ? unique.length : i + batchSize);
      final values = List.filled(batch.length, '(?, ?, ?)').join(', ');
      final rows = await _db.customSelect(
        'SELECT book_id, chapter, verse, text FROM verses '
        'WHERE translation_id = ? AND (book_id, chapter, verse) IN (VALUES $values) '
        'ORDER BY book_id, chapter, verse',
        variables: [
          Variable.withString(translationId),
          for (final r in batch) ...[Variable.withInt(r.bookId), Variable.withInt(r.chapter), Variable.withInt(r.verse)],
        ],
      ).get();
      result.addAll(
        rows.map(
          (r) => Verse(
            ref: VerseRef(r.read<int>('book_id'), r.read<int>('chapter'), r.read<int>('verse')),
            text: cleanVerseText(r.read<String>('text')),
          ),
        ),
      );
    }
    return result;
  }

  /// Value stored by the build script in the `meta` table, or null.
  Future<String?> meta(String key) async {
    final row = await _db.customSelect(
      'SELECT value FROM meta WHERE key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();
    return row?.read<String>('value');
  }
}
