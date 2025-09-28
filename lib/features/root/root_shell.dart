import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/features/home/screens/home_screen.dart';
import 'package:dirasiq/features/notifications/notifications_screen.dart';
import 'package:dirasiq/features/profile/student_profile_screen.dart';
import 'package:dirasiq/features/courses/screens/suggested_courses_screen.dart';
import 'package:dirasiq/features/bookings/screens/bookings_list_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  // نسخة لكل تبويب لإجبار إعادة البناء عند تغييره
  final List<int> _tabVersion = [0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      const SuggestedCoursesScreen(),
      BookingsListScreen(onNavigateToTab: navigateToTab),
      const NotificationsScreen(),
      const StudentProfileScreen(),
    ];
  }

  void navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
      _tabVersion[index]++;
    });
  }

  Widget _buildCurrentPage() {
    final page = _pages[_currentIndex];
    return KeyedSubtree(
      key: ValueKey('tab-$_currentIndex-${_tabVersion[_currentIndex]}'),
      child: page,
    );
  }

  Future<bool> _handleWillPop() async {
    if (_currentIndex != 0) {
      // ✅ لو مو على الرئيسية → رجعه للرئيسية
      setState(() {
        _currentIndex = 0;
        _tabVersion[0]++;
      });
      return Future.value(false); // منع الخروج
    }

    // ✅ لو على الرئيسية → اعرض رسالة التأكيد
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هل تريد الخروج من التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      SystemNavigator.pop(); // خروج فعلي
      return Future.value(true);
    }

    return Future.value(false); // لا يخرج
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.lightScheme;

    return WillPopScope(
      onWillPop: _handleWillPop, // ربط المعالجة بزِر الرجوع
      child: Scaffold(
        body: SafeArea(top: false, bottom: true, child: _buildCurrentPage()),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 6),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) {
              setState(() {
                _currentIndex = i;
                _tabVersion[i]++;
              });
            },
            backgroundColor: scheme.surface,
            indicatorColor: scheme.primary.withOpacity(0.12),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'الدورات',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'حجوزاتي',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'الإشعارات',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'الحساب',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
