import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/config/initial_bindings.dart';
import 'core/services/notification_service.dart';
import 'shared/themes/app_colors.dart';
import 'shared/controllers/theme_controller.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

// ✅ الشاشات
import 'features/splash/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/profile/complete_profile_screen.dart';
import 'features/profile/student_profile_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/courses/screens/suggested_courses_screen.dart';
import 'features/courses/screens/course_details_screen.dart';
import 'features/root/root_shell.dart';
import 'features/bookings/screens/bookings_list_screen.dart';
import 'features/bookings/screens/booking_details_screen.dart';
import 'features/enrollments/screens/enrollments_screen.dart';
import 'features/enrollments/screens/enrollment_actions_screen.dart';
import 'features/qr/qr_scan_screen.dart';
import 'features/enrollments/screens/course_weekly_schedule_screen.dart';
import 'features/enrollments/screens/course_attendance_screen.dart';
import 'features/invoices/screens/student_invoices_screen.dart';
import 'features/invoices/screens/invoice_details_screen.dart';
import 'features/teachers/screens/suggested_teachers_screen.dart';
import 'features/teachers/screens/teacher_details_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

  final id = OneSignal.User.pushSubscription.id;
  print("PLAYER ID => $id");

  Get.put(ThemeController(), permanent: true);

  runApp(const MyApp());
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
          GetPage(name: "/home", page: () => const RootShell()),
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
      const btnSize = 56.0;
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
    final btnSize = 56.0;
    final margin = 16.0;
    final pos =
        _offset ??
        Offset(
          size.width - btnSize - margin,
          size.height - btnSize - padding.bottom - margin - 80,
        );

    return Stack(
      children: [
        widget.child,
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
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: btnSize,
                height: btnSize,
                child: FloatingActionButton(
                  heroTag: 'wa_support_fab',
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  onPressed: _openWhatsApp,
                  child: const Icon(Icons.support_agent),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
