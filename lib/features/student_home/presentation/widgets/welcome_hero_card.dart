import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

/// The large blue hero card from the "B Hero + Bento" design: greeting + name,
/// an avatar circle, a day-streak pill, and a weekly-plan progress row with an
/// orange bar. White-on-navy, full-bleed gradient.
class WelcomeHeroCard extends StatelessWidget {
  const WelcomeHeroCard({
    super.key,
    required this.profile,
    this.streakDays,
    this.weeklyProgress,
    this.activeCourses,
    this.onProfile,
  });

  final StudentProfile profile;
  final int? streakDays;

  /// 0–100 weekly-plan progress; null hides the progress row.
  final int? weeklyProgress;
  final int? activeCourses;
  final VoidCallback? onProfile;

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'صباح الخير،' : 'مساء الخير،';
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final name = profile.name.isEmpty ? 'طالبنا العزيز' : profile.name;
    const onHero = Colors.white;

    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [mq.accent, mq.accentDeep],
        ),
        borderRadius: MqRadius.brXl,
        boxShadow: [
          BoxShadow(color: mq.accentShadow, blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onProfile,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ShAvatar(url: profile.imageUrl, name: name, size: 52),
                ),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_greeting,
                        style: context.text.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text(name,
                        style: context.text.titleLarge?.copyWith(color: onHero),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (streakDays != null && streakDays! > 0) _StreakPill(days: streakDays!),
            ],
          ),
          if (weeklyProgress != null) ...[
            MqSpacing.gapLg,
            _WeeklyProgress(value: weeklyProgress!, activeCourses: activeCourses),
          ],
        ],
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: MqRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 15, color: mq.orange),
          const SizedBox(width: 4),
          Text('$days يوم',
              style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _WeeklyProgress extends StatelessWidget {
  const _WeeklyProgress({required this.value, this.activeCourses});
  final int value;
  final int? activeCourses;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final v = value.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('تقدّم الخطة الأسبوعية',
                style: context.text.labelMedium?.copyWith(color: Colors.white70)),
            const Spacer(),
            Text('$v%',
                style: context.text.titleSmall?.copyWith(color: mq.orange, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: MqRadius.brPill,
          child: LinearProgressIndicator(
            value: v / 100,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation(mq.orange),
          ),
        ),
        if (activeCourses != null && activeCourses! > 0) ...[
          const SizedBox(height: MqSpacing.sm),
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text('$activeCourses دورات نشطة',
                  style: context.text.labelSmall?.copyWith(color: Colors.white70)),
            ],
          ),
        ],
      ],
    );
  }
}
