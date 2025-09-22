import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ✅ استدعاء الشاشات
import 'features/splash/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/complete_profile_screen.dart';
import 'core/config/initial_bindings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Dirasiq',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialBinding: InitialBindings(),
      smartManagement: SmartManagement.full,

      // ✅ دعم تعدد اللغات
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],

      // ✅ شاشة البداية + تعريف الصفحات باستخدام GetX
      initialRoute: "/splash",
      getPages: [
        GetPage(name: "/splash", page: () => const SplashScreen()),
        GetPage(name: "/login", page: () => LoginScreen()),
        GetPage(name: "/home", page: () => const HomeScreen()),
        GetPage(name: "/complete-profile", page: () => const CompleteProfileScreen()),
      ],
    );
  }
}

