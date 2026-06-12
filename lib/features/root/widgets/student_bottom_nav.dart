// Student RootShell — custom MulhimIQ bottom navigation.
//
// PRESENTATION ONLY. Renders the same five tabs and calls [onTap] with the
// tapped tab's LOGICAL index — RootShell owns all selection / version-bump /
// PopScope logic. Tabs are laid out with الرئيسية in the visual centre, but
// every slot carries its real logical index (0 الرئيسية … 4 حجوزاتي) so the
// routes / indices / onTap behaviour are exactly as before regardless of the
// visual ordering.
//
// The SELECTED tab becomes a dominant raised floating blue circle at its own
// position; the others are normal muted icon-above-label items. When the
// selection changes the circle slides smoothly to the newly-selected tab
// (AnimatedPositionedDirectional, RTL-aware) and the labels recolour. Light =
// white elevated bar; dark = dark-navy bar.

import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

class StudentBottomNav extends StatelessWidget {
  const StudentBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  // MulhimIQ Blue — active accent.
  static const Color _blue = Color(0xFF1F4D8F);

  // Visual order (right → left in RTL) with each slot's LOGICAL index last.
  // الرئيسية sits in the visual centre; logical indices are untouched.
  static const List<(IconData, IconData, String, int)> _tabs = [
    (Icons.menu_book_outlined, Icons.menu_book, 'الدورات', 1),
    (Icons.school_outlined, Icons.school, 'دوراتي', 2),
    (Icons.home_outlined, Icons.home_rounded, 'الرئيسية', 0),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'فواتيري', 3),
    (Icons.event_note_outlined, Icons.event_note, 'حجوزاتي', 4),
  ];

  static const double _barHeight = 60;
  static const double _raise = 28; // overflow region above the bar
  static const double _circle = 58; // floating button outer diameter
  static const Duration _dur = Duration(milliseconds: 300);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barColor = isDark ? const Color(0xFF13294B) : Colors.white;
    final Color muted = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : const Color(0xFF8A94A6);
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // Visual slot that holds the currently-selected logical index.
    final activeSlot = _tabs.indexWhere((t) => t.$4 == currentIndex);
    final activeIcon = activeSlot >= 0 ? _tabs[activeSlot].$2 : _tabs.first.$2;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: _raise + _barHeight + bottomInset,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotW = constraints.maxWidth / 5;
            // Start offset (RTL-aware) of the floating circle for the active slot.
            final circleStart = (activeSlot < 0 ? 0 : activeSlot) * slotW + (slotW - _circle) / 2;

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
                      color: barColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.08,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        for (int i = 0; i < _tabs.length; i++)
                          Expanded(child: _slot(i, muted)),
                      ],
                    ),
                  ),
                ),
                // ── Floating active circle (slides to the selected tab) ────
                AnimatedPositionedDirectional(
                  duration: _dur,
                  curve: _curve,
                  start: circleStart,
                  top: 0,
                  width: _circle,
                  height: _circle,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(currentIndex),
                    child: _floatingButton(barColor, isDark, activeIcon),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _slot(int slot, Color muted) {
    final (outline, _, label, logical) = _tabs[slot];
    final selected = logical == currentIndex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(logical),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The selected slot's icon fades out — the floating circle takes its
          // place above. Layout space is kept so labels stay aligned.
          AnimatedOpacity(
            duration: _dur,
            curve: _curve,
            opacity: selected ? 0 : 1,
            child: Icon(outline, size: MqSize.iconMd, color: muted),
          ),
          const SizedBox(height: MqSpacing.xxs),
          AnimatedDefaultTextStyle(
            duration: _dur,
            curve: _curve,
            style: TextStyle(
              fontSize: 11,
              color: selected ? _blue : muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _floatingButton(Color barColor, bool isDark, IconData icon) {
    return Container(
      // Halo in the bar colour gives the floating "cut-out" look.
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: barColor,
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: isDark ? 0.45 : 0.32),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _blue),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey<int>(icon.codePoint),
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
