import 'package:flutter/material.dart';

/// OLED-black background with soft pools of coloured light behind the content
/// (blue top-left, violet right, cyan low). In light mode: white with a faint
/// blue wash. Static, so it costs nothing while scrolling.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, this.child, this.intensity = 1});

  final Widget? child;

  /// 0 = plain background, 1 = normal glow.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AmbientPainter(dark: dark, intensity: intensity),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.dark, required this.intensity});

  final bool dark;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = dark ? const Color(0xFF020409) : const Color(0xFFF7FAFF));

    void glow(Offset center, double radius, Color color, double alpha) {
      final r = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: alpha * intensity), color.withValues(alpha: 0)],
          ).createShader(r),
      );
    }

    final w = size.width, h = size.height;
    if (dark) {
      glow(Offset(w * 0.05, h * 0.08), w * 0.95, const Color(0xFF1A5FD0), 0.28);
      glow(Offset(w * 1.05, h * 0.42), w * 0.85, const Color(0xFF6A4DFF), 0.16);
      glow(Offset(w * 0.3, h * 0.98), w * 0.9, const Color(0xFF00A3C4), 0.12);
    } else {
      glow(Offset(w * 0.05, h * 0.05), w * 0.95, const Color(0xFF7FB2FF), 0.22);
      glow(Offset(w * 1.05, h * 0.5), w * 0.8, const Color(0xFFB9A8FF), 0.14);
      glow(Offset(w * 0.3, h * 1.0), w * 0.9, const Color(0xFF7FD3FF), 0.14);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.dark != dark || old.intensity != intensity;
}
