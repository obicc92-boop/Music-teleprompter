import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders the Music Teleprompter logo at any size via CustomPainter.
/// Design: dark rounded square, five lyric lines, active (middle) line in
/// orange with a play-cursor triangle, subtle beamed-note watermark.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  // All coordinates defined in a 100×100 unit space, then scaled.
  static const _bg = Color(0xFF141414);
  static const _inactive = Color(0xFF2A2A2A);
  static const _accent = Color(0xFFFF6B35);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0; // scale factor

    // ── Background ──────────────────────────────────────────────────────────
    final bgPaint = Paint()..color = _bg;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(21.9 * s),
      ),
      bgPaint,
    );

    // ── Lyric lines ──────────────────────────────────────────────────────────
    // Five lines; line[2] is the active one.
    // y positions and widths in 100-unit space:
    const lineData = [
      // [startX, startY, width, height, isActive]
      [14.5, 23.0, 58.0, 5.1, 0.0], // line 1
      [14.5, 33.4, 65.2, 5.1, 0.0], // line 2
      [26.5, 43.8, 59.0, 10.2, 1.0], // line 3 (active, starts after cursor)
      [14.5, 64.6, 62.3, 5.1, 0.0], // line 4
      [14.5, 75.0, 45.7, 5.1, 0.0], // line 5
    ];

    for (final d in lineData) {
      final x = d[0] * s;
      final y = d[1] * s;
      final w = d[2] * s;
      final h = d[3] * s;
      final active = d[4] == 1.0;

      if (active) {
        // Glow behind active line
        final glowPaint = Paint()
          ..color = _accent.withValues(alpha: 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(14.5 * s, (y - 1.5) * s, 71 * s, h + 3 * s),
            Radius.circular((h + 3 * s) / 2),
          ),
          glowPaint,
        );
      }

      final paint = Paint()..color = active ? _accent : _inactive;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(h / 2),
        ),
        paint,
      );
    }

    // ── Play-cursor triangle ─────────────────────────────────────────────────
    // Sits to the left of the active line
    final triPaint = Paint()..color = _accent;
    final path = Path()
      ..moveTo(14.5 * s, 43.3 * s)
      ..lineTo(14.5 * s, 55.3 * s)
      ..lineTo(24.5 * s, 49.3 * s)
      ..close();
    canvas.drawPath(path, triPaint);

    // ── Beamed-note watermark (top-right, low opacity) ───────────────────────
    if (size.width >= 32) {
      // Only draw at sizes where it's visible
      canvas.save();
      canvas.translate(0, 0);

      final notePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.17)
        ..style = PaintingStyle.fill;

      // Note 1 notehead
      _drawRotatedEllipse(canvas, notePaint, 73.8 * s, 19.1 * s, 4.3 * s,
          3.1 * s, -15 * math.pi / 180);
      // Note 1 stem
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(77.4 * s, 9.4 * s, 1.4 * s, 10.5 * s),
          const Radius.circular(1),
        ),
        notePaint,
      );

      // Note 2 notehead
      _drawRotatedEllipse(canvas, notePaint, 83.6 * s, 16.4 * s, 4.3 * s,
          3.1 * s, -15 * math.pi / 180);
      // Note 2 stem
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(87.2 * s, 6.6 * s, 1.4 * s, 10.5 * s),
          const Radius.circular(1),
        ),
        notePaint,
      );

      // Beam connecting the two stems
      final beamPath = Path()
        ..moveTo(77.4 * s, 9.4 * s)
        ..lineTo(88.6 * s, 6.6 * s)
        ..lineTo(88.6 * s, 8.4 * s)
        ..lineTo(77.4 * s, 11.2 * s)
        ..close();
      canvas.drawPath(beamPath, notePaint);

      canvas.restore();
    }
  }

  void _drawRotatedEllipse(Canvas canvas, Paint paint, double cx, double cy,
      double rx, double ry, double angle) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
