import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../shared/design/teacher_design.dart';

/// Platform announcements published by super-admin for the teacher mobile app.
class TeacherPlatformNewsSection extends StatelessWidget {
  const TeacherPlatformNewsSection({
    super.key,
    required this.items,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onOpen;

  static String imageUrl(Object? path) {
    final p = path?.toString().trim() ?? '';
    if (p.isEmpty) return '';
    if (p.startsWith('http')) return p;
    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/$'), '');
    return p.startsWith('/') ? '$base$p' : '$base/$p';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final mq = context.mq;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.campaign_outlined, color: mq.accent, size: 20),
            const SizedBox(width: MqSpacing.sm),
            Text('إعلانات المنصة', style: context.text.titleSmall),
          ],
        ),
        const SizedBox(height: MqSpacing.sm),
        Text(
          'آخر الإعلانات من إدارة المنصة',
          style: context.text.labelSmall?.copyWith(color: mq.ink3),
        ),
        const SizedBox(height: MqSpacing.md),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: MqSpacing.md),
            itemBuilder: (context, i) {
              final item = items[i];
              final title = (item['title'] ?? '').toString();
              final img = imageUrl(item['imageUrl'] ?? item['image_url']);
              return SizedBox(
                width: 260,
                child: Material(
                  color: mq.card,
                  borderRadius: MqRadius.brLg,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onOpen(item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 120,
                          width: double.infinity,
                          color: mq.fill,
                          child: img.isNotEmpty
                              ? Image.network(img, fit: BoxFit.cover)
                              : Icon(Icons.newspaper_outlined, color: mq.ink3, size: 40),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(MqSpacing.md),
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void showTeacherPlatformNewsDetail(BuildContext context, Map<String, dynamic> item) {
  final title = (item['title'] ?? '').toString();
  final details = (item['details'] ?? item['description'] ?? '').toString();
  final img = TeacherPlatformNewsSection.imageUrl(item['imageUrl'] ?? item['image_url']);

  showDialog<void>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (img.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(img, height: 160, fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
              ],
              Text(details.isEmpty ? 'لا يوجد تفاصيل إضافية.' : details),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إغلاق')),
        ],
      ),
    ),
  );
}
