// Teacher application — submit-success screen (Teacher Design System pass).
//
// Reached after the form submits successfully (and any chosen files have
// finished uploading). No identifiers from the application leak here —
// just a confirmation + email reminder + return-to-login CTA.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../teacher/shared/design/teacher_design.dart';

class TeacherApplicationSuccessScreen extends StatelessWidget {
  const TeacherApplicationSuccessScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      // The user just submitted — sending them back into the form is
      // confusing and would also let them re-submit the same data.
      // canPop:false suppresses the default pop; we route to /login ourselves.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Get.offAllNamed('/login');
      },
      child: Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(builder: (context) {
            final mq = context.mq;
            final t = context.teacher;
            return Scaffold(
              backgroundColor: mq.page,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(MqSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: t.successSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_circle_outline,
                              size: 64, color: t.success),
                        ),
                      ),
                      const SizedBox(height: MqSpacing.xl),
                      Text('تم استلام طلبك بنجاح',
                          textAlign: TextAlign.center,
                          style: context.text.headlineSmall),
                      const SizedBox(height: MqSpacing.md),
                      Text(
                        'سيقوم فريق الإدارة بمراجعة طلب انضمامك خلال 24–72 ساعة عمل.',
                        textAlign: TextAlign.center,
                        style:
                            context.text.bodyMedium?.copyWith(color: mq.ink2),
                      ),
                      const SizedBox(height: MqSpacing.lg),
                      MqCard(
                        padding: const EdgeInsets.all(MqSpacing.lg),
                        child: Column(
                          children: [
                            Icon(Icons.mark_email_read_outlined,
                                color: mq.accent, size: 28),
                            const SizedBox(height: MqSpacing.sm),
                            Text(
                              'سيصلك إشعار + رسالة بريد فور البتّ في الطلب على:',
                              textAlign: TextAlign.center,
                              style: context.text.bodySmall
                                  ?.copyWith(color: mq.ink2),
                            ),
                            const SizedBox(height: MqSpacing.xs),
                            Text(
                              email,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: context.text.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: MqSpacing.xxl),
                      MqButton(
                        label: 'العودة إلى تسجيل الدخول',
                        icon: Icons.login_rounded,
                        onPressed: () => Get.offAllNamed('/login'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
