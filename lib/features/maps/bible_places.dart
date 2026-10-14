import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/bible_models.dart';

/// Kind of place; the letter is how tools/build_maps.py stores it.
enum PlaceKind {
  city('c'),
  place('p'),
  water('w'),
  mountain('m'),
  region('r'),
  landmark('l');

  const PlaceKind(this.code);
  final String code;

  static PlaceKind of(String code) => values.firstWhere((k) => k.code == code, orElse: () => place);
}

/// The groups offered as filter chips on the map.
enum PlaceFilter {
  towns({PlaceKind.city, PlaceKind.place}),
  lands({PlaceKind.region}),
  water({PlaceKind.water}),
  mountains({PlaceKind.mountain}),
  other({PlaceKind.landmark});

  const PlaceFilter(this.kinds);
  final Set<PlaceKind> kinds;

  static PlaceFilter of(PlaceKind kind) => values.firstWhere((f) => f.kinds.contains(kind));
}

@immutable
class BiblePlace {
  const BiblePlace({
    required this.id,
    required this.name,
    required this.kind,
    required this.lon,
    required this.lat,
    required this.mentions,
    required this.verses,
    required this.description,
  });

  final String id;
  final String name;
  final PlaceKind kind;
  final double lon;
  final double lat;

  /// Number of verses that mention this place.
  final int mentions;

  /// Verses as book*1000000 + chapter*1000 + verse (KJV numbering).
  final List<int> verses;

  /// From Easton's Bible Dictionary (English); may be empty.
  final String description;

  static VerseRef refOf(int code) => VerseRef(code ~/ 1000000, (code ~/ 1000) % 1000, code % 1000);
}

/// Coastline, lakes and rivers, as flat [lon, lat, lon, lat, …] lists.
@immutable
class BibleLands {
  const BibleLands({required this.bounds, required this.land, required this.lakes, required this.rivers});

  /// lon min, lat min, lon max, lat max.
  final List<double> bounds;

  /// Each polygon is a list of rings (outer first).
  final List<List<Float32List>> land;
  final List<List<Float32List>> lakes;
  final List<Float32List> rivers;
}

/// Turns longitude/latitude into map units and back. 100 units = 1° of latitude;
/// longitude is narrowed by cos(latitude) so shapes keep their proportions.
@immutable
class MapProjection {
  MapProjection(List<double> bounds)
      : lonMin = bounds[0],
        latMin = bounds[1],
        lonMax = bounds[2],
        latMax = bounds[3],
        _k = math.cos((bounds[1] + bounds[3]) / 2 * math.pi / 180);

  static const unit = 100.0;
  final double lonMin, latMin, lonMax, latMax;
  final double _k;

  double get width => (lonMax - lonMin) * _k * unit;
  double get height => (latMax - latMin) * unit;

  double x(double lon) => (lon - lonMin) * _k * unit;
  double y(double lat) => (latMax - lat) * unit;

  bool contains(double lon, double lat) => lon >= lonMin && lon <= lonMax && lat >= latMin && lat <= latMax;
}

final bibleLandsProvider = FutureProvider<BibleLands>((ref) async {
  final raw = await rootBundle.loadString('assets/maps/bible_lands.json');
  return compute(_parseLands, raw);
});

/// Every place, most-mentioned first.
final biblePlacesProvider = FutureProvider<List<BiblePlace>>((ref) async {
  final raw = await rootBundle.loadString('assets/maps/places.json');
  return compute(_parsePlaces, raw);
});

BibleLands _parseLands(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  Float32List ring(dynamic r) => Float32List.fromList([for (final v in r as List) (v as num).toDouble()]);
  List<List<Float32List>> polys(dynamic list) => [
        for (final p in list as List) [for (final r in p as List) ring(r)],
      ];
  return BibleLands(
    bounds: [for (final v in json['bounds'] as List) (v as num).toDouble()],
    land: polys(json['land']),
    lakes: polys(json['lakes']),
    rivers: [for (final r in json['rivers'] as List) ring(r)],
  );
}

List<BiblePlace> _parsePlaces(String raw) => [
      for (final p in jsonDecode(raw) as List)
        BiblePlace(
          id: p['i'] as String,
          name: p['n'] as String,
          kind: PlaceKind.of(p['t'] as String),
          lon: (p['x'] as num).toDouble(),
          lat: (p['y'] as num).toDouble(),
          mentions: p['c'] as int,
          verses: [for (final v in p['v'] as List) v as int],
          description: (p['d'] as String?) ?? '',
        ),
    ];
