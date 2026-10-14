import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../data/repositories/bible_repository.dart';
import '../reader/reader_position.dart';

/// A bookmark, highlight or note with its reference and verse text, in the
/// translation currently open in the reader.
@immutable
class LibraryEntry<T> {
  const LibraryEntry({required this.item, required this.ref, required this.reference, required this.verseText});

  final T item;
  final VerseRef ref;

  /// e.g. "ዮሐንስ 3:16"
  final String reference;

  /// Empty if this translation has no text for the verse.
  final String verseText;
}

Future<List<LibraryEntry<T>>> _resolve<T>(
  BibleRepository bible,
  String translationId,
  List<T> items,
  VerseRef Function(T) refOf,
) async {
  if (items.isEmpty) return const [];
  final books = {for (final b in await bible.books(translationId)) b.id: b};
  final texts = {for (final v in await bible.verses(translationId, items.map(refOf))) v.ref: v.text};
  return [
    for (final item in items)
      LibraryEntry(
        item: item,
        ref: refOf(item),
        reference: '${books[refOf(item).bookId]?.shortName ?? refOf(item).bookId} '
            '${refOf(item).chapter}:${refOf(item).verse}',
        verseText: texts[refOf(item)] ?? '',
      ),
  ];
}

/// Shared setup: re-resolves when the data changes or the reader switches translation.
Stream<List<LibraryEntry<T>>> _entries<T>(
  Ref ref,
  Stream<List<T>> Function() watch,
  VerseRef Function(T) refOf,
) {
  final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
  final bible = ref.watch(bibleRepositoryProvider);
  return watch().asyncMap((items) => _resolve(bible, translationId, items, refOf));
}

final libraryBookmarksProvider = StreamProvider.autoDispose<List<LibraryEntry<Bookmark>>>(
  (ref) => _entries(ref, ref.watch(userDataRepositoryProvider).watchBookmarks, (b) => b.ref),
);

final libraryHighlightsProvider = StreamProvider.autoDispose<List<LibraryEntry<Highlight>>>(
  (ref) => _entries(ref, ref.watch(userDataRepositoryProvider).watchHighlights, (h) => h.ref),
);

/// Most recently edited first.
final libraryNotesProvider = StreamProvider.autoDispose<List<LibraryEntry<Note>>>(
  (ref) => _entries(ref, ref.watch(userDataRepositoryProvider).watchNotes, (n) => n.ref),
);
