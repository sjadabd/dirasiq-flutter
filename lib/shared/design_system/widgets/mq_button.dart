import 'package:flutter/material.dart';

import '../mq_spacing.dart';
import '../mq_theme.dart';

/// Visual ranking of a [MqButton], matching the export's button row:
/// `إجراء أساسي` (filled accent) and `ثانوي` (outlined/secondary).
enum MqButtonVariant {
  /// Solid accent fill — the single primary action on a surface.
  primary,

  /// Outlined on a neutral fill — companion to a primary action.
  secondary,

  /// Soft accent-tinted fill — lower emphasis than [primary].
  tonal,

  /// Text-only — lowest emphasis.
  text,
}

enum MqButtonSize { regular, small }

/// The MulhimIQ button. One widget covers every emphasis level via
/// [MqButtonVariant] so call sites stay consistent and on-brand.
class MqButton extends StatelessWidget {
  const MqButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = MqButtonVariant.primary,
    this.size = MqButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  const MqButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = MqButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = MqButtonVariant.secondary;

  const MqButton.tonal({
    super.key,
    required this.label,
    this.onPressed,
    this.size = MqButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = MqButtonVariant.tonal;

  const MqButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.size = MqButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = MqButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final MqButtonVariant variant;
  final MqButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final small = size == MqButtonSize.small;
    final height = small ? MqSize.buttonHeightSm : MqSize.buttonHeight;
    final disabled = onPressed == null || loading;

    final (Color bg, Color fg, BorderSide side) = switch (variant) {
      MqButtonVariant.primary => (mq.accent, mq.onAccent, BorderSide.none),
      MqButtonVariant.secondary => (mq.card, mq.ink, BorderSide(color: mq.line)),
      MqButtonVariant.tonal => (mq.accentSoft, mq.accent, BorderSide.none),
      MqButtonVariant.text => (Colors.transparent, mq.accent, BorderSide.none),
    };

    final labelStyle = (small ? context.text.labelMedium : context.text.labelLarge)
        ?.copyWith(color: fg, fontWeight: FontWeight.w600);

    final child = loading
        ? SizedBox(
            height: small ? 16 : 20,
            width: small ? 16 : 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: small ? MqSize.iconSm : MqSize.iconMd, color: fg),
                MqSpacing.gapSm,
              ],
              Flexible(child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: MqRadius.brMd,
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(
              horizontal: small ? MqSpacing.lg : MqSpacing.xl,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
