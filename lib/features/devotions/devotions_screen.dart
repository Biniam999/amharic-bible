import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/utils/geez_numerals.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/scene_image.dart';
import '../../core/widgets/scenic_background.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../reader/reader_position.dart';
import '../settings/settings_providers.dart';
import '../share/share_image_screen.dart';
import 'devotions_data.dart';

/// Pages are laid out on a leap year so 29 February has a reading too.
const _leapYear = 2024;
const _dayCount = 366;

int _indexOf(int month, int day) =>
    DateTime.utc(_leapYear, month, day).difference(DateTime.utc(_leapYear)).inDays;

DateTime _dateOf(int index) => DateTime.utc(_leapYear).add(Duration(days: index));

int _todayIndex() {
  final now = DateTime.now();
  return _indexOf(now.month, now.day);
}

/// "13 October" in the app language (Ge'ez digits when chosen).
String _formatDay(BuildContext context, int month, int day, {required bool geez}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  String text;
  try {
    text = DateFormat.MMMMd(locale).format(DateTime(_leapYear, month, day));
  } catch (_) {
    text = DateFormat.MMMMd().format(DateTime(_leapYear, month, day));
  }
  return geez ? geezifyDigits(text) : text;
}

/// Daily devotions: swipe between days, Morning / Evening in the floating
/// pill, calendar to jump to any day.
class DevotionsScreen extends ConsumerStatefulWidget {
  const DevotionsScreen({super.key});

  @override
  ConsumerState<DevotionsScreen> createState() => _DevotionsScreenState();
}

class _DevotionsScreenState extends ConsumerState<DevotionsScreen> {
  late final PageController _controller;
  late final ValueNotifier<int> _page;
  DevotionPeriod _period = currentPeriod();

  @override
  void initState() {
    super.initState();
    final today = _todayIndex();
    _controller = PageController(initialPage: today);
    _page = ValueNotifier(today);
  }

  @override
  void dispose() {
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final i = index.clamp(0, _dayCount - 1);
    if ((i - _page.value).abs() > 1) {
      _controller.jumpToPage(i);
    } else {
      _controller.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final shown = _dateOf(_page.value);
    final isLeap = DateTime(now.year, 2, 29).month == 2;
    final day = shown.month == 2 && shown.day == 29 && !isLeap ? 28 : shown.day;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, shown.month, day),
      firstDate: DateTime(now.year),
      lastDate: DateTime(now.year, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && mounted) _goTo(_indexOf(picked.month, picked.day));
  }

