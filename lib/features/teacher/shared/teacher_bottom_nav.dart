import 'package:flutter/material.dart';
import 'teacher_workspace.dart';

/// Bottom nav — quick access for the 5 most-used pages.
/// Drives the workspace IndexedStack index (same mechanism as the drawer).
class TeacherBottomNav extends StatelessWidget {
  const TeacherBottomNav({super.key});

  static const _tabs = <_Tab>[
    _Tab(TeacherWorkspaceState.homeIdx,          Icons.dashboard_outlined,            Icons.dashboard,            'الرئيسية'),
    _Tab(TeacherWorkspaceState.sessionsIdx,      Icons.calendar_today_outlined,       Icons.calendar_today,       'الجدول'),
    _Tab(TeacherWorkspaceState.bookingsIdx,      Icons.assignment_turned_in_outlined, Icons.assignment_turned_in, 'الحجوزات'),
    _Tab(TeacherWorkspaceState.notificationsIdx, Icons.notifications_outlined,        Icons.notifications,        'الإشعارات'),
    _Tab(TeacherWorkspaceState.profileIdx,       Icons.person_outline,                Icons.person,               'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = TeacherWorkspace.currentIndexOf(context) ?? 0;
    int selected = 0;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].index == current) { selected = i; break; }
    }
    return NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (i) => TeacherWorkspace.switchTo(context, _tabs[i].index),
      backgroundColor: cs.surface,
      indicatorColor: cs.primary.withValues(alpha: 0.12),
      destinations: [
        for (final t in _tabs)
          NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
      ],
    );
  }
}

class _Tab {
  const _Tab(this.index, this.icon, this.selectedIcon, this.label);
  final int index;
  final IconData icon, selectedIcon;
  final String label;
}
