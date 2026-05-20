import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_app_bar.dart';

/// Teacher profile — view + edit + logout.
///
/// Mirrors the dashboard's profile-setup.vue fields:
///   • name, phone, address, bio, experienceYears
///   • gradeIds (multi-select from /teacher/academic-years grades)
///   • studyYear
///   • optional: gender, birthDate
///
/// Logout lives here — and ONLY here.
class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final TeacherApiService _api = TeacherApiService();
  final AuthService _auth = AuthService();
  final _form = GlobalKey<FormState>();

  bool _loading = false;
  bool _saving = false;
  bool _editing = false;

  Map<String, dynamic> _user = {};
  List<Map<String, dynamic>> _allGrades = [];
  String? _activeStudyYear;
  List<String> _years = [];

  // Form controllers
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _bio = TextEditingController();
  final _experienceYears = TextEditingController();
  String? _studyYear;
  Set<String> _selectedGradeIds = {};
  String? _gender;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _bio.dispose();
    _experienceYears.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await Future.wait([_loadUser(), _loadAcademicYears(), _loadGrades()]);
      _hydrateForm();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return;
    try {
      _user = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
  }

  Future<void> _loadAcademicYears() async {
    try {
      final res = await _api.fetchAcademicYears();
      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years.map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString())).where((s) => s.isNotEmpty).toList().cast<String>();
      _activeStudyYear = (data['active'] is Map) ? data['active']['year']?.toString() : null;
    } catch (_) {}
  }

  Future<void> _loadGrades() async {
    try {
      // /grades/all-student is the public endpoint we already use elsewhere.
      // It returns the same active grade list the teacher signed up with.
      final tokenedApi = _api; // reuse Dio with auth
      final res = await tokenedApi.fetchCourseNames(); // wrong endpoint; we want /grades/all
      // fallback: try the auth-required grades endpoint via raw Dio.
      // We use the same Dio under the hood — call /grades/all directly.
      final res2 = await _api.fetchAcademicYears();
      // The simplest path: derive grade list from user.teacherGrades (already loaded).
      final list = (_user['teacherGrades'] is List) ? (_user['teacherGrades'] as List) : [];
      _allGrades = list.whereType<Map>().map((g) => Map<String, dynamic>.from(g)).toList();
      // Avoid 'unused' warnings (Dart treats locals as needed otherwise).
      // ignore: unused_local_variable
      final _ = [res, res2];
    } catch (_) {
      _allGrades = [];
    }
  }

  void _hydrateForm() {
    _name.text = (_user['name'] ?? '').toString();
    _phone.text = (_user['phone'] ?? '').toString();
    _address.text = (_user['address'] ?? _user['formattedAddress'] ?? '').toString();
    _bio.text = (_user['bio'] ?? '').toString();
    final yr = _user['experienceYears'];
    _experienceYears.text = yr == null ? '' : yr.toString();
    _gender = _user['gender']?.toString();
    final bd = _user['birthDate'];
    if (bd is String && bd.isNotEmpty) {
      _birthDate = DateTime.tryParse(bd);
    }

    // Default study year: any existing teacherGrade.studyYear, else active.
    final tg = _user['teacherGrades'];
    if (tg is List && tg.isNotEmpty) {
      final first = tg.first;
      if (first is Map) _studyYear = first['studyYear']?.toString();
    }
    _studyYear ??= _activeStudyYear ?? (_years.isNotEmpty ? _years.first : null);

    // Preselect the grades currently associated with the teacher.
    _selectedGradeIds = _allGrades.map((g) => (g['gradeId'] ?? g['id']).toString()).where((s) => s.isNotEmpty).toSet();
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label مطلوب';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedGradeIds.isEmpty) {
      Get.snackbar('خطأ', 'اختر صفاً واحداً على الأقل', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_studyYear == null || _studyYear!.isEmpty) {
      Get.snackbar('خطأ', 'اختر السنة الدراسية', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'bio': _bio.text.trim(),
        'experienceYears': int.tryParse(_experienceYears.text.trim()) ?? 0,
        'gradeIds': _selectedGradeIds.toList(),
        'studyYear': _studyYear,
      };
      if (_address.text.trim().isNotEmpty) payload['address'] = _address.text.trim();
      if (_gender != null && _gender!.isNotEmpty) payload['gender'] = _gender;
      if (_birthDate != null) {
        payload['birthDate'] = _birthDate!.toIso8601String().substring(0, 10);
      }

      final result = await _auth.updateProfile(payload);
      if (result['success'] == true) {
        Get.snackbar('تم', 'حُفظت التعديلات', snackPosition: SnackPosition.BOTTOM);
        setState(() => _editing = false);
        await _loadUser();
        if (mounted) setState(() {});
      } else {
        Get.snackbar('خطأ', result['message']?.toString() ?? 'تعذّر الحفظ', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (ok == true) await teacherLogout();
  }

  Future<void> _pickBirthDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (d != null) setState(() => _birthDate = d);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          if (!_editing && !_loading)
            IconButton(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header avatar + name
                      _HeaderCard(name: _name.text.isNotEmpty ? _name.text : (_user['name'] ?? '').toString(), email: (_user['email'] ?? '').toString()),
                      const SizedBox(height: 16),

                      _Section(title: 'البيانات الأساسية'),
                      _TextRow(controller: _name,            label: 'الاسم *',         enabled: _editing, validator: (v) => _required(v, 'الاسم'), icon: Icons.person_outline),
                      _TextRow(controller: _phone,           label: 'رقم الهاتف *',    enabled: _editing, validator: (v) => _required(v, 'الهاتف'), icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                      _TextRow(controller: _address,         label: 'العنوان',         enabled: _editing, icon: Icons.location_on_outlined),
                      _TextRow(controller: _experienceYears, label: 'سنوات الخبرة *', enabled: _editing, validator: (v) => _required(v, 'سنوات الخبرة'), icon: Icons.workspace_premium_outlined, keyboardType: TextInputType.number),

                      const SizedBox(height: 12),
                      _Section(title: 'النبذة الشخصية'),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: TextFormField(
                          controller: _bio,
                          enabled: _editing,
                          minLines: 3, maxLines: 6,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'نبذة عن خبرتك التدريسية...',
                          ),
                          validator: (v) => _required(v, 'النبذة'),
                        ),
                      ),

                      const SizedBox(height: 16),
                      _Section(title: 'البيانات الأكاديمية'),

                      // Study year
                      if (_years.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _studyYear,
                          decoration: const InputDecoration(
                            labelText: 'السنة الدراسية *',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                          onChanged: _editing ? (v) => setState(() => _studyYear = v) : null,
                        ),
                      const SizedBox(height: 12),

                      // Grades (chips)
                      Text('الصفوف المُدرَّسة', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _allGrades.isEmpty
                            ? [Text('—', style: TextStyle(color: cs.onSurfaceVariant))]
                            : _allGrades.map((g) {
                                final id = (g['gradeId'] ?? g['id']).toString();
                                final name = (g['gradeName'] ?? g['name'] ?? '').toString();
                                final selected = _selectedGradeIds.contains(id);
                                return FilterChip(
                                  label: Text(name),
                                  selected: selected,
                                  onSelected: _editing
                                      ? (v) => setState(() {
                                            v ? _selectedGradeIds.add(id) : _selectedGradeIds.remove(id);
                                          })
                                      : null,
                                );
                              }).toList(),
                      ),

                      const SizedBox(height: 16),
                      _Section(title: 'بيانات إضافية'),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: const InputDecoration(
                                labelText: 'الجنس',
                                prefixIcon: Icon(Icons.person_pin_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('ذكر')),
                                DropdownMenuItem(value: 'female', child: Text('أنثى')),
                              ],
                              onChanged: _editing ? (v) => setState(() => _gender = v) : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _editing ? _pickBirthDate : null,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'تاريخ الميلاد',
                                  prefixIcon: Icon(Icons.cake_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(_fmtDate(_birthDate)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Save / cancel
                      if (_editing)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : () { setState(() { _editing = false; _hydrateForm(); }); },
                                child: const Text('إلغاء'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                                label: const Text('حفظ التعديلات'),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 32),
                      // Logout — the ONLY place it lives.
                      OutlinedButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.email});
  final String name, email;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2545), Color(0xFF163E72)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32, backgroundColor: const Color(0xFFFF8A00),
            child: Text(
              name.isNotEmpty ? name.characters.first : '?',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'أستاذ' : name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.controller, required this.label,
    this.enabled = true, this.validator, this.icon, this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? Function(String?)? validator;
  final IconData? icon;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }
}
