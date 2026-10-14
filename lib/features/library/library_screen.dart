import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../reader/reader_position.dart';
import '../reader/widgets/note_editor_sheet.dart';
import 'library_providers.dart';

/// Bookmarks, highlights and notes. Tap to open the verse; swipe to delete.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navLibrary),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.bookmark_border), text: l10n.bookmarks),
              Tab(icon: const Icon(Icons.border_color_outlined), text: l10n.highlights),
              Tab(icon: const Icon(Icons.sticky_note_2_outlined), text: l10n.notes),
            ],
          ),
        ),
        body: const TabBarView(children: [_BookmarksTab(), _HighlightsTab(), _NotesTab()]),
      ),
    );
  }
}

void _openVerse(BuildContext context, WidgetRef ref, VerseRef verse) {
  openInReader(ref, bookId: verse.bookId, chapter: verse.chapter, verse: verse.verse);
  context.go(AppRoutes.read);
}

// --------------------------------------------------------------------------- //

class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _EntryList<Bookmark>(
      entries: ref.watch(libraryBookmarksProvider),
      emptyIcon: Icons.bookmark_border,
      emptyMessage: l10n.noBookmarks,
      idOf: (b) => b.id,
      onDelete: (entry) async {
        await ref.read(userDataRepositoryProvider).deleteBookmark(entry.item.id);
        return _UndoSnack(
          message: l10n.bookmarkRemoved,
          undo: () => ref.read(userDataRepositoryProvider).toggleBookmarks(entry.item.translationId, [entry.ref]),
        );
      },
      itemBuilder: (context, entry) => _EntryTile(
        leading: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
        entry: entry,
        onTap: () => _openVerse(context, ref, entry.ref),
      ),
    );
  }
}

class _HighlightsTab extends ConsumerWidget {
  const _HighlightsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _EntryList<Highlight>(
      entries: ref.watch(libraryHighlightsProvider),
      emptyIcon: Icons.border_color_outlined,
      emptyMessage: l10n.noHighlights,
      idOf: (h) => h.id,
      onDelete: (entry) async {
        await ref.read(userDataRepositoryProvider).deleteHighlight(entry.item.id);
        return _UndoSnack(
          message: l10n.highlightRemoved,
          undo: () => ref.read(userDataRepositoryProvider).setHighlight([entry.ref], entry.item.color),
        );
      },
      itemBuilder: (context, entry) => _EntryTile(
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: ReadingTheme.highlightSwatches[entry.item.color.index],
            shape: BoxShape.circle,
          ),
        ),
        entry: entry,
        onTap: () => _openVerse(context, ref, entry.ref),
      ),
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _EntryList<Note>(
      entries: ref.watch(libraryNotesProvider),
      emptyIcon: Icons.sticky_note_2_outlined,
      emptyMessage: l10n.noNotes,
      idOf: (n) => n.id,
      confirmDelete: confirmDeleteNote,
      onDelete: (entry) async {
        await ref.read(userDataRepositoryProvider).deleteNoteById(entry.item.id);
        return _UndoSnack(message: l10n.noteDeleted);
      },
      itemBuilder: (context, entry) => ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        title: Text(entry.reference, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(entry.item.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              l10n.updatedOn(MaterialLocalizations.of(context).formatMediumDate(entry.item.updatedAt)),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.edit,
          onPressed: () => showNoteEditor(context, verse: entry.ref, title: entry.reference),
        ),
        onTap: () => _openVerse(context, ref, entry.ref),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //

class _UndoSnack {
  const _UndoSnack({required this.message, this.undo});

  final String message;
  final Future<void> Function()? undo;
}

/// Loading/empty/error states plus swipe-to-delete for one tab.
class _EntryList<T> extends StatefulWidget {
  const _EntryList({
    super.key,
    required this.entries,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.idOf,
    required this.onDelete,
    required this.itemBuilder,
    this.confirmDelete,
  });

  final AsyncValue<List<LibraryEntry<T>>> entries;
  final IconData emptyIcon;
  final String emptyMessage;
  final int Function(T item) idOf;
  final Future<_UndoSnack> Function(LibraryEntry<T> entry) onDelete;
  final Widget Function(BuildContext context, LibraryEntry<T> entry) itemBuilder;
  final Future<bool> Function(BuildContext context)? confirmDelete;

  @override
  State<_EntryList<T>> createState() => _EntryListState<T>();
}

class _EntryListState<T> extends State<_EntryList<T>> {
  /// Ids swiped away but not yet gone from the database stream. A dismissed
  /// Dismissible must leave the tree on the very next frame.
  final _dismissed = <int>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return widget.entries.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(icon: Icons.error_outline, message: '$e'),
      data: (all) {
        final ids = {for (final e in all) widget.idOf(e.item)};
        _dismissed.retainAll(ids);
        final entries = [for (final e in all) if (!_dismissed.contains(widget.idOf(e.item))) e];
        if (entries.isEmpty) return EmptyState(icon: widget.emptyIcon, message: widget.emptyMessage);

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, i) {
            final entry = entries[i];
            final id = widget.idOf(entry.item);
            return Dismissible(
              key: ValueKey(id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: scheme.errorContainer,
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsetsDirectional.only(end: 24),
                child: Icon(Icons.delete_outline, color: scheme.onErrorContainer, semanticLabel: l10n.delete),
              ),
              confirmDismiss: widget.confirmDelete == null ? null : (_) => widget.confirmDelete!(context),
              onDismissed: (_) async {
                setState(() => _dismissed.add(id));
                final messenger = ScaffoldMessenger.of(context);
                final snack = await widget.onDelete(entry);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(snack.message),
                      action: snack.undo == null ? null : SnackBarAction(label: l10n.undo, onPressed: snack.undo!),
                    ),
                  );
              },
              child: widget.itemBuilder(context, entry),
            );
          },
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.leading, required this.entry, required this.onTap});

  final Widget leading;
  final LibraryEntry<Object?> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: SizedBox(width: 32, child: Center(child: leading)),
      title: Text(entry.reference, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      subtitle: entry.verseText.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(entry.verseText, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
            ),
      onTap: onTap,
    );
  }
}
