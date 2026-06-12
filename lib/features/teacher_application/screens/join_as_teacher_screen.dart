// Join-as-Teacher landing page (Teacher Design System pass).
//
// First touchpoint for a prospective teacher. Sells the program in a few
// lines and routes to the multi-step application form. Pre-auth — uses the
// base MulhimIQ design system + teacher hero tokens, but no teacher-session
// chrome (the applicant has no account yet).

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../teacher/shared/design/teacher_design.dart';
import '../widgets/join_widgets.dart';
import 'check_application_status_screen.dart';
import 'teacher_application_form_screen.dart';

class JoinAsTeacherScreen extends StatelessWidget {
  const JoinAsTeacherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          final t = context.teacher;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: const JoinAppBar(title: 'انضم كأستاذ'),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(MqSpacing.xl),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [t.heroA, t.heroB],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: MqRadius.brXl,
                        boxShadow: t.shadowLg,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: t.heroTile,
                              shape: BoxShape.circle,
                              border: Border.all(color: t.heroLine),
                            ),
                            child: Icon(Icons.school_outlined,
                                size: 42, color: t.heroInk),
                          ),
                          const SizedBox(height: MqSpacing.lg),
                          Text('انضم إلى مُلهِم IQ كأستاذ',
                              textAlign: TextAlign.center,
                              style: context.text.titleLarge
                                  ?.copyWith(color: t.heroInk)),
                          const SizedBox(height: MqSpacing.sm),
                          Text(
                            'قدّم طلب الانضمام، أرفق مستنداتك، وسيتواصل معك فريق الإدارة فور المراجعة.',
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium
                                ?.copyWith(color: t.heroInk2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MqSpacing.xl),
                    const _Bullet(
                      icon: Icons.assignment_outlined,
                      title: 'تقديم سريع وبسيط',
                      subtitle: 'املأ النموذج على 4 خطوات قصيرة.',
                    ),
                    const _Bullet(
                      icon: Icons.verified_user_outlined,
                      title: 'مراجعة من الإدارة',
                      subtitle: 'يتم مراجعة طلبك خلال 24–72 ساعة عمل.',
                    ),
                    const _Bullet(
                      icon: Icons.notifications_active_outlined,
                      title: 'إشعار فوري بالنتيجة',
                      subtitle: 'ستصلك رسالة بالبريد فور البتّ في الطلب.',
                    ),
                    const SizedBox(height: MqSpacing.xl),
                    MqButton(
                      label: 'ابدأ تقديم الطلب',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () =>
                          Get.to(() => const TeacherApplicationFormScreen()),
                    ),
                    const SizedBox(height: MqSpacing.sm),
                    MqButton.secondary(
                      label: 'سبق وقدّمت — تحقّق من حالة طلبي',
                      icon: Icons.search_outlined,
                      onPressed: () =>
                          Get.to(() => const CheckApplicationStatusScreen()),
                    ),
                    const SizedBox(height: MqSpacing.md),
                    Text(
                      'إنشاء حسابات المعلمين يتمّ حصراً من قبل الإدارة بعد قبول الطلب.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(color: mq.ink3),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: MqCard(
        padding: const EdgeInsets.all(MqSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: mq.accentSoft,
                borderRadius: MqRadius.brSm,
              ),
              child: Icon(icon, color: mq.accent, size: 20),
            ),
            const SizedBox(width: MqSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          context.text.bodySmall?.copyWith(color: mq.ink2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
