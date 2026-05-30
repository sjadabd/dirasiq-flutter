// Phase 7 — Marketplace card.
//
// One compact card used by every horizontal carousel and the "My Library"
// section. Pulls the cover image, title, teacher name, and a price /
// "owned" / "free" badge from the row map. Defensive on key names — the
// backend can return any of `coverImage` / `cover_image`, `title` /
// `name`, etc.

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

class VideoCourseCard extends StatelessWidget {
  const VideoCourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.showOwned = false,
    this.width = 180,
    this.height = 200,
  });

  final Map<String, dynamic> course;
  final VoidCallback onTap;

  /// When true the card shows an "owned" badge instead of the price. Used
  /// by the My Library carousel.
  final bool showOwned;

  final double width;
  final double height;

  String get _title =>
      (course['title'] ?? course['name'] ?? '—').toString();

  String get _teacherName =>
      (course['teacherName'] ?? course['teacher_name'] ?? '').toString();

  String? get _coverUrl {
    final raw = (course['coverImage'] ?? course['cover_image'] ?? '').toString();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return '${AppConfig.serverBaseUrl}$raw';
  }

  bool get _isFree =>
      course['isFree'] == true || course['is_free'] == true || course['price'] == 0;

  String get _priceLabel {
    final p = course['price'];
    if (p is num && p > 0) return '${p.toInt()} د.ع';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cover = _coverUrl;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover == null
                      ? Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(Icons.movie_outlined,
                              color: cs.onSurfaceVariant, size: 32),
                        )
                      : Image.network(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.broken_image_outlined,
                                color: cs.onSurfaceVariant),
                          ),
                        ),
                  Positioned(
                    top: 6, right: 6,
                    child: _buildBadge(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    if (_teacherName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _teacherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    Color color;
    String label;
    if (showOwned) {
      color = Colors.indigo;
      label = 'مملوكة';
    } else if (_isFree) {
      color = Colors.green;
      label = 'مجاني';
    } else if (_priceLabel.isNotEmpty) {
      color = Colors.orange;
      label = _priceLabel;
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
