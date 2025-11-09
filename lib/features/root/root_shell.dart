import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mulhimiq/features/home/screens/home_screen.dart';
import 'package:mulhimiq/features/courses/screens/suggested_courses_screen.dart';
import 'package:mulhimiq/features/bookings/screens/bookings_list_screen.dart';
import 'package:mulhimiq/features/enrollments/screens/enrollments_screen.dart';
import 'package:mulhimiq/features/invoices/screens/student_invoices_screen.dart';

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
    final cs = Theme.of(context).colorScheme;

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
            backgroundColor: cs.surface,
            indicatorColor: cs.primary.withValues(alpha: 0.12),
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
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school),
                label: 'دوراتي',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'فواتيري',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'حجوزاتي',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
