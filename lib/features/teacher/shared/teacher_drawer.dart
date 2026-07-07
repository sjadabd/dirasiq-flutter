import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design/teacher_design.dart';
import 'teacher_workspace.dart';

/// Teacher drawer — drives the workspace's IndexedStack index, NOT route nav.
///
/// Restyled to the Teacher Design System: the hero-gradient profile header, the
/// `context.mq` token surfaces, Cairo type, and soft icon chips that match the
/// dashboard cards + header. Light/dark via [MqTheme]. The IndexedStack-backed
/// navigation contract is unchanged (state preservation, working back-button).
class TeacherDrawer extends StatelessWidget {
  const TeacherDrawer({super.key});

  Future<Map<String, dynamic>?> _readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _go(BuildContext ctx, int index) {
    Navigator.of(ctx).pop(); // close drawer first
    TeacherWorkspace.jumpTo(ctx, index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Builder(builder: (context) {
        final mq = context.mq;
        final active = TeacherWorkspace.currentIndexOf(context) ?? 0;

        return Drawer(
          backgroundColor: mq.card,
          shape: const RoundedRectangleBorder(),
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
                  children: [
                    _Item(active: active, index: TeacherWorkspaceState.homeIdx,                icon: Icons.dashboard_outlined,             label: 'الرئيسية',           onTap: _go),

                    const _Section('المالية'),
                    _Item(active: active, index: TeacherWorkspaceState.reservationPaymentsIdx, icon: Icons.local_atm_outlined,             label: 'فواتير العربون',     onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.invoicesIdx,            icon: Icons.receipt_long_outlined,          label: 'فواتير الطلاب',      onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.expensesIdx,            icon: Icons.shopping_cart_outlined,         label: 'المصاريف',           onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.reportsIdx,             icon: Icons.bar_chart_outlined,             label: 'التقارير المالية',   onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.walletIdx,              icon: Icons.account_balance_wallet_outlined, label: 'المحفظة',           onTap: _go),

                    const _Section('المحتوى'),
                    _Item(active: active, index: TeacherWorkspaceState.subjectsIdx,            icon: Icons.menu_book_outlined,             label: 'المواد',             onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.coursesIdx,             icon: Icons.school_outlined,                label: 'الكورسات',           onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.videoCoursesIdx,        icon: Icons.video_library_outlined,         label: 'الدورات المرئية',    onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.advertisementsIdx, icon: Icons.campaign_outlined, label: 'الإعلانات', onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.sessionsIdx,            icon: Icons.calendar_today_outlined,        label: 'الجدول الأسبوعي',    onTap: _go),

                    const _Section('الطلاب'),
                    _Item(active: active, index: TeacherWorkspaceState.bookingsIdx,            icon: Icons.assignment_turned_in_outlined,  label: 'الحجوزات',           onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.attendanceQrIdx,        icon: Icons.qr_code_2_rounded,              label: 'رمز الحضور',         onTap: _go),

                    const _Section('التواصل'),
                    _Item(active: active, index: TeacherWorkspaceState.chatsIdx,               icon: Icons.chat_bubble_outline_rounded,    label: 'المحادثات',          onTap: _go),
                    _Item(active: active, index: TeacherWorkspaceState.notificationsIdx,       icon: Icons.notifications_outlined,         label: 'الإشعارات',          onTap: _go),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: MqSpacing.lg, vertical: MqSpacing.sm),
                      child: Divider(height: 1, color: mq.line),
                    ),
                    _Item(active: active, index: TeacherWorkspaceState.profileIdx,             icon: Icons.person_outline_rounded,         label: 'حسابي',              onTap: _go),
                  ],
                ),
              ),
              _footer(context),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.teacher;
    return FutureBuilder<Map<String, dynamic>?>(
      future: _readUser(),
      builder: (ctx, snap) {
        final user = snap.data;
        final name = (user?['name'] ?? 'أستاذ').toString();
        final email = (user?['email'] ?? '').toString();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _go(context, TeacherWorkspaceState.profileIdx),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(MqSpacing.lg,
                  MediaQuery.of(context).padding.top + MqSpacing.lg, MqSpacing.lg, MqSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.heroA, t.heroB],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: context.mq.orange,
                    child: Text(
                      name.isNotEmpty ? name.characters.first : '؟',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: MqSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(color: t.heroInk)),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(color: t.heroInk2)),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, color: t.heroInk2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _footer(BuildContext context) {
    final mq = context.mq;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
            MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.md),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: mq.line)),
        ),
        child: Text(
          'لإدارة باقة الاشتراك والمدفوعات، استخدم لوحة التحكم على الويب.',
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(color: mq.ink3, height: 1.5),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.xl, MqSpacing.md, MqSpacing.xl, MqSpacing.xs),
      child: Text(
        text,
        style: context.text.labelSmall?.copyWith(
          color: context.mq.ink3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.active,
    required this.index,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final int active;
  final int index;
  final IconData icon;
  final String label;
  final void Function(BuildContext, int) onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final isActive = active == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.sm, vertical: 2),
      child: Material(
        color: isActive ? mq.accentSoft : Colors.transparent,
        borderRadius: MqRadius.brMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(context, index),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.sm, vertical: MqSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive ? mq.accent : mq.fill,
                    borderRadius: MqRadius.brSm,
                    border: Border.all(color: isActive ? mq.accent : mq.line),
                  ),
                  child: Icon(icon,
                      size: 18, color: isActive ? mq.onAccent : mq.ink2),
                ),
                const SizedBox(width: MqSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      color: isActive ? mq.accent : mq.ink,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  isActive ? Icons.check_rounded : Icons.chevron_left_rounded,
                  size: isActive ? 18 : 20,
                  color: isActive ? mq.accent : mq.ink3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
