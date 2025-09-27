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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final isComplete = await _authService.isProfileComplete();

    if (!isComplete && mounted) {
      Future.delayed(Duration.zero, () {
        Get.snackbar(
          'إكمال البيانات',
          'يرجى إكمال بياناتك لتحسين تجربتك. يمكنك المتابعة بدون إكمال الآن.',
          snackPosition: SnackPosition.BOTTOM,
          mainButton: TextButton(
            onPressed: () {
              Get.offNamed('/complete-profile');
            },
            child: const Text('إكمال الآن'),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child; // يرجع الصفحة الأصلية
  }
}
