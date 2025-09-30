import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/notification_service.dart';

// ✅ استدعاء الشاشات
import 'features/splash/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/profile/complete_profile_screen.dart';
import 'features/profile/student_profile_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'core/config/initial_bindings.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'shared/themes/app_colors.dart';
import 'features/courses/screens/suggested_courses_screen.dart';
import 'features/courses/screens/course_details_screen.dart';
import 'features/root/root_shell.dart';
import 'features/bookings/screens/bookings_list_screen.dart';
import 'features/bookings/screens/booking_details_screen.dart';
import 'features/enrollments/screens/enrollments_screen.dart';
import 'features/enrollments/screens/enrollment_actions_screen.dart';
import 'features/qr/qr_scan_screen.dart';
import 'features/enrollments/screens/course_weekly_schedule_screen.dart';

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

    return GetMaterialApp(
      title: 'Dirasiq',
      debugShowCheckedModeBanner: false,
      // ✅ اتجاه عربي افتراضي + RTL
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },

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
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
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
          color: Colors.white,
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(0),
        ),
      ),

      initialBinding: InitialBindings(),
      smartManagement: SmartManagement.full,

      // ✅ شاشة البداية + تعريف الصفحات باستخدام GetX
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
        GetPage(
          name: "/enrollments",
          page: () => const EnrollmentsScreen(),
        ),
        GetPage(
          name: "/enrollment-actions",
          page: () {
            final args = Get.arguments as Map<String, dynamic>?;
            final courseId = args?['courseId']?.toString() ?? '';
            final courseName = args?['courseName']?.toString();
            final teacherId = args?['teacherId']?.toString();
            return EnrollmentActionsScreen(
              courseId: courseId,
              courseName: courseName,
              teacherId: teacherId,
            );
          },
        ),
        GetPage(
          name: "/qr-scan",
          page: () => const QrScanScreen(),
        ),
        GetPage(
          name: "/course-weekly-schedule",
          page: () {
            final args = Get.arguments as Map<String, dynamic>?;
            final courseId = args?['courseId']?.toString() ?? '';
            final courseName = args?['courseName']?.toString();
            return CourseWeeklyScheduleScreen(
              courseId: courseId,
              courseName: courseName,
            );
          },
        ),
        GetPage(
          name: "/suggested-courses",
          page: () => const SuggestedCoursesScreen(),
        ),
        GetPage(
          name: "/course-details",
          page: () {
            final courseId = Get.arguments as String; // استلام الـ argument
            return CourseDetailsScreen(courseId: courseId);
          },
        ),
        GetPage(name: "/bookings", page: () => const BookingsListScreen()),
        GetPage(
          name: "/booking-details",
          page: () {
            final bookingId = Get.arguments as String; // استلام الـ argument
            return BookingDetailsScreen(bookingId: bookingId);
          },
        ),
      ],
    );
  }
}
