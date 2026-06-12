import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';

/// "تقدّمك الأكاديمي" — overall progress ring plus the per-dimension meters
/// (attendance / assignments / exams). Only the metrics the backend supplied
/// are rendered; the section itself is gated upstream by [AcademicProgress.hasData].
class AcademicProgressCard extends StatelessWidget {
  const AcademicProgressCard({super.key, required this.progress});

  final AcademicProgress progress;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final meters = <_MeterSpec>[
      if (progress.attendance != null)
        _MeterSpec('الحضور', progress.attendance!, MqProgressTone.success, Icons.event_available_outlined),
      if (progress.assignments != null)
        _MeterSpec('إنجاز الواجبات', progress.assignments!, MqProgressTone.accent, Icons.assignment_turned_in_outlined),
      if (progress.exams != null)
        _MeterSpec('أداء الاختبارات', progress.exams!, MqProgressTone.orange, Icons.insights_outlined),
    ];

    return MqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (progress.overall != null) ...[
                MqRingProgress(
                  value: progress.overall! / 100,
                  size: 92,
                  strokeWidth: 8,
                  caption: 'التقدم العام',
                ),
                MqSpacing.gapLg,
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < meters.length; i++) ...[
                      if (i > 0) MqSpacing.gapMd,
                      _Meter(spec: meters[i]),
                    ],
                    if (meters.isEmpty && progress.overall != null)
                      Text('تقدّمك العام هذا الفصل الدراسي',
                          style: context.text.bodySmall?.copyWith(color: mq.ink2)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeterSpec {
  const _MeterSpec(this.label, this.value, this.tone, this.icon);
  final String label;
  final int value;
  final MqProgressTone tone;
  final IconData icon;
}

class _Meter extends StatelessWidget {
  const _Meter({required this.spec});
  final _MeterSpec spec;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(spec.icon, size: 14, color: mq.ink3),
            MqSpacing.gapXs,
            Expanded(child: Text(spec.label, style: context.text.labelMedium)),
            Text('${spec.value}%',
                style: context.text.labelMedium?.copyWith(color: mq.ink, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        MqLinearProgress(value: spec.value / 100, tone: spec.tone, height: 7),
      ],
    );
  }
}
