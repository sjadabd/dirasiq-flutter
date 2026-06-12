import 'package:flutter/material.dart';

import 'design/teacher_design.dart';
import 'teacher_workspace.dart';

/// Teacher bottom navigation — MulhimIQ raised-center style.
///
/// Five tabs with الرئيسية in the visual centre. The tab matching the active
/// workspace page rises into a dominant floating accent circle; the rest are
/// flat muted icon-above-label items. Navigating moves that raised circle from
/// الرئيسية to the selected page (الجدول / الحجوزات / …). Drives the workspace
/// IndexedStack index — routes / state-preservation are unchanged.
///
/// When the active page is a drawer-only page (not one of the five tabs) no tab
/// is raised — the bar renders fully flat.
///
/// Controlled component: it's hosted ONCE at the [TeacherWorkspace] level (not
/// per page), so it stays mounted across tab switches and the floating circle
/// genuinely slides between tabs. [currentIndex] is the active workspace index;
/// [onTap] forwards a tapped tab's workspace index back to the workspace.
class TeacherBottomNav extends StatelessWidget {
  const TeacherBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  // Visual order (right → left in RTL) with each slot's workspace index last.
  // الرئيسية sits in the centre slot.
  static const List<(IconData, IconData, String, int)> _tabs = [
    (Icons.calendar_today_outlined,        Icons.calendar_today_rounded,        'الجدول',     TeacherWorkspaceState.sessionsIdx),
    (Icons.assignment_turned_in_outlined,  Icons.assignment_turned_in_rounded,  'الحجوزات',   TeacherWorkspaceState.bookingsIdx),
    (Icons.home_outlined,                  Icons.home_rounded,                  'الرئيسية',   TeacherWorkspaceState.homeIdx),
    (Icons.notifications_outlined,         Icons.notifications_rounded,         'الإشعارات',  TeacherWorkspaceState.notificationsIdx),
    (Icons.person_outline_rounded,         Icons.person_rounded,                'حسابي',      TeacherWorkspaceState.profileIdx),
  ];

  static const double _barHeight = 62;
  static const double _raise = 28; // overflow region above the bar
  static const double _circle = 58; // floating button outer diameter
  static const Duration _dur = Duration(milliseconds: 300);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final current = currentIndex;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final activeSlot = _tabs.indexWhere((t) => t.$4 == current);
    final hasActive = activeSlot >= 0;
    final activeIcon = hasActive ? _tabs[activeSlot].$2 : _tabs.first.$2;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: _raise + _barHeight + bottomInset,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotW = constraints.maxWidth / _tabs.length;
            final circleStart =
                (hasActive ? activeSlot : 0) * slotW + (slotW - _circle) / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Elevated bar ──────────────────────────────────────────
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: Container(
                    height: _barHeight + bottomInset,
                    padding: EdgeInsets.only(bottom: bottomInset),
                    decoration: BoxDecoration(
                      color: mq.card,
                      border: Border(top: BorderSide(color: mq.line)),
                      boxShadow: [
                        BoxShadow(
                          color: mq.accentShadow.withValues(alpha: 0.10),
                          blurRadius: 16,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        for (int i = 0; i < _tabs.length; i++)
                          Expanded(child: _slot(context, i, current)),
                      ],
                    ),
                  ),
                ),
                // ── Floating active circle ────────────────────────────────
                if (hasActive)
                  AnimatedPositionedDirectional(
                    duration: _dur,
                    curve: _curve,
                    start: circleStart,
                    top: 0,
                    width: _circle,
                    height: _circle,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(current),
                      child: _floatingButton(context, activeIcon),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, int slot, int current) {
    final mq = context.mq;
    final (outline, _, label, index) = _tabs[slot];
    final selected = index == current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The selected slot's icon fades out — the floating circle replaces
          // it. Layout space is kept so labels stay aligned.
          AnimatedOpacity(
            duration: _dur,
            curve: _curve,
            opacity: selected ? 0 : 1,
            child: Icon(outline, size: MqSize.iconMd, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.xxs),
          AnimatedDefaultTextStyle(
            duration: _dur,
            curve: _curve,
            style: context.text.labelSmall!.copyWith(
              color: selected ? mq.accent : mq.ink3,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _floatingButton(BuildContext context, IconData icon) {
    final mq = context.mq;
    return Container(
      // Halo in the bar colour gives the floating "cut-out" look.
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: mq.card,
        boxShadow: [
          BoxShadow(
            color: mq.accent.withValues(alpha: 0.32),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: mq.accent),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey<int>(icon.codePoint),
              size: 24,
              color: mq.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}
