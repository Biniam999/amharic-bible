import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Frosted-glass panel. Looks right on top of [ScenicBackground] or any dark
/// gradient; in light mode it becomes a soft white panel with a blue edge.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.blur = 16,
    this.forceDark = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final double blur;

  /// Use the dark glass style regardless of theme (e.g. on the welcome screen).
  final bool forceDark;

  @override
  Widget build(BuildContext context) {
    final dark = forceDark || Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    final fill = dark
        ? [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.04)]
        : [Colors.white.withValues(alpha: 0.92), const Color(0xFFF0F5FE).withValues(alpha: 0.92)];
    final border = dark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFCFDDF5);

    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: shape,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: shape,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: fill),
                border: Border.all(color: border, width: 1),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide glowing pill button, e.g. "Get started  ›".
class GlowPillButton extends StatelessWidget {
  const GlowPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing = Icons.chevron_right_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: enabled
              ? [BoxShadow(color: const Color(0xFF5AA9FF).withValues(alpha: 0.35), blurRadius: 28, spreadRadius: -4)]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(40),
            child: Ink(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  colors: [Color(0xFF16336E), Color(0xFF1F4E9C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border.all(color: const Color(0xFF7FD3FF).withValues(alpha: 0.35)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                  if (trailing != null)
                    Positioned(
                      right: 20,
                      child: Icon(trailing, color: const Color(0xFF9FE6FF), size: 26),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A cross drawn with a soft white-blue glow that gently breathes.
class GlowingCross extends StatefulWidget {
  const GlowingCross({super.key, this.size = 64});

  final double size;

  @override
  State<GlowingCross> createState() => _GlowingCrossState();
}

class _GlowingCrossState extends State<GlowingCross> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size(widget.size * 0.7, widget.size),
        painter: _CrossPainter(reduceMotion ? 0.5 : Curves.easeInOut.transform(_c.value)),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.pulse);

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bar = w * 0.11;
    final vertical = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, h / 2), width: bar, height: h), Radius.circular(bar / 2));
    final horizontal = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, h * 0.3), width: w, height: bar), Radius.circular(bar / 2));

    final glow = Paint()
      ..color = const Color(0xFF7FD3FF).withValues(alpha: 0.35 + 0.3 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 8 * pulse);
    final core = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFCFEAFF), Color(0xFF8CCBFF)],
      ).createShader(Offset.zero & size);

    for (final r in [vertical, horizontal]) {
      canvas.drawRRect(r, glow);
    }
    for (final r in [vertical, horizontal]) {
      canvas.drawRRect(r, core);
    }
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.pulse != pulse;
}
