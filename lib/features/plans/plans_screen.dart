import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/geez_numerals.dart';
import '../../core/widgets/glass.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../reader/reader_position.dart';
import '../settings/settings_providers.dart';
import 'plan_progress.dart';
import 'reading_plans.dart';

/// "My plans" (started) and the plans that can be started.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(planProgressProvider);
    final active = readingPlans.where((p) => progress.containsKey(p.id)).toList()
      ..sort((a, b) => progress[b.id]!.startedOn.compareTo(progress[a.id]!.startedOn));
    final others = readingPlans.where((p) => !progress.containsKey(p.id)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.readingPlans)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (active.isNotEmpty) ...[
            _SectionTitle(l10n.myPlans),
            for (final p in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActivePlanCard(plan: p, progress: progress[p.id]!),
              ),
            const SizedBox(height: 12),
          ],
          if (others.isNotEmpty) _SectionTitle(l10n.allPlans),
          for (final p in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlanCard(plan: p),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

/// Round gradient badge with the plan's icon.
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key, required this.plan, this.size = 48});

  final ReadingPlan plan;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: plan.colors),
          boxShadow: [BoxShadow(color: plan.colors.last.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: -2)],
        ),
        child: Icon(plan.icon, color: Colors.white, size: size * 0.5),
      );
}

/// A started plan: progress bar and the next day's reading.
class ActivePlanCard extends ConsumerWidget {
  const ActivePlanCard({super.key, required this.plan, required this.progress});

  final ReadingPlan plan;
  final PlanProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final geez = ref.watch(appSettingsProvider.select((s) => s.geezNumerals));
    final days = ref.watch(planScheduleProvider(plan.id)).valueOrNull;
    final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
    final books = {
      for (final b in ref.watch(booksProvider(translationId)).valueOrNull ?? const <Book>[]) b.id: b,
    };
    final total = days?.length ?? plan.days;
    final next = progress.nextDay(total);
    final finished = progress.isFinished(total);

    return GlassCard(
      onTap: () => context.push(AppRoutes.plan(plan.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlanBadge(plan: plan, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title(l10n),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      finished
                          ? l10n.planFinished
                          : l10n.planDayOf(formatNumber(next + 1, geez: geez), formatNumber(total, geez: geez)),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : progress.done.length / total,
              minHeight: 7,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          if (!finished && days != null && next < days.length) ...[
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${l10n.todaysReading}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: describeReadings(days[next], books, geez: geez)),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
          ],
        ],
      ),
    );
  }
}

/// A plan that hasn't been started yet.
class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});

  final ReadingPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final geez = ref.watch(appSettingsProvider.select((s) => s.geezNumerals));
    final radius = BorderRadius.circular(24);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [BoxShadow(color: plan.colors.last.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push(AppRoutes.plan(plan.id)),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: plan.colors),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)),
                      child: Icon(plan.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.title(l10n),
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(plan.description(l10n),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13.5, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(l10n.planDays(formatNumber(plan.days, geez: geez)),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF12306A),
                      ),
                      onPressed: () async {
                        await ref.read(planProgressProvider.notifier).start(plan.id);
                        if (context.mounted) context.push(AppRoutes.plan(plan.id));
                      },
                      child: Text(l10n.startPlan),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
