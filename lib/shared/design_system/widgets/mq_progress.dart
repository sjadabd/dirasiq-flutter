import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../mq_spacing.dart';
import '../mq_theme.dart';
import '../mq_typography.dart';

/// Progress accent — maps to the design's `مؤشرات التقدّم` indicators
/// (accent blue for general progress, success green / orange for outcome-based
/// metrics like attendance or scores).
enum MqProgressTone { accent, success, orange }

Color _toneColor(BuildContext context, MqProgressTone tone) {
  final mq = context.mq;
  return switch (tone) {
    MqProgressTone.accent => mq.accent,
    MqProgressTone.success => mq.success,
    MqProgressTone.orange => mq.orange,
  };
}

/// A rounded, on-brand linear progress bar. [value] is 0–1.
class MqLinearProgress extends StatelessWidget {
  const MqLinearProgress({
    super.key,
    required this.value,
    this.tone = MqProgressTone.accent,
    this.height = 8,
    this.showLabel = false,
  });

  final double value;
  final MqProgressTone tone;
  final double height;

  /// Trailing percentage label (mono numerals), as in the `92%` stat.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final color = _toneColor(context, tone);
    final clamped = value.clamp(0.0, 1.0);

    final bar = ClipRRect(
      borderRadius: MqRadius.brPill,
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: height,
        backgroundColor: mq.fill2,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );

    if (!showLabel) return bar;

    return Row(
      children: [
        Expanded(child: bar),
        MqSpacing.gapSm,
        Text('${(clamped * 100).round()}%',
            style: MqTypography.mono(color: mq.ink, size: 13)),
      ],
    );
  }
}

/// A circular progress ring with a centered value — the `92%` / `78%` rings
/// in the export.
class MqRingProgress extends StatelessWidget {
  const MqRingProgress({
    super.key,
    required this.value,
    this.tone = MqProgressTone.accent,
    this.size = 72,
    this.strokeWidth = 7,
    this.label,
    this.caption,
  });

  final double value;
  final MqProgressTone tone;
  final double size;
  final double strokeWidth;

  /// Centered primary text. Defaults to the rounded percentage.
  final String? label;

  /// Small caption under the value.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final color = _toneColor(context, tone);
    final clamped = value.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(
                value: clamped,
                color: color,
                track: mq.fill2,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label ?? '${(clamped * 100).round()}%',
                  style: MqTypography.mono(
                      color: mq.ink, size: size * 0.22, weight: FontWeight.w700)),
              if (caption != null)
                Text(caption!,
                    style: context.text.labelSmall?.copyWith(color: mq.ink3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
