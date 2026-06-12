import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../core/services/auth_service.dart';
import '../../../shared/controllers/global_controller.dart';
import '../../../shared/controllers/theme_controller.dart';
import 'design/teacher_design.dart';
import '../chat/screens/teacher_conversations_screen.dart';
import '../chat/services/chat_unread_service.dart';
import '../profile/teacher_profile_screen.dart';

/// Global header for every teacher page.
///
/// Persistent (pinned) chrome built from the Teacher Design System — the same
/// `context.mq` tokens, Cairo type, soft `fill`+`line` icon chips, and rounded
/// icon set the dashboard cards use, so the header reads as part of the new
/// teacher UI rather than stock Material chrome.
///
/// Action order (RTL, from the title outward): 🔔 notifications · 💬 chat ·
/// 🌙 theme. Communication controls sit nearest the title; the theme utility
/// sits at the far edge. Notifications + chat carry reactive unread badges.
/// The leading slot is a matching chip — the drawer menu, or a back button on
/// pushed screens. Profile/identity lives in the home greeting card, the
/// drawer, and the bottom-nav "حسابي" tab.
class TeacherAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TeacherAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: mq.card,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 60,
      leading: Builder(
        builder: (context) {
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold?.hasDrawer ?? false) {
            return Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _HeaderChip(
                icon: Icons.menu_rounded,
                tooltip: 'القائمة',
                onTap: scaffold!.openDrawer,
              ),
            );
          }
          if (Navigator.of(context).canPop()) {
            return Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _HeaderChip(
                icon: Icons.arrow_forward_rounded,
                tooltip: 'رجوع',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium?.copyWith(color: mq.ink)),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: mq.ink3)),
        ],
      ),
      actions: [
        if (actions != null) ...[
          ...actions!,
          const SizedBox(width: MqSpacing.sm),
        ],
        const _TeacherNotificationBell(),
        const SizedBox(width: MqSpacing.sm),
        const _TeacherChatIconWithBadge(),
        const SizedBox(width: MqSpacing.sm),
        const _TeacherThemeToggle(),
        const SizedBox(width: MqSpacing.lg),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: mq.line),
      ),
    );
  }
}

/// Navigate to the profile (exposed for deep-links / external callers).
Future<void> openTeacherProfile() async {
  await Get.to(() => const TeacherProfileScreen());
}

/// Sign out (single source of truth). Used by the profile screen.
Future<void> teacherLogout() async {
  await AuthService().logout();
  Get.offAllNamed('/login');
}

// ---------------------------------------------------------------------------
// _HeaderChip — the shared design-system icon button for the header
// ---------------------------------------------------------------------------

/// A 40×40 soft icon chip: `mq.fill` background, hairline `mq.line` border,
/// rounded-square (`brMd`), `mq.ink2` icon — the same treatment as the KPI /
/// dashboard-card icon badges. Optional reactive [badge] count pill.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final fg = mq.ink2;
    final bg = mq.fill;
    final border = mq.line;

    final chip = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: MqRadius.brMd,
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Icon(icon, size: MqSize.iconSm, color: fg),
        ),
      ),
    );

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            chip,
            if (badge > 0)
              PositionedDirectional(
                top: -4,
                end: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: mq.error,
                    borderRadius: MqRadius.brPill,
                    border: Border.all(color: mq.card, width: 1.5),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dark / light toggle
// ---------------------------------------------------------------------------

class _TeacherThemeToggle extends StatelessWidget {
  const _TeacherThemeToggle();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Touch the observable so the icon flips reactively on toggle.
      ThemeController.to.themeMode.value;
      final isDark = Get.isDarkMode;
      return _HeaderChip(
        icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        tooltip: 'تبديل النمط',
        onTap: ThemeController.to.toggleDarkLight,
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Notification bell + reactive unread badge
// ---------------------------------------------------------------------------

class _TeacherNotificationBell extends StatelessWidget {
  const _TeacherNotificationBell();

  @override
  Widget build(BuildContext context) {
    GlobalController? gc;
    try {
      gc = Get.find<GlobalController>();
    } catch (_) {
      gc = null;
    }

    Future<void> open() async {
      await Get.toNamed('/notifications');
      gc?.loadUnread();
    }

    if (gc == null) {
      return _HeaderChip(
          icon: Icons.notifications_outlined, tooltip: 'الإشعارات', onTap: open);
    }

    final controller = gc;
    return Obx(() => _HeaderChip(
          icon: Icons.notifications_outlined,
          tooltip: 'الإشعارات',
          badge: controller.unreadCount.value,
          onTap: open,
        ));
  }
}

// ---------------------------------------------------------------------------
// Chat icon + reactive unread badge
// ---------------------------------------------------------------------------
//
// Doubles as a fallback bootstrap for `ChatUnreadService.start(userId)` — the
// service is also booted from `GlobalController._initialize`, but a mid-session
// login (logout → login without app restart) doesn't re-run that path.
// `start()` is idempotent.
class _TeacherChatIconWithBadge extends StatefulWidget {
  const _TeacherChatIconWithBadge();

  @override
  State<_TeacherChatIconWithBadge> createState() =>
      _TeacherChatIconWithBadgeState();
}

class _TeacherChatIconWithBadgeState extends State<_TeacherChatIconWithBadge> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null || raw.isEmpty) return;
    try {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      _userId = (user['id'] ?? user['_id'])?.toString();
    } catch (_) {}
    if (_userId == null || _userId!.isEmpty) return;
    try {
      ChatUnreadService.instance.start(_userId!);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    void open() => Get.to(() => const TeacherConversationsScreen());
    return Obx(() {
      int count = 0;
      try {
        count = ChatUnreadService.instance.total.value;
      } catch (_) {}
      return _HeaderChip(
        icon: Icons.chat_bubble_outline_rounded,
        tooltip: 'المحادثات',
        badge: count,
        onTap: open,
      );
    });
  }
}
