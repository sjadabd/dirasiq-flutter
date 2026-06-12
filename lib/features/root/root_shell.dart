import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// v3 home — design-system Student Home, embedded so RootShell owns the chrome.
// The previous v2 home (StudentMyTeachersHome) stays on disk for rollback.
import 'package:mulhimiq/features/student_home/presentation/pages/student_home_screen.dart';
import 'package:mulhimiq/features/courses/screens/suggested_courses_screen.dart';
import 'package:mulhimiq/features/bookings/screens/bookings_list_screen.dart';
import 'package:mulhimiq/features/enrollments/screens/enrollments_screen.dart';
import 'package:mulhimiq/features/invoices/screens/student_invoices_screen.dart';
import 'package:mulhimiq/features/root/widgets/student_bottom_nav.dart';

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
      const StudentHomeScreen(embedded: true),
      const SuggestedCoursesScreen(),
      const EnrollmentsScreen(),
      const StudentInvoicesScreen(),
      BookingsListScreen(onNavigateToTab: navigateToTab),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
            _tabVersion[0]++;
          });
          return;
        }
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
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(top: false, bottom: true, child: _buildCurrentPage()),
        bottomNavigationBar: StudentBottomNav(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() {
              _currentIndex = i;
              _tabVersion[i]++;
            });
          },
        ),
      ),
    );
  }
}
