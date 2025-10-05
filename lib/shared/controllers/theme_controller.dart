import 'package:get/get.dart';
import 'package:flutter/material.dart';

/// Controls theme mode and applies changes instantly via GetX.
class ThemeController extends GetxController {
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  static ThemeController get to => Get.find<ThemeController>();

  void setThemeMode(ThemeMode mode) {
    if (themeMode.value == mode) return;
    themeMode.value = mode;
    Get.changeThemeMode(mode);
  }

  void toggleDarkLight() {
    final isDark = themeMode.value == ThemeMode.dark ||
        (themeMode.value == ThemeMode.system && Get.isDarkMode);
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}


