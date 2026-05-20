import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../core/services/auth_service.dart';
import '../chat/screens/teacher_conversations_screen.dart';
import '../chat/services/chat_unread_service.dart';
import '../profile/teacher_profile_screen.dart';

/// App bar used by every teacher tab.
///
/// One avatar on the leading side opens the profile route — that's the ONLY
/// place where logout lives. No logout button is rendered anywhere else.
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  Future<Map<String, dynamic>?> _readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null || raw.isEmpty) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  Future<String?> _readContentUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('content_url');
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts.last.characters.first;
  }

  String? _resolveAvatarUrl(Map<String, dynamic> user, String? contentUrl) {
    final path = (user['profileImagePath'] ?? user['profileImage'] ?? '').toString();
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('data:')) {
      return path;
    }
    final base = (contentUrl ?? 'https://api.mulhimiq.com').replaceAll(RegExp(r'/$'), '');
    final rel = path.startsWith('/') ? path : '/$path';
    return '$base$rel';
  }

  void _openProfile() {
    Get.to(() => const TeacherProfileScreen());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      elevation: 0,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      titleSpacing: 0,
      // Title block — small two-line text aligned to start.
      title: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(subtitle!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
      actions: [
        // Default chat shortcut on EVERY teacher tab. Lives before the
        // per-tab `actions` so the position stays consistent.
        const _TeacherChatIconWithBadge(),
        if (actions != null) ...actions!,
        // Avatar opens the profile page — single source of profile + logout.
        FutureBuilder<Map<String, dynamic>?>(
          future: _readUser(),
          builder: (context, snap) {
            final user = snap.data;
            final name = user?['name']?.toString();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: _openProfile,
                child: FutureBuilder<String?>(
                  future: _readContentUrl(),
                  builder: (ctx, urlSnap) {
                    final avatar = user != null ? _resolveAvatarUrl(user, urlSnap.data) : null;
                    return CircleAvatar(
                      radius: 18,
                      backgroundColor: cs.primary,
                      foregroundImage: avatar != null ? NetworkImage(avatar) : null,
                      child: Text(
                        _initials(name),
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
    );
  }
}

/// Helper: navigate to the profile and return only after it closes.
/// Currently unused but exposed for future deep-links.
Future<void> openTeacherProfile() async {
  await Get.to(() => const TeacherProfileScreen());
}

/// Sign out (single source of truth). Used by the profile screen.
Future<void> teacherLogout() async {
  await AuthService().logout();
  Get.offAllNamed('/login');
}

// Chat icon + reactive unread badge for the teacher AppBar. Mirrors the
// student-side `_ChatIconWithBadge` but routes to the teacher list screen,
// which exposes the "create group" action and the manage-members entry
// points students don't have.
//
// Doubles as a fallback bootstrap for `ChatUnreadService.start(userId)` —
// the service is also booted from `GlobalController._initialize`, but a
// mid-session login (logout → login without app restart) doesn't re-run
// that path. `start()` is idempotent.
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
      // Idempotent — short-circuits if already running for this user.
      ChatUnreadService.instance.start(_userId!);
    } catch (_) {
      // Service not yet registered (extremely early in the boot graph).
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      int count = 0;
      try {
        count = ChatUnreadService.instance.total.value;
      } catch (_) {
        // Service not registered — render the icon without a badge.
      }
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'المحادثات',
            icon: Icon(Icons.forum_outlined, color: cs.onSurface),
            onPressed: () =>
                Get.to(() => const TeacherConversationsScreen()),
          ),
          if (count > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
