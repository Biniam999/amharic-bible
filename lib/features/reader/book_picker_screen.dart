import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import 'reader_position.dart';

/// Old/New Testament tabs with a grid of books in the active translation's language.
class BookPickerScreen extends ConsumerWidget {
  const BookPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
    final currentBook = ref.watch(readerPositionProvider.select((p) => p.bookId));
    final books = ref.watch(booksProvider(translationId));

    void select(Book book) {
      if (book.chapters == 1) {
        openInReader(ref, bookId: book.id, chapter: 1);
        context.go(AppRoutes.read);
      } else {
        context.push(AppRoutes.chapterPicker(book.id));
      }
    }

    return DefaultTabController(
      length: 2,
      initialIndex: currentBook >= 40 ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chooseBook),
          bottom: TabBar(tabs: [Tab(text: l10n.oldTestament), Tab(text: l10n.newTestament)]),
        ),
        body: books.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(icon: Icons.error_outline, message: '$e'),
          data: (list) => TabBarView(
            children: [
              _BookGrid(books: [...list.where((b) => !b.isNewTestament)], currentBook: currentBook, onSelect: select),
              _BookGrid(books: [...list.where((b) => b.isNewTestament)], currentBook: currentBook, onSelect: select),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books, required this.currentBook, required this.onSelect});

  final List<Book> books;
  final int currentBook;
  final ValueChanged<Book> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 60,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        final selected = book.id == currentBook;
        return Material(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelect(book),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  book.shortName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
