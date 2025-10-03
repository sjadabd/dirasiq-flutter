import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/features/auth/screens/login_screen.dart';
import 'package:dirasiq/core/services/notification_events.dart';
import 'dart:async';

class GlobalAppBar extends StatefulWidget implements PreferredSizeWidget {
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
  Size get preferredSize => const Size.fromHeight(72);

  @override
  State<GlobalAppBar> createState() => _GlobalAppBarState();
}

class _GlobalAppBarState extends State<GlobalAppBar>
    with WidgetsBindingObserver {
  final _api = ApiService();
  final _auth = AuthService();
  int _unreadCount = 0;
  StreamSubscription<void>? _notifSub;
  StreamSubscription<Map<String, dynamic>>? _payloadSub;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _loadUnread();
    _notifSub = NotificationEvents.instance.onNewNotification.listen((_) {
      _loadUnread();
    });
    _payloadSub = NotificationEvents.instance.onNotificationPayload.listen((_) {
      // زيّد الشارة فوراً بشكل تفاؤلي، وسيتم التصحيح عبر _loadUnread لاحقاً
      if (!mounted) return;
      setState(() => _unreadCount = (_unreadCount + 1).clamp(0, 999));
      // أعد الحساب من الخادم بعد لحظات لتأكيد العدد
      Future.delayed(const Duration(milliseconds: 800), _loadUnread);
    });
  }

  Future<void> _loadUser() async {
    try {
      final u = await _auth.getUser();
      if (!mounted) return;
      setState(() => _user = u);
    } catch (_) {}
  }

  Future<void> _loadUnread() async {
    try {
      final unread = await _api.fetchUnreadNotificationsCount();
      if (!mounted) return;
      setState(() => _unreadCount = unread);
    } catch (_) {}
  }

  Future<void> _logout(BuildContext context) async {
    try {
      if (!context.mounted) return;
      final authService = AuthService();
      await authService.logout();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('حدث خطأ في تسجيل الخروج'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: cs.surface,
      elevation: 0,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: SafeArea(
        child: Row(
          children: [
            // Profile popup avatar
            PopupMenuButton<String>(
              tooltip: 'الحساب',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              offset: const Offset(0, 50),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'الملف الشخصي',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: AppColors.error),
                    title: Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              onSelected: (value) async {
                if (!context.mounted) return;
                if (value == 'profile') {
                  await Navigator.pushNamed(context, '/student-profile');
                  if (mounted) _loadUser();
                } else if (value == 'logout') {
                  _logout(context);
                }
              },
              child: _buildAvatar(cs),
            ),
            const SizedBox(width: 12),

            // Search field
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) => widget.onSearch?.call(q),
                  onTapOutside: (_) {
                    _searchFocusNode.unfocus();
                  },
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'ابحث...',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                    filled: true,
                    fillColor: cs.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    prefixIcon: Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.primary, width: 1.2),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Theme toggle
            IconButton(
              tooltip: 'تبديل النمط',
              icon: Icon(
                Get.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: cs.onSurface,
              ),
              onPressed: () {
                final next = Get.isDarkMode ? ThemeMode.light : ThemeMode.dark;
                Get.changeThemeMode(next);
              },
            ),

            // Notifications with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'الإشعارات',
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: cs.onSurface,
                  ),
                  onPressed: () async {
                    try {
                      if (!context.mounted) return;
                      await Navigator.pushNamed(context, '/notifications');
                      await _loadUnread();
                    } catch (_) {}
                  },
                ),
                if (_unreadCount > 0)
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
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _notifSub?.cancel();
    _payloadSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnread();
      _loadUser();
    }
  }

  Widget _buildAvatar(ColorScheme cs) {
    final provider = _avatarImageProvider();
    if (provider != null) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: provider,
        backgroundColor: Colors.transparent,
      );
    }
    final initials = _userInitials();
    return CircleAvatar(
      radius: 18,
      backgroundColor: cs.primary.withOpacity(0.15),
      child: Text(
        initials,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  ImageProvider<Object>? _avatarImageProvider() {
    // Try base64 fields
    final possibleB64Keys = [
      'profileImageBase64',
      'avatarBase64',
      'photoBase64',
      'imageBase64',
    ];
    for (final k in possibleB64Keys) {
      final raw = _user?[k]?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          final b64 = raw.contains(',') ? raw.split(',').last : raw; // handle data URLs
          return MemoryImage(base64Decode(b64));
        } catch (_) {}
      }
    }

    // Try URL/path fields
    final possibleUrlKeys = [
      'profileImageUrl',
      'profileImagePath',
      'avatarUrl',
      'photoUrl',
      'imageUrl',
      'profileImage',
      'avatar',
      'photo',
      'image',
    ];
    for (final k in possibleUrlKeys) {
      final url = _user?[k]?.toString();
      if (url != null && url.isNotEmpty) {
        if (url.startsWith('http')) return NetworkImage(url);
        if (url.startsWith('/')) return NetworkImage('${AppConfig.serverBaseUrl}$url');
      }
    }
    return null;
  }

  String _userInitials() {
    final name = (_user?['name']?.toString() ?? '').trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts[0].substring(0, 1);
    String second = '';
    if (parts.length > 1) {
      second = parts[1].substring(0, 1);
    }
    return (first + second).toUpperCase();
  }
}
