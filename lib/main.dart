import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/config/initial_bindings.dart';
import 'core/services/notification_service.dart';
import 'core/services/realtime_service.dart';
import 'shared/themes/app_colors.dart';
import 'shared/controllers/theme_controller.dart';
import 'shared/design_system/design_system.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

// ✅ الشاشات
import 'features/splash/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/teacher_application/screens/join_as_teacher_screen.dart';
import 'features/profile/complete_profile_screen.dart';
import 'features/profile/student_profile_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/courses/screens/suggested_courses_screen.dart';
import 'features/courses/screens/course_details_screen.dart';
import 'features/student/video_courses/student_video_courses_screen.dart';
import 'features/student/video_courses/student_video_course_detail_screen.dart';
import 'features/video_marketplace/screens/video_marketplace_screen.dart';
import 'features/root/root_shell.dart';
import 'features/content_feed/screens/content_detail_screen.dart';
import 'features/bookings/screens/bookings_list_screen.dart';
import 'features/bookings/screens/booking_details_screen.dart';
import 'features/enrollments/screens/enrollments_screen.dart';
import 'features/enrollments/screens/enrollment_actions_screen.dart';
import 'features/course_hub/screens/course_hub_screen.dart';
import 'features/course_hub/screens/teacher_courses_picker_screen.dart';
import 'features/qr/qr_scan_screen.dart';
import 'features/enrollments/screens/course_weekly_schedule_screen.dart';
import 'features/enrollments/screens/course_attendance_screen.dart';
import 'features/invoices/screens/student_invoices_screen.dart';
import 'features/invoices/screens/invoice_details_screen.dart';
import 'features/teachers/screens/suggested_teachers_screen.dart';
import 'features/teachers/screens/teacher_details_screen.dart';
import 'features/teacher/shared/teacher_routes.dart';
import 'features/teacher/shared/teacher_workspace.dart';
import 'features/student/chat/screens/student_conversations_screen.dart';
import 'features/student_home/presentation/pages/student_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

  final id = OneSignal.User.pushSubscription.id;
  debugPrint("PLAYER ID => $id");

  Get.put(ThemeController(), permanent: true);

  // Open the realtime socket if the user is already authenticated
  // (warm app start). The login flow opens it again on a fresh login.
  // No-op when no token is in SharedPreferences yet (caller-safe).
  unawaited(RealtimeService.instance.connect());

  // App-lifecycle observer that re-opens the realtime socket whenever
  // the user brings the app back to the foreground. Android can
  // suspend the network stack when the app is backgrounded for a few
  // minutes, killing the WebSocket — `connect()` is idempotent so this
  // is safe to call on every resume.
  WidgetsBinding.instance.addObserver(_RealtimeLifecycleHook());

  runApp(const MyApp());
}

