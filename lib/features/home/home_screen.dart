import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/utils/geez_numerals.dart';
import '../../core/utils/verse_clean.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/scene_image.dart';
import '../../core/widgets/scenic_background.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../devotions/devotions_screen.dart';
import '../onboarding/edit_name_dialog.dart';
import '../onboarding/profile_providers.dart';
import '../plans/plan_progress.dart';
import '../plans/reading_plans.dart';
import '../reader/reader_position.dart';
import '../settings/settings_providers.dart';
import '../share/share_image_screen.dart';
import 'verse_of_the_day.dart';

/// Home: hero image with greeting, Today's verse, plan spotlight,
/// shortcut tiles and quick access — on the ambient-light background.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = todaysVerseRef();
    final top = MediaQuery.paddingOf(context).top;
    final heroHeight = 290 + top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The top of the hero image is always dark sky: light status-bar icons.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            const Positioned.fill(child: AmbientBackground()),
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(height: heroHeight, child: const _HeroImage()),
                      Padding(
                        padding: EdgeInsets.fromLTRB(22, top + 22, 18, 0),
                        child: const _Greeting(),
                      ),
                      // The verse card overlaps the bottom of the image.
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, heroHeight - 96, 16, 0),
                        child: _TodaysVerseCard(verseRef: today),
                      ),
                    ],
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(child: _ActionGrid()),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(child: _PlanSpotlight()),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(child: DevotionSpotlight()),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 28),
                  sliver: SliverToBoxAdapter(child: _QuickAccess()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Hero
// --------------------------------------------------------------------------- //

class _HeroImage extends StatelessWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).colorScheme.surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        const SceneImage(AppImages.homeHero, fallback: SceneVariant.twilight, alignment: Alignment(0.35, 0)),
        // Darken the top for the greeting; fade the bottom into the page.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.0),
                background.withValues(alpha: 0.0),
                background.withValues(alpha: 0.85),
                background,
              ],
              stops: const [0, 0.35, 0.55, 0.88, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = ref.watch(userProfileProvider.select((p) => p.name));
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.goodMorning
        : hour < 17
            ? l10n.goodAfternoon
            : l10n.goodEvening;
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 12)];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 21, shadows: shadow)),
              Text(
                name.isEmpty ? l10n.welcomeTitle : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  shadows: shadow,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.homeTagline,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  letterSpacing: 0.4,
                  shadows: shadow,
                ),
              ),
            ],
          ),
        ),
        _Avatar(name: name),
      ],
    );
  }
}

/// Glass circle with the reader's initial and a glowing ring; tap to rename.
class _Avatar extends ConsumerWidget {
  const _Avatar({required this.name});

  final String name;

