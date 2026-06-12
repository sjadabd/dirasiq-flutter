// Create-group flow for teachers (Teacher Design System pass).
//
// Two-step screen:
//   1. Group details — name (required), description, mode toggle (open vs
//      announce_only).
//   2. Members — picked from the teacher's enrolled-students roster via a
//      bottom-sheet multi-select. No raw-UUID typing.
//
// Presentation only: ChatApiService.createGroup / addMembers, the validation,
// the member picker, and the `Get.back(result: true)` contract are UNCHANGED.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/design/teacher_design.dart';
import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import '../widgets/student_picker_sheet.dart';

class TeacherCreateGroupScreen extends StatefulWidget {
  const TeacherCreateGroupScreen({super.key});

  @override
  State<TeacherCreateGroupScreen> createState() =>
      _TeacherCreateGroupScreenState();
}

class _TeacherCreateGroupScreenState extends State<TeacherCreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  ConversationMode _mode = ConversationMode.open;
  final List<({String id, String name})> _selectedMembers = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickMembers() async {
    final excluded = _selectedMembers.map((m) => m.id).toSet();
    final picked = await StudentPickerSheet.show(
      context,
      title: 'اختر الطلاب',
      excludeUserIds: excluded,
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final p in picked) {
        if (_selectedMembers.any((m) => m.id == p.id)) continue;
        _selectedMembers.add((id: p.id, name: p.name));
      }
    });
  }

  void _removeMember(String id) {
    setState(() => _selectedMembers.removeWhere((m) => m.id == id));
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ChatApiService.instance.createGroup(
        name: _name.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        mode: _mode,
      );

      if (_selectedMembers.isNotEmpty) {
        final convId = result['conversation']?['id']?.toString();
        if (convId != null) {
          try {
            await ChatApiService.instance.addMembers(
              convId,
              _selectedMembers.map((m) => m.id).toList(),
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('تم إنشاء المجموعة، لكن تعذّر إضافة بعض الأعضاء.'),
                ),
              );
            }
          }
        }
      }

      if (!mounted) return;
      Get.back(result: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _humanise(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: AppBar(
              backgroundColor: mq.card,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text('مجموعة جديدة',
                  style: context.text.titleMedium?.copyWith(color: mq.ink)),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: mq.line),
              ),
            ),
            body: AbsorbPointer(
              absorbing: _saving,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  children: [
                    // ── Group details ──────────────────────────────────────
                    MqCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionTitle(context, 'تفاصيل المجموعة',
                              Icons.groups_2_outlined),
                          const SizedBox(height: MqSpacing.md),
                          TextFormField(
                            controller: _name,
                            maxLength: 120,
                            decoration: const InputDecoration(
                              labelText: 'اسم المجموعة *',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                          ),
                          const SizedBox(height: MqSpacing.sm),
                          TextFormField(
                            controller: _description,
                            maxLength: 1000,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'وصف اختياري',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MqSpacing.md),

                    // ── Mode ───────────────────────────────────────────────
                    MqCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionTitle(
                              context, 'وضع المجموعة', Icons.tune_rounded),
                          const SizedBox(height: MqSpacing.md),
                          _ModeOption(
                            icon: Icons.forum_outlined,
                            title: 'الجميع يكتب',
                            subtitle: 'يمكن لكل الأعضاء إرسال الرسائل',
                            selected: _mode == ConversationMode.open,
                            onTap: () =>
                                setState(() => _mode = ConversationMode.open),
                          ),
                          const SizedBox(height: MqSpacing.sm),
                          _ModeOption(
                            icon: Icons.campaign_outlined,
                            title: 'إعلانات فقط',
                            subtitle: 'أنت فقط من يرسل، الأعضاء يقرؤون',
                            selected: _mode == ConversationMode.announceOnly,
                            onTap: () => setState(
                                () => _mode = ConversationMode.announceOnly),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MqSpacing.md),

                    // ── Members ────────────────────────────────────────────
                    MqCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _sectionTitle(context, 'الأعضاء',
                                    Icons.group_outlined),
                              ),
                              MqButton.text(
                                label: _selectedMembers.isEmpty
                                    ? 'اختر طلاب'
                                    : 'إضافة المزيد',
                                icon: Icons.person_add_alt_1,
                                onPressed: _saving ? null : _pickMembers,
                              ),
                            ],
                          ),
                          const SizedBox(height: MqSpacing.sm),
                          if (_selectedMembers.isEmpty)
                            MqSurface(
                              tone: MqSurfaceTone.neutral,
                              child: Text(
                                'لم يتم اختيار أعضاء بعد. يمكنك تركها فارغة وإضافتهم لاحقاً من إعدادات المجموعة.',
                                style: context.text.bodySmall
                                    ?.copyWith(color: mq.ink2),
                              ),
                            )
                          else
                            Wrap(
                              spacing: MqSpacing.sm,
                              runSpacing: MqSpacing.sm,
                              children: [
                                for (final m in _selectedMembers)
                                  _MemberChip(
                                    name: m.name,
                                    onRemove: () => _removeMember(m.id),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: MqSpacing.md),
                      MqSurface(
                        tone: MqSurfaceTone.neutral,
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 18, color: mq.error),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text(_error!,
                                  style: context.text.bodySmall
                                      ?.copyWith(color: mq.error)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: MqSpacing.lg),
                    MqButton(
                      label: _saving ? 'جارٍ الإنشاء…' : 'إنشاء المجموعة',
                      icon: _saving ? null : Icons.check_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : _create,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, IconData icon) {
    final mq = context.mq;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration:
              BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
          child: Icon(icon, size: MqSize.iconSm, color: mq.accent),
        ),
        const SizedBox(width: MqSpacing.sm),
        Text(text, style: context.text.titleSmall),
      ],
    );
  }

  String _humanise(Object e) {
    final s = e.toString();
    if (s.contains('ROLE_REQUIRED')) {
      return 'إنشاء المجموعات متاح للمعلمين فقط.';
    }
    if (s.contains('SocketException')) {
      return 'تحقّق من الإنترنت ثم حاول مجدّداً.';
    }
    return 'تعذّر إنشاء المجموعة.';
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: selected ? mq.accentSoft : mq.fill,
      borderRadius: MqRadius.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(MqSpacing.md),
          decoration: BoxDecoration(
            borderRadius: MqRadius.brMd,
            border: Border.all(color: selected ? mq.accent : mq.line),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: MqSize.iconMd, color: selected ? mq.accent : mq.ink2),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: context.text.bodyMedium?.copyWith(
                            color: selected ? mq.accent : mq.ink,
                            fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style:
                            context.text.labelSmall?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? mq.accent : mq.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.name, required this.onRemove});
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsetsDirectional.only(
          start: 4, end: MqSpacing.sm, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: mq.fill,
        borderRadius: MqRadius.brPill,
        border: Border.all(color: mq.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: mq.accentSoft,
            child: Text(
              name.isNotEmpty ? name.characters.first : '؟',
              style: MqTypography.mono(
                  color: mq.accent, size: 11, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: MqSpacing.xs),
          Text(name, style: context.text.labelMedium?.copyWith(color: mq.ink)),
          const SizedBox(width: MqSpacing.xs),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: Icon(Icons.close_rounded, size: 16, color: mq.ink3),
          ),
        ],
      ),
    );
  }
}
