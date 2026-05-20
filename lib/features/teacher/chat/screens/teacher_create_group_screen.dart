// Create-group flow for teachers.
//
// Two-step screen:
//   1. Group details — name (required), description, mode toggle (open vs
//      announce_only). Course-id linking is deferred (no picker yet).
//   2. Members — picked from the teacher's enrolled-students roster via a
//      bottom-sheet multi-select. No raw-UUID typing.
//
// Members can be added now or later from group settings; both flows reuse
// the same picker.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
                  content: Text(
                      'تم إنشاء المجموعة، لكن تعذّر إضافة بعض الأعضاء.'),
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('مجموعة جديدة')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Group details ─────────────────────────────────────────────
              Text('تفاصيل المجموعة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'اسم المجموعة *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'الاسم مطلوب';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                maxLength: 1000,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'وصف اختياري',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // ── Mode ───────────────────────────────────────────────────────
              Text('وضع المجموعة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 4),
              SegmentedButton<ConversationMode>(
                segments: const [
                  ButtonSegment(
                    value: ConversationMode.open,
                    icon: Icon(Icons.forum_outlined),
                    label: Text('الجميع يكتب'),
                  ),
                  ButtonSegment(
                    value: ConversationMode.announceOnly,
                    icon: Icon(Icons.campaign_outlined),
                    label: Text('إعلانات فقط'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),

              // ── Members ───────────────────────────────────────────────────
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('الأعضاء',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickMembers,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: Text(_selectedMembers.isEmpty
                        ? 'اختر طلاب'
                        : 'إضافة المزيد'),
                  ),
                ],
              ),
              if (_selectedMembers.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'لم يتم اختيار أعضاء بعد. يمكنك تركها فارغة وإضافتهم لاحقاً من إعدادات المجموعة.',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in _selectedMembers)
                      InputChip(
                        avatar: CircleAvatar(
                          backgroundColor:
                              cs.primary.withValues(alpha: 0.12),
                          child: Text(
                            m.name.isNotEmpty ? m.name.characters.first : '?',
                            style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                        label: Text(m.name),
                        onDeleted: () => _removeMember(m.id),
                      ),
                  ],
                ),

              // ── Error + submit ────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: TextStyle(color: cs.onErrorContainer)),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _create,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'جارٍ الإنشاء…' : 'إنشاء المجموعة'),
              ),
            ],
          ),
        ),
      ),
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
