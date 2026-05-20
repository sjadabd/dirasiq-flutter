import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../home/teacher_home_screen.dart';
import '../sessions/teacher_sessions_screen.dart';
import '../bookings/teacher_bookings_screen.dart';
import '../notifications/teacher_notifications_screen.dart';
import '../profile/teacher_profile_screen.dart';

/// Five-tab teacher shell mirroring the student RootShell's structure.
///
/// Tab layout (right-to-left visual order in Arabic):
///   0 — الرئيسية (Home)
///   1 — الجدول (Sessions)
///   2 — الحجوزات (Bookings)
///   3 — الإشعارات (Notifications)
///   4 — حسابي (Profile)
///
/// IMPORTANT — mobile teacher scope:
///   • Subscription / Wayl payment is dashboard-only by design — no tab here
///     triggers a payment flow; billing actions deep-link to the web dashboard.
///   • Teacher account creation is dashboard-only — no signup CTA in the
///     profile tab; only edit / logout are exposed.
class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  // Bump per tab to force a fresh KeyedSubtree (mirrors student RootShell).
  final List<int> _tabVersion = [0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _pages = const <Widget>[
      TeacherHomeScreen(),
      TeacherSessionsScreen(),
      TeacherBookingsScreen(),
      TeacherNotificationsScreen(),
      TeacherProfileScreen(),
    ];
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
      _tabVersion[index]++;
    });
  }

  Widget _buildCurrentPage() {
    final page = _pages[_currentIndex];
    return KeyedSubtree(
      key: ValueKey('teacher-tab-$_currentIndex-${_tabVersion[_currentIndex]}'),
      child: page,
    );
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هل تريد الخروج من التطبيق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
        ],
      ),
    );
    if (exit == true) SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        body: _buildCurrentPage(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _navigateToTab,
          backgroundColor: cs.surface,
          indicatorColor: cs.primary.withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'الجدول',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_turned_in_outlined),
              selectedIcon: Icon(Icons.assignment_turned_in),
              label: 'الحجوزات',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'الإشعارات',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}
