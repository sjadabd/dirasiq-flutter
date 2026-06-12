import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

import '../../data/models/student_home_data.dart';
import 'sh_common.dart';

/// "آخر الأخبار" — horizontal rail of news cards (image + title + relative time).
class NewsSection extends StatelessWidget {
  const NewsSection({super.key, required this.items, required this.onOpen});

  final List<NewsItem> items;
  final void Function(NewsItem) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShSectionHeader(title: 'آخر الأخبار', subtitle: 'آخر المستجدّات من المنصّة'),
        ShHorizontalRail(
          height: 244,
          itemCount: items.length,
          itemBuilder: (context, i) => _NewsCard(item: items[i], onTap: () => onOpen(items[i])),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.onTap});
  final NewsItem item;
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
            ShCover(
              url: item.imageUrl,
              icon: Icons.campaign_outlined,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(MqRadius.lg)),
            ),
            Padding(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title,
                      style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (item.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: mq.ink3),
                        MqSpacing.gapXs,
                        Text(shTimeAgo(item.createdAt), style: context.text.labelSmall),
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
