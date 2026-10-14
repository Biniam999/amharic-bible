import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../settings/settings_providers.dart';

/// Morning (or the only reading of the day) and evening.
enum DevotionPeriod { morning, evening }

/// One day's reading.
class Devotion {
  const Devotion({
    required this.month,
    required this.day,
    required this.period,
    required this.reference,
    required this.keyVerse,
    required this.paragraphs,
    this.verse,
  });

  final int month;
  final int day;
  final DevotionPeriod period;

  /// As printed, e.g. "Joshua 5:12".
  final String reference;
  final String keyVerse;
  final List<String> paragraphs;

  /// The key verse as a position in the Bible, when known.
  final VerseRef? verse;

  String get plainText => paragraphs.join('\n\n');
}

/// A devotional book: one or two readings for each day of the year.
class DevotionalBook {
  DevotionalBook({
    required this.id,
    required this.title,
    required this.author,
    required this.language,
    required this.periods,
    required Map<int, List<Devotion>> byDay,
  }) : _byDay = byDay;

  final String id;
  final String title;
  final String author;

  /// "en", "am", …
  final String language;

  /// 1 = one reading a day, 2 = morning and evening.
  final int periods;
  final Map<int, List<Devotion>> _byDay;

  bool get hasEvening => periods > 1;
  bool get isEthiopic => language == 'am';

  Devotion? reading(int month, int day, DevotionPeriod period) {
    final list = _byDay[month * 100 + day];
    if (list == null || list.isEmpty) return null;
    for (final d in list) {
      if (d.period == period) return d;
    }
    return hasEvening ? null : list.first;
  }
}

/// Parsed off the UI thread: the file is ~1.4 MB.
DevotionalBook _parse(String source) {
  final j = jsonDecode(source) as Map<String, dynamic>;
  final byDay = <int, List<Devotion>>{};
  for (final raw in j['entries'] as List) {
    final e = raw as List;
    final month = e[0] as int, day = e[1] as int;
    final book = e.length > 6 ? (e[6] as int? ?? 0) : 0;
    final d = Devotion(
      month: month,
      day: day,
      period: (e[2] as int? ?? 0) == 1 ? DevotionPeriod.evening : DevotionPeriod.morning,
      reference: e[3] as String? ?? '',
      keyVerse: e[4] as String? ?? '',
      paragraphs: [
        for (final p in (e[5] as String? ?? '').split('\n\n'))
          if (p.trim().isNotEmpty) p.trim(),
      ],
      verse: book > 0 ? VerseRef(book, e[7] as int, e[8] as int) : null,
    );
    (byDay[month * 100 + day] ??= []).add(d);
  }
  return DevotionalBook(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    author: j['author'] as String? ?? '',
    language: j['language'] as String? ?? 'en',
    periods: j['periods'] as int? ?? 1,
    byDay: byDay,
  );
}

const _dir = 'assets/devotions';

/// Devotional books listed in assets/devotions/index.json.
final devotionalIndexProvider = FutureProvider<List<({String id, String file})>>((ref) async {
  final list = jsonDecode(await rootBundle.loadString('$_dir/index.json')) as List;
  return [
    for (final e in list.cast<Map<String, dynamic>>()) (id: e['id'] as String, file: e['file'] as String),
  ];
});

final devotionalBookProvider = FutureProvider.family<DevotionalBook, String>((ref, file) async {
  final source = await rootBundle.loadString('$_dir/$file');
  return compute(_parse, source);
});

/// The devotional the reader chose (the first one by default).
class SelectedDevotional extends Notifier<String?> {
  static const _key = 'devotions.book';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> select(String id) async {
    state = id;
    await ref.read(sharedPreferencesProvider).setString(_key, id);
  }
}

final selectedDevotionalProvider = NotifierProvider<SelectedDevotional, String?>(SelectedDevotional.new);

/// The book currently shown, falling back to the first listed.
final currentDevotionalProvider = FutureProvider<DevotionalBook>((ref) async {
  final index = await ref.watch(devotionalIndexProvider.future);
  final chosen = ref.watch(selectedDevotionalProvider);
  final entry = index.firstWhere((e) => e.id == chosen, orElse: () => index.first);
  return ref.watch(devotionalBookProvider(entry.file).future);
});

/// Morning until 2 pm, then evening.
DevotionPeriod currentPeriod([DateTime? now]) =>
    (now ?? DateTime.now()).hour < 14 ? DevotionPeriod.morning : DevotionPeriod.evening;

/// The key verse in the reader's translation, when it isn't the devotional's
/// own language. Skipped where the Amharic verse numbering differs from the
/// KJV in that chapter, so the wrong verse is never shown.
final devotionBibleVerseProvider =
    FutureProvider.autoDispose.family<String?, ({VerseRef verse, String translationId})>((ref, key) async {
  final repo = ref.watch(bibleRepositoryProvider);
  final v = key.verse;
  if (key.translationId != AppConstants.kjvTranslation) {
    final mine = await repo.verseCount(key.translationId, v.bookId, v.chapter);
    final kjv = await repo.verseCount(AppConstants.kjvTranslation, v.bookId, v.chapter);
    if (mine != kjv) return null;
  }
  final verses = await repo.verses(key.translationId, [v]);
  return verses.isEmpty ? null : verses.first.text;
});
