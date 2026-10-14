import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/utils/geez_numerals.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/bible_models.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../maps/bible_places.dart';
import '../reader/reader_position.dart';
import '../settings/settings_providers.dart';
import 'people_data.dart';

/// Gradient circle with the person's initial; the colour follows the name.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  static const _gradients = [
    [Color(0xFF12306A), Color(0xFF3D5AFE)],
    [Color(0xFF0E2352), Color(0xFF0E7FA8)],
    [Color(0xFF0A1633), Color(0xFF1A5FD0)],
    [Color(0xFF101E42), Color(0xFF5A7BFF)],
    [Color(0xFF07304A), Color(0xFF00A3C4)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[name.hashCode.abs() % _gradients.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: -2)],
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Everyone in the Bible, A–Z, with search.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final people = ref.watch(biblePeopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.peopleOfTheBible)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchPeople,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: people.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(icon: Icons.groups_outlined, message: l10n.loadError),
              data: (all) {
                final q = _query.trim().toLowerCase();
                final list = q.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(q)).toList();
                if (list.isEmpty) return EmptyState(icon: Icons.person_search_outlined, message: l10n.noPeopleFound);

                // A–Z headers between the groups.
                final rows = <Object>[];
                String? letter;
                for (final p in list) {
                  final l = p.name.characters.first.toUpperCase();
                  if (l != letter) {
                    letter = l;
                    rows.add(l);
                  }
                  rows.add(p);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    if (row is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        child: Text(row,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      );
                    }
                    final p = row as BiblePerson;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: PersonAvatar(name: p.name),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: p.mentions > 0 ? Text(l10n.mentionedIn(p.mentions)) : null,
                      trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                      onTap: () => context.push(AppRoutes.person(p.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// How many verses are listed on a person's page.
const _versesShown = 40;

final _personVersesProvider = FutureProvider.autoDispose.family<List<Verse>, String>((ref, personId) async {
  final person = (await ref.watch(biblePeopleByIdProvider.future))[personId];
  if (person == null) return const [];
  final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
  return ref
      .watch(bibleRepositoryProvider)
      .verses(translationId, person.verses.take(_versesShown).map(BiblePlace.refOf));
});

/// One person: family, places, dictionary entry and the verses about them.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byId = ref.watch(biblePeopleByIdProvider);
    final places = {for (final p in ref.watch(biblePlacesProvider).valueOrNull ?? const <BiblePlace>[]) p.id: p};
    final person = byId.valueOrNull?[id];

    if (person == null) {
      return Scaffold(
        appBar: AppBar(),
        body: byId.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.person_off_outlined, message: l10n.noPeopleFound),
      );
    }
    final people = byId.valueOrNull!;

    Widget section(String title, List<Widget> chips) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        );

    List<Widget> personChips(List<String> ids) => [
          for (final pid in ids)
            if (people[pid] case final relative?)
              ActionChip(
                avatar: PersonAvatar(name: relative.name, size: 22),
                label: Text(relative.name),
                onPressed: () => context.push(AppRoutes.person(relative.id)),
              ),
        ];

    Widget placeChip(String placeId) {
      final place = places[placeId];
      final onMap = place != null;
      return ActionChip(
        avatar: Icon(onMap ? Icons.place_rounded : Icons.place_outlined, size: 18, color: scheme.primary),
        label: Text(place?.name ?? placeId.split('_').first),
        onPressed: onMap ? () => context.push(AppRoutes.mapsAt(placeId)) : null,
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Center(child: PersonAvatar(name: person.name, size: 84)),
          const SizedBox(height: 14),
          Text(person.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (person.mentions > 0) ...[
            const SizedBox(height: 4),
            Text(l10n.mentionedIn(person.mentions),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),

          // Family
          if (person.fathers.isNotEmpty) section(l10n.familyFather, personChips(person.fathers)),
          if (person.mothers.isNotEmpty) section(l10n.familyMother, personChips(person.mothers)),
          if (person.spouses.isNotEmpty) section(l10n.familySpouses, personChips(person.spouses)),
          if (person.siblings.isNotEmpty) section(l10n.familySiblings, personChips(person.siblings)),
          if (person.children.isNotEmpty) section(l10n.familyChildren, personChips(person.children)),

          // Places
          if (person.birthPlace != null) section(l10n.bornIn, [placeChip(person.birthPlace!)]),
          if (person.deathPlace != null) section(l10n.diedIn, [placeChip(person.deathPlace!)]),

          // Dictionary entry
          if (person.description.isNotEmpty) ...[
            const SizedBox(height: 22),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(person.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
            ),
            const SizedBox(height: 6),
            Text(l10n.eastonCredit, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],

          // Verses
          if (person.verses.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(l10n.placeVerses, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _VerseMentions(personId: person.id, total: person.mentions),
          ],
        ],
      ),
    );
  }
}

class _VerseMentions extends ConsumerWidget {
  const _VerseMentions({required this.personId, required this.total});

  final String personId;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final geez = ref.watch(appSettingsProvider.select((s) => s.geezNumerals));
    final fontSize = ref.watch(appSettingsProvider.select((s) => s.fontSize));
    final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
    final ethiopic = (ref.watch(translationsProvider).valueOrNull ?? const <Translation>[])
            .where((t) => t.id == translationId)
            .firstOrNull
            ?.isEthiopic ??
        true;
    final books = {
      for (final b in ref.watch(booksProvider(translationId)).valueOrNull ?? const <Book>[]) b.id: b,
    };

    return ref.watch(_personVersesProvider(personId)).when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text(l10n.loadError),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final v in list)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    openInReader(ref, bookId: v.ref.bookId, chapter: v.ref.chapter, verse: v.ref.verse);
                    context.go(AppRoutes.read);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${books[v.ref.bookId]?.shortName ?? v.ref.bookId} '
                          '${geez ? geezifyDigits('${v.ref.chapter}:${v.ref.verse}') : '${v.ref.chapter}:${v.ref.verse}'}',
                          style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          v.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.reading
                              .verseStyle(ethiopic: ethiopic, fontSize: fontSize * 0.85, lineSpacing: 0.85),
                        ),
                      ],
                    ),
                  ),
                ),
              if (total > list.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(l10n.moreVerses(total - list.length),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
        );
  }
}
