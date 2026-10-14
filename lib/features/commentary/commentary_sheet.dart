import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'commentary_repository.dart';

/// Opens the commentary for one verse as a draggable bottom sheet.
///
/// [book] is a USFM code ('JHN'); convert the app's 1–66 book ids with
/// [CommentaryRepository.toUsfm].
Future<void> showCommentarySheet(
  BuildContext context, {
  required String book,
  required int chapter,
  required int verse,
  required String reference,
  String? verseText,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, controller) => _CommentaryView(
        book: book,
        chapter: chapter,
        verse: verse,
        reference: reference,
        verseText: verseText,
        scrollController: controller,
      ),
    ),
  );
}

class _CommentaryView extends StatefulWidget {
  final String book;
  final int chapter;
  final int verse;
  final String reference;
  final String? verseText;
  final ScrollController scrollController;

  const _CommentaryView({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.reference,
    required this.verseText,
    required this.scrollController,
  });

  @override
  State<_CommentaryView> createState() => _CommentaryViewState();
}

class _CommentaryViewState extends State<_CommentaryView> {
  final _repo = CommentaryRepository.instance;
  late final Future<List<CommentarySource>> _sources = _repo.sources();
  String? _selected;
  Future<CommentaryNote?>? _note;

  void _select(String id) {
    _selected = id;
    _note = _repo.noteFor(id, widget.book, widget.chapter, widget.verse);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return FutureBuilder<List<CommentarySource>>(
      future: _sources,
      builder: (context, sourcesSnap) {
        final sources = sourcesSnap.data ?? const <CommentarySource>[];
        if (_selected == null && sources.isNotEmpty) _select(sources.first.id);
        final source = sources.where((s) => s.id == _selected).firstOrNull;

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text('${l10n.commentary} · ${widget.reference}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (widget.verseText != null) ...[
              const SizedBox(height: 8),
              Text(widget.verseText!,
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: muted)),
            ],
            const SizedBox(height: 14),
            if (sources.length > 1)
              Wrap(
                spacing: 8,
                children: [
                  for (final s in sources)
                    ChoiceChip(
                      label: Text(s.shortName),
                      selected: s.id == _selected,
                      onSelected: (_) => setState(() => _select(s.id)),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            if (sourcesSnap.hasError)
              Text(l10n.commentaryUnavailable, style: theme.textTheme.bodyMedium?.copyWith(color: muted))
            else
              FutureBuilder<CommentaryNote?>(
                future: _note,
                builder: (context, snap) {
                  if (_note == null || snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Text(l10n.commentaryUnavailable,
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted));
                  }
                  final note = snap.data;
                  if (note == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(l10n.commentaryEmpty,
                          style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.fromVerse != widget.verse)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(l10n.commentaryFromVerse(note.fromVerse),
                              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                        ),
                      // The commentaries are English: always left-to-right.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: SelectableText(note.text,
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
                      ),
                    ],
                  );
                },
              ),
            if (source != null) ...[
              const SizedBox(height: 24),
              Text(source.name, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
            ],
          ],
        );
      },
    );
  }
}

/// Small dot that can be drawn next to verse numbers that start a note.
class CommentaryDot extends StatelessWidget {
  const CommentaryDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.only(left: 2, bottom: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
      );
}
