import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/geez_numerals.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/glass.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../reader/reader_position.dart';
import '../settings/settings_providers.dart';
import 'commentary_repository.dart';

// --------------------------------------------------------------------------- //
// Data
// --------------------------------------------------------------------------- //

final commentarySourcesProvider =
    FutureProvider<List<CommentarySource>>((ref) => CommentaryRepository.instance.sources());

typedef _ChapterKey = ({String source, int bookId, int chapter});

/// Chapter overview and all notes of one source for one chapter.
final _commentaryChapterProvider = FutureProvider.autoDispose
    .family<({String? intro, List<CommentaryNote> notes}), _ChapterKey>((ref, key) async {
  final repo = CommentaryRepository.instance;
  final book = CommentaryRepository.toUsfm(key.bookId);
  final results = await Future.wait<Object?>([
    repo.chapterIntro(key.source, book, key.chapter),
    repo.notesForChapter(key.source, book, key.chapter),
  ]);
  return (intro: results[0] as String?, notes: results[1] as List<CommentaryNote>);
});

final _bookIntroProvider = FutureProvider.autoDispose.family<String?, ({String source, int bookId})>(
  (ref, key) => CommentaryRepository.instance.bookIntro(key.source, CommentaryRepository.toUsfm(key.bookId)),
);

/// Commentary verse numbering follows the KJV.
final _kjvVerseCountProvider = FutureProvider.autoDispose.family<int, ({int bookId, int chapter})>(
  (ref, key) =>
      ref.watch(bibleRepositoryProvider).verseCount(AppConstants.kjvTranslation, key.bookId, key.chapter),
);

// --------------------------------------------------------------------------- //
// Screen
// --------------------------------------------------------------------------- //

/// Commentary tab: choose a commentary, then book, chapter and verse; the
/// chapter's notes are listed and the note covering the chosen verse glows.
class CommentaryScreen extends ConsumerStatefulWidget {
  const CommentaryScreen({super.key});

  @override
  ConsumerState<CommentaryScreen> createState() => _CommentaryScreenState();
}

class _CommentaryScreenState extends ConsumerState<CommentaryScreen> {
  final _scroll = ScrollController();
  final _noteKeys = <int, GlobalKey>{};
  String? _source;
  late int _bookId;
  late int _chapter;
  int? _verse;

  @override
  void initState() {
    super.initState();
    // Start where the reader is.
    final pos = ref.read(readerPositionProvider);
    _bookId = pos.bookId;
    _chapter = pos.chapter;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setChapter(int bookId, int chapter) {
    setState(() {
      _bookId = bookId;
      _chapter = chapter;
      _verse = null;
      _noteKeys.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Selects [verse] and scrolls to the note that covers it.
  void _selectVerse(int verse, List<CommentaryNote> notes) {
    setState(() => _verse = verse);
    final covering = _coveringNote(notes, verse);
    if (covering == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _noteKeys[covering.fromVerse]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
    });
  }

  static CommentaryNote? _coveringNote(List<CommentaryNote> notes, int verse) {
    CommentaryNote? found;
    for (final n in notes) {
      if (n.fromVerse <= verse) found = n;
    }
    return found;
  }

  Future<void> _pickBook(List<Book> books) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookSheet(books: books, selected: _bookId),
    );
    if (picked != null && mounted) _setChapter(picked, 1);
  }

  Future<void> _pickNumber({required String title, required int count, required int? selected,
      Set<int> marked = const {}, required ValueChanged<int> onPicked}) async {
    final geez = ref.read(appSettingsProvider).geezNumerals;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NumberSheet(title: title, count: count, selected: selected, marked: marked, geez: geez),
    );
    if (picked != null && mounted) onPicked(picked);
  }

  Future<void> _showBookIntro(String title, String text) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _EnglishText(text),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final geez = ref.watch(appSettingsProvider.select((s) => s.geezNumerals));
    final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
    final books = ref.watch(booksProvider(translationId)).valueOrNull ?? const <Book>[];
    final book = books.where((b) => b.id == _bookId).firstOrNull;

    final sourcesAsync = ref.watch(commentarySourcesProvider);
    final sources = sourcesAsync.valueOrNull ?? const <CommentarySource>[];
    final source = sources.where((s) => s.id == _source).firstOrNull ?? sources.firstOrNull;

