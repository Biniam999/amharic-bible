import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/bible_database.dart';
import 'database/user_database.dart';
import 'models/bible_models.dart';
import 'repositories/bible_repository.dart';
import 'repositories/user_data_repository.dart';

// Both databases are opened in main() before runApp and injected here, so
// every provider below can use them synchronously.

final bibleDatabaseProvider = Provider<BibleDatabase>(
  (ref) => throw UnimplementedError('Override bibleDatabaseProvider in main()'),
);

final userDatabaseProvider = Provider<UserDatabase>(
  (ref) => throw UnimplementedError('Override userDatabaseProvider in main()'),
);

final bibleRepositoryProvider = Provider<BibleRepository>(
  (ref) => BibleRepository(ref.watch(bibleDatabaseProvider)),
);

final userDataRepositoryProvider = Provider<UserDataRepository>(
  (ref) => UserDataRepository(ref.watch(userDatabaseProvider)),
);

final translationsProvider = FutureProvider<List<Translation>>(
  (ref) => ref.watch(bibleRepositoryProvider).translations(),
);

/// Books of one translation, in Bible order.
final booksProvider = FutureProvider.family<List<Book>, String>(
  (ref, translationId) => ref.watch(bibleRepositoryProvider).books(translationId),
);

typedef ChapterKey = ({String translationId, int bookId, int chapter});

/// One chapter's text. autoDispose: chapters the user has left are freed.
final chapterProvider = FutureProvider.autoDispose.family<ChapterContent, ChapterKey>(
  (ref, key) => ref.watch(bibleRepositoryProvider).chapter(key.translationId, key.bookId, key.chapter),
);

typedef ChapterPosition = ({int bookId, int chapter});

/// Bookmarks, highlights and notes for a chapter (same in every translation).
final chapterAnnotationsProvider =
    StreamProvider.autoDispose.family<Map<int, VerseAnnotations>, ChapterPosition>(
  (ref, pos) => ref.watch(userDataRepositoryProvider).watchChapter(pos.bookId, pos.chapter),
);
