import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

/// "جدولك الأسبوعي" — a day selector (chips with per-day lesson counts) over
/// the selected day's lessons. Stateful only for the local selection.
class WeeklyScheduleCard extends StatefulWidget {
  const WeeklyScheduleCard({super.key, required this.days});

  final List<WeeklyScheduleDay> days;

  @override
  State<WeeklyScheduleCard> createState() => _WeeklyScheduleCardState();
}

class _WeeklyScheduleCardState extends State<WeeklyScheduleCard> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    // Default to today if it has lessons, else the first day that does.
    // DOW convention (0=Sun..6=Sat) to match the backend's scheduleByDay keys.
    final today = DateTime.now().weekday % 7; // Dart Mon=1..Sun=7 → DOW Sun=0..Sat=6
    final hasToday = widget.days.any((d) => d.weekday == today && d.count > 0);
    _selected = hasToday
        ? today
        : (widget.days.firstWhere((d) => d.count > 0, orElse: () => widget.days.first).weekday);
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final totalLessons = widget.days.fold<int>(0, (sum, d) => sum + d.count);
    final selectedDay = widget.days.firstWhere(
      (d) => d.weekday == _selected,
      orElse: () => const WeeklyScheduleDay(weekday: 0, lessons: []),
    );

    return MqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ClipRect keeps the horizontal chip rail inside the card — the shared
          // rail paints with Clip.none, which otherwise lets chips bleed across
          // the full screen width past the card edges while scrolling.
          ClipRect(
            child: ShHorizontalRail(
              height: MqSize.chipHeight,
              itemCount: widget.days.length,
              itemSpacing: MqSpacing.xs,
              itemBuilder: (context, i) {
                final d = widget.days[i];
                return MqChip(
                  label: '${shDayName(d.weekday)} (${d.count})',
                  selected: d.weekday == _selected,
                  onTap: () => setState(() => _selected = d.weekday),
                );
              },
            ),
          ),
          MqSpacing.gapMd,
          if (selectedDay.lessons.isEmpty)
            const ShMutedHint('لا توجد حصص في هذا اليوم')
          else
            ...selectedDay.lessons.map((l) => _LessonRow(lesson: l)),
          if (totalLessons > 0) ...[
            const Divider(height: MqSpacing.xl),
            Row(
              children: [
                Text('تقدّم الخطة الأسبوعية', style: context.text.labelMedium),
                const Spacer(),
                Text('$totalLessons حصة',
                    style: context.text.labelMedium?.copyWith(color: mq.ink)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson});
  final ScheduleLesson lesson;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: mq.accent, shape: BoxShape.circle),
          ),
          MqSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lesson.courseName,
                    style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (lesson.teacherName.isNotEmpty)
                  Text(lesson.teacherName, style: context.text.bodySmall),
              ],
            ),
          ),
          if (lesson.startTime.isNotEmpty)
            MqBadge(label: lesson.startTime, tone: MqBadgeTone.neutral, icon: Icons.schedule_rounded),
        ],
      ),
    );
  }
}
