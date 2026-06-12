import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../teacher/shared/design/teacher_design.dart';

/// Shared chrome for the (pre-auth) teacher join-request flow. These leaf
/// widgets assume they are built UNDER a `Theme(MqTheme)` + `Directionality.rtl`
/// subtree — each screen applies that wrap itself, mirroring the rest of the
/// teacher design-system pass.

/// Lightweight app bar: a back chip + screen title. No teacher-session chrome
/// (notifications/chat/theme) because the applicant is not authenticated yet.
class JoinAppBar extends StatelessWidget implements PreferredSizeWidget {
  const JoinAppBar({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md, vertical: MqSpacing.sm),
        child: Row(
          children: [
            Material(
              color: mq.fill,
              shape: RoundedRectangleBorder(
                borderRadius: MqRadius.brMd,
                side: BorderSide(color: mq.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onBack ?? () => Get.back(),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: MqSize.iconSm, color: mq.ink2),
                ),
              ),
            ),
            const SizedBox(width: MqSpacing.md),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular hero icon on a soft tinted disc.
class JoinHeroIcon extends StatelessWidget {
  const JoinHeroIcon({super.key, required this.icon, this.tone, this.size = 96});

  final IconData icon;
  final Color? tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final accent = tone ?? mq.accent;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.5, color: accent),
      ),
    );
  }
}

/// Soft accent info banner.
class JoinInfoBox extends StatelessWidget {
  const JoinInfoBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.accentSoft,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.accentLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: mq.accent, size: MqSize.iconSm),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(message,
                style: context.text.bodySmall?.copyWith(color: mq.ink)),
          ),
        ],
      ),
    );
  }
}

/// Error banner.
class JoinErrorBox extends StatelessWidget {
  const JoinErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.error.withValues(alpha: 0.10),
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: mq.error, size: MqSize.iconSm),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(message,
                style: context.text.bodySmall?.copyWith(color: mq.ink)),
          ),
        ],
      ),
    );
  }
}

/// Centered 6-digit OTP entry, design-system styled.
class JoinOtpField extends StatelessWidget {
  const JoinOtpField({
    super.key,
    required this.controller,
    required this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      onFieldSubmitted: onSubmitted,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: context.text.headlineSmall?.copyWith(
        letterSpacing: 10,
        fontWeight: FontWeight.w700,
      ),
      decoration: const InputDecoration(
        labelText: 'رمز التحقق',
        hintText: '------',
      ),
      validator: validator,
    );
  }
}
