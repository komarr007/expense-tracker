import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// CustomPainter that draws a circular progress arc.
/// Used by SavingsGoalScreen cards and the Finance hub mini-rings.
class RingPainter extends CustomPainter {
  final double progress;    // 0.0–1.0
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const RingPainter({
    required this.progress,
    required this.color,
    this.trackColor = AppColors.divider,
    this.strokeWidth = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Paint arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,           // start at 12 o'clock
        2 * math.pi * progress, // clockwise sweep
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
