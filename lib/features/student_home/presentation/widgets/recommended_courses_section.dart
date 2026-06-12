import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

/// "دورات حضورية موصى بها" — discovery rail of suggested in-person courses,
/// each with cover, teacher, price, and a CTA.
class RecommendedCoursesSection extends StatelessWidget {
  const RecommendedCoursesSection({
    super.key,
    required this.courses,
    required this.onOpen,
    this.onSeeAll,
  });

  final List<RecommendedCourse> courses;
  final void Function(RecommendedCourse) onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShSectionHeader(
          title: 'دورات حضورية موصى بها',
          subtitle: 'دورات قد تهمّك',
          actionLabel: onSeeAll != null ? 'الكل' : null,
          onAction: onSeeAll,
        ),
        ShHorizontalRail(
          height: 262,
          itemCount: courses.length,
          itemBuilder: (context, i) => _CourseCard(course: courses[i], onTap: () => onOpen(courses[i])),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});
  final RecommendedCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return SizedBox(
      width: 232,
      child: MqCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShCover(
              url: course.imageUrl,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(MqRadius.lg)),
            ),
            Padding(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(course.name,
                      style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (course.teacherName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(course.teacherName,
                        style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  MqSpacing.gapMd,
                  Row(
                    children: [
                      if (course.price != null)
                        Expanded(
                          child: Text(shMoney(course.price, course.currency),
                              style: context.text.titleMedium?.copyWith(color: mq.accent),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        )
                      else
                        const Spacer(),
                      MqButton(
                        label: 'اشترك الآن',
                        onPressed: onTap,
                        size: MqButtonSize.small,
                        expand: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