    final chapterAsync = source == null
        ? null
        : ref.watch(_commentaryChapterProvider((source: source.id, bookId: _bookId, chapter: _chapter)));
    final notes = chapterAsync?.valueOrNull?.notes ?? const <CommentaryNote>[];
    final intro = chapterAsync?.valueOrNull?.intro;
    final verseCount = ref.watch(_kjvVerseCountProvider((bookId: _bookId, chapter: _chapter))).valueOrNull ?? 0;
    final bookIntro =
        source == null ? null : ref.watch(_bookIntroProvider((source: source.id, bookId: _bookId))).valueOrNull;
    final noteStarts = {for (final n in notes) n.fromVerse};
    final covering = _verse == null ? null : _coveringNote(notes, _verse!);

    String num(int n) => formatNumber(n, geez: geez);
    final bookName = book?.shortName ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: AmbientBackground()),
            CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.commentary,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                    shadows: [Shadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 18)],
                                  ),
                                ),
                                if (source != null)
                                  Text(source.name,
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (bookIntro != null && bookIntro.trim().isNotEmpty)
                            IconButton.filledTonal(
                              tooltip: l10n.bookIntroduction,
                              icon: const Icon(Icons.info_outline_rounded),
                              onPressed: () => _showBookIntro('${l10n.bookIntroduction} · $bookName', bookIntro),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (sources.length > 1)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SourceSwitch(
                        sources: sources,
                        selected: source?.id,
                        onSelected: (id) => setState(() {
                          _source = id;
                          _noteKeys.clear();
                        }),
                      ),
                    ),
                  ),
                // Book · chapter · verse selector.
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: GlassCard(
                      radius: 22,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _SelectorButton(
                                  icon: Icons.menu_book_rounded,
                                  label: bookName.isEmpty ? l10n.pickerBook : bookName,
                                  onTap: books.isEmpty ? null : () => _pickBook(books),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: _SelectorButton(
                                  label: '${l10n.pickerChapter} ${num(_chapter)}',
                                  onTap: book == null
                                      ? null
                                      : () => _pickNumber(
                                            title: bookName,
                                            count: book.chapters,
                                            selected: _chapter,
                                            onPicked: (c) => _setChapter(_bookId, c),
                                          ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: _SelectorButton(
                                  label: _verse == null ? l10n.pickerVerse : '${l10n.pickerVerse} ${num(_verse!)}',
                                  onTap: verseCount == 0
                                      ? null
                                      : () => _pickNumber(
                                            title: '$bookName ${num(_chapter)}',
                                            count: verseCount,
                                            selected: _verse,
                                            marked: noteStarts,
                                            onPicked: (v) => _selectVerse(v, notes),
                                          ),
                                ),
                              ),
                            ],
                          ),
                          if (verseCount > 0) ...[
                            const SizedBox(height: 10),
                            _VerseStrip(
                              count: verseCount,
                              selected: _verse,
                              marked: noteStarts,
                              geez: geez,
                              onTap: (v) => _selectVerse(v, notes),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (sourcesAsync.hasError || (chapterAsync?.hasError ?? false))
                  _Message(l10n.commentaryUnavailable)
                else if (chapterAsync == null || chapterAsync.isLoading)
                  const SliverPadding(
                    padding: EdgeInsets.all(40),
                    sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                  )
                else if (notes.isEmpty && (intro == null || intro.trim().isEmpty))
                  _Message(l10n.noChapterCommentary)
                else ...[
                  if (intro != null && intro.trim().isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _OverviewCard(title: '${l10n.chapterOverview} · $bookName ${num(_chapter)}', text: intro),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    sliver: SliverList.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, i) {
                        final n = notes[i];
                        final end = i + 1 < notes.length ? notes[i + 1].fromVerse - 1 : verseCount;
                        final label = end > n.fromVerse
                            ? l10n.commentaryVerses(num(n.fromVerse), num(end))
                            : l10n.commentaryVerse(num(n.fromVerse));
                        return Padding(
                          key: _noteKeys.putIfAbsent(n.fromVerse, GlobalKey.new),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NoteCard(
                            label: '$bookName ${num(_chapter)} · $label',
                            text: n.text,
                            lit: identical(n, covering),
                            readLabel: l10n.readPassage,
                            onRead: () {
                              openInReader(ref, bookId: _bookId, chapter: _chapter, verse: n.fromVerse);
                              context.go(AppRoutes.read);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Pieces
// --------------------------------------------------------------------------- //

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 48),
        sliver: SliverToBoxAdapter(
          child: Column(
            children: [
              Icon(Icons.history_edu_rounded, size: 44, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}

/// The commentaries are English: always left-to-right, selectable.
class _EnglishText extends StatelessWidget {
  const _EnglishText(this.text, {this.maxLines});

  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 16);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: maxLines == null
          ? SelectableText(text, style: style)
          : Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SourceSwitch extends StatelessWidget {
  const _SourceSwitch({required this.sources, required this.selected, required this.onSelected});

  final List<CommentarySource> sources;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF0A1633).withValues(alpha: 0.7);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.85),
            border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFCFDDF5)),
          ),
          child: Row(
            children: [
              for (final s in sources)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelected(s.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: s.id == selected
                            ? const LinearGradient(colors: [Color(0xFF1E88FF), Color(0xFF2B5CE6)])
                            : null,
                        boxShadow: s.id == selected
                            ? [BoxShadow(color: const Color(0xFF1E88FF).withValues(alpha: 0.5), blurRadius: 14, spreadRadius: -2)]
                            : null,
                      ),
                      child: Text(
                        s.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: s.id == selected ? Colors.white : idle,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.10),
      shape: StadiumBorder(side: BorderSide(color: scheme.primary.withValues(alpha: 0.35))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: scheme.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 20, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of verse numbers; verses where a note begins have a dot.
class _VerseStrip extends StatelessWidget {
  const _VerseStrip({
    required this.count,
    required this.selected,
    required this.marked,
    required this.geez,
    required this.onTap,
  });

  final int count;
  final int? selected;
  final Set<int> marked;
  final bool geez;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final v = i + 1;
          final isSelected = v == selected;
          return GestureDetector(
            onTap: () => onTap(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected ? const LinearGradient(colors: [Color(0xFF1E88FF), Color(0xFF2B5CE6)]) : null,
                color: isSelected ? null : scheme.primary.withValues(alpha: 0.07),
                border: Border.all(
                  color: isSelected ? Colors.transparent : scheme.primary.withValues(alpha: marked.contains(v) ? 0.5 : 0.15),
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF1E88FF).withValues(alpha: 0.55), blurRadius: 12, spreadRadius: -2)]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    formatNumber(v, geez: geez),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : scheme.onSurface,
                    ),
                  ),
                  if (marked.contains(v) && !isSelected)
                    Positioned(
                      bottom: 5,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatefulWidget {
  const _OverviewCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  State<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<_OverviewCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(color: scheme.primary, fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: _EnglishText(widget.text, maxLines: _open ? null : 4),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text(_open ? l10n.showLess : l10n.showMore),
            ),
          ),
        ],
      ),
    );
  }
}

/// One note; [lit] = it covers the chosen verse (glowing outline).
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.label,
    required this.text,
    required this.lit,
    required this.readLabel,
    required this.onRead,
  });

  final String label;
  final String text;
  final bool lit;
  final String readLabel;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: lit ? scheme.primary : Colors.transparent, width: 1.4),
        boxShadow: lit
            ? [BoxShadow(color: scheme.primary.withValues(alpha: dark ? 0.45 : 0.25), blurRadius: 22, spreadRadius: -4)]
            : null,
      ),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 10, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.7), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                TextButton.icon(
                  onPressed: onRead,
                  icon: const Icon(Icons.menu_book_rounded, size: 17),
                  label: Text(readLabel),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.only(right: 10), child: _EnglishText(text)),
          ],
        ),
      ),
    );
  }
}

