import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Time of day for [ScenicBackground].
enum SceneVariant { dawn, twilight, night }

/// A painted mountain landscape in blues and white — no image files needed.
///
/// Used full-screen on the welcome screen, and later as the background of the
/// "Today's verse" card and share images. [seed] changes the mountain shapes,
/// so each card can look different while staying on-brand.
class ScenicBackground extends StatelessWidget {
  const ScenicBackground({
    super.key,
    this.variant = SceneVariant.dawn,
    this.seed = 7,
    this.child,
  });

  final SceneVariant variant;
  final int seed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ScenePainter(variant, seed),
        child: child == null ? const SizedBox.expand() : SizedBox.expand(child: child),
      ),
    );
  }
}

class _Palette {
  const _Palette(this.sky, this.skyStops, this.sunCore, this.sunGlow, this.layers, this.stars);

  final List<Color> sky;
  final List<double> skyStops;
  final Color sunCore;
  final Color sunGlow;

  /// Far → near.
  final List<Color> layers;
  final bool stars;

  static _Palette of(SceneVariant v) => switch (v) {
        SceneVariant.dawn => const _Palette(
            [Color(0xFF07122B), Color(0xFF123068), Color(0xFF3F74B8), Color(0xFFB9D6F2)],
            [0.0, 0.38, 0.7, 1.0],
            Color(0xFFFFFFFF),
            Color(0xFFBFE6FF),
            [Color(0xFF7F9FCB), Color(0xFF4F6E9E), Color(0xFF2A436F), Color(0xFF14244A), Color(0xFF0A1430)],
            false,
          ),
        SceneVariant.twilight => const _Palette(
            [Color(0xFF050B1E), Color(0xFF0E2352), Color(0xFF2C5797), Color(0xFF7FA9DD)],
            [0.0, 0.42, 0.75, 1.0],
            Color(0xFFEAF6FF),
            Color(0xFF8CCBFF),
            [Color(0xFF52709F), Color(0xFF34507F), Color(0xFF1E355F), Color(0xFF101E40), Color(0xFF070F26)],
            true,
          ),
        SceneVariant.night => const _Palette(
            [Color(0xFF02050F), Color(0xFF071430), Color(0xFF0F2A5A), Color(0xFF2B4F86)],
            [0.0, 0.45, 0.8, 1.0],
            Color(0xFFE6F3FF),
            Color(0xFF5E9BE0),
            [Color(0xFF2E4672), Color(0xFF1E3358), Color(0xFF132444), Color(0xFF0B1631), Color(0xFF050B1C)],
            true,
          ),
      };
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.variant, this.seed);

  final SceneVariant variant;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _Palette.of(variant);
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;

    // Sky
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.sky,
          stops: p.skyStops,
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.72)),
    );

    final rnd = math.Random(seed);

    // Stars
    if (p.stars) {
      final star = Paint();
      for (var i = 0; i < 70; i++) {
        final x = rnd.nextDouble() * w;
        final y = math.pow(rnd.nextDouble(), 1.6) * h * 0.45;
        final r = rnd.nextDouble() * 1.1 + 0.3;
        star.color = Colors.white.withValues(alpha: 0.25 + rnd.nextDouble() * 0.55);
        canvas.drawCircle(Offset(x, y.toDouble()), r, star);
      }
    }

    // Sun glow on the horizon, right of centre
    final sun = Offset(w * 0.84, h * 0.56);
    final glowR = math.max(w, h) * 0.55;
    canvas.drawCircle(
      sun,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.sunGlow.withValues(alpha: 0.55),
            p.sunGlow.withValues(alpha: 0.12),
            p.sunGlow.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: sun, radius: glowR)),
    );
    canvas.drawCircle(
      sun,
      w * 0.035,
      Paint()
        ..color = p.sunCore
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Mountain layers, far to near. Each gets a slightly lighter top edge
    // (atmospheric haze) fading to its own colour.
    const bases = [0.56, 0.62, 0.69, 0.78, 0.89];
    const amps = [0.15, 0.10, 0.085, 0.065, 0.05];
    for (var i = 0; i < p.layers.length; i++) {
      final noise = _FractalNoise(math.Random(rnd.nextInt(1 << 30)));
      final peakX = 0.38 + rnd.nextDouble() * 0.14;
      final path = Path()..moveTo(0, h);
      var top = h;
      const steps = 160;
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        var v = (noise(t) - 0.3) * 2.0;
        if (i == 0) {
          // One tall summit on the farthest range.
          final d = (t - peakX) / 0.13;
          v += 0.8 * math.exp(-d * d);
        }
        final y = bases[i] * h - v * amps[i] * h;
        if (y < top) top = y;
        path.lineTo(t * w, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      final haze = Color.lerp(p.layers[i], Colors.white, 0.10)!;
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [haze, p.layers[i]],
          ).createShader(Rect.fromLTWH(0, top, w, h * 0.18)),
      );
    }

    // Fade the foreground into the app background, so content sits on it cleanly
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.layers.last.withValues(alpha: 0), p.layers.last.withValues(alpha: 0.85), p.layers.last],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.38)),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.variant != variant || old.seed != seed;
}

/// Smooth 1-D fractal (value) noise in 0..1, for natural-looking ridgelines.
class _FractalNoise {
  _FractalNoise(math.Random rnd, {int octaves = 5})
      : _tables = [
          for (var o = 0; o < octaves; o++) [for (var i = 0; i < (4 << o) + 2; i++) rnd.nextDouble()],
        ];

  final List<List<double>> _tables;

  double call(double t) {
    var value = 0.0, amp = 1.0, total = 0.0;
    for (var o = 0; o < _tables.length; o++) {
      final x = t.clamp(0.0, 1.0) * (4 << o);
      final i = x.floor();
      var f = x - i;
      f = (1 - math.cos(f * math.pi)) / 2; // cosine interpolation
      final tab = _tables[o];
      value += amp * (tab[i] * (1 - f) + tab[i + 1] * f);
      total += amp;
      amp *= 0.5;
    }
    return value / total;
  }
}
