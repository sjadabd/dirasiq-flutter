import 'package:flutter/material.dart';

import '../mq_spacing.dart';
import '../mq_theme.dart';

/// The MulhimIQ surface card: `--wf-card` fill, hairline `--wf-line` border,
/// and the token `--wf-card-shadow`. This is the base container for course
/// cards, list rows, stat tiles, and dialogs across the app.
class MqCard extends StatelessWidget {
  const MqCard({
    super.key,
    required this.child,
    this.padding = MqSpacing.cardPadding,
    this.onTap,
    this.borderRadius = MqRadius.brLg,
    this.elevated = true,
    this.bordered = true,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  /// Apply the resting card shadow. Disable for cards inside already-elevated
  /// surfaces (sheets, dialogs) to avoid double shadows.
  final bool elevated;
  final bool bordered;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? mq.card,
        borderRadius: borderRadius,
        border: bordered ? Border.all(color: mq.line) : null,
        boxShadow: elevated ? mq.cardShadow : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: content,
              ),
      ),
    );
  }
}

/// A small tinted "wash" surface for inline callouts — selected states, info
/// banners, achievement strips. Pick the tint via [tone].
enum MqSurfaceTone { neutral, accent, orange, success }

class MqSurface extends StatelessWidget {
  const MqSurface({
    super.key,
    required this.child,
    this.tone = MqSurfaceTone.neutral,
    this.padding = const EdgeInsets.all(MqSpacing.md),
    this.borderRadius = MqRadius.brMd,
  });

  final Widget child;
  final MqSurfaceTone tone;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final (Color bg, Color border) = switch (tone) {
      MqSurfaceTone.neutral => (mq.fill, mq.line),
      MqSurfaceTone.accent => (mq.accentSoft, mq.accentLine),
      MqSurfaceTone.orange => (mq.orangeSoft, mq.orangeLine),
      MqSurfaceTone.success => (mq.success.withValues(alpha: 0.12), mq.success.withValues(alpha: 0.4)),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