  Future<void> _editName(BuildContext context, WidgetRef ref) =>
      showEditNameDialog(context, ref, name);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = name.isEmpty ? '' : name.characters.first.toUpperCase();
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).editName,
      child: GestureDetector(
        onTap: () => _editName(context, ref),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xCC12306A), Color(0xCC0A1633)],
            ),
            border: Border.all(color: const Color(0xFF7FD3FF).withValues(alpha: 0.8), width: 1.5),
            boxShadow: [BoxShadow(color: const Color(0xFF5AA9FF).withValues(alpha: 0.55), blurRadius: 18)],
          ),
          child: initial.isEmpty
              ? const Icon(Icons.person_rounded, color: Colors.white, size: 28)
              : Text(initial, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Today's verse
// --------------------------------------------------------------------------- //

class _TodaysVerseCard extends ConsumerWidget {
  const _TodaysVerseCard({required this.verseRef});

  final VerseRef verseRef;

  Future<void> _shareImage(BuildContext context, WidgetRef ref, HomeVerse verse) async {
    final geez = ref.read(appSettingsProvider).geezNumerals;
    final translationId = ref.read(readerPositionProvider).translationId;
    final translation =
        (await ref.read(translationsProvider.future)).where((t) => t.id == translationId).firstOrNull;
    final reference = '${verse.book.shortName} ${verse.verse.ref.chapter}:${verse.verse.ref.verse}';
    if (!context.mounted) return;
    await openShareImage(
      context,
      text: cleanVerseText(verse.verse.text),
      reference: geez ? geezifyDigits(reference) : reference,
      translation: translation?.abbreviation ?? translationId,
      ethiopic: verse.ethiopic,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final verse = ref.watch(homeVerseProvider(verseRef)).valueOrNull;
    final geez = ref.watch(appSettingsProvider.select((s) => s.geezNumerals));
    final cv = '${verseRef.chapter}:${verseRef.verse}';
    final reference = verse == null ? '' : '${verse.book.shortName} ${geez ? geezifyDigits(cv) : cv}';

    void open() {
      openInReader(ref, bookId: verseRef.bookId, chapter: verseRef.chapter, verse: verseRef.verse);
      context.go(AppRoutes.read);
    }

    // Always deep blue with white text (both themes), like a lit glass panel.
    const ice = Color(0xFF8FD3FF);
    final shape = BorderRadius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E6BFF).withValues(alpha: 0.40), blurRadius: 34, offset: const Offset(0, 10)),
          BoxShadow(color: const Color(0xFF5AA9FF).withValues(alpha: 0.18), blurRadius: 8, spreadRadius: -2),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: open,
            borderRadius: shape,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: shape,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF123C82), Color(0xFF0B2559), Color(0xFF071735)],
                  stops: [0, 0.55, 1],
                ),
                border: Border.all(color: const Color(0xFF6FB6FF).withValues(alpha: 0.45), width: 1.2),
              ),
              child: Stack(
                children: [
                  // Light pooling on the right, behind a faint open book.
                  Positioned(
                    right: -70,
                    top: -30,
                    bottom: -60,
                    width: 260,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF3D8BFF).withValues(alpha: 0.55),
                            const Color(0xFF3D8BFF).withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Glassy sheen across the top edge.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: -6,
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 128,
                      color: const Color(0xFFB9DDFF).withValues(alpha: 0.13),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 21, color: ice),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.todaysVerse.toUpperCase(),
                                style: const TextStyle(
                                  color: ice,
                                  fontSize: 12.5,
                                  letterSpacing: 2.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (verse != null)
                              IconButton(
                                tooltip: l10n.shareAsImage,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.ios_share_rounded, size: 20, color: Colors.white.withValues(alpha: 0.7)),
                                onPressed: () => _shareImage(context, ref, verse),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            verse == null ? ' ' : '“${cleanVerseText(verse.verse.text)}”',
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: verse == null
                                ? null
                                : context.reading
                                    .verseStyle(ethiopic: verse.ethiopic, fontSize: 19, lineSpacing: 0.85)
                                    .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      shadows: const [Shadow(color: Color(0x663D8BFF), blurRadius: 12)],
                                    ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: ice,
                                boxShadow: [BoxShadow(color: ice.withValues(alpha: 0.8), blurRadius: 6)],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reference,
                                style: const TextStyle(color: ice, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                            _CardArrow(onTap: open),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White-rimmed glass circle with a chevron, for the blue verse card.
class _CardArrow extends StatelessWidget {
  const _CardArrow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.55), width: 1.2)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _GlowArrow extends StatelessWidget {
  const _GlowArrow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.14),
      shape: CircleBorder(side: BorderSide(color: scheme.primary.withValues(alpha: 0.5))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.chevron_right_rounded, color: scheme.primary, size: 28),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Plan spotlight
// --------------------------------------------------------------------------- //

/// The current reading plan with today's reading, or an invitation to start one.
class _PlanSpotlight extends ConsumerWidget {
  const _PlanSpotlight();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final geez = ref.watch(appSettingsProvider.select((s) => s.geezNumerals));
    final progress = ref.watch(planProgressProvider);
    final active = readingPlans.where((p) => progress.containsKey(p.id)).toList()
      ..sort((a, b) => progress[b.id]!.startedOn.compareTo(progress[a.id]!.startedOn));
    final plan = active.firstOrNull;

    String label, title, subtitle;
    VoidCallback onTap;
    if (plan == null) {
      label = l10n.readingPlans;
      title = l10n.startAPlan;
      subtitle = l10n.plansAvailable(readingPlans.length);
      onTap = () => context.push(AppRoutes.plans);
    } else {
      final p = progress[plan.id]!;
      final days = ref.watch(planScheduleProvider(plan.id)).valueOrNull;
      final total = days?.length ?? plan.days;
      final next = p.nextDay(total);
      final translationId = ref.watch(readerPositionProvider.select((r) => r.translationId));
      final books = {
        for (final b in ref.watch(booksProvider(translationId)).valueOrNull ?? const <Book>[]) b.id: b,
      };
      label = l10n.yourPlan;
      title = plan.title(l10n);
      subtitle = p.isFinished(total)
          ? l10n.planFinished
          : days == null || next >= days.length
              ? l10n.planDayOf(formatNumber(next + 1, geez: geez), formatNumber(total, geez: geez))
              : '${l10n.planDayN(formatNumber(next + 1, geez: geez))} · ${describeReadings(days[next], books, geez: geez)}';
      onTap = () => context.push(AppRoutes.plan(plan.id));
    }

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(width: 78, height: 78, child: SceneImage(AppImages.cardSunrise)),
          ),
          const SizedBox(width: 14),
          Container(
            width: 3,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: TextStyle(color: scheme.primary, fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _GlowArrow(onTap: onTap),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Shortcut tiles
// --------------------------------------------------------------------------- //

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tiles = <_Tile>[
      _Tile(Icons.auto_stories_rounded, l10n.homeRead, l10n.tileReadSub, const [Color(0xFF3B9BFF), Color(0xFF1A5FD0)],
          () => context.go(AppRoutes.read)),
      _Tile(Icons.event_note_rounded, l10n.homePlans, l10n.tilePlansSub, const [Color(0xFFA78BFA), Color(0xFF6D28D9)],
          () => context.push(AppRoutes.plans)),
      _Tile(Icons.menu_book_rounded, l10n.homeCommentary, l10n.tileCommentarySub,
          const [Color(0xFF2DD4BF), Color(0xFF0E7490)], () => context.go(AppRoutes.commentary)),
      _Tile(Icons.groups_rounded, l10n.homePeople, l10n.tilePeopleSub, const [Color(0xFF818CF8), Color(0xFF4338CA)],
          () => context.push(AppRoutes.people)),
      _Tile(Icons.map_rounded, l10n.homeMaps, l10n.tileMapsSub, const [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
          () => context.push(AppRoutes.maps)),
      _Tile(Icons.spa_rounded, l10n.homeDevotions, l10n.tileDevotionsSub, const [Color(0xFF4ADE80), Color(0xFF15803D)],
          () => context.push(AppRoutes.devotions)),
      _Tile(Icons.search_rounded, l10n.homeSearch, l10n.tileSearchSub, const [Color(0xFFFBBF24), Color(0xFFB45309)],
          () => context.push(AppRoutes.search)),
      _Tile(Icons.more_horiz_rounded, l10n.homeMore, l10n.tileMoreSub, const [Color(0xFF94A3B8), Color(0xFF334155)],
          () => context.go(AppRoutes.settings)),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final size = (box.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          // Width is fixed (4 per row); height follows the content, so tiles
          // never overflow on small phones or with large text.
          children: [for (final t in tiles) SizedBox(width: size, child: _TileView(tile: t))],
        );
      },
    );
  }
}

class _Tile {
  const _Tile(this.icon, this.label, this.subtitle, this.colors, this.onTap);

  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile});

  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
      onTap: tile.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tile.colors),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              boxShadow: [BoxShadow(color: tile.colors.first.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: -3)],
            ),
            child: Icon(tile.icon, size: 23, color: Colors.white),
          ),
          const SizedBox(height: 9),
          Text(
            tile.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.2, fontWeight: FontWeight.w700, color: scheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            tile.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, height: 1.2, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Quick access
// --------------------------------------------------------------------------- //

class _QuickAccess extends ConsumerWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pos = ref.watch(readerPositionProvider);
    final book = ref.watch(booksProvider(pos.translationId)).valueOrNull?.where((b) => b.id == pos.bookId).firstOrNull;
    final where = book == null ? '' : l10n.bookAndChapter(book.shortName, pos.chapter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(l10n.quickAccess, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                icon: Icons.play_circle_fill_rounded,
                title: l10n.continueReading,
                subtitle: where,
                onTap: () => context.go(AppRoutes.read),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                icon: Icons.bookmarks_rounded,
                title: l10n.navLibrary,
                subtitle: l10n.libraryShortcut,
                onTap: () => context.go(AppRoutes.library),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      radius: 22,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 28, shadows: [Shadow(color: scheme.primary, blurRadius: 12)]),
            const SizedBox(height: 14),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.onSurface)),
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
