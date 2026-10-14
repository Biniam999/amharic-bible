import 'package:flutter/material.dart';

import 'commentary_repository.dart';

/// "የመጽሐፉ መግቢያ" — the commentary's introduction to a whole book.
/// Push it from a book's info button or before chapter 1.
class BookIntroPage extends StatelessWidget {
  final String book;       // USFM id, e.g. 'GEN'
  final String bookTitle;  // Amharic title, e.g. 'ኦሪት ዘፍጥረት'

  const BookIntroPage({super.key, required this.book, required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    final repo = CommentaryRepository.instance;
    return FutureBuilder<List<CommentarySource>>(
      future: repo.sources(),
      builder: (context, snap) {
        final sources = snap.data ?? const <CommentarySource>[];
        return DefaultTabController(
          length: sources.isEmpty ? 1 : sources.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text('የመጽሐፉ መግቢያ · $bookTitle'),
              bottom: sources.length > 1
                  ? TabBar(tabs: [for (final s in sources) Tab(text: s.shortName)])
                  : null,
            ),
            body: sources.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    for (final s in sources)
                      _TextBody(future: repo.bookIntro(s.id, book), credit: s.name),
                  ]),
          ),
        );
      },
    );
  }
}

/// "የመጽሐፍ ቅዱስ ሰዎች" — People of the Bible, from Tyndale's profiles.
/// [onOpenReference] lets you jump to the verse in your reader.
class BiblePeoplePage extends StatefulWidget {
  final void Function(String book, int chapter, int verse)? onOpenReference;
  const BiblePeoplePage({super.key, this.onOpenReference});

  @override
  State<BiblePeoplePage> createState() => _BiblePeoplePageState();
}

class _BiblePeoplePageState extends State<BiblePeoplePage> {
  late final Future<List<BibleProfile>> _profiles = CommentaryRepository.instance.profiles();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('የመጽሐፍ ቅዱስ ሰዎች')),
      body: FutureBuilder<List<BibleProfile>>(
        future: _profiles,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!
              .where((p) => p.subject.toLowerCase().contains(_filter.toLowerCase()))
              .toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'ፈልግ (Search)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final person = list[i];
                  return ListTile(
                    title: Text(person.subject),
                    subtitle: person.refBook == null
                        ? null
                        : Text('${person.refBook} ${person.refChapter}:${person.refVerse}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _ProfilePage(
                        profile: person,
                        onOpenReference: widget.onOpenReference,
                      ),
                    )),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final BibleProfile profile;
  final void Function(String book, int chapter, int verse)? onOpenReference;
  const _ProfilePage({required this.profile, this.onOpenReference});

  @override
  Widget build(BuildContext context) {
    final canOpen = onOpenReference != null && profile.refBook != null;
    return Scaffold(
      appBar: AppBar(title: Text(profile.subject)),
      floatingActionButton: canOpen
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.menu_book),
              label: const Text('ጥቅሱን ክፈት'),
              onPressed: () => onOpenReference!(
                  profile.refBook!, profile.refChapter ?? 1, profile.refVerse ?? 1),
            )
          : null,
      body: _TextBody(
        future: Future.value(profile.text),
        credit: 'Tyndale Open Study Notes (CC BY-SA 4.0)',
      ),
    );
  }
}

class _TextBody extends StatelessWidget {
  final Future<String?> future;
  final String credit;
  const _TextBody({required this.future, required this.credit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final text = snap.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                text ?? 'መግቢያ የለም።',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(credit,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        );
      },
    );
  }
}
