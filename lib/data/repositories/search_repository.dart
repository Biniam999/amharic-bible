import 'dart:isolate';

import 'package:drift/drift.dart';

import '../../core/utils/search_normalizer.dart';
import '../../features/search/search_matching.dart';
import '../database/bible_database.dart';
import '../models/bible_models.dart';
import '../../core/utils/verse_clean.dart';

enum SearchScope { all, oldTestament, newTestament }

class SearchPage {
  const SearchPage({required this.hits, required this.total, required this.offset});

  final List<SearchHit> hits;

  /// Number of matching verses (only counted for the first page).
  final int? total;
  final int offset;
}

/// Full-text search over bible.db's FTS5 index.
///
/// The SQL runs on drift's background isolate; turning rows into highlighted
/// results runs in a short-lived isolate (Isolate.run), so typing never janks.
class SearchRepository {
  SearchRepository(this._db);

  final BibleDatabase _db;

  // rowid = ordinal * 1e8 + book * 1e6 + chapter * 1e3 + verse (see build_bible_db.py)
  static const _perTranslation = 100000000;
  static const _perBook = 1000000;

  static const _searchSql = '''
SELECT v.book_id, v.chapter, v.verse, v.text
FROM verses_fts f
JOIN verses v ON v.translation_id = ?
  AND v.book_id = (f.rowid / 1000000) % 100
  AND v.chapter = (f.rowid / 1000) % 1000
  AND v.verse = f.rowid % 1000
WHERE verses_fts MATCH ? AND f.rowid BETWEEN ? AND ?
ORDER BY f.rowid
LIMIT ? OFFSET ?''';

  static const _countSql = 'SELECT count(*) AS n FROM verses_fts WHERE verses_fts MATCH ? AND rowid BETWEEN ? AND ?';

  /// FTS5 query: every word must match, each as a word prefix
  /// ("ፍቅር" finds ፍቅሩ, ፍቅራችሁ…). Returns null for an empty query.
  static String? matchExpression(List<String> terms) =>
      terms.isEmpty ? null : terms.map((t) => '"${t.replaceAll('"', '')}"*').join(' ');

  Future<SearchPage> search({
    required Translation translation,
    required String query,
    SearchScope scope = SearchScope.all,
    int offset = 0,
    int limit = 100,
  }) async {
    final terms = SearchNormalizer.terms(query);
    final match = matchExpression(terms);
    if (match == null) return SearchPage(hits: const [], total: 0, offset: offset);

    final (firstBook, lastBook) = switch (scope) {
      SearchScope.all => (1, 66),
      SearchScope.oldTestament => (1, 39),
      SearchScope.newTestament => (40, 66),
    };
    final base = translation.ordinal * _perTranslation;
    final low = base + firstBook * _perBook;
    final high = base + lastBook * _perBook + (_perBook - 1);

    final rows = await _db.customSelect(
      _searchSql,
      variables: [
        Variable.withString(translation.id),
        Variable.withString(match),
        Variable.withInt(low),
        Variable.withInt(high),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
    ).get();
    final total = offset == 0
        ? (await _db.customSelect(
            _countSql,
            variables: [Variable.withString(match), Variable.withInt(low), Variable.withInt(high)],
          ).getSingle())
            .read<int>('n')
        : null;

    final raw = [
      for (final r in rows)
        (r.read<int>('book_id'), r.read<int>('chapter'), r.read<int>('verse'), cleanVerseText(r.read<String>('text'))),
    ];
    final amharic = translation.isEthiopic;
    // Small pages aren't worth the cost of starting an isolate.
    final hits = raw.length <= 30
        ? buildSearchHits(raw, terms, amharic: amharic)
        : await Isolate.run(() => buildSearchHits(raw, terms, amharic: amharic));
    return SearchPage(hits: hits, total: total, offset: offset);
  }
}
