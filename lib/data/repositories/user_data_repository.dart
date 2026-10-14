import 'package:drift/drift.dart';

import '../database/user_database.dart';
import '../models/bible_models.dart';

/// Bookmarks, highlights and notes. All writes go through here so the reader
/// and library screens stay in sync via drift's watched queries.
class UserDataRepository {
  UserDataRepository(this._db);

  final UserDatabase _db;

  // ------------------------------------------------------------------ reader

  /// Bookmark / highlight / note state for every annotated verse in a chapter,
  /// keyed by verse number. Emits again whenever any of them changes.
  Stream<Map<int, VerseAnnotations>> watchChapter(int bookId, int chapter) {
    final vars = [Variable.withInt(bookId), Variable.withInt(chapter)];
    return _db
        .customSelect(
          "SELECT 'b' AS kind, verse, NULL AS color, NULL AS note "
          'FROM bookmarks WHERE book_id = ?1 AND chapter = ?2 '
          'UNION ALL '
          "SELECT 'h', verse, color, NULL FROM highlights WHERE book_id = ?1 AND chapter = ?2 "
          'UNION ALL '
          "SELECT 'n', verse, NULL, note_text FROM notes WHERE book_id = ?1 AND chapter = ?2",
          variables: vars,
          readsFrom: {_db.bookmarks, _db.highlights, _db.notes},
        )
        .watch()
        .map((rows) {
      final result = <int, VerseAnnotations>{};
      for (final r in rows) {
        final verse = r.read<int>('verse');
        final current = result[verse] ?? VerseAnnotations.empty;
        result[verse] = switch (r.read<String>('kind')) {
          'b' => current.copyWith(bookmarked: true),
          'h' => current.copyWith(highlight: _color(r.read<int>('color'))),
          _ => current.copyWith(note: r.read<String>('note')),
        };
      }
      return result;
    });
  }

  // --------------------------------------------------------------- bookmarks

  /// If every ref is already bookmarked, removes them all; otherwise adds the
  /// missing ones. Returns true if the verses are bookmarked afterwards.
  Future<bool> toggleBookmarks(String translationId, Iterable<VerseRef> refs) {
    final list = refs.toSet().toList();
    return _db.transaction(() async {
      final existing = <VerseRef>{};
      for (final r in list) {
        final row = await (_db.select(_db.bookmarks)..where((b) => _matches(b.bookId, b.chapter, b.verse, r)))
            .getSingleOrNull();
        if (row != null) existing.add(r);
      }
      if (existing.length == list.length) {
        for (final r in list) {
          await (_db.delete(_db.bookmarks)..where((b) => _matches(b.bookId, b.chapter, b.verse, r))).go();
        }
        return false;
      }
      for (final r in list.where((r) => !existing.contains(r))) {
        await _db.into(_db.bookmarks).insert(
              BookmarksCompanion.insert(
                translationId: translationId,
                bookId: r.bookId,
                chapter: r.chapter,
                verse: r.verse,
              ),
            );
      }
      return true;
    });
  }

  Future<void> deleteBookmark(int id) => (_db.delete(_db.bookmarks)..where((b) => b.id.equals(id))).go();

  Stream<List<Bookmark>> watchBookmarks() =>
      (_db.select(_db.bookmarks)..orderBy([(b) => OrderingTerm.desc(b.createdAt), (b) => OrderingTerm.desc(b.id)]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                Bookmark(
                  id: r.id,
                  translationId: r.translationId,
                  ref: VerseRef(r.bookId, r.chapter, r.verse),
                  createdAt: r.createdAt,
                ),
            ],
          );

  // -------------------------------------------------------------- highlights

  Future<void> setHighlight(Iterable<VerseRef> refs, HighlightColor color) => _db.transaction(() async {
        for (final r in refs.toSet()) {
          await _db.into(_db.highlights).insert(
                HighlightsCompanion.insert(bookId: r.bookId, chapter: r.chapter, verse: r.verse, color: color.index),
                mode: InsertMode.insertOrReplace,
              );
        }
      });

  Future<void> removeHighlights(Iterable<VerseRef> refs) => _db.transaction(() async {
        for (final r in refs.toSet()) {
          await (_db.delete(_db.highlights)..where((h) => _matches(h.bookId, h.chapter, h.verse, r))).go();
        }
      });

  Future<void> deleteHighlight(int id) => (_db.delete(_db.highlights)..where((h) => h.id.equals(id))).go();

  Stream<List<Highlight>> watchHighlights() =>
      (_db.select(_db.highlights)..orderBy([(h) => OrderingTerm.desc(h.createdAt), (h) => OrderingTerm.desc(h.id)]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                Highlight(
                  id: r.id,
                  ref: VerseRef(r.bookId, r.chapter, r.verse),
                  color: _color(r.color),
                  createdAt: r.createdAt,
                ),
            ],
          );

  // ------------------------------------------------------------------- notes

  Future<Note?> note(VerseRef ref) async {
    final row = await (_db.select(_db.notes)..where((n) => _matches(n.bookId, n.chapter, n.verse, ref)))
        .getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  /// Creates or updates the note on [ref]. Blank text deletes it.
  Future<void> saveNote(VerseRef ref, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await deleteNote(ref);
      return;
    }
    await _db.transaction(() async {
      final updated = await (_db.update(_db.notes)..where((n) => _matches(n.bookId, n.chapter, n.verse, ref)))
          .write(NotesCompanion(noteText: Value(trimmed), updatedAt: Value(DateTime.now())));
      if (updated == 0) {
        await _db.into(_db.notes).insert(
              NotesCompanion.insert(bookId: ref.bookId, chapter: ref.chapter, verse: ref.verse, noteText: trimmed),
            );
      }
    });
  }

  Future<void> deleteNote(VerseRef ref) =>
      (_db.delete(_db.notes)..where((n) => _matches(n.bookId, n.chapter, n.verse, ref))).go();

  Future<void> deleteNoteById(int id) => (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();

  /// All notes, most recently edited first.
  Stream<List<Note>> watchNotes() =>
      (_db.select(_db.notes)..orderBy([(n) => OrderingTerm.desc(n.updatedAt), (n) => OrderingTerm.desc(n.id)]))
          .watch()
          .map((rows) => rows.map(_toNote).toList(growable: false));

  // ----------------------------------------------------------------- helpers

  static Expression<bool> _matches(
    GeneratedColumn<int> book,
    GeneratedColumn<int> chapter,
    GeneratedColumn<int> verse,
    VerseRef r,
  ) =>
      book.equals(r.bookId) & chapter.equals(r.chapter) & verse.equals(r.verse);

  static HighlightColor _color(int index) =>
      HighlightColor.values[index.clamp(0, HighlightColor.values.length - 1)];

  static Note _toNote(NoteRow r) => Note(
        id: r.id,
        ref: VerseRef(r.bookId, r.chapter, r.verse),
        text: r.noteText,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );
}
