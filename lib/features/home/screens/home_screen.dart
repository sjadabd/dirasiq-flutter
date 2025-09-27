import 'package:dirasiq/features/courses/widgets/suggested_courses_widget.dart';
import 'package:flutter/material.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/features/home/widgets/news_carousel.dart'; // Added import for news carousel
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:dirasiq/features/auth/screens/login_screen.dart';
import 'package:dirasiq/core/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  int _unreadCount = 0;
  int _refreshToken = 0; // لتمريره للويدجتس لإعادة التحميل
  // مفتاح لإجبار إعادة بناء عناصر الصفحة بشكل كامل عند السحب للتحديث
  Key _refreshKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnread();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  Future<void> _loadUnread() async {
    try {
      final count = await _api.fetchUnreadNotificationsCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await _loadUnread();
    if (!mounted) return;
    setState(() {
      _refreshToken++; // لإعادة تحميل الأبناء مثل NewsCarousel
      _refreshKey = UniqueKey(); // إجبار إعادة بناء كامل للواجهة
    });
  }

  void _logout(BuildContext context) async {
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
            content: Text('حدث خطأ في تسجيل الخروج'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          "الرئيسية - درس عراق",
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
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
                      // تحديث العداد بعد العودة من شاشة الإشعارات
                      await _loadUnread();
                    } catch (e) {
                      // ignore
                    }
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
          ),
          const SizedBox(width: 4),
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.white.withValues(alpha: 0.2),
                  offset: Offset(0, 2),
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
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                ),
                PopupMenuDivider(height: 1),
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
                try {
                  if (!context.mounted) return;

                  if (value == 'profile') {
                    Navigator.pushNamed(context, '/student-profile');
                  } else if (value == 'logout') {
                    _logout(context);
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ في التنقل'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.transparent,
                  child: Icon(Icons.person, size: 20, color: AppColors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: KeyedSubtree(
          key: _refreshKey,
          child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.background, AppColors.surfaceVariant],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                NewsCarousel(refreshToken: _refreshToken),

                SuggestedCoursesCompact(),

                const SizedBox(height: 8),
                const SizedBox(height: 20),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
