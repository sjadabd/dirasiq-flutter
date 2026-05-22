// Join-as-Teacher landing page (Phase 6).
//
// First touchpoint for a prospective teacher. Sells the program in a few
// lines and routes to the multi-step application form. Intentionally
// minimal — the heavy lifting lives in the form screen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'teacher_application_form_screen.dart';

class JoinAsTeacherScreen extends StatelessWidget {
  const JoinAsTeacherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('انضم كأستاذ'),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.school_outlined,
                      size: 48, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'انضم إلى مُلهِم IQ كأستاذ',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'قدّم طلب الانضمام، أرفق مستنداتك، وسيتواصل معك فريق الإدارة فور المراجعة.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              _Bullet(
                icon: Icons.assignment_outlined,
                title: 'تقديم سريع وبسيط',
                subtitle: 'املأ النموذج على 4 خطوات قصيرة.',
                color: scheme.primary,
              ),
              _Bullet(
                icon: Icons.verified_user_outlined,
                title: 'مراجعة من الإدارة',
                subtitle: 'يتم مراجعة طلبك خلال 24–72 ساعة عمل.',
                color: scheme.primary,
              ),
              _Bullet(
                icon: Icons.notifications_active_outlined,
                title: 'إشعار فوري بالنتيجة',
                subtitle: 'ستصلك رسالة بالبريد فور البتّ في الطلب.',
                color: scheme.primary,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  label: const Text('ابدأ تقديم الطلب',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Get.to(() => const TeacherApplicationFormScreen()),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'إنشاء حسابات المعلمين يتمّ حصراً من قبل الإدارة بعد قبول الطلب.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