/// Re-opens the realtime socket whenever the app comes back to the
/// foreground. Without this, Android's network suspension while
/// backgrounded silently kills the WebSocket and the user's first sign
/// that anything is wrong is "the lesson card never updates".
///
/// The observer lives for the lifetime of the process — registered in
/// `main()` and never removed, by design.
class _RealtimeLifecycleHook extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: avoid_print
      print('[realtime] app resumed → ensuring socket is connected');
      unawaited(RealtimeService.instance.connect());
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.lightScheme;
    final dark = AppColors.darkScheme;
    final theme = ThemeController.to;

    return Obx(
      () => GetMaterialApp(
        title: 'Mulhim IQ',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        // ✅ الاتجاه الافتراضي RTL
        builder: (context, child) {
          final base = Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox(),
          );
          return _WhatsAppSupportOverlay(child: base);
        },

        themeMode: theme.themeMode.value,

        // ✅ الثيم الفاتح
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          fontFamily: GoogleFonts.cairo().fontFamily,
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.primary, width: 1.6),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: scheme.primary),
          ),
          cardTheme: CardThemeData(
            color: scheme.surface,
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // ✅ الثيم الداكن
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: dark,
          fontFamily: GoogleFonts.cairo().fontFamily,
          scaffoldBackgroundColor: AppColors.darkBackground,
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: dark.surface,
            foregroundColor: dark.onSurface,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: dark.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark.primary, width: 1.6),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: dark.primary,
              foregroundColor: dark.onPrimary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: dark.primary),
          ),
          cardTheme: CardThemeData(
            color: dark.surface,
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        initialBinding: InitialBindings(),
        smartManagement: SmartManagement.onlyBuilder,

        // ✅ تعريف الصفحات
        initialRoute: "/splash",
        getPages: [
          GetPage(name: "/splash", page: () => const SplashScreen()),
          GetPage(name: "/onboarding", page: () => const OnboardingScreen()),
          GetPage(name: "/login", page: () => LoginScreen()),
          // Teacher Onboarding (Phase 6). Public — does not require auth.
          // Routes the prospective teacher through the application form,
          // then back to /login once the super-admin approves them.
          GetPage(
            name: "/join-as-teacher",
            page: () => const JoinAsTeacherScreen(),
            transition: Transition.fadeIn,
          ),
          GetPage(name: "/home", page: () => const RootShell()),
          // Teacher entry route. RoleRouter dispatches here on userType=teacher.
          // The workspace owns a single Scaffold and swaps pages via an
          // IndexedStack — so the per-page Get routes are intentionally gone
          // (they'd unmount pages on each tap and break state preservation).
          GetPage(
            name: TeacherRoutes.home,
            page: () => const TeacherWorkspace(),
            // 300ms fade — feels like a premium SaaS dashboard, not a re-route.
            transition: Transition.fadeIn,
            transitionDuration: const Duration(milliseconds: 300),
          ),
          // Deep target for withdrawal-status notifications: opens the workspace
          // shell directly on the wallet tab (which hosts the "السحوبات" list).
          GetPage(
            name: TeacherRoutes.wallet,
            page: () => const TeacherWorkspace(
              initialIndex: TeacherWorkspaceState.walletIdx,
            ),
            transition: Transition.fadeIn,
            transitionDuration: const Duration(milliseconds: 300),
          ),
          GetPage(
            name: TeacherRoutes.advertisements,
            page: () => const TeacherWorkspace(
              initialIndex: TeacherWorkspaceState.advertisementsIdx,
            ),
            transition: Transition.fadeIn,
            transitionDuration: const Duration(milliseconds: 300),
          ),
          GetPage(
            name: '/content-detail',
            page: () => const ContentDetailScreen(),
            transition: Transition.rightToLeft,
          ),
          GetPage(
            name: "/complete-profile",
            page: () => const CompleteProfileScreen(),
          ),
          GetPage(
            name: "/student-profile",
            page: () => const StudentProfileScreen(),
          ),
          GetPage(
            name: "/notifications",
            page: () => const NotificationsScreen(),
          ),
          GetPage(name: "/enrollments", page: () => const EnrollmentsScreen()),
          GetPage(
            name: "/enrollment-actions",
            page: () {
              final args = Get.arguments as Map<String, dynamic>? ?? {};
              return EnrollmentActionsScreen(
                courseId: args['courseId'] ?? '',
                courseName: args['courseName'],
                teacherId: args['teacherId'],
              );
            },
          ),
          // Phase 6 — Unified Course Hub. The legacy /enrollment-actions
          // route above stays in place for back-compat with deep links;
          // navigation entry points pick between the two via
          // AppConfig.useNewCourseHub.
          GetPage(
            name: "/course-hub",
            page: () {
              final args = Get.arguments as Map<String, dynamic>? ?? {};
              return CourseHubScreen(
                courseId: (args['courseId'] ?? '').toString(),
                courseName: args['courseName']?.toString(),
                teacherId: args['teacherId']?.toString(),
              );
            },
          ),
          // Phase 6 — Teacher → Courses picker, used when a teacher card
          // is tapped from "My Teachers" and the student shares MORE
          // than one course with that teacher.
          GetPage(
            name: "/teacher-courses-picker",
            page: () {
              final args = Get.arguments as Map<String, dynamic>? ?? {};
              final raw = args['courses'];
              final courses = raw is List
                  ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
                  : <Map<String, dynamic>>[];
              return TeacherCoursesPickerScreen(
                teacherId: (args['teacherId'] ?? '').toString(),
                teacherName: (args['teacherName'] ?? '').toString(),
                courses: courses,
              );
            },
          ),
          GetPage(name: "/qr-scan", page: () => const QrScanScreen()),
          GetPage(
            name: "/course-weekly-schedule",
            page: () {
              final args = Get.arguments as Map<String, dynamic>? ?? {};
              return CourseWeeklyScheduleScreen(
                courseId: args['courseId'] ?? '',
                courseName: args['courseName'],
              );
            },
          ),
          GetPage(
            name: "/course-attendance",
            page: () {
              final args = Get.arguments as Map<String, dynamic>? ?? {};
              return CourseAttendanceScreen(
                courseId: args['courseId'] ?? '',
                courseName: args['courseName'],
              );
            },
          ),
          GetPage(name: "/invoices", page: () => const StudentInvoicesScreen()),
          GetPage(
            name: "/invoice-details",
            page: () {
              final id = Get.arguments as String;
              return InvoiceDetailsScreen(invoiceId: id);
            },
          ),
          GetPage(
            name: "/suggested-courses",
            page: () => const SuggestedCoursesScreen(),
          ),
          // Phase 10.1 — Student-side VOD video courses
          GetPage(
            name: "/student/video-courses",
            page: () => const StudentVideoCoursesScreen(),
          ),
          GetPage(
            name: "/student/video-course-details",
            page: () {
              final id = Get.arguments as String;
              return StudentVideoCourseDetailScreen(courseId: id);
            },
          ),
          // Phase 7 — National Video Marketplace
          GetPage(
            name: "/student/video-marketplace",
            page: () => const VideoMarketplaceScreen(),
          ),
          GetPage(
            name: "/course-details",
            page: () {
              final id = Get.arguments as String;
              return CourseDetailsScreen(courseId: id);
            },
          ),
          GetPage(
            name: "/suggested-teachers",
            page: () => const SuggestedTeachersScreen(),
          ),
          GetPage(
            name: "/teacher-details",
            page: () {
              final id = Get.arguments as String;
              return TeacherDetailsScreen(teacherId: id);
            },
          ),
          GetPage(name: "/bookings", page: () => const BookingsListScreen()),
          GetPage(
            name: "/booking-details",
            page: () {
              final id = Get.arguments as String;
              return BookingDetailsScreen(bookingId: id);
            },
          ),
          // Phase 7 — student chat list. The per-conversation screen is
          // pushed imperatively via Get.to() from the list, not registered
          // as a named route (it needs a conversationId + myUserId).
          GetPage(
            name: "/chat/conversations",
            page: () => const StudentConversationsScreen(),
          ),
          // Phase 1 — standalone QA route for the new design-system Student
          // Home. Not yet wired into RootShell; reach via Get.toNamed.
          GetPage(
            name: "/student-home",
            page: () => const StudentHomeScreen(),
          ),
        ],
      ),
    );
  }
}

