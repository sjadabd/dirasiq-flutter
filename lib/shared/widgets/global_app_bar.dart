import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/features/auth/screens/login_screen.dart';
import 'package:dirasiq/features/search/screens/student_unified_search_screen.dart';
import 'package:dirasiq/shared/controllers/global_controller.dart';
import 'package:dirasiq/shared/controllers/theme_controller.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final void Function(String query)? onSearch;

  const GlobalAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.onSearch,
  });

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = Get.find<GlobalController>();

    return AppBar(
      backgroundColor: cs.surface,
      elevation: 0,
      toolbarHeight: 50,
      titleSpacing: 8,
      automaticallyImplyLeading: false,
      title: SafeArea(
        child: Row(
          children: [
            // ✅ الصورة الشخصية + قائمة الحساب
            PopupMenuButton<String>(
              tooltip: 'الحساب',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              offset: const Offset(0, 50),
              onSelected: (value) async {
                if (value == 'profile') {
                  await Navigator.pushNamed(context, '/student-profile');
                  controller.loadUser();
                } else if (value == 'logout') {
                  await AuthService().logout();
                  Get.offAll(() => LoginScreen());
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('الملف الشخصي'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('تسجيل الخروج'),
                ),
              ],
              child: Obx(() {
                final user = controller.user.value;
                final avatar = _buildAvatar(user, cs);
                return avatar;
              }),
            ),

            const SizedBox(width: 10),
            // شعار التطبيق صغير في الشريط
            Image.asset(
              'assets/logo.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 10),

            // ✅ حقل البحث
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'ابحث...',
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentUnifiedSearchScreen(),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ✅ تبديل الوضع الليلي والنهاري
            IconButton(
              tooltip: 'تبديل النمط',
              icon: Icon(
                Get.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: cs.onSurface,
              ),
              onPressed: () {
                ThemeController.to.toggleDarkLight();
              },
            ),

            // ✅ الإشعارات مع الشارة
            Obx(() {
              final count = controller.unreadCount.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'الإشعارات',
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: cs.onSurface,
                    ),
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/notifications');
                      controller.loadUnread();
                    },
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
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic>? user, ColorScheme cs) {
    final provider = _avatarImageProvider(user);
    if (provider != null) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: cs.surface,
        foregroundImage: provider,
        child: const SizedBox.shrink(),
      );
    }
    final initials = _userInitials(user);
    return CircleAvatar(
      radius: 18,
      backgroundColor: cs.primary.withOpacity(0.15),
      child: Text(
        initials,
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
      ),
    );
  }

  ImageProvider<Object>? _avatarImageProvider(Map<String, dynamic>? user) {
    final possibleB64 = [
      'profileImageBase64',
      'avatarBase64',
      'imageBase64',
      'photoBase64',
    ];
    for (final key in possibleB64) {
      final raw = user?[key]?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          final b64 = raw.contains(',') ? raw.split(',').last : raw;
          return MemoryImage(base64Decode(b64));
        } catch (_) {}
      }
    }

    final possibleUrls = [
      'profileImagePath',
      'profileImageUrl',
      'profileImage',
      'avatarUrl',
      'photoUrl',
      'photoURL',
      'imageUrl',
      'image',
      'avatar',
      'profile_photo_url',
      'profilePhotoUrl',
    ];
    for (final key in possibleUrls) {
      final url = user?[key]?.toString();
      if (url != null && url.isNotEmpty) {
        final normalized = _normalizeImageUrl(url);
        return NetworkImage(normalized);
      }
    }

    // Nested fallbacks like profile.imageUrl, account.profileImage, data.image
    final nestedKeys = [
      ['profile', 'imageUrl'],
      ['profile', 'avatar'],
      ['account', 'profileImage'],
      ['data', 'image'],
    ];
    for (final path in nestedKeys) {
      dynamic val = user;
      for (final key in path) {
        val = (val is Map) ? val[key] : null;
      }
      if (val is String && val.isNotEmpty) {
        final normalized = _normalizeImageUrl(val);
        return NetworkImage(normalized);
      }
    }
    return null;
  }

  // Normalize various URL shapes to a usable absolute URL
  String _normalizeImageUrl(String raw) {
    String s = raw.trim();
    if (s.isEmpty) return s;

    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('data:image')) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('//')) {
      final scheme = Uri.parse(AppConfig.serverBaseUrl).scheme;
      return '$scheme:$s';
    }
    String path = s.replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base$path';
  }

  String _userInitials(Map<String, dynamic>? user) {
    final name = (user?['name']?.toString() ?? '').trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }
}
