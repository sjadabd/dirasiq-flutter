// Video course card (MulhimIQ design system).
//
// One reusable card used by the marketplace grid and the "مكتبتي" continue-
// watching row. Every field renders only when the row provides it (defensive
// key handling — the backend has drifted across camel/snake variants), so a
// sparse row never shows placeholder/fake data. When the course is owned and
// carries a progress value, a "متابعة المشاهدة" CTA + a thin progress bar are
// shown; otherwise the CTA is "عرض التفاصيل".

import 'package:flutter/material.dart';

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/utils/money.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/app_network_image.dart';

class VideoCourseCard extends StatelessWidget {
  const VideoCourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.width,
  });

  final Map<String, dynamic> course;
  final VoidCallback onTap;

  /// Fixed width for horizontal carousels. Null = fill the parent (grid cell).
  final double? width;

  String get _title => (course['title'] ?? course['name'] ?? '—').toString();
  String get _teacher => (course['teacherName'] ?? course['teacher_name'] ?? '').toString();
  String get _subject => (course['subject'] ?? course['subjectName'] ?? course['subject_name'] ?? '').toString();
  String get _stage =>
      (course['teachingStage'] ?? course['stage'] ?? course['gradeName'] ?? course['grade_name'] ?? '').toString();

  String get _coverUrl {
    final raw = (course['coverImage'] ?? course['cover_image'] ?? '').toString();
    if (raw.isEmpty) return '';
    return raw.startsWith('http') ? raw : '${AppConfig.serverBaseUrl}$raw';
  }

  bool get _isFree => course['isFree'] == true || course['is_free'] == true || course['price'] == 0;
  bool get _isOwned =>
      course['isOwned'] == true ||
      course['is_owned'] == true ||
      course['hasAccess'] == true ||
      course['has_access'] == true;

  num? get _price {
    final p = course['price'];
    if (p is num) return p;
    if (p is String) return num.tryParse(p);
    return null;
  }

  int get _lessonCount {
    final v = course['lessonCount'] ?? course['lessonsCount'] ?? course['lessons_count'] ?? course['readyLessons'];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String get _durationLabel {
    final v = course['durationSeconds'] ?? course['totalDuration'] ?? course['duration'];
    final n = (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    if (n <= 0) return '';
    final h = n ~/ 3600;
    final m = (n % 3600) ~/ 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')} س';
    return '$m د';
  }

  double? get _progress {
    final v = course['progress'] ?? course['watchProgress'] ?? course['completionPercent'];
    if (v == null) return null;
    final d = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (d == null) return null;
    return (d > 1 ? d / 100 : d).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mq;
    final cover = _coverUrl;
    final progress = _isOwned ? _progress : null;
    final duration = _durationLabel;

    final card = MqCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail + badges + duration + progress bar.
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppNetworkImage(url: cover, fit: BoxFit.cover, fallbackIcon: Icons.movie_outlined),
                ),
              ),
              Positioned(top: 6, right: 6, child: _badge(context)),
              if (duration.isNotEmpty)
                Positioned(
                  bottom: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.66), borderRadius: MqRadius.brSm),
                    child: Text(duration, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              if (progress != null && progress > 0)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: ClipRRect(
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.black26,
                      valueColor: AlwaysStoppedAnimation(m.accent),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(MqSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  if (_teacher.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_teacher, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall),
                  ],
                  if (_subject.isNotEmpty || _stage.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [_subject, _stage].where((e) => e.isNotEmpty).join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: m.accent),
                    ),
                  ],
                  const Spacer(),
                  Row(children: [
                    if (_lessonCount > 0) ...[
                      Icon(Icons.play_lesson_outlined, size: 12, color: m.ink3),
                      MqSpacing.gapXxs,
                      Text('$_lessonCount درس', style: context.text.labelSmall),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    Text(
                      _isOwned ? 'متابعة المشاهدة' : 'عرض التفاصيل',
                      style: context.text.labelSmall?.copyWith(color: m.accent, fontWeight: FontWeight.w700),
                    ),
                    Icon(Icons.chevron_left_rounded, size: 16, color: m.accent),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return width == null ? card : SizedBox(width: width, child: card);
  }

  Widget _badge(BuildContext context) {
    if (_isOwned) return const MqBadge(label: 'مملوكة', tone: MqBadgeTone.accent, solid: true);
    if (_isFree) return const MqBadge(label: 'مجاني', tone: MqBadgeTone.success, solid: true);
    final p = _price;
    if (p != null && p > 0) return MqBadge(label: '${fmtMoney(p)} د.ع', tone: MqBadgeTone.orange, solid: true);
    return const SizedBox.shrink();
  }
}
