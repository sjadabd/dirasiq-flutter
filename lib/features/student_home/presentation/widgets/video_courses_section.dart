import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

/// Horizontal rail of video courses. Used twice:
///   • "دوراتي المرئية / متابعة المشاهدة" — owned courses, shows watch progress.
///   • "دورات مرئية موصى بها" — recommendations, shows price + CTA.
class VideoCoursesSection extends StatelessWidget {
  const VideoCoursesSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.onOpen,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final List<VideoCourseItem> items;
  final void Function(VideoCourseItem) onOpen;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShSectionHeader(title: title, subtitle: subtitle, actionLabel: actionLabel, onAction: onAction),
        ShHorizontalRail(
          height: 250,
          itemCount: items.length,
          itemBuilder: (context, i) => _VideoTile(
            item: items[i],
            showProgress: showProgress,
            onTap: () => onOpen(items[i]),
          ),
        ),
      ],
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.item, required this.showProgress, required this.onTap});
  final VideoCourseItem item;
  final bool showProgress;
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
            Stack(
              children: [
                ShCover(
                  url: item.thumbnailUrl,
                  icon: Icons.play_circle_outline_rounded,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(MqRadius.lg)),
                ),
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: mq.accent.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow_rounded, color: mq.onAccent, size: 24),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title,
                      style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (item.teacherName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.teacherName, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  MqSpacing.gapSm,
                  if (showProgress) ...[
                    Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded, size: 14, color: mq.accent),
                        MqSpacing.gapXxs,
                        Text('متابعة المشاهدة', style: context.text.labelSmall?.copyWith(color: mq.accent)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MqLinearProgress(value: item.progress ?? 0, height: 6, showLabel: true),
                  ] else
                    Row(
                      children: [
                        if (item.price != null)
                          Expanded(
                            child: Text(shMoney(item.price, item.currency),
                                style: context.text.titleSmall?.copyWith(color: mq.accent),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          )
                        else
                          const Spacer(),
                        MqButton(label: 'اشترك الآن', onPressed: onTap, size: MqButtonSize.small, expand: false),
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
