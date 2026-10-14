import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A person in the Bible (Theographic Bible Metadata, CC BY-SA 4.0).
@immutable
class BiblePerson {
  const BiblePerson({
    required this.id,
    required this.name,
    required this.female,
    required this.mentions,
    required this.verses,
    required this.description,
    this.fathers = const [],
    this.mothers = const [],
    this.siblings = const [],
    this.spouses = const [],
    this.children = const [],
    this.birthPlace,
    this.deathPlace,
  });

  final String id;
  final String name;
  final bool female;

  /// Number of verses that mention this person.
  final int mentions;

  /// The first verses that mention them, as book*1000000 + chapter*1000 + verse.
  final List<int> verses;

  /// From Easton's Bible Dictionary (English); may be empty.
  final String description;

  /// Family, as ids of other people.
  final List<String> fathers, mothers, siblings, spouses, children;

  /// Place ids on the Bible map, when known.
  final String? birthPlace, deathPlace;

  bool get hasFamily =>
      fathers.isNotEmpty || mothers.isNotEmpty || siblings.isNotEmpty || spouses.isNotEmpty || children.isNotEmpty;
}

/// Everyone, sorted by name.
final biblePeopleProvider = FutureProvider<List<BiblePerson>>((ref) async {
  final raw = await rootBundle.loadString('assets/maps/people.json');
  return compute(_parsePeople, raw);
});

/// The same people, looked up by id.
final biblePeopleByIdProvider = FutureProvider<Map<String, BiblePerson>>((ref) async {
  return {for (final p in await ref.watch(biblePeopleProvider.future)) p.id: p};
});

List<BiblePerson> _parsePeople(String raw) {
  List<String> ids(dynamic v) => v is List ? [for (final x in v) x as String] : const [];
  return [
    for (final p in jsonDecode(raw) as List)
      BiblePerson(
        id: p['i'] as String,
        name: p['n'] as String,
        female: p['g'] == 'f',
        mentions: p['c'] as int,
        verses: [for (final v in p['v'] as List) v as int],
        description: (p['d'] as String?) ?? '',
        fathers: ids(p['fa']),
        mothers: ids(p['mo']),
        siblings: ids(p['si']),
        spouses: ids(p['pa']),
        children: ids(p['ch']),
        birthPlace: p['bp'] as String?,
        deathPlace: p['dp'] as String?,
      ),
  ];
}