class _BookSheet extends StatelessWidget {
  const _BookSheet({required this.books, required this.selected});

  final List<Book> books;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget section(String title, Iterable<Book> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(color: scheme.primary, fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w700),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in list)
                  ChoiceChip(
                    label: Text(b.shortName),
                    selected: b.id == selected,
                    onSelected: (_) => Navigator.pop(context, b.id),
                  ),
              ],
            ),
          ],
        );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          section(l10n.oldTestament, books.where((b) => b.id < AppConstants.firstNtBookId)),
          const SizedBox(height: 8),
          section(l10n.newTestament, books.where((b) => b.id >= AppConstants.firstNtBookId)),
        ],
      ),
    );
  }
}

class _NumberSheet extends StatelessWidget {
  const _NumberSheet({
    required this.title,
    required this.count,
    required this.selected,
    required this.marked,
    required this.geez,
  });

  final String title;
  final int count;
  final int? selected;
  final Set<int> marked;
  final bool geez;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: count > 40 ? 0.7 : 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => CustomScrollView(
        controller: controller,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 64,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: count,
              itemBuilder: (context, i) {
                final n = i + 1;
                final isSelected = n == selected;
                return Material(
                  color: isSelected ? scheme.primary : scheme.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: scheme.primary.withValues(alpha: marked.contains(n) ? 0.6 : 0.2)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, n),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          formatNumber(n, geez: geez),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isSelected ? scheme.onPrimary : scheme.onSurface,
                          ),
                        ),
                        if (marked.contains(n) && !isSelected)
                          Positioned(
                            bottom: 7,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
