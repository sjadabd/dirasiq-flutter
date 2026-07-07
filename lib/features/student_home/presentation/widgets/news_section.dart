import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

/// "الأخبار والإعلانات" — horizontal rail with badge chips.
class NewsSection extends StatelessWidget {
  const NewsSection({super.key, required this.items, required this.onOpen});

  final List<ContentFeedItem> items;
  final void Function(ContentFeedItem) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShSectionHeader(
          title: 'الأخبار والإعلانات',
          subtitle: 'آخر المستجدّات من المنصّة والمعلمين',
        ),
        ShHorizontalRail(
          height: 264,
          itemCount: items.length,
          itemBuilder: (context, i) => _FeedCard(item: items[i], onTap: () => onOpen(items[i])),
        ),
      ],
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item, required this.onTap});
  final ContentFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return SizedBox(
      width: 260,
      child: MqCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ShCover(
                  url: item.imageUrl,
                  icon: item.isAd ? Icons.campaign_outlined : Icons.newspaper_outlined,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(MqRadius.lg)),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isAd ? mq.orange.withValues(alpha: 0.92) : mq.accent.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(MqRadius.sm),
                    ),
                    child: Text(
                      item.badgeLabel,
                      style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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
                      style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if ((item.publisherName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.publisherName!,
                        style: context.text.labelSmall?.copyWith(color: mq.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  if (item.publishedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: mq.ink3),
                        MqSpacing.gapXs,
                        Text(shTimeAgo(item.publishedAt), style: context.text.labelSmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
