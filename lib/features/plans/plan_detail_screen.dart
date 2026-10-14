import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/geez_numerals.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../reader/reader_position.dart';
import '../settings/settings_providers.dart';
import 'plan_progress.dart';
import 'plans_screen.dart';
import 'reading_plans.dart';

/// One plan: header with progress, then every day with a tick box.
class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  static const _rowHeight = 84.0;
  final _scroll = ScrollController();
  bool _scrolledToNext = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the list near the next day to read.
  void _scrollToNext(int nextDay) {
    if (_scrolledToNext || nextDay <= 0) return;
    _scrolledToNext = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = math.max(0.0, (nextDay - 1) * _rowHeight);
      _scroll.jumpTo(math.min(target, _scroll.position.maxScrollExtent));
    });
  }

  Future<bool> _confirm(String message, String action) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = planById(widget.planId);
    if (plan == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.event_busy_rounded, message: l10n.loadError));
    }
    final progress = ref.watch(planProgressProvider)[plan.id];
    final schedule = ref.watch(planScheduleProvider(plan.id));
    final notifier = ref.read(planProgressProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title(l10n)),
        actions: [
          if (progress != null)
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'restart' && await _confirm(l10n.planRestartConfirm, l10n.restartPlan)) {
                  await notifier.stop(plan.id);
                  await notifier.start(plan.id);
                } else if (action == 'stop' && await _confirm(l10n.stopPlanConfirm, l10n.stopPlan)) {
                  await notifier.stop(plan.id);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'restart', child: Text(l10n.restartPlan)),
                PopupMenuItem(value: 'stop', child: Text(l10n.stopPlan)),
              ],
            ),
        ],
      ),
      body: schedule.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline, message: l10n.loadError),
        data: (days) {
          if (progress != null) _scrollToNext(progress.nextDay(days.length));
          return CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(child: _PlanHeader(plan: plan, progress: progress, totalDays: days.length)),
              SliverFixedExtentList(
                itemExtent: _rowHeight,
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _DayRow(
                    plan: plan,
                    day: i,
                    readings: days[i],
                    progress: progress,
                    isNext: progress != null && !progress.isFinished(days.length) && progress.nextDay(days.length) == i,
                  ),
                  childCount: days.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _PlanHeader extends ConsumerWidget {
  const _PlanHeader({required this.plan, required this.progress, required this.totalDays});

  final ReadingPlan plan;
  final PlanProgress? progress;
  final int totalDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final geez = ref.watch(appSettingsProvider.select((s) => s.geezNumerals));
    final p = progress;
    const white70 = Color(0xB3FFFFFF);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: plan.colors),
        boxShadow: [BoxShadow(color: plan.colors.last.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlanBadge(plan: plan, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Text(plan.description(l10n),
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (p == null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF12306A)),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('${l10n.startPlan} · ${l10n.planDays(formatNumber(plan.days, geez: geez))}'),
                onPressed: () => ref.read(planProgressProvider.notifier).start(plan.id),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: totalDays == 0 ? 0 : p.done.length / totalDays,
                minHeight: 8,
                color: const Color(0xFF9FE6FF),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.isFinished(totalDays)
                        ? l10n.planFinished
                        : l10n.planDayOf(
                            formatNumber(p.nextDay(totalDays) + 1, geez: geez), formatNumber(totalDays, geez: geez)),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  l10n.planPercent(totalDays == 0 ? 0 : (p.done.length * 100 / totalDays).floor()),
                  style: const TextStyle(color: white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.startedOn(MaterialLocalizations.of(context).formatMediumDate(p.startedOn)),
              style: const TextStyle(color: white70, fontSize: 12.5),
            ),
            if (!p.isFinished(totalDays) && p.behind(totalDays) > 0) ...[
              const SizedBox(height: 4),
              Text(l10n.planBehind(p.behind(totalDays)), style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5)),
            ],
          ],
        ],
      ),
    );
  }
}

class _DayRow extends ConsumerWidget {
  const _DayRow({
    required this.plan,
    required this.day,
    required this.readings,
    required this.progress,
    required this.isNext,
  });

  final ReadingPlan plan;
  final int day;
  final List<PlanReading> readings;
  final PlanProgress? progress;
  final bool isNext;

  Future<void> _openDay(BuildContext context, WidgetRef ref, Map<int, Book> books, bool geez) {
    final l10n = AppLocalizations.of(context);
    final started = progress != null;
    final done = progress?.done.contains(day) ?? false;
    final screenContext = context;

    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.planDayN(formatNumber(day + 1, geez: geez))} · ${plan.title(l10n)}',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in readings)
                        ActionChip(
                          avatar: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                              '${books[r.bookId]?.shortName ?? r.bookId} ${formatNumber(r.chapter, geez: geez)}'),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            openInReader(ref, bookId: r.bookId, chapter: r.chapter);
                            screenContext.go(AppRoutes.read);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              if (started) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.tonalIcon(
                    icon: Icon(done ? Icons.remove_done_rounded : Icons.done_all_rounded),
                    label: Text(done ? l10n.markUnread : l10n.markRead),
                    onPressed: () {
                      ref.read(planProgressProvider.notifier).setDay(plan.id, day, done: !done);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final geez = ref.watch(appSettingsProvider.select((s) => s.geezNumerals));
    final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
    final books = {
      for (final b in ref.watch(booksProvider(translationId)).valueOrNull ?? const <Book>[]) b.id: b,
    };
    final started = progress != null;
    final done = progress?.done.contains(day) ?? false;

    return InkWell(
      onTap: () => _openDay(context, ref, books, geez),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: isNext ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? scheme.primary : Colors.transparent,
                border: Border.all(color: done || isNext ? scheme.primary : scheme.outline, width: isNext ? 2.5 : 1.5),
              ),
              child: done
                  ? Icon(Icons.check_rounded, color: scheme.onPrimary, size: 22)
                  : Text(formatNumber(day + 1, geez: geez),
                      style: TextStyle(fontWeight: FontWeight.w700, color: isNext ? scheme.primary : scheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.planDayN(formatNumber(day + 1, geez: geez)),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isNext ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    describeReadings(readings, books, geez: geez),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
            if (started)
              Checkbox(
                value: done,
                shape: const CircleBorder(),
                onChanged: (v) => ref.read(planProgressProvider.notifier).setDay(plan.id, day, done: v ?? false),
              ),
          ],
        ),
      ),
    );
  }
}
