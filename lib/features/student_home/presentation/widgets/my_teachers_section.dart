import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

/// "معلّموني" — the student's active teachers (grouped from enrollments). Each
/// card shows the teacher, their main course, the active-course count, and the
/// مراسلة / عرض التفاصيل actions from the design.
class MyTeachersSection extends StatelessWidget {
  const MyTeachersSection({
    super.key,
    required this.teachers,
    required this.onOpen,
    this.onMessage,
    this.onSeeAll,
  });

  final List<MyTeacher> teachers;
  final void Function(MyTeacher) onOpen;
  final void Function(MyTeacher)? onMessage;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShSectionHeader(
          title: 'معلّموني',
          subtitle: 'تابع كل ما يخص دوراتك',
          trailingCount: teachers.length,
          actionLabel: onSeeAll != null ? 'الكل' : null,
          onAction: onSeeAll,
        ),
        ShHorizontalRail(
          height: 248,
          itemCount: teachers.length,
          itemBuilder: (context, i) => _TeacherCard(
            teacher: teachers[i],
            onOpen: () => onOpen(teachers[i]),
            onMessage: onMessage == null ? null : () => onMessage!(teachers[i]),
          ),
        ),
      ],
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher, required this.onOpen, this.onMessage});
  final MyTeacher teacher;
  final VoidCallback onOpen;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return SizedBox(
      width: 232,
      child: MqCard(
        onTap: onOpen,
        padding: const EdgeInsets.all(MqSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    ShAvatar(url: teacher.imageUrl, name: teacher.name, size: 56),
                    if (teacher.isActive)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: mq.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: mq.card, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                MqBadge(
                  label: '${teacher.courses.length} دورات',
                  tone: MqBadgeTone.accent,
                  icon: Icons.menu_book_outlined,
                ),
              ],
            ),
            MqSpacing.gapMd,
            Text('الأستاذ', style: context.text.labelSmall),
            const SizedBox(height: 2),
            Text(teacher.name,
                style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (teacher.mainCourseName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(teacher.mainCourseName,
                  style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: MqButton(
                    label: 'عرض التفاصيل',
                    onPressed: onOpen,
                    size: MqButtonSize.small,
                  ),
                ),
                if (onMessage != null) ...[
                  MqSpacing.gapSm,
                  _IconAction(icon: Icons.chat_bubble_outline_rounded, onTap: onMessage!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.accentSoft,
      shape: const RoundedRectangleBorder(borderRadius: MqRadius.brMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MqSpacing.sm),
          child: Icon(icon, size: MqSize.iconSm, color: mq.accent),
        ),
      ),
    );
  }
}
