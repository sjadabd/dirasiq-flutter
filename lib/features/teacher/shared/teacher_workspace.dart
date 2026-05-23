import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bookings/teacher_bookings_screen.dart';
import '../chat/screens/teacher_conversations_screen.dart';
import '../courses/teacher_courses_screen.dart';
import '../expenses/teacher_expenses_screen.dart';
import '../home/teacher_home_screen.dart';
import '../invoices/teacher_invoices_screen.dart';
import '../notifications/teacher_notifications_screen.dart';
import '../profile/teacher_profile_screen.dart';
import '../reports/teacher_reports_screen.dart';
import '../reservation_payments/teacher_reservation_payments_screen.dart';
import '../sessions/teacher_sessions_screen.dart';
import '../subjects/teacher_subjects_screen.dart';
import '../video_courses/teacher_video_courses_screen.dart';
import '../wallet/teacher_wallet_screen.dart';
import 'teacher_app_bar.dart';

/// The single Scaffold owner for the entire teacher area.
///
/// All teacher "pages" are children of a lazy IndexedStack inside this
/// workspace. The page widgets remain MOUNTED once visited so:
///   • Scroll positions, filter chips, search terms survive navigation.
///   • Tabs feel instantaneous (no rebuild, no API re-fetch).
///   • The browser/device back button has a real history to walk.
///
/// Each page widget keeps its own Scaffold for now — Flutter renders nested
/// Scaffolds fine; the outer workspace doesn't show its own AppBar to avoid
/// double headers (each page's AppBar is what the user sees). The outer
/// Scaffold supplies the Drawer + BottomNav so the chrome is consistent.
///
/// History + back-button:
///   • Tapping a menu/nav item pushes the new index onto an internal stack.
///   • PopScope intercepts back: pops the internal stack first; only when
///     the stack is empty do we ask the user to exit the app.
///
/// State preservation: IndexedStack keeps everything mounted by default.
/// Lazy mount: pages that have NEVER been visited render as a thin loader
/// until the user opens them the first time (so we don't fire 12 API calls
/// on cold start).
class TeacherWorkspace extends StatefulWidget {
  const TeacherWorkspace({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<TeacherWorkspace> createState() => TeacherWorkspaceState();

  /// Tap target for anything that wants to navigate WITHIN the workspace
  /// (drawer items, bottom-nav tabs, in-page deep links).
  ///
  /// Falls back to a normal Get.toNamed if no workspace is on the tree
  /// (e.g. during the very first login flow before the workspace mounts).
  static void switchTo(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<TeacherWorkspaceState>();
    if (state != null) {
      state.goTo(index);
    }
  }

  /// Quick reads from anywhere (drawer uses this for the active highlight).
  static int? currentIndexOf(BuildContext context) {
    return context.findAncestorStateOfType<TeacherWorkspaceState>()?._currentIndex;
  }
}

class TeacherWorkspaceState extends State<TeacherWorkspace> {
  // -- Page registry ----------------------------------------------------------
  // Order matches the drawer + bottom nav. Keep in sync with TeacherRoutes
  // (used by deep-link lookups elsewhere). The first 5 are also the bottom-nav
  // quick tabs (Home / Sessions / Bookings / Notifications / Profile) — for
  // those we just index into _pages directly.
  static const int homeIdx                = 0;
  static const int reservationPaymentsIdx = 1;
  static const int invoicesIdx            = 2;
  static const int expensesIdx            = 3;
  static const int reportsIdx             = 4;
  static const int walletIdx              = 5;
  static const int subjectsIdx            = 6;
  static const int coursesIdx             = 7;
  static const int videoCoursesIdx        = 8;
  static const int sessionsIdx            = 9;
  static const int bookingsIdx            = 10;
  static const int notificationsIdx       = 11;
  static const int profileIdx             = 12;
  static const int chatsIdx               = 13;

  late final List<Widget> _pages = const [
    TeacherHomeScreen(),                  // 0
    TeacherReservationPaymentsScreen(),   // 1
    TeacherInvoicesScreen(),              // 2
    TeacherExpensesScreen(),              // 3
    TeacherReportsScreen(),               // 4
    TeacherWalletScreen(),                // 5
    TeacherSubjectsScreen(),              // 6
    TeacherCoursesScreen(),               // 7 — live/classroom courses
    TeacherVideoCoursesScreen(),          // 8 — pre-recorded VOD (Phase 10.1.B)
    TeacherSessionsScreen(),              // 9
    TeacherBookingsScreen(),              // 10
    TeacherNotificationsScreen(),         // 11
    TeacherProfileScreen(),               // 12
    TeacherConversationsScreen(),         // 13 — chat (Phase 6)
  ];

  // -- State ------------------------------------------------------------------
  int _currentIndex = 0;
  // Internal navigation stack — drives back-button behaviour. Always contains
  // at least one entry (the entry index, default 0).
  final List<int> _history = <int>[0];
  // Which pages have been opened at least once (so we can lazy-mount them).
  final Set<int> _visited = <int>{0};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _history[0] = _currentIndex;
    _visited.add(_currentIndex);
  }

  /// Switch to a page. Same-index taps are no-ops (so re-tapping the active
  /// item in the drawer just closes the drawer instead of navigating).
  void goTo(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _visited.add(index);
      _history.add(index);
      // Keep the stack bounded (typical SaaS dashboards allow ~20 levels).
      if (_history.length > 30) _history.removeAt(0);
    });
  }

  Future<bool> _onWillPop() async {
    // 1) If there are previous pages in the workspace stack → go back inside
    //    the workspace (no Navigator.pop, no GetX route changes).
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _currentIndex = _history.last;
      });
      return false;
    }
    // 2) Otherwise we're at the bottom of the workspace → ask before exiting
    //    the app. This prevents accidental exits the user complained about.
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هل تريد الخروج من التطبيق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
        ],
      ),
    );
    if (exit == true) {
      SystemNavigator.pop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < _pages.length; i++)
            // Lazy mount: pages not yet visited render a minimal placeholder.
            // First visit replaces the placeholder with the real widget, and
            // from then on IndexedStack keeps it mounted (state preserved).
            _visited.contains(i)
                ? _pages[i]
                : const _LazyPlaceholder(),
        ],
      ),
    );
  }
}

class _LazyPlaceholder extends StatelessWidget {
  const _LazyPlaceholder();
  @override
  Widget build(BuildContext context) {
    // Wrap in Scaffold so an unmounted IndexedStack child still has a
    // material context. Body is a thin loader — invisible to the user
    // because IndexedStack only shows the active child.
    return const Scaffold(
      appBar: TeacherAppBar(title: ''),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Convenience: jump to a named page from anywhere (e.g. after login).
class TeacherNav {
  TeacherNav._();
  static void open(BuildContext ctx, int index) => TeacherWorkspace.switchTo(ctx, index);
}