  Future<void> _share(DevotionalBook book) async {
    final d = _dateOf(_page.value);
    final dev = book.reading(d.month, d.day, _period);
    if (dev == null) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: '“${dev.keyVerse}” — ${dev.reference}\n\n${dev.plainText}\n\n— ${book.author}, ${book.title}',
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bookAsync = ref.watch(currentDevotionalProvider);
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: AmbientBackground()),
            bookAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(l10n.noDevotion)),
              data: (book) => PageView.builder(
                controller: _controller,
                itemCount: _dayCount,
                onPageChanged: (i) => _page.value = i,
                itemBuilder: (context, i) {
                  final d = _dateOf(i);
                  return _DevotionPage(
                    key: ValueKey('$i-${_period.name}'),
                    book: book,
                    month: d.month,
                    day: d.day,
                    period: _period,
                    isToday: i == _todayIndex(),
                  );
                },
              ),
            ),
            // Floating glass controls over the hero picture.
            Positioned(
              top: top + 8,
              left: 12,
              right: 12,
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (context, page, _) => Row(
                  children: [
                    _GlassCircle(
                      icon: Icons.arrow_back_rounded,
                      tooltip: l10n.back,
                      onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
                    ),
                    const Spacer(),
                    if (page != _todayIndex()) ...[
                      _GlassCircle(
                        icon: Icons.today_rounded,
                        tooltip: l10n.today,
                        onTap: () => _goTo(_todayIndex()),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _GlassCircle(icon: Icons.calendar_month_rounded, tooltip: l10n.chooseDay, onTap: _pickDay),
                    const SizedBox(width: 8),
                    _GlassCircle(
                      icon: Icons.ios_share_rounded,
                      tooltip: l10n.share,
                      onTap: () {
                        final book = bookAsync.valueOrNull;
                        if (book != null) _share(book);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _page,
                  builder: (context, page, _) => _DevotionHud(
                    period: _period,
                    showPeriods: bookAsync.valueOrNull?.hasEvening ?? true,
                    onPrevious: page > 0 ? () => _goTo(page - 1) : null,
                    onNext: page < _dayCount - 1 ? () => _goTo(page + 1) : null,
                    onPeriod: (p) => setState(() => _period = p),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// One day
// --------------------------------------------------------------------------- //

class _DevotionPage extends ConsumerWidget {
  const _DevotionPage({
    super.key,
    required this.book,
    required this.month,
    required this.day,
    required this.period,
    required this.isToday,
  });

  final DevotionalBook book;
  final int month;
  final int day;
  final DevotionPeriod period;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final dev = book.reading(month, day, period);
    final top = MediaQuery.paddingOf(context).top;

    final body = context.reading.verseStyle(
      ethiopic: book.isEthiopic,
      fontSize: settings.fontSize * 0.94,
      lineSpacing: settings.lineSpacing,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Hero(
            height: 250 + top,
            period: book.hasEvening ? period : null,
            date: _formatDay(context, month, day, geez: settings.geezNumerals),
            isToday: isToday,
          ),
        ),
        if (dev == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Center(
                child: Text(l10n.noDevotion, style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _KeyVerseCard(book: book, devotion: dev)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 110),
            sliver: SliverToBoxAdapter(
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, p) in dev.paragraphs.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: i == 0 ? _DropCapParagraph(text: p, style: body) : Text(p, style: body),
                      ),
                    const SizedBox(height: 6),
                    Center(child: _Ornament(color: scheme.primary)),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        '${book.author} · ${book.title}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, letterSpacing: 0.4),
                      ),
                    ),
                    if (book.language != Localizations.localeOf(context).languageCode) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          l10n.devotionLanguageNote,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 11.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Picture with the date and "Morning reading" / "Evening reading".
class _Hero extends StatelessWidget {
  const _Hero({required this.height, required this.period, required this.date, required this.isToday});

  final double height;

  /// Null when the book has a single reading a day.
  final DevotionPeriod? period;
  final String date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF020409) : const Color(0xFFF7FAFF);
    final evening = period == DevotionPeriod.evening;
    final label = switch (period) {
      DevotionPeriod.morning => l10n.morningReading,
      DevotionPeriod.evening => l10n.eveningReading,
      null => l10n.homeDevotions,
    };

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: SceneImage(
              evening ? AppImages.homeHero : AppImages.cardSunrise,
              key: ValueKey(evening),
              fallback: evening ? SceneVariant.night : SceneVariant.dawn,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.25),
                  base,
                ],
                stops: const [0, 0.35, 0.72, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      period == null
                          ? Icons.spa_rounded
                          : evening
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_rounded,
                      size: 15,
                      color: const Color(0xFF7FD3FF),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF7FD3FF),
                          fontSize: 11.5,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          l10n.today,
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 18)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The day's verse, glowing; tap the reference to open it in the reader.
class _KeyVerseCard extends ConsumerWidget {
  const _KeyVerseCard({required this.book, required this.devotion});

  final DevotionalBook book;
  final Devotion devotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(appSettingsProvider);
    final reading = context.reading;
    final verse = devotion.verse;

    final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
    final translation = ref
        .watch(translationsProvider)
        .valueOrNull
        ?.where((t) => t.id == translationId)
        .firstOrNull;
    // Show the verse from the reader's own Bible when it's in another language.
    String? mine;
    Book? myBook;
    if (verse != null && translation != null && translation.isEthiopic != book.isEthiopic) {
      mine = ref.watch(devotionBibleVerseProvider((verse: verse, translationId: translationId))).valueOrNull;
      myBook = ref.watch(booksProvider(translationId)).valueOrNull?.where((b) => b.id == verse.bookId).firstOrNull;
    }

    void open() {
      if (verse == null) return;
      openInReader(ref, bookId: verse.bookId, chapter: verse.chapter, verse: verse.verse);
      context.go(AppRoutes.read);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (dark) BoxShadow(color: scheme.primary.withValues(alpha: 0.28), blurRadius: 34, spreadRadius: -6),
        ],
      ),
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote_rounded, color: scheme.primary, size: 28),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                devotion.keyVerse,
                style: reading
                    .verseStyle(ethiopic: book.isEthiopic, fontSize: settings.fontSize * 1.12)
                    .copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: scheme.onSurface),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: _RefPill(
                    label: devotion.reference,
                    tooltip: l10n.readPassage,
                    onTap: verse == null ? null : open,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.shareAsImage,
                  icon: Icon(Icons.image_outlined, color: scheme.primary),
                  onPressed: () => openShareImage(
                    context,
                    text: devotion.keyVerse,
                    reference: devotion.reference,
                    translation: book.title,
                    ethiopic: book.isEthiopic,
                  ),
                ),
              ],
            ),
            if (mine != null && mine.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10, right: 6),
                child: Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              Text(
                [
                  l10n.inYourBible,
                  if (myBook != null)
                    '${myBook.shortName} ${settings.geezNumerals ? geezifyDigits('${verse!.chapter}:${verse.verse}') : '${verse!.chapter}:${verse.verse}'}',
                ].join(' · ').toUpperCase(),
                style: TextStyle(color: scheme.primary, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: Text(
                  mine,
                  style: reading.verseStyle(ethiopic: translation!.isEthiopic, fontSize: settings.fontSize * 0.92),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RefPill extends StatelessWidget {
  const _RefPill({required this.label, required this.tooltip, required this.onTap});

  final String label;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: StadiumBorder(side: BorderSide(color: scheme.primary.withValues(alpha: 0.45))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18, color: scheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First paragraph with a large, glowing initial.
class _DropCapParagraph extends StatelessWidget {
  const _DropCapParagraph({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chars = text.characters;
    if (chars.isEmpty) return const SizedBox.shrink();
    // Keep an opening quote mark with the letter that follows it.
    var n = 1;
    if (chars.length > 1 && '"\'“‘'.contains(chars.first)) n = 2;
    final cap = chars.take(n).toString();
    final rest = chars.skip(n).toString();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: cap,
            style: style.copyWith(
              fontSize: (style.fontSize ?? 17) * 1.7,
              height: 1,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
              shadows: [Shadow(color: scheme.primary.withValues(alpha: 0.5), blurRadius: 14)],
            ),
          ),
          TextSpan(text: rest),
        ],
      ),
      style: style,
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Container(
          width: 46,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: left ? [color.withValues(alpha: 0), color] : [color, color.withValues(alpha: 0)],
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.auto_awesome_rounded, size: 14, color: color),
        ),
        line(false),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
// Floating controls
// --------------------------------------------------------------------------- //

/// Glass pill:  ‹  [☀ Morning | ☾ Evening]  ›
class _DevotionHud extends StatelessWidget {
  const _DevotionHud({
    required this.period,
    required this.showPeriods,
    required this.onPrevious,
    required this.onNext,
    required this.onPeriod,
  });

  final DevotionPeriod period;
  final bool showPeriods;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<DevotionPeriod> onPeriod;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF0A1633);

    Widget arrow(IconData icon, String tip, VoidCallback? onTap) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, color: onTap == null ? fg.withValues(alpha: 0.3) : fg),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.85),
            border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFCFDDF5)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.5 : 0.12), blurRadius: 24)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              arrow(Icons.chevron_left_rounded, l10n.previousDay, onPrevious),
              if (showPeriods) ...[
                _PeriodChip(
                  icon: Icons.wb_sunny_rounded,
                  label: l10n.morning,
                  selected: period == DevotionPeriod.morning,
                  onTap: () => onPeriod(DevotionPeriod.morning),
                ),
                const SizedBox(width: 4),
                _PeriodChip(
                  icon: Icons.nightlight_round,
                  label: l10n.evening,
                  selected: period == DevotionPeriod.evening,
                  onTap: () => onPeriod(DevotionPeriod.evening),
                ),
              ],
              arrow(Icons.chevron_right_rounded, l10n.nextDay, onNext),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF0A1633).withValues(alpha: 0.7);
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: selected
                ? const LinearGradient(colors: [Color(0xFF1E88FF), Color(0xFF2B5CE6)])
                : null,
            boxShadow: selected
                ? [BoxShadow(color: const Color(0xFF1E88FF).withValues(alpha: 0.55), blurRadius: 16, spreadRadius: -2)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: selected ? Colors.white : idle),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : idle,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.black.withValues(alpha: 0.28),
            shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.22))),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 21)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small card for the home screen: today's devotion at a glance.
class DevotionSpotlight extends ConsumerWidget {
  const DevotionSpotlight({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final book = ref.watch(currentDevotionalProvider).valueOrNull;
    final now = DateTime.now();
    final period = currentPeriod(now);
    final dev = book?.reading(now.month, now.day, period);
    if (book == null || dev == null) return const SizedBox.shrink();
    final evening = book.hasEvening && period == DevotionPeriod.evening;

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      onTap: () => context.push(AppRoutes.devotions),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: evening
                    ? const [Color(0xFF818CF8), Color(0xFF312E81)]
                    : const [Color(0xFFFBBF24), Color(0xFFEA580C)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (evening ? const Color(0xFF818CF8) : const Color(0xFFFBBF24)).withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Icon(evening ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.todaysDevotion} · ${evening ? l10n.evening : l10n.morning}'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.primary, fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '“${dev.keyVerse}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dev.reference} · ${book.author}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.primary),
        ],
      ),
    );
  }
}
