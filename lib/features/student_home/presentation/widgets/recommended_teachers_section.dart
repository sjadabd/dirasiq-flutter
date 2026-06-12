import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

/// "معلّمون موصى بهم" — discovery rail of suggested teachers with subject,
/// rating, and a متابعة action, matching the design's card.
class RecommendedTeachersSection extends StatelessWidget {
  const RecommendedTeachersSection({
    super.key,
    required this.teachers,
    required this.onOpen,
    this.onSeeAll,
  });

  final List<RecommendedTeacher> teachers;
  final void Function(RecommendedTeacher) onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShSectionHeader(
          title: 'معلّمون موصى بهم',
          subtitle: 'تعرّف على معلمين جدد',
          actionLabel: onSeeAll != null ? 'الكل' : null,
          onAction: onSeeAll,
        ),
        ShHorizontalRail(
          height: 210,
          itemCount: teachers.length,
          itemBuilder: (context, i) => _TeacherTile(teacher: teachers[i], onTap: () => onOpen(teachers[i])),
        ),
      ],
    );
  }
}

class _TeacherTile extends StatelessWidget {
  const _TeacherTile({required this.teacher, required this.onTap});
  final RecommendedTeacher teacher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return SizedBox(
      width: 156,
      child: MqCard(
        onTap: onTap,
        padding: const EdgeInsets.all(MqSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShAvatar(url: teacher.imageUrl, name: teacher.name, size: 60),
            MqSpacing.gapSm,
            Text(teacher.name,
                textAlign: TextAlign.center,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (teacher.subject != null && teacher.subject!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(teacher.subject!,
                  style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (teacher.rating != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 15, color: mq.orange),
                  MqSpacing.gapXxs,
                  Text(teacher.rating!.toStringAsFixed(1),
                      style: context.text.labelMedium?.copyWith(color: mq.ink, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
            const Spacer(),
            MqButton.tonal(label: 'متابعة', onPressed: onTap, size: MqButtonSize.small),
          ],
        ),
      ),
    );
  }
}
