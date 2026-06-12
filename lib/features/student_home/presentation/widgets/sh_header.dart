import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/shared/controllers/theme_controller.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

/// Top app header per the "B Hero + Bento" design: a compact action row
/// (MulhimIQ logo/name + profile / theme-toggle / notifications / chat icons)
/// over a full-width search bar.
class ShHeader extends StatelessWidget {
  const ShHeader({
    super.key,
    this.unread = 0,
    this.onProfile,
    this.onNotifications,
    this.onChat,
    this.onSearch,
  });

  final int unread;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final VoidCallback? onChat;
  final VoidCallback? onSearch;

  void _toggleTheme() {
    if (Get.isRegistered<ThemeController>()) {
      ThemeController.to.toggleDarkLight();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            _Logo(),
            const Spacer(),
            _IconButton(icon: Icons.person_outline_rounded, onTap: onProfile),
            const SizedBox(width: MqSpacing.xs),
            _IconButton(
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              onTap: _toggleTheme,
            ),
            const SizedBox(width: MqSpacing.xs),
            _IconButton(
              icon: Icons.notifications_outlined,
              onTap: onNotifications,
              badge: unread,
            ),
            const SizedBox(width: MqSpacing.xs),
            _IconButton(icon: Icons.chat_bubble_outline_rounded, onTap: onChat),
          ],
        ),
        const SizedBox(height: MqSpacing.md),
        _SearchBar(onTap: onSearch, hint: 'ابحث عن معلم أو دورة…', fill: mq.fill, border: mq.line),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: mq.accent, borderRadius: MqRadius.brSm),
          child: Text('M',
              style: context.text.titleMedium?.copyWith(
                color: mq.onAccent,
                fontWeight: FontWeight.w800,
              )),
        ),
        const SizedBox(width: MqSpacing.sm),
        Text('MulhimIQ',
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap, this.badge = 0});
  final IconData icon;
  final VoidCallback? onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.fill,
      shape: RoundedRectangleBorder(borderRadius: MqRadius.brMd, side: BorderSide(color: mq.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MqSpacing.sm),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: mq.ink2, size: MqSize.iconMd),
              if (badge > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 14),
                    decoration: BoxDecoration(
                      color: mq.error,
                      borderRadius: MqRadius.brPill,
                      border: Border.all(color: mq.card, width: 1.5),
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(
                        color: mq.onAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.fill, required this.border, this.onTap});
  final String hint;
  final Color fill;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(borderRadius: MqRadius.brMd, side: BorderSide(color: border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg, vertical: MqSpacing.md),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: mq.ink3, size: MqSize.iconMd),
              MqSpacing.gapSm,
              Expanded(
                child: Text(hint,
                    style: context.text.bodyMedium?.copyWith(color: mq.ink3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
