import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

({IconData icon, String label}) _lectureTypeMeta(LectureType type) {
  return switch (type) {
    LectureType.physical => (icon: Icons.location_on_outlined, label: 'حضوري'),
    LectureType.live => (icon: Icons.sensors_rounded, label: 'بث مباشر'),
    LectureType.video => (icon: Icons.play_circle_outline_rounded, label: 'مرئي'),
  };
}

/// "المحاضرة القادمة" / "المحاضرة الجارية" — next session, or the in-progress
/// one with a per-second countdown to its end and a filling progress bar.
///
/// Stateful so it can own a 1-second ticker while a lecture is live. When the
/// running lecture ends, [onEnded] fires once so the parent can refetch and
/// surface the following lecture.
class UpcomingLectureCard extends StatefulWidget {
  const UpcomingLectureCard({super.key, required this.lecture, this.onOpen, this.onEnded});

  final UpcomingLecture lecture;
  final VoidCallback? onOpen;
  final VoidCallback? onEnded;

  @override
  State<UpcomingLectureCard> createState() => _UpcomingLectureCardState();
}

class _UpcomingLectureCardState extends State<UpcomingLectureCard> {
  Timer? _ticker;
  late bool _wasOngoing;

  @override
  void initState() {
    super.initState();
    _wasOngoing = widget.lecture.isOngoing;
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant UpcomingLectureCard old) {
    super.didUpdateWidget(old);
    if (old.lecture.startAt != widget.lecture.startAt ||
        old.lecture.endAt != widget.lecture.endAt) {
      _wasOngoing = widget.lecture.isOngoing;
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    // Only a live or imminent lecture needs a per-second clock; otherwise the
    // far-out "بعد X ساعة" label refreshes lazily on the next data reload.
    final e = widget.lecture.endAt;
    if (e == null || !e.isAfter(DateTime.now())) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    final ongoingNow = widget.lecture.isOngoing;
    if (_wasOngoing && !ongoingNow) {
      // The running lecture just ended — ask the parent to load the next one.
      widget.onEnded?.call();
      _ticker?.cancel();
    }
    _wasOngoing = ongoingNow;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.lecture.isOngoing ? _ongoing(context) : _upcoming(context);
  }

  // ── upcoming (not started) ─────────────────────────────────────────────────
  Widget _upcoming(BuildContext context) {
    final mq = context.mq;
    final lecture = widget.lecture;
    final meta = _lectureTypeMeta(lecture.type);
    final actionLabel = lecture.type == LectureType.physical ? 'التفاصيل' : 'انضمام';

    return MqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
                child: Icon(Icons.event_rounded, color: mq.accent, size: MqSize.iconMd),
              ),
              MqSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('المحاضرة القادمة', style: context.text.bodySmall),
                    Text(lecture.courseName,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              MqBadge(label: meta.label, tone: MqBadgeTone.accent, icon: meta.icon),
            ],
          ),
          MqSpacing.gapMd,
          if (lecture.teacherName.isNotEmpty)
            _MetaRow(icon: Icons.person_outline_rounded, text: lecture.teacherName),
          _MetaRow(icon: Icons.schedule_rounded, text: 'حتى البدء: ${shCountdown(lecture.startAt)}'),
          MqSpacing.gapMd,
          MqButton(
            label: actionLabel,
            onPressed: widget.onOpen,
            size: MqButtonSize.small,
            icon: lecture.type == LectureType.physical ? Icons.arrow_back_rounded : Icons.login_rounded,
          ),
        ],
      ),
    );
  }

  // ── ongoing (live) ─────────────────────────────────────────────────────────
  Widget _ongoing(BuildContext context) {
    final mq = context.mq;
    final lecture = widget.lecture;
    final meta = _lectureTypeMeta(lecture.type);
    final actionLabel = lecture.type == LectureType.physical ? 'التفاصيل' : 'انضمام';

    final start = lecture.startAt!;
    final end = lecture.endAt!;
    final now = DateTime.now();
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    final remaining = end.difference(now);

    return MqCard(
      color: Color.alphaBlend(mq.success.withValues(alpha: 0.06), mq.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    color: mq.success.withValues(alpha: 0.14), borderRadius: MqRadius.brMd),
                child: Icon(Icons.sensors_rounded, color: mq.success, size: MqSize.iconMd),
              ),
              MqSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('المحاضرة الجارية', style: context.text.bodySmall),
                    Text(lecture.courseName,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              MqBadge(label: meta.label, tone: MqBadgeTone.accent, icon: meta.icon),
            ],
          ),
          MqSpacing.gapMd,
          if (lecture.teacherName.isNotEmpty)
            _MetaRow(icon: Icons.person_outline_rounded, text: lecture.teacherName),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: MqSize.iconSm, color: mq.success),
              MqSpacing.gapXs,
              Text('ينتهي خلال:', style: context.text.bodySmall),
              MqSpacing.gapXs,
              Text(_hms(remaining),
                  style: MqTypography.mono(color: mq.success, size: 16, weight: FontWeight.w700)),
            ],
          ),
          MqSpacing.gapSm,
          MqLinearProgress(value: progress, tone: MqProgressTone.success, showLabel: true),
          MqSpacing.gapMd,
          MqButton(
            label: actionLabel,
            onPressed: widget.onOpen,
            size: MqButtonSize.small,
            icon: lecture.type == LectureType.physical ? Icons.arrow_back_rounded : Icons.login_rounded,
          ),
        ],
      ),
    );
  }
}

/// `HH:MM:SS` (drops the hours field under an hour) for the live end-countdown.
String _hms(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
  final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
}

/// "الاختبار القادم" — next exam with course + countdown.
class UpcomingExamCard extends StatelessWidget {
  const UpcomingExamCard({super.key, required this.exam, this.onOpen});

  final UpcomingExam exam;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return MqCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(color: mq.orangeSoft, borderRadius: MqRadius.brMd),
                child: Icon(Icons.quiz_outlined, color: mq.orangeDeep, size: MqSize.iconMd),
              ),
              MqSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('الاختبار القادم', style: context.text.bodySmall),
                    Text(exam.title,
                        style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          MqSpacing.gapMd,
          if (exam.courseName.isNotEmpty && exam.courseName != exam.title)
            _MetaRow(icon: Icons.menu_book_outlined, text: exam.courseName),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: MqSize.iconSm, color: mq.ink3),
              MqSpacing.gapXs,
              Text('أيام متبقية:', style: context.text.bodySmall),
              MqSpacing.gapXs,
              MqBadge(label: shCountdown(exam.examAt), tone: MqBadgeTone.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: MqSize.iconSm, color: mq.ink3),
          MqSpacing.gapXs,
          Expanded(
            child: Text(text,
                style: context.text.bodySmall?.copyWith(color: mq.ink2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
