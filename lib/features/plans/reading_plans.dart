import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/geez_numerals.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// One chapter to read on a plan day.
typedef PlanReading = ({int bookId, int chapter});

/// A reading plan: read books [firstBook]..[lastBook] in [days] days.
@immutable
class ReadingPlan {
  const ReadingPlan({
    required this.id,
    required this.firstBook,
    required this.lastBook,
    required this.days,
    required this.icon,
    required this.colors,
  });

  /// Stable id, saved with the reader's progress. Never rename.
  final String id;
  final int firstBook;
  final int lastBook;
  final int days;
  final IconData icon;

  /// Card gradient.
  final List<Color> colors;

  String title(AppLocalizations l10n) => switch (id) {
        'bible-year' => l10n.planBibleYear,
        'bible-90' => l10n.planBible90,
        'nt-90' => l10n.planNt90,
        'gospels-30' => l10n.planGospels30,
        'psalms-30' => l10n.planPsalms30,
        'proverbs-31' => l10n.planProverbs31,
        'paul-30' => l10n.planPaul30,
        _ => id,
      };

  String description(AppLocalizations l10n) => switch (id) {
        'bible-year' => l10n.planBibleYearDesc,
        'bible-90' => l10n.planBible90Desc,
        'nt-90' => l10n.planNt90Desc,
        'gospels-30' => l10n.planGospels30Desc,
        'psalms-30' => l10n.planPsalms30Desc,
        'proverbs-31' => l10n.planProverbs31Desc,
        'paul-30' => l10n.planPaul30Desc,
        _ => '',
      };
}

const readingPlans = <ReadingPlan>[
  ReadingPlan(
    id: 'bible-year',
    firstBook: 1,
    lastBook: 66,
    days: 365,
    icon: Icons.public_rounded,
    colors: [Color(0xFF0A1633), Color(0xFF1A5FD0)],
  ),
  ReadingPlan(
    id: 'nt-90',
    firstBook: 40,
    lastBook: 66,
    days: 90,
    icon: Icons.auto_stories_rounded,
    colors: [Color(0xFF0E2352), Color(0xFF0E7FA8)],
  ),
  ReadingPlan(
    id: 'gospels-30',
    firstBook: 40,
    lastBook: 43,
    days: 30,
    icon: Icons.favorite_rounded,
    colors: [Color(0xFF12306A), Color(0xFF3D5AFE)],
  ),
  ReadingPlan(
    id: 'psalms-30',
    firstBook: 19,
    lastBook: 19,
    days: 30,
    icon: Icons.music_note_rounded,
    colors: [Color(0xFF0B1D45), Color(0xFF2F78E8)],
  ),
  ReadingPlan(
    id: 'proverbs-31',
    firstBook: 20,
    lastBook: 20,
    days: 31,
    icon: Icons.lightbulb_rounded,
    colors: [Color(0xFF07304A), Color(0xFF00A3C4)],
  ),
  ReadingPlan(
    id: 'paul-30',
    firstBook: 45,
    lastBook: 57,
    days: 30,
    icon: Icons.mail_rounded,
    colors: [Color(0xFF101E42), Color(0xFF5A7BFF)],
  ),
  ReadingPlan(
    id: 'bible-90',
    firstBook: 1,
    lastBook: 66,
    days: 90,
    icon: Icons.bolt_rounded,
    colors: [Color(0xFF050B1C), Color(0xFF14336E)],
  ),
];

ReadingPlan? planById(String id) => readingPlans.where((p) => p.id == id).firstOrNull;

/// Splits [items] into [days] consecutive groups of similar total [weights].
///
/// Every day gets at least one item. After each day the target is worked out
/// again from what is left, so one very long item (Psalm 119) doesn't leave
/// the following days nearly empty.
List<List<T>> splitIntoDays<T>(List<T> items, List<int> weights, int days) {
  assert(items.length == weights.length);
  final n = items.length;
  if (n == 0 || days <= 0) return const [];
  final dayCount = days < n ? days : n;
  final result = <List<T>>[];
  var remaining = weights.fold<int>(0, (a, b) => a + b);
  var i = 0;
  for (var d = 0; d < dayCount; d++) {
    final daysLeft = dayCount - d;
    if (daysLeft == 1) {
      result.add(items.sublist(i));
      break;
    }
    final target = remaining / daysLeft;
    final day = <T>[items[i]];
    var sum = weights[i];
    i++;
    // Add the next chapter while that brings the day closer to the target,
    // always leaving at least one chapter for each remaining day.
    while (i < n - (daysLeft - 1) && (sum + weights[i] - target).abs() <= (sum - target).abs()) {
      day.add(items[i]);
      sum += weights[i];
      i++;
    }
    remaining -= sum;
    result.add(day);
  }
  return result;
}

/// Each day's chapters for a plan. Uses KJV verse counts so the schedule is
/// the same whichever translation is being read.
final planScheduleProvider = FutureProvider.family<List<List<PlanReading>>, String>((ref, planId) async {
  final plan = planById(planId);
  if (plan == null) return const [];
  final repo = ref.watch(bibleRepositoryProvider);

  var source = AppConstants.kjvTranslation;
  var books = await repo.books(source);
  if (books.isEmpty) {
    source = (await repo.translations()).first.id;
    books = await repo.books(source);
  }
  final counts = await repo.chapterVerseCounts(source);

  final readings = <PlanReading>[];
  final weights = <int>[];
  for (final b in books) {
    if (b.id < plan.firstBook || b.id > plan.lastBook) continue;
    for (var c = 1; c <= b.chapters; c++) {
      readings.add((bookId: b.id, chapter: c));
      weights.add(counts[(b.id, c)] ?? 25);
    }
  }
  return splitIntoDays(readings, weights, plan.days);
});

/// "ዘፍጥረት 1–3, ዘጸአት 1" — consecutive chapters of a book are joined.
String describeReadings(List<PlanReading> readings, Map<int, Book> books, {bool geez = false}) {
  final parts = <String>[];
  var i = 0;
  while (i < readings.length) {
    final start = readings[i];
    var end = start;
    while (i + 1 < readings.length &&
        readings[i + 1].bookId == start.bookId &&
        readings[i + 1].chapter == end.chapter + 1) {
      i++;
      end = readings[i];
    }
    final name = books[start.bookId]?.shortName ?? '${start.bookId}';
    final range = end.chapter == start.chapter ? '${start.chapter}' : '${start.chapter}–${end.chapter}';
    parts.add('$name ${geez ? geezifyDigits(range) : range}');
    i++;
  }
  return parts.join(', ');
}
