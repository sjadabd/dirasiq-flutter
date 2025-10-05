import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dirasiq/core/services/auth_service.dart';

class ProfileCompletionGuard extends StatefulWidget {
  final Widget child;
  const ProfileCompletionGuard({super.key, required this.child});

  @override
  State<ProfileCompletionGuard> createState() => _ProfileCompletionGuardState();
}

class _ProfileCompletionGuardState extends State<ProfileCompletionGuard> {
  final AuthService _authService = AuthService();
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      _checkProfile();
    }
  }

  Future<void> _checkProfile() async {
    final isComplete = await _authService.isProfileComplete();

    if (!isComplete && mounted) {
      Future.delayed(Duration.zero, () {
        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        Get.snackbar(
          'إكمال الملف الشخصي',
          'يرجى إكمال بياناتك الشخصية لتحسين تجربتك التعليمية.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: isDark
              ? scheme.surface.withOpacity(0.95)
              : scheme.surface,
          colorText: scheme.onSurface,
          margin: const EdgeInsets.all(12),
          borderRadius: 12,
          icon: Icon(Icons.info_outline, color: scheme.primary),
          duration: const Duration(seconds: 8),
          mainButton: TextButton(
            onPressed: () {
              Get.closeCurrentSnackbar();
              Get.toNamed('/complete-profile');
            },
            child: Text(
              'إكمال الآن',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
