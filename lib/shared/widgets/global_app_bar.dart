import 'package:flutter/material.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/features/auth/screens/login_screen.dart';
import 'package:dirasiq/core/services/notification_events.dart';
import 'dart:async';

class GlobalAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;

  const GlobalAppBar({super.key, required this.title, this.centerTitle = false});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<GlobalAppBar> createState() => _GlobalAppBarState();
}

class _GlobalAppBarState extends State<GlobalAppBar> with WidgetsBindingObserver {
  final _api = ApiService();
  int _unreadCount = 0;
  StreamSubscription<void>? _notifSub;
  StreamSubscription<Map<String, dynamic>>? _payloadSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: widget.centerTitle,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.gradientWelcome,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Text(
        widget.title,
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        // Notifications button with badge
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'الإشعارات',
                icon: Icon(
                  Icons.notifications_outlined,
                  color: AppColors.white,
                  size: 22,
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        ),
        const SizedBox(width: 4),
        // Profile popup
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.white.withOpacity(0.2),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: PopupMenuButton<String>(
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
                  leading: Icon(Icons.person_outline, color: AppColors.primary),
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
                Navigator.pushNamed(context, '/student-profile');
              } else if (value == 'logout') {
                _logout(context);
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.transparent,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _payloadSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnread();
    }
  }
}