// تمت إزالة اعتراض الخروج العام. تأكيد الخروج موجود فقط في RootShell (الصفحة الرئيسية).

class _WhatsAppSupportOverlay extends StatefulWidget {
  const _WhatsAppSupportOverlay({required this.child});
  final Widget child;

  @override
  State<_WhatsAppSupportOverlay> createState() =>
      _WhatsAppSupportOverlayState();
}

class _WhatsAppSupportOverlayState extends State<_WhatsAppSupportOverlay> {
  Offset? _offset;
  final String _localNumber = '07724275947';
  final String _countryCode = '964';

  // True while the user is actively scrolling — used to subtly fade the
  // support button. A ValueNotifier (not setState) so scrolling rebuilds only
  // the small button, never the whole app subtree below this overlay.
  final ValueNotifier<bool> _scrolling = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _scrolling.dispose();
    super.dispose();
  }

  String _normalizedNumber() {
    final digits = _localNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) {
      return digits.substring(1);
    }
    if (digits.startsWith('0')) {
      return _countryCode + digits.substring(1);
    }
    return digits;
  }

  Future<void> _openWhatsApp() async {
    final phone = _normalizedNumber();
    final uriApp = Uri.parse('whatsapp://send?phone=$phone');
    final uriWeb = Uri.parse('https://wa.me/$phone');
    try {
      if (await canLaunchUrl(uriApp)) {
        await launchUrl(uriApp, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mq = MediaQuery.of(context);
      final size = mq.size;
      final padding = mq.padding;
      const btnSize = 50.0;
      const margin = 16.0;
      final dxDefault = size.width - btnSize - margin;
      final dyDefault = size.height - btnSize - padding.bottom - margin - 80;
      if (mounted) {
        setState(() {
          _offset = Offset(dxDefault, dyDefault);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final padding = mq.padding;
    final btnSize = 50.0;
    final margin = 16.0;
    final pos =
        _offset ??
        Offset(
          size.width - btnSize - margin,
          size.height - btnSize - padding.bottom - margin - 80,
        );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pin the overlay to physical LTR so `Positioned(left:)` (and the drag
    // maths) stay absolute — the app inherits the MaterialApp's RTL, which
    // would otherwise mirror the button to the visual left. The wrapped child
    // keeps its own Directionality.rtl, so page content is unaffected.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
      children: [
        // Passive scroll listener — never consumes (returns false) and never
        // calls setState, so it can't affect scrolling or rebuild the app.
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
              _scrolling.value = true;
            } else if (n is ScrollEndNotification) {
              _scrolling.value = false;
            }
            return false;
          },
          child: widget.child,
        ),
        Positioned(
          left: pos.dx.clamp(margin, size.width - btnSize - margin),
          top: pos.dy.clamp(
            margin + padding.top,
            size.height - btnSize - padding.bottom - margin,
          ),
          child: GestureDetector(
            onPanUpdate: (d) {
              setState(() {
                final current = _offset ?? pos;
                _offset = Offset(
                  current.dx + d.delta.dx,
                  current.dy + d.delta.dy,
                );
              });
            },
            child: _WaSupportButton(
              size: btnSize,
              isDark: isDark,
              scrolling: _scrolling,
              onTap: _openWhatsApp,
            ),
          ),
        ),
      ],
      ),
    );
  }
}

/// Floating WhatsApp support button (MulhimIQ design system). Presentation +
/// micro-interactions only — the tap delegates to the overlay's unchanged
/// `_openWhatsApp` launcher. White card in light mode / dark navy card in dark
/// mode, WhatsApp-green icon, subtle border + soft shadow, a smooth fade/slide
/// entrance, a gentle press scale, and a subtle opacity dip while scrolling.
class _WaSupportButton extends StatefulWidget {
  const _WaSupportButton({
    required this.size,
    required this.isDark,
    required this.scrolling,
    required this.onTap,
  });

  final double size;
  final bool isDark;
  final ValueNotifier<bool> scrolling;
  final VoidCallback onTap;

  @override
  State<_WaSupportButton> createState() => _WaSupportButtonState();
}

class _WaSupportButtonState extends State<_WaSupportButton> {
  static const Color _whatsappGreen = Color(0xFF25D366);
  bool _pressed = false;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dsTheme = widget.isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Builder(
        builder: (context) {
          final m = context.mq;
          return ValueListenableBuilder<bool>(
            valueListenable: widget.scrolling,
            builder: (context, scrolling, _) {
              return AnimatedSlide(
                offset: _shown ? Offset.zero : const Offset(0.25, 0),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _shown ? (scrolling ? 0.5 : 1.0) : 0.0,
                  duration: const Duration(milliseconds: 240),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    onTap: widget.onTap,
                    child: AnimatedScale(
                      scale: _pressed ? 0.9 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          color: m.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: m.line),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: widget.isDark ? 0.4 : 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.support_agent_rounded, color: _whatsappGreen, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
