import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../shared/design/teacher_design.dart';

/// Platform announcements published by super-admin for the teacher mobile app.
class TeacherPlatformNewsSection extends StatefulWidget {
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
  State<TeacherPlatformNewsSection> createState() =>
      _TeacherPlatformNewsSectionState();
}

class _TeacherPlatformNewsSectionState extends State<TeacherPlatformNewsSection> {
  PageController? _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant TeacherPlatformNewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _pageController?.dispose();
      _currentIndex = 0;
      _initController();
    }
  }

  void _initController() {
    if (widget.items.length > 1) {
      _pageController = PageController(viewportFraction: 0.9);
    } else {
      _pageController = null;
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final multiple = widget.items.length > 1;
    final countLabel = '${widget.items.length} إعلانات';

    return TeacherDashboardCard(
      title: 'إعلانات المنصة',
      subtitle: 'آخر الإعلانات من إدارة المنصة',
      icon: Icons.campaign_outlined,
      tone: TeacherTone.info,
      trailing: multiple
          ? TeacherStatusPill(
              label: countLabel,
              tone: TeacherTone.info,
              dense: true,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (multiple)
            SizedBox(
              height: 152,
              child: PageView.builder(
                controller: _pageController,
                padEnds: false,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: index == 0 ? 0 : MqSpacing.xs,
                      end: index == widget.items.length - 1 ? 0 : MqSpacing.xs,
                    ),
                    child: _NewsBannerCard(
                      item: item,
                      onTap: () => widget.onOpen(item),
                    ),
                  );
                },
              ),
            )
          else
            _NewsBannerCard(
              item: widget.items.first,
              onTap: () => widget.onOpen(widget.items.first),
            ),
          if (multiple) ...[
            const SizedBox(height: MqSpacing.sm),
            _PageDots(count: widget.items.length, current: _currentIndex),
          ],
        ],
      ),
    );
  }
}

class _NewsBannerCard extends StatelessWidget {
  const _NewsBannerCard({
    required this.item,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final title = (item['title'] ?? '').toString().trim();
    final details =
        (item['details'] ?? item['description'] ?? '').toString().trim();
    final img = TeacherPlatformNewsSection.imageUrl(
      item['imageUrl'] ?? item['image_url'],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: MqRadius.brLg,
        child: Ink(
          height: 152,
          decoration: BoxDecoration(
            borderRadius: MqRadius.brLg,
            border: Border.all(color: mq.line),
            boxShadow: [
              BoxShadow(
                color: mq.accentShadow.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: MqRadius.brLg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (img.isNotEmpty)
                  Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallbackBg(context),
                  )
                else
                  _fallbackBg(context),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: MqSpacing.sm,
                  end: MqSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MqSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.info.withValues(alpha: 0.92),
                      borderRadius: MqRadius.brPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'إعلان',
                          style: context.text.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: MqSpacing.md,
                  end: MqSpacing.md,
                  bottom: MqSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.isNotEmpty ? title : 'إعلان من المنصة',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: MqSpacing.sm,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackBg(BuildContext context) {
    final t = context.teacher;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.heroA, t.heroB],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: active ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? mq.accent : mq.line,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

void showTeacherPlatformNewsDetail(
    BuildContext context, Map<String, dynamic> item) {
  final mq = context.mq;
  final title = (item['title'] ?? '').toString();
  final details =
      (item['details'] ?? item['description'] ?? '').toString();
  final img = TeacherPlatformNewsSection.imageUrl(
    item['imageUrl'] ?? item['image_url'],
  );

  showDialog<void>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: mq.card,
        shape: RoundedRectangleBorder(borderRadius: MqRadius.brLg),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: mq.accentSoft,
                borderRadius: MqRadius.brSm,
              ),
              child: Icon(Icons.campaign_outlined, color: mq.accent, size: 20),
            ),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: Text(
                title.isNotEmpty ? title : 'إعلان المنصة',
                style: context.text.titleSmall,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (img.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: MqRadius.brMd,
                  child: Image.network(img, height: 160, fit: BoxFit.cover),
                ),
                const SizedBox(height: MqSpacing.md),
              ],
              Text(
                details.isEmpty ? 'لا يوجد تفاصيل إضافية.' : details,
                style: context.text.bodyMedium?.copyWith(
                  color: mq.ink2,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    ),
  );
}
