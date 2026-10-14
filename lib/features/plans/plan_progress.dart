import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';

/// Progress in one reading plan. Days are numbered from 0.
@immutable
class PlanProgress {
  const PlanProgress({required this.planId, required this.startedOn, this.done = const {}});

  final String planId;

  /// Local date the plan was started (time ignored).
  final DateTime startedOn;
  final Set<int> done;

  /// The day the schedule says to read today (0-based, within the plan).
  int scheduledDay(int totalDays, [DateTime? now]) {
    final today = _dateOnly(now ?? DateTime.now());
    final days = today.difference(_dateOnly(startedOn)).inDays;
    return days.clamp(0, totalDays - 1);
  }

  /// First day not yet read, or the last day when everything is read.
  int nextDay(int totalDays) {
    for (var d = 0; d < totalDays; d++) {
      if (!done.contains(d)) return d;
    }
    return totalDays - 1;
  }

  bool isFinished(int totalDays) => done.length >= totalDays;

  /// Days that should have been read by now but weren't.
  int behind(int totalDays, [DateTime? now]) {
    final due = scheduledDay(totalDays, now);
    var missed = 0;
    for (var d = 0; d < due; d++) {
      if (!done.contains(d)) missed++;
    }
    return missed;
  }

  PlanProgress copyWith({Set<int>? done}) =>
      PlanProgress(planId: planId, startedOn: startedOn, done: done ?? this.done);

  Map<String, Object> toJson() => {
        'start': '${startedOn.year}-${startedOn.month}-${startedOn.day}',
        'done': (done.toList()..sort()),
      };

  static PlanProgress? fromJson(String planId, Object? json) {
    if (json is! Map) return null;
    final parts = '${json['start']}'.split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.contains(null)) return null;
    final done = json['done'];
    return PlanProgress(
      planId: planId,
      startedOn: DateTime(parts[0]!, parts[1]!, parts[2]!),
      done: {if (done is List) ...done.whereType<int>()},
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}

/// Plans the reader has started (plan id → progress), saved on the phone.
class PlanProgressNotifier extends Notifier<Map<String, PlanProgress>> {
  static const _key = 'plans.progress';

  @override
  Map<String, PlanProgress> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          if (PlanProgress.fromJson(e.key, e.value) case final p?) e.key: p,
      };
    } on FormatException {
      return const {};
    } on TypeError {
      return const {};
    }
  }

  Future<void> start(String planId) =>
      _save({...state, planId: PlanProgress(planId: planId, startedOn: DateTime.now())});

  Future<void> stop(String planId) => _save({...state}..remove(planId));

  Future<void> setDay(String planId, int day, {required bool done}) async {
    final p = state[planId];
    if (p == null) return;
    final days = {...p.done};
    if (done) {
      days.add(day);
    } else {
      days.remove(day);
    }
    await _save({...state, planId: p.copyWith(done: days)});
  }

  Future<void> _save(Map<String, PlanProgress> next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setString(
          _key,
          jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}),
        );
  }
}

final planProgressProvider =
    NotifierProvider<PlanProgressNotifier, Map<String, PlanProgress>>(PlanProgressNotifier.new);
