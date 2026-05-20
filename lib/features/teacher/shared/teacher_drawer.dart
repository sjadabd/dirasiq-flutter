import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_workspace.dart';

/// Teacher drawer — drives the workspace's IndexedStack index, NOT route nav.
///
/// Why: route-based nav (Get.toNamed / offNamed) creates these UX problems:
///   • offNamed = no history (back-button exits app)
///   • toNamed  = pages unmount on each navigation (lose filters / scroll)
///   • Either way the chunk-build flash and re-fetch is visible.
///
/// IndexedStack-backed workspace gives:
///   • State preservation (filters/scroll/data survive the menu round-trip)
///   • Instant transitions (no rebuild)
///   • Working back-button (workspace maintains its own history)
class TeacherDrawer extends StatelessWidget {
  const TeacherDrawer({super.key});

  Future<Map<String, dynamic>?> _readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  void _go(BuildContext ctx, int index) {
    Navigator.of(ctx).pop(); // close drawer first
    TeacherWorkspace.switchTo(ctx, index);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = TeacherWorkspace.currentIndexOf(context) ?? 0;

    return Drawer(
      child: SafeArea(child: Column(children: [
        FutureBuilder<Map<String, dynamic>?>(
          future: _readUser(),
          builder: (ctx, snap) {
            final user = snap.data;
            final name = (user?['name'] ?? 'أستاذ').toString();
            final email = (user?['email'] ?? '').toString();
            return InkWell(
              onTap: () => _go(context, TeacherWorkspaceState.profileIdx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0B2545), Color(0xFF163E72)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 28, backgroundColor: const Color(0xFFFF8A00),
                    child: Text(name.isNotEmpty ? name.characters.first : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  const Icon(Icons.chevron_left, color: Colors.white),
                ]),
              ),
            );
          },
        ),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          _Item(active: active, index: TeacherWorkspaceState.homeIdx,                icon: Icons.dashboard_outlined,             label: 'الرئيسية',           onTap: _go),

          const _Section('المالية'),
          _Item(active: active, index: TeacherWorkspaceState.reservationPaymentsIdx, icon: Icons.local_atm_outlined,            label: 'فواتير العربون',      onTap: _go),
          _Item(active: active, index: TeacherWorkspaceState.invoicesIdx,            icon: Icons.receipt_long_outlined,          label: 'فواتير الطلاب',       onTap: _go),
          _Item(active: active, index: TeacherWorkspaceState.expensesIdx,            icon: Icons.shopping_cart_outlined,         label: 'المصاريف',            onTap: _go),
          _Item(active: active, index: TeacherWorkspaceState.reportsIdx,             icon: Icons.bar_chart_outlined,             label: 'التقارير المالية',    onTap: _go),
          _Item(active: active, index: TeacherWorkspaceState.walletIdx,              icon: Icons.account_balance_wallet_outlined, label: 'المحفظة',             onTap: _go),

          const _Section('المحتوى'),
          _Item(active: active, index: TeacherWorkspaceState.subjectsIdx,            icon: Icons.menu_book_outlined,             label: 'المواد',              onTap: _go),
          _Item(active: active, index: TeacherWorkspaceState.coursesIdx,             icon: Icons.school_outlined,                label: 'الكورسات',            onTap: _go),
          _Item(active: active, index: TeacherWorkspaceState.sessionsIdx,            icon: Icons.calendar_today_outlined,        label: 'الجدول الأسبوعي',     onTap: _go),

          const _Section('الطلاب'),
          _Item(active: active, index: TeacherWorkspaceState.bookingsIdx,            icon: Icons.assignment_turned_in_outlined,  label: 'الحجوزات',            onTap: _go),

          const _Section('التواصل'),
          _Item(active: active, index: TeacherWorkspaceState.chatsIdx,               icon: Icons.chat_bubble_outline,            label: 'المحادثات',           onTap: _go),
          _Item(active: active, index: TeacherWorkspaceState.notificationsIdx,       icon: Icons.notifications_outlined,         label: 'الإشعارات',           onTap: _go),

          const Divider(height: 1),
          _Item(active: active, index: TeacherWorkspaceState.profileIdx,             icon: Icons.person_outline,                 label: 'حسابي',               onTap: _go),

          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'لإدارة باقة الاشتراك والمدفوعات، استخدم لوحة التحكم على الويب.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ])),
      ])),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
          color: cs.onSurfaceVariant, letterSpacing: 0.5)),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.active, required this.index, required this.icon, required this.label, required this.onTap});
  final int active;
  final int index;
  final IconData icon;
  final String label;
  final void Function(BuildContext, int) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = active == index;
    final color = isActive ? cs.primary : cs.onSurface;
    return Stack(children: [
      if (isActive) Positioned.fill(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      )),
      if (isActive) Positioned(right: 0, top: 6, bottom: 6,
        child: Container(width: 4, decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
        )),
      ),
      ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, size: 22, color: color),
        title: Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.w500)),
        trailing: isActive
            ? Icon(Icons.check, size: 16, color: cs.primary)
            : Icon(Icons.chevron_left, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        onTap: () => onTap(context, index),
      ),
    ]);
  }
}
