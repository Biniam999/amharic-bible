import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../reader/reader_position.dart';

/// Hand-picked, well-loved verses for "Today's verse". One per day, in a
/// fixed rotation, so everyone sees the same verse on the same day.
///
/// Only verses from chapters whose Amharic numbering matches the KJV are
/// listed, so the verse shown is the right one in both translations.
const _verses = <(int, int, int)>[
  (1, 1, 1),
  (1, 1, 27),
  (4, 6, 24),
  (4, 6, 25),
  (4, 6, 26),
  (5, 31, 6),
  (5, 31, 8),
  (6, 24, 15),
  (9, 16, 7),
  (14, 7, 14),
  (18, 19, 25),
  (19, 1, 1),
  (19, 4, 8),
  (19, 16, 8),
  (19, 16, 11),
  (19, 18, 2),
  (19, 19, 1),
  (19, 19, 14),
  (19, 23, 1),
  (19, 23, 4),
  (19, 27, 1),
  (19, 27, 14),
  (19, 28, 7),
  (19, 30, 5),
  (19, 32, 8),
  (19, 34, 8),
  (19, 37, 4),
  (19, 37, 5),
  (19, 40, 1),
  (19, 42, 11),
  (19, 46, 1),
  (19, 46, 10),
  (19, 51, 10),
  (19, 55, 22),
  (19, 62, 1),
  (19, 63, 1),
  (19, 73, 26),
  (19, 84, 11),
  (19, 90, 12),
  (19, 91, 1),
  (19, 91, 11),
  (19, 100, 4),
  (19, 103, 2),
  (19, 103, 12),
  (19, 107, 1),
  (19, 118, 24),
  (19, 119, 11),
  (19, 119, 105),
  (19, 121, 1),
  (19, 121, 2),
  (19, 127, 1),
  (19, 133, 1),
  (19, 139, 14),
  (19, 143, 8),
  (19, 145, 18),
  (19, 147, 3),
  (19, 150, 6),
  (20, 3, 5),
  (20, 3, 6),
  (20, 4, 23),
  (20, 16, 3),
  (20, 16, 9),
  (20, 17, 17),
  (20, 18, 10),
  (20, 31, 30),
  (21, 3, 1),
  (23, 26, 3),
  (23, 40, 8),
  (23, 40, 31),
  (23, 53, 5),
  (23, 55, 8),
  (23, 61, 1),
  (24, 17, 7),
  (24, 29, 11),
  (24, 33, 3),
  (26, 36, 26),
  (29, 2, 28),
  (33, 6, 8),
  (34, 1, 7),
  (35, 3, 17),
  (36, 3, 17),
  (39, 3, 10),
  (40, 7, 7),
  (40, 7, 12),
  (40, 11, 28),
  (40, 11, 29),
  (40, 16, 24),
  (40, 18, 20),
  (40, 19, 26),
  (41, 10, 27),
  (41, 11, 24),
  (42, 6, 31),
  (42, 12, 34),
  (43, 1, 1),
  (43, 1, 5),
  (43, 1, 12),
  (43, 6, 35),
  (43, 8, 12),
  (43, 8, 32),
  (43, 11, 25),
  (43, 13, 34),
  (43, 13, 35),
  (43, 15, 5),
  (43, 15, 13),
  (44, 16, 31),
  (45, 8, 1),
  (45, 8, 28),
  (45, 8, 31),
  (45, 8, 38),
  (45, 10, 9),
  (45, 10, 17),
  (45, 12, 2),
  (45, 12, 12),
  (45, 12, 21),
  (46, 13, 4),
  (46, 13, 13),
  (46, 16, 14),
  (47, 5, 7),
  (47, 5, 17),
  (47, 12, 9),
  (48, 2, 20),
  (48, 6, 9),
  (50, 4, 4),
  (50, 4, 6),
  (50, 4, 7),
  (50, 4, 13),
  (50, 4, 19),
  (51, 3, 2),
  (51, 3, 23),
  (58, 4, 12),
  (58, 4, 16),
  (58, 12, 1),
  (58, 12, 2),
  (58, 13, 5),
  (58, 13, 8),
  (59, 4, 8),
  (60, 3, 15),
  (60, 5, 7),
  (61, 1, 3),
  (62, 1, 9),
  (62, 4, 8),
  (62, 4, 18),
  (62, 4, 19),
  (66, 3, 20),
  (66, 22, 13),
];

/// Verse shown above the home page, under the greeting.
const headerVerse = VerseRef(19, 119, 105); // Psalm 119:105

/// Today's verse (changes at local midnight).
VerseRef todaysVerseRef([DateTime? now]) {
  final d = now ?? DateTime.now();
  final day = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024)).inDays;
  final (b, c, v) = _verses[day % _verses.length];
  return VerseRef(b, c, v);
}

/// Day number used to vary the painted scene on the verse card.
int todaysSceneSeed([DateTime? now]) {
  final d = now ?? DateTime.now();
  return DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024)).inDays;
}

typedef HomeVerse = ({Verse verse, Book book, bool ethiopic});

/// A verse in the translation the reader currently uses.
final homeVerseProvider = FutureProvider.autoDispose.family<HomeVerse?, VerseRef>((ref, verseRef) async {
  final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
  final repo = ref.watch(bibleRepositoryProvider);
  final found = await repo.verses(translationId, [verseRef]);
  if (found.isEmpty) return null;
  final book = await repo.book(translationId, verseRef.bookId);
  final translations = await ref.watch(translationsProvider.future);
  final ethiopic = translations.where((t) => t.id == translationId).firstOrNull?.isEthiopic ?? true;
  return (verse: found.first, book: book, ethiopic: ethiopic);
});
