// Teacher application — submit-success screen (Phase 6).
//
// Reached after the form submits successfully (and any chosen files have
// finished uploading). No identifiers from the application leak here —
// just a confirmation + email reminder + return-to-login CTA.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TeacherApplicationSuccessScreen extends StatelessWidget {
  const TeacherApplicationSuccessScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      // The user just submitted — sending them back into the form is
      // confusing and would also let them re-submit the same data.
      // canPop:false suppresses the default pop; we route to /login ourselves.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Get.offAllNamed('/login');
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'تم استلام طلبك بنجاح',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'سيقوم فريق الإدارة بمراجعة طلب انضمامك خلال 24–72 ساعة عمل.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.mark_email_read_outlined,
                          color: scheme.primary, size: 28),
                      const SizedBox(height: 8),
                      const Text(
                        'سيصلك إشعار + رسالة بريد فور البتّ في الطلب على:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text(
                      'العودة إلى تسجيل الدخول',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Get.offAllNamed('/login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
