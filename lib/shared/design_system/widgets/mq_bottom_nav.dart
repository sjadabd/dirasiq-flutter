import 'package:flutter/material.dart';

import '../mq_spacing.dart';
import '../mq_theme.dart';

/// One destination in [MqBottomNav]. Mirrors the export's nav row
/// (`الرئيسية / الدورات / المحادثة / المزيد`).
class MqNavItem {
  const MqNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;

  /// Unread/notification count shown as a dot-badge on the icon.
  final int badgeCount;
}

/// The MulhimIQ bottom navigation bar. Card surface, hairline top border, the
/// active destination tinted with the accent and lifted onto a soft accent
/// wash. Reusable across role shells — pass any 3–5 [items].
class MqBottomNav extends StatelessWidget {
  const MqBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  }) : assert(items.length >= 2 && items.length <= 5,
            'Bottom nav supports 2–5 destinations');

  final List<MqNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;

    return Container(
      decoration: BoxDecoration(
        color: mq.card,
        border: Border(top: BorderSide(color: mq.line)),
        boxShadow: mq.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MqSize.bottomNavHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavCell(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MqNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final color = selected ? mq.accent : mq.ink3;
    final icon = selected ? (item.activeIcon ?? item.icon) : item.icon;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.lg, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? mq.accentSoft : Colors.transparent,
              borderRadius: MqRadius.brPill,
            ),
            child: _IconWithBadge(
              icon: icon,
              color: color,
              count: item.badgeCount,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final badge = Icon(icon, size: MqSize.iconMd, color: color);
    if (count <= 0) return badge;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: mq.error,
              borderRadius: MqRadius.brPill,
              border: Border.all(color: mq.card, width: 1.5),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(
                color: mq.onAccent,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
