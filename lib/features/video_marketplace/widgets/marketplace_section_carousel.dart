// Phase 7 — Section carousel.
//
// A titled row with a horizontal list of [VideoCourseCard]s. Shows an
// inline "no results" hint when its list is empty so the surrounding
// screen doesn't develop holes when filters narrow a section to zero.

import 'package:flutter/material.dart';

import 'video_course_card.dart';

class MarketplaceSectionCarousel extends StatelessWidget {
  const MarketplaceSectionCarousel({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    required this.onTapCourse,
    this.subtitle,
    this.showOwnedBadge = false,
    this.emptyMessage = 'لا توجد نتائج في هذا القسم',
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String? subtitle;

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> course) onTapCourse;
  final bool showOwnedBadge;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                Text('${items.length}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              emptyMessage,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => VideoCourseCard(
                course: items[i],
                showOwned: showOwnedBadge,
                onTap: () => onTapCourse(items[i]),
              ),
            ),
          ),
      ],
    );
  }
}
