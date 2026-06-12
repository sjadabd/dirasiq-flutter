import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

/// Shared building blocks + formatters for the Student Home sections.

/// Section title row with an optional "see all" action — used above every
/// horizontal rail.
class ShSectionHeader extends StatelessWidget {
  const ShSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailingCount,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? trailingCount;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(color: mq.accent, borderRadius: MqRadius.brPill),
          ),
          MqSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          style: context.text.titleMedium, overflow: TextOverflow.ellipsis),
                    ),
                    if (trailingCount != null) ...[
                      MqSpacing.gapXs,
                      MqBadge(label: '$trailingCount', tone: MqBadgeTone.accent),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(subtitle!,
                      style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            MqButton.text(label: actionLabel!, onPressed: onAction, size: MqButtonSize.small),
        ],
      ),
    );
  }
}

/// Horizontal rail with consistent padding/spacing for card lists.
class ShHorizontalRail extends StatelessWidget {
  const ShHorizontalRail({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.itemSpacing = MqSpacing.md,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemSpacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(width: itemSpacing),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Small muted "nothing here yet" line for optional sub-sections.
class ShMutedHint extends StatelessWidget {
  const ShMutedHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
      child: Center(
        child: Text(text, style: context.text.bodySmall, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Network image with a graceful fallback (icon or initials) and a token-tinted
/// placeholder background.
class ShAvatar extends StatelessWidget {
  const ShAvatar({super.key, required this.url, required this.name, this.size = 56});

  final String url;
  final String name;
  final double size;

  String get _initials {
    final n = name.trim();
    if (n.isEmpty) return '؟';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.take(1).toString();
    return parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString();
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final fallback = Container(
      color: mq.accentSoft,
      alignment: Alignment.center,
      child: Text(_initials,
          style: context.text.titleMedium?.copyWith(color: mq.accent)),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? fallback
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

/// 16:9 cover image with token-tinted fallback (course / news / video thumb).
class ShCover extends StatelessWidget {
  const ShCover({super.key, required this.url, this.icon = Icons.school_rounded, this.borderRadius});

  final String url;
  final IconData icon;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final fallback = Container(
      color: mq.fill2,
      alignment: Alignment.center,
      child: Icon(icon, size: 36, color: mq.ink3),
    );
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url.isEmpty
            ? fallback
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

// ── formatters ───────────────────────────────────────────────────────────────

/// Localised "until start" countdown for the upcoming cards.
String shCountdown(DateTime? target) {
  if (target == null) return '—';
  final diff = target.difference(DateTime.now());
  if (diff.isNegative) return 'انتهت';
  if (diff.inDays >= 1) return 'بعد ${diff.inDays} يوم';
  if (diff.inHours >= 1) return 'بعد ${diff.inHours} ساعة';
  if (diff.inMinutes >= 1) return 'بعد ${diff.inMinutes} دقيقة';
  return 'الآن';
}

/// "منذ ..." relative time for news cards.
String shTimeAgo(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
  return 'منذ ${(diff.inDays / 30).floor()} شهر';
}

// The backend keys scheduleByDay by Postgres EXTRACT(DOW): 0=Sunday .. 6=Saturday
// (see StudentService.getWeeklySchedule). The mapping is 0-based to match.
const List<String> _dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

String shDayName(int weekday) =>
    (weekday >= 0 && weekday <= 6) ? _dayNames[weekday] : '';

/// Price + currency. Defaults to IQD ("د.ع") per the project currency standard.
/// Amounts use thousands separators and no decimals (e.g. 100000 → "100,000").
String shMoney(num? price, String? currency) {
  if (price == null) return '';
  final unit = (currency == null || currency.trim().isEmpty) ? 'د.ع' : currency.trim();
  final n = price
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '$n $unit';
}
