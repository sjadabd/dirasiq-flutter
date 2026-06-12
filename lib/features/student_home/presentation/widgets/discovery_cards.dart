import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

/// Search-style entry point shown to new students to explore courses/teachers.
class ExploreSearchBar extends StatelessWidget {
  const ExploreSearchBar({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.fill,
      shape: RoundedRectangleBorder(borderRadius: MqRadius.brMd, side: BorderSide(color: mq.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg, vertical: MqSpacing.md),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: mq.ink3, size: MqSize.iconMd),
              MqSpacing.gapSm,
              Text('ابحث عن معلم أو دورة…', style: context.text.bodyMedium?.copyWith(color: mq.ink3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onboarding / call-to-action card for students with no courses yet —
/// explains how to start and links into discovery.
class StartLearningCard extends StatelessWidget {
  const StartLearningCard({super.key, required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
                child: Icon(Icons.rocket_launch_rounded, color: mq.accent, size: MqSize.iconLg),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ابدأ رحلتك التعليمية', style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text('تصفّح المعلمين والدورات، واحجز دورتك الأولى لتظهر هنا متابعتك وجدولك وتقدّمك.',
                        style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          MqSpacing.gapMd,
          const _StartStep(index: 1, text: 'اختر معلماً أو دورة تناسب مرحلتك'),
          const _StartStep(index: 2, text: 'أرسل طلب الحجز وانتظر الموافقة'),
          const _StartStep(index: 3, text: 'ابدأ التعلّم وتابع حضورك ودرجاتك'),
          MqSpacing.gapMd,
          MqButton(label: 'استكشف الدورات', onPressed: onExplore, icon: Icons.explore_outlined),
        ],
      ),
    );
  }
}

class _StartStep extends StatelessWidget {
  const _StartStep({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: mq.accentSoft, shape: BoxShape.circle),
            child: Text('$index',
                style: context.text.labelSmall?.copyWith(color: mq.accent, fontWeight: FontWeight.w700)),
          ),
          MqSpacing.gapSm,
          Expanded(child: Text(text, style: context.text.bodySmall?.copyWith(color: mq.ink2))),
        ],
      ),
    );
  }
}
