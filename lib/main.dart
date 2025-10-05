import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/config/initial_bindings.dart';
import 'core/services/notification_service.dart';
import 'shared/themes/app_colors.dart';

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

// ✅ المتحكم العام للإشعارات والمستخدم
import 'shared/controllers/global_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.lightScheme;
    final dark = AppColors.darkScheme;

    // ✅ تحميل المتحكم العام
    Get.put(GlobalController(), permanent: true);

    return GetMaterialApp(
      title: 'Dirasiq',
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
        return AnimatedTheme(
          data: Theme.of(context),
          duration: const Duration(milliseconds: 300),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox(),
          ),
        );
      },

      themeMode: ThemeMode.system,

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
      smartManagement: SmartManagement.full,

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
        GetPage(name: "/bookings", page: () => const BookingsListScreen()),
        GetPage(
          name: "/booking-details",
          page: () {
            final id = Get.arguments as String;
            return BookingDetailsScreen(bookingId: id);
          },
        ),
      ],
    );
  }
}
