import 'dart:math' as math;

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
import '../reader/reader_position.dart';
import '../settings/settings_providers.dart';
import 'bible_places.dart';

/// Offline map of the Bible lands with every place that has known coordinates.
class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key, this.initialPlaceId});

  /// Open zoomed in on this place, with its details showing.
  final String? initialPlaceId;

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> with SingleTickerProviderStateMixin {
  TransformationController? _tc;
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..addListener(_onAnimate);
  Animation<Matrix4>? _move;

  Set<PlaceFilter> _filters = PlaceFilter.values.toSet();
  bool _initialPlaceShown = false;
  BiblePlace? _selected;
  Size _viewport = Size.zero;

  // Built once from the map data.
  BibleLands? _builtFor;
  MapProjection? _proj;
  final _land = Path()..fillType = PathFillType.evenOdd;
  final _lakes = Path();
  final _rivers = Path();

  // Place-name labels, laid out once per theme.
  final _labels = <String, TextPainter>{};
  Brightness? _labelsBrightness;

  @override
  void dispose() {
    _anim.dispose();
    _tc?.dispose();
    for (final t in _labels.values) {
      t.dispose();
    }
    super.dispose();
  }

  void _onAnimate() {
    final move = _move;
    if (move != null) _tc?.value = move.value;
  }

  void _buildPaths(BibleLands lands) {
    if (identical(_builtFor, lands)) return;
    _builtFor = lands;
    final p = _proj = MapProjection(lands.bounds);
    List<Offset> points(List<double> r) => [for (var i = 0; i + 1 < r.length; i += 2) Offset(p.x(r[i]), p.y(r[i + 1]))];
    for (final poly in lands.land) {
      for (final ring in poly) {
        _land.addPolygon(points(ring), true);
      }
    }
    for (final poly in lands.lakes) {
      for (final ring in poly) {
        _lakes.addPolygon(points(ring), true);
      }
    }
    for (final line in lands.rivers) {
      _rivers.addPolygon(points(line), false);
    }
  }

  // --------------------------------------------------------------- camera

  double _minScale(MapProjection p) => math.max(_viewport.width / p.width, _viewport.height / p.height);

  /// A transform with world point (wx, wy) in the middle of the screen at scale [s],
  /// kept inside the map edges.
  Matrix4 _cameraAt(MapProjection p, double wx, double wy, double s) {
    s = s.clamp(_minScale(p), _maxScale).toDouble();
    // min(…, 0) guards against rounding when the map is exactly screen-sized.
    final double tx = (_viewport.width / 2 - wx * s).clamp(math.min(_viewport.width - p.width * s, 0.0), 0.0).toDouble();
    final double ty = (_viewport.height / 2 - wy * s).clamp(math.min(_viewport.height - p.height * s, 0.0), 0.0).toDouble();
    // Column-major: scale on the diagonal, translation in the last column.
    return Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  static const _maxScale = 14.0;

  void _animateTo(Matrix4 target) {
    final tc = _tc;
    if (tc == null) return;
    _move = Matrix4Tween(begin: tc.value, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _anim.forward(from: 0);
  }

  double get _scale => _tc?.value.getMaxScaleOnAxis() ?? 1;

  Offset get _worldCenter {
    final m = _tc!.value.storage;
    final s = _scale;
    return Offset((_viewport.width / 2 - m[12]) / s, (_viewport.height / 2 - m[13]) / s);
  }

  void _zoom(double factor) {
    final p = _proj;
    if (p == null || _tc == null) return;
    final c = _worldCenter;
    _animateTo(_cameraAt(p, c.dx, c.dy, _scale * factor));
  }

  void _showWholeMap() {
    final p = _proj;
    if (p == null) return;
    _animateTo(_cameraAt(p, p.x(35.5), p.y(31.8), _minScale(p)));
  }

  void _focus(BiblePlace place) {
    final p = _proj;
    if (p == null) return;
    setState(() => _selected = place);
    if (p.contains(place.lon, place.lat)) {
      _animateTo(_cameraAt(p, p.x(place.lon), p.y(place.lat), math.max(_scale, 3.5)));
    }
    _openPlace(place);
  }

  // ----------------------------------------------------------- what shows

  /// Fewer, more important places when zoomed out.
  static int _minMentionsForDot(double s) => s < 0.45 ? 4 : (s < 0.9 ? 1 : 0);

  bool _visible(BiblePlace place) =>
      _filters.contains(PlaceFilter.of(place.kind)) && (_proj?.contains(place.lon, place.lat) ?? false);

  void _onTap(Offset world, List<BiblePlace> places) {
    final p = _proj;
    if (p == null) return;
    final s = _scale;
    final minDot = _minMentionsForDot(s);
    BiblePlace? best;
    var bestDist = 26.0 / s; // 26 screen pixels
    for (final place in places) {
      if (!_visible(place) || place.mentions < minDot) continue;
      final d = (Offset(p.x(place.lon), p.y(place.lat)) - world).distance;
      if (d < bestDist) {
        bestDist = d;
        best = place;
      }
    }
    if (best == null) {
      setState(() => _selected = null);
    } else {
      setState(() => _selected = best);
      _openPlace(best);
    }
  }

  Future<void> _openPlace(BiblePlace place) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.95,
          builder: (sheetContext, controller) => _PlaceSheet(
            place: place,
            insideMap: _proj?.contains(place.lon, place.lat) ?? true,
            controller: controller,
            onOpenVerse: (verse) {
              Navigator.pop(sheetContext);
              openInReader(ref, bookId: verse.bookId, chapter: verse.chapter, verse: verse.verse);
              context.go(AppRoutes.read);
            },
          ),
        ),
      );

  Future<void> _search(List<BiblePlace> places) async {
    final place = await showModalBottomSheet<BiblePlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PlaceSearch(places: places),
    );
    if (place != null && mounted) _focus(place);
  }

  /// Labels are coloured for the theme; lay them out again when it changes.
  void _syncLabelTheme(Brightness brightness) {
    if (_labelsBrightness == brightness) return;
    for (final t in _labels.values) {
      t.dispose();
    }
    _labels.clear();
    _labelsBrightness = brightness;
  }

  /// Called while painting, so it must not look anything up from [context].
  TextPainter _label(BiblePlace place, _MapPalette palette) {
    return _labels.putIfAbsent(place.id, () {
      final region = place.kind == PlaceKind.region;
      final halo = Shadow(color: palette.sea, blurRadius: 3);
      return TextPainter(
        text: TextSpan(
          text: region ? place.name.toUpperCase() : place.name,
          style: TextStyle(
            color: region ? palette.kind(PlaceKind.region) : palette.label,
            fontSize: region ? 10.5 : (place.mentions >= 100 ? 13.5 : 12),
            fontWeight: place.mentions >= 40 ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: region ? 1.4 : 0,
            fontStyle: place.kind == PlaceKind.water ? FontStyle.italic : FontStyle.normal,
            shadows: [halo, halo],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lands = ref.watch(bibleLandsProvider);
    final places = ref.watch(biblePlacesProvider);
    final palette = _MapPalette.of(Theme.of(context));
    _syncLabelTheme(Theme.of(context).brightness);

    final error = lands.error ?? places.error;
    if (error != null) {
      return Scaffold(appBar: AppBar(title: Text(l10n.mapsTitle)), body: EmptyState(icon: Icons.map_outlined, message: l10n.loadError));
    }
    final landData = lands.valueOrNull;
    final placeList = places.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n.searchPlaces,
            onPressed: placeList == null ? null : () => _search(placeList),
          ),
        ],
      ),
      body: landData == null || placeList == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, box) {
                _buildPaths(landData);
                final proj = _proj!;
                _viewport = box.biggest;
                // First layout: open on the requested place, or on the Holy Land and its neighbours.
                final start = widget.initialPlaceId == null
                    ? null
                    : placeList.where((p) => p.id == widget.initialPlaceId && proj.contains(p.lon, p.lat)).firstOrNull;
                _tc ??= TransformationController(
                  start != null
                      ? _cameraAt(proj, proj.x(start.lon), proj.y(start.lat), 3.5)
                      : _cameraAt(proj, proj.x(36.5), proj.y(32.3),
                          _viewport.width / (16 * proj.width / (proj.lonMax - proj.lonMin))),
                );
                if (start != null && !_initialPlaceShown) {
                  _initialPlaceShown = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _selected = start);
                    _openPlace(start);
                  });
                }
                final tc = _tc!;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _MapPainter(
                            controller: tc,
                            proj: proj,
                            land: _land,
                            lakes: _lakes,
                            rivers: _rivers,
                            places: placeList,
                            visible: _visible,
                            minDot: _minMentionsForDot,
                            selected: _selected,
                            palette: palette,
                            label: (p) => _label(p, palette),
                          ),
                        ),
                      ),
                    ),
                    InteractiveViewer(
                      transformationController: tc,
                      constrained: false,
                      minScale: _minScale(proj),
                      maxScale: _maxScale,
                      onInteractionStart: (_) => _anim.stop(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _onTap(d.localPosition, placeList),
                        child: SizedBox(width: proj.width, height: proj.height),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 8,
                      child: _FilterBar(
                        palette: palette,
                        selected: _filters,
                        onChanged: (f) => setState(() => _filters = f),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 16 + MediaQuery.paddingOf(context).bottom,
                      child: Column(
                        children: [
                          _MapButton(icon: Icons.add_rounded, tooltip: l10n.zoomIn, onTap: () => _zoom(2)),
                          const SizedBox(height: 8),
                          _MapButton(icon: Icons.remove_rounded, tooltip: l10n.zoomOut, onTap: () => _zoom(0.5)),
                          const SizedBox(height: 8),
                          _MapButton(icon: Icons.zoom_out_map_rounded, tooltip: l10n.showWholeMap, onTap: _showWholeMap),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Painting
// --------------------------------------------------------------------------- //

@immutable
class _MapPalette {
  const _MapPalette({
    required this.dark,
    required this.sea,
    required this.land,
    required this.coast,
    required this.grid,
    required this.river,
    required this.label,
    required this.selection,
  });

  final bool dark;
  final Color sea, land, coast, grid, river, label, selection;

  static _MapPalette of(ThemeData theme) => theme.brightness == Brightness.dark
      ? _MapPalette(
          dark: true,
          sea: const Color(0xFF060E22),
          land: const Color(0xFF12244A),
          coast: const Color(0xFF5AA9FF),
          grid: const Color(0xFF0F2148),
          river: const Color(0xFF3D8BFF),
          label: const Color(0xFFEAF1FF),
          selection: theme.colorScheme.primary,
        )
      : _MapPalette(
          dark: false,
          sea: const Color(0xFFDCEBFF),
          land: Colors.white,
          coast: const Color(0xFF1A5FD0),
          grid: const Color(0xFFC9DCF7),
          river: const Color(0xFF2F78E8),
          label: const Color(0xFF0E1A33),
          selection: theme.colorScheme.primary,
        );

  Color kind(PlaceKind k) => switch (k) {
        PlaceKind.city => dark ? const Color(0xFF7FD3FF) : const Color(0xFF0E7FA8),
        PlaceKind.place => dark ? const Color(0xFFB4C8E6) : const Color(0xFF4E5F80),
        PlaceKind.water => dark ? const Color(0xFF3D9BFF) : const Color(0xFF1E88FF),
        PlaceKind.mountain => dark ? const Color(0xFFFFD27A) : const Color(0xFFB7791F),
        PlaceKind.region => dark ? const Color(0xFFB39DFF) : const Color(0xFF6A4DFF),
        PlaceKind.landmark => dark ? const Color(0xFFEAF1FF) : const Color(0xFF0E1A33),
      };

  Color filter(PlaceFilter f) => kind(f.kinds.first);
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.controller,
    required this.proj,
    required this.land,
    required this.lakes,
    required this.rivers,
    required this.places,
    required this.visible,
    required this.minDot,
    required this.selected,
    required this.palette,
    required this.label,
  }) : super(repaint: controller);

  final TransformationController controller;
  final MapProjection proj;
  final Path land, lakes, rivers;
  final List<BiblePlace> places;
  final bool Function(BiblePlace) visible;
  final int Function(double scale) minDot;
  final BiblePlace? selected;
  final _MapPalette palette;
  final TextPainter Function(BiblePlace) label;

  static double _radius(BiblePlace p) => p.mentions >= 100 ? 6 : (p.mentions >= 20 ? 4.5 : 3.2);

  /// More names appear as you zoom in.
  static int _minMentionsForLabel(double s) =>
      s < 0.45 ? 100 : s < 0.9 ? 40 : s < 1.8 ? 15 : s < 3.5 ? 5 : s < 7 ? 1 : 0;

  @override
  void paint(Canvas canvas, Size size) {
    final m = controller.value;
    final s = m.getMaxScaleOnAxis();
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.sea);

    // ---- the land, drawn in map units
    canvas.save();
    canvas.transform(m.storage);
    final step = s < 0.6 ? 5 : (s < 2.5 ? 2 : 1);
    final grid = Paint()
      ..color = palette.grid
      ..strokeWidth = 1 / s;
    for (var lon = (proj.lonMin / step).ceil() * step; lon <= proj.lonMax; lon += step) {
      canvas.drawLine(Offset(proj.x(lon.toDouble()), 0), Offset(proj.x(lon.toDouble()), proj.height), grid);
    }
    for (var lat = (proj.latMin / step).ceil() * step; lat <= proj.latMax; lat += step) {
      canvas.drawLine(Offset(0, proj.y(lat.toDouble())), Offset(proj.width, proj.y(lat.toDouble())), grid);
    }
    canvas.drawPath(land, Paint()..color = palette.land);
    canvas.drawPath(
      land,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 / s
        ..color = palette.coast.withValues(alpha: palette.dark ? 0.16 : 0.10),
    );
    final coast = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / s
      ..color = palette.coast.withValues(alpha: 0.85);
    canvas.drawPath(land, coast);
    canvas.drawPath(lakes, Paint()..color = palette.sea);
    canvas.drawPath(lakes, coast);
    canvas.drawPath(
      rivers,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = palette.river,
    );
    canvas.restore();

    // ---- places, drawn at a fixed size on screen
    final screen = (Offset.zero & size).inflate(24);
    final dotMin = minDot(s);
    final shown = <(BiblePlace, Offset)>[];
    for (final p in places) {
      if (!visible(p) || (p.mentions < dotMin && p != selected)) continue;
      final pt = MatrixUtils.transformPoint(m, Offset(proj.x(p.lon), proj.y(p.lat)));
      if (screen.contains(pt)) shown.add((p, pt));
    }
    // Small dots first, so important places sit on top.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = palette.sea;
    for (final (p, pt) in shown.reversed) {
      final r = _radius(p);
      final color = palette.kind(p.kind);
      if (r >= 4.5) {
        canvas.drawCircle(
          pt,
          r + 5,
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(pt, r, Paint()..color = color);
      canvas.drawCircle(pt, r, outline);
    }

    // Labels, most-mentioned first, skipping any that would overlap.
    final labelMin = _minMentionsForLabel(s);
    final taken = <Rect>[];
    var count = 0;
    void drawLabel(BiblePlace p, Offset pt, {bool force = false}) {
      final tp = label(p);
      final r = _radius(p);
      final rect = Rect.fromLTWH(pt.dx + r + 4, pt.dy - tp.height / 2, tp.width, tp.height);
      if (!force && taken.any((t) => t.overlaps(rect.inflate(2)))) return;
      tp.paint(canvas, rect.topLeft);
      taken.add(rect);
      count++;
    }

    final sel = selected;
    if (sel != null) {
      final hit = shown.where((e) => e.$1 == sel).firstOrNull;
      if (hit != null) {
        canvas.drawCircle(
          hit.$2,
          _radius(sel) + 8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = palette.selection,
        );
        drawLabel(sel, hit.$2, force: true);
      }
    }
    for (final (p, pt) in shown) {
      if (count >= 80) break;
      if (p == sel || p.mentions < labelMin) continue;
      drawLabel(p, pt);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}

// --------------------------------------------------------------------------- //
// Controls
// --------------------------------------------------------------------------- //

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.palette, required this.selected, required this.onChanged});

  final _MapPalette palette;
  final Set<PlaceFilter> selected;
  final ValueChanged<Set<PlaceFilter>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = {
      PlaceFilter.towns: l10n.filterTowns,
      PlaceFilter.lands: l10n.filterLands,
      PlaceFilter.water: l10n.filterWater,
      PlaceFilter.mountains: l10n.filterMountains,
      PlaceFilter.other: l10n.filterOther,
    };
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final f in PlaceFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: CircleAvatar(radius: 6, backgroundColor: palette.filter(f)),
                label: Text(names[f]!),
                selected: selected.contains(f),
                showCheckmark: false,
                onSelected: (on) {
                  final next = {...selected};
                  if (on) {
                    next.add(f);
                  } else {
                    next.remove(f);
                  }
                  onChanged(next);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
      shape: CircleBorder(side: BorderSide(color: scheme.primary.withValues(alpha: 0.3))),
      elevation: 3,
      child: IconButton(icon: Icon(icon), color: scheme.primary, tooltip: tooltip, onPressed: onTap),
    );
  }
}

// --------------------------------------------------------------------------- //
// Place details
// --------------------------------------------------------------------------- //

/// How many verses are listed in a place's sheet.
const _versesShown = 40;

final _placeVersesProvider = FutureProvider.autoDispose.family<List<Verse>, String>((ref, placeId) async {
  final places = await ref.watch(biblePlacesProvider.future);
  final place = places.where((p) => p.id == placeId).firstOrNull;
  if (place == null) return const [];
  final translationId = ref.watch(readerPositionProvider.select((p) => p.translationId));
  return ref
      .watch(bibleRepositoryProvider)
      .verses(translationId, place.verses.take(_versesShown).map(BiblePlace.refOf));
});

String _kindName(AppLocalizations l10n, PlaceKind k) => switch (k) {
      PlaceKind.city => l10n.kindCity,
      PlaceKind.place => l10n.kindPlace,
      PlaceKind.water => l10n.kindWater,
      PlaceKind.mountain => l10n.kindMountain,
      PlaceKind.region => l10n.kindRegion,
      PlaceKind.landmark => l10n.kindLandmark,
    };

class _PlaceSheet extends ConsumerWidget {
  const _PlaceSheet({required this.place, required this.insideMap, required this.controller, required this.onOpenVerse});

  final BiblePlace place;
  final bool insideMap;
  final ScrollController controller;
  final ValueChanged<VerseRef> onOpenVerse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = _MapPalette.of(theme);
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
    final verses = ref.watch(_placeVersesProvider(place.id));

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(place.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(radius: 5, backgroundColor: palette.kind(place.kind)),
            const SizedBox(width: 8),
            Text(_kindName(l10n, place.kind), style: theme.textTheme.labelLarge),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.mentionedIn(place.mentions),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        if (!insideMap) ...[
          const SizedBox(height: 10),
          Text(l10n.outsideMap, style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary)),
        ],
        if (place.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(place.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ),
          const SizedBox(height: 6),
          Text(l10n.eastonCredit, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        if (place.verses.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l10n.placeVerses, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...verses.when<List<Widget>>(
            loading: () => [const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [Text(l10n.loadError)],
            data: (list) => [
              for (final v in list)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onOpenVerse(v.ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          () {
                            final r = '${v.ref.chapter}:${v.ref.verse}';
                            return '${books[v.ref.bookId]?.shortName ?? v.ref.bookId} ${geez ? geezifyDigits(r) : r}';
                          }(),
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
              if (place.verses.length > _versesShown)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(l10n.moreVerses(place.verses.length - _versesShown),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PlaceSearch extends StatefulWidget {
  const _PlaceSearch({required this.places});

  final List<BiblePlace> places;

  @override
  State<_PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<_PlaceSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = _MapPalette.of(theme);
    final q = _query.trim().toLowerCase();
    // Places are sorted by mentions, so the best-known match comes first.
    final results = (q.isEmpty ? widget.places : widget.places.where((p) => p.name.toLowerCase().contains(q)))
        .take(60)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchPlaces,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? EmptyState(icon: Icons.location_off_outlined, message: l10n.noPlacesFound)
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final p = results[i];
                        return ListTile(
                          leading: CircleAvatar(radius: 7, backgroundColor: palette.kind(p.kind)),
                          title: Text(p.name),
                          subtitle: Text('${_kindName(l10n, p.kind)} · ${l10n.mentionedIn(p.mentions)}'),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
