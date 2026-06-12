import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import 'widgets/teacher_location_picker.dart';

/// Teacher profile — view + edit + logout (Teacher Design System pass).
///
/// Presentation only — `updateProfile`, `syncMyTeacherGrades`, the academic-
/// years / grades loading, the edit/save flow, and the logout are UNCHANGED.
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

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _bio = TextEditingController();
  final _experienceYears = TextEditingController();
  String? _studyYear;
  Set<String> _selectedGradeIds = {};
  String? _gender;
  DateTime? _birthDate;
  double? _latitude;
  double? _longitude;

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
      await _loadUser();
      await Future.wait([
        _loadAcademicYears(),
        _loadGradesCatalog(),
        _loadMyGrades(),
      ]);
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
      final data =
          (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years
          .map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString()))
          .where((s) => s.isNotEmpty)
          .toList()
          .cast<String>();
      _activeStudyYear =
          (data['active'] is Map) ? data['active']['year']?.toString() : null;
    } catch (_) {}
  }

  Future<void> _loadGradesCatalog() async {
    try {
      final res = await _api.fetchAllGrades();
      final data = res['data'];
      if (data is List) {
        _allGrades = data
            .whereType<Map>()
            .map((g) => Map<String, dynamic>.from(g))
            .toList();
      } else {
        _allGrades = [];
      }
    } catch (_) {
      _allGrades = [];
    }
  }

  Future<void> _loadMyGrades() async {
    try {
      final res = await _api.fetchMyTeacherGrades();
      final data =
          res['data'] is Map ? Map<String, dynamic>.from(res['data']) : {};
      final yr = data['studyYear']?.toString();
      if (yr != null && yr.isNotEmpty) {
        _activeStudyYear = yr;
      }
      final grades =
          (data['grades'] is List) ? data['grades'] as List : const [];
      _selectedGradeIds = grades
          .whereType<Map>()
          .map((g) => (g['gradeId'] ?? g['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (_) {
      final list = (_user['teacherGrades'] is List)
          ? (_user['teacherGrades'] as List)
          : const [];
      _selectedGradeIds = list
          .whereType<Map>()
          .map((g) => (g['gradeId'] ?? g['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
  }

  void _hydrateForm() {
    _name.text = (_user['name'] ?? '').toString();
    _phone.text = (_user['phone'] ?? '').toString();
    _address.text =
        (_user['address'] ?? _user['formattedAddress'] ?? '').toString();
    _bio.text = (_user['bio'] ?? '').toString();
    final yr = _user['experienceYears'];
    _experienceYears.text = yr == null ? '' : yr.toString();
    _gender = _user['gender']?.toString();
    final bd = _user['birthDate'];
    if (bd is String && bd.isNotEmpty) {
      _birthDate = DateTime.tryParse(bd);
    }

    final tg = _user['teacherGrades'];
    if (tg is List && tg.isNotEmpty) {
      final first = tg.first;
      if (first is Map) _studyYear = first['studyYear']?.toString();
    }
    _studyYear ??= _activeStudyYear ?? (_years.isNotEmpty ? _years.first : null);

    final loc = _user['location'] is Map ? _user['location'] as Map : null;
    _latitude = _toDouble(_user['latitude'] ?? loc?['latitude']);
    _longitude = _toDouble(_user['longitude'] ?? loc?['longitude']);
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label مطلوب';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedGradeIds.isEmpty) {
      Get.snackbar('خطأ', 'اختر صفاً واحداً على الأقل',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_studyYear == null || _studyYear!.isEmpty) {
      Get.snackbar('خطأ', 'اختر السنة الدراسية',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'bio': _bio.text.trim(),
        'experienceYears': int.tryParse(_experienceYears.text.trim()) ?? 0,
        // The teacher update-profile schema REQUIRES these two even though the
        // handler ignores them for teachers (grades persist via
        // syncMyTeacherGrades below). Omitting them → 400 VALIDATION_ERROR.
        'gradeIds': _selectedGradeIds.toList(),
        'studyYear': _studyYear,
      };
      if (_address.text.trim().isNotEmpty) {
        payload['address'] = _address.text.trim();
      }
      if (_gender != null && _gender!.isNotEmpty) payload['gender'] = _gender;
      if (_birthDate != null) {
        payload['birthDate'] = _birthDate!.toIso8601String().substring(0, 10);
      }
      if (_latitude != null && _longitude != null) {
        payload['latitude'] = _latitude;
        payload['longitude'] = _longitude;
      }

      final result = await _auth.updateProfile(payload);
      if (result['success'] != true) {
        Get.snackbar('خطأ', result['message']?.toString() ?? 'تعذّر الحفظ',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      try {
        await _api.syncMyTeacherGrades(_selectedGradeIds.toList());
      } catch (e) {
        Get.snackbar(
          'تحذير',
          'حُفظت البيانات لكن تعذّر تحديث المراحل الدراسية: $e',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      Get.snackbar('تم', 'حُفظت التعديلات', snackPosition: SnackPosition.BOTTOM);
      setState(() => _editing = false);
      await _loadUser();
      await _loadMyGrades();
      if (mounted) setState(() {});
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'الملف الشخصي',
              actions: [
                if (!_editing && !_loading)
                  _ActionChip(
                      icon: Icons.edit_outlined,
                      onTap: () => setState(() => _editing = true)),
              ],
            ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                          MqSpacing.lg, MqSpacing.lg, MqSpacing.xl),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _header(context),
                            const SizedBox(height: MqSpacing.lg),
                            _basicCard(context),
                            const SizedBox(height: MqSpacing.md),
                            _bioCard(context),
                            const SizedBox(height: MqSpacing.md),
                            _academicCard(context),
                            const SizedBox(height: MqSpacing.md),
                            _extraCard(context),
                            const SizedBox(height: MqSpacing.md),
                            _locationCard(context),
                            const SizedBox(height: MqSpacing.lg),
                            if (_editing) _editActions(context),
                            const SizedBox(height: MqSpacing.lg),
                            _logoutButton(context),
                          ],
                        ),
                      ),
                    ),
                  ),
          );
        }),
      ),
    );
  }

  // ---- header ---------------------------------------------------------------

  Widget _header(BuildContext context) {
    final t = context.teacher;
    final name = _name.text.isNotEmpty
        ? _name.text
        : (_user['name'] ?? 'أستاذ').toString();
    final email = (_user['email'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.heroA, t.heroB],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: MqRadius.brXl,
        boxShadow: t.shadowLg,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: context.mq.orange,
            child: Text(name.isNotEmpty ? name.characters.first : '؟',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'أستاذ' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge?.copyWith(color: t.heroInk)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall
                          ?.copyWith(color: t.heroInk2)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- cards ----------------------------------------------------------------

  Widget _basicCard(BuildContext context) {
    return _SectionCard(
      title: 'البيانات الأساسية',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _TextRow(
              controller: _name,
              label: 'الاسم *',
              enabled: _editing,
              validator: (v) => _required(v, 'الاسم'),
              icon: Icons.person_outline),
          _TextRow(
              controller: _phone,
              label: 'رقم الهاتف *',
              enabled: _editing,
              validator: (v) => _required(v, 'الهاتف'),
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          _TextRow(
              controller: _address,
              label: 'العنوان',
              enabled: _editing,
              icon: Icons.location_on_outlined),
          _TextRow(
              controller: _experienceYears,
              label: 'سنوات الخبرة *',
              enabled: _editing,
              validator: (v) => _required(v, 'سنوات الخبرة'),
              icon: Icons.workspace_premium_outlined,
              keyboardType: TextInputType.number,
              last: true),
        ],
      ),
    );
  }

  Widget _bioCard(BuildContext context) {
    return _SectionCard(
      title: 'النبذة الشخصية',
      icon: Icons.description_outlined,
      child: TextFormField(
        controller: _bio,
        enabled: _editing,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          hintText: 'نبذة عن خبرتك التدريسية...',
        ),
        validator: (v) => _required(v, 'النبذة'),
      ),
    );
  }

  Widget _academicCard(BuildContext context) {
    final mq = context.mq;
    return _SectionCard(
      title: 'البيانات الأكاديمية',
      icon: Icons.school_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_years.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _studyYear,
              dropdownColor: mq.card,
              decoration: const InputDecoration(
                labelText: 'السنة الدراسية *',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              items: _years
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged:
                  _editing ? (v) => setState(() => _studyYear = v) : null,
            ),
          const SizedBox(height: MqSpacing.md),
          Text('الصفوف المُدرَّسة',
              style: context.text.labelMedium?.copyWith(color: mq.ink2)),
          const SizedBox(height: MqSpacing.sm),
          if (_allGrades.isEmpty)
            Text('لا توجد مراحل متاحة حالياً',
                style: context.text.bodySmall?.copyWith(color: mq.ink3))
          else
            Wrap(
              spacing: MqSpacing.sm,
              runSpacing: MqSpacing.sm,
              children: _allGrades.map((g) {
                final id = (g['id'] ?? g['gradeId'] ?? '').toString();
                final name = (g['name'] ?? g['gradeName'] ?? '').toString();
                if (id.isEmpty) return const SizedBox.shrink();
                final selected = _selectedGradeIds.contains(id);
                return MqChip(
                  label: name,
                  selected: selected,
                  onTap: _editing
                      ? () => setState(() {
                            selected
                                ? _selectedGradeIds.remove(id)
                                : _selectedGradeIds.add(id);
                          })
                      : () {},
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _extraCard(BuildContext context) {
    final mq = context.mq;
    return _SectionCard(
      title: 'بيانات إضافية',
      icon: Icons.tune_rounded,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _gender,
              dropdownColor: mq.card,
              decoration: const InputDecoration(
                labelText: 'الجنس',
                prefixIcon: Icon(Icons.person_pin_outlined),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('ذكر')),
                DropdownMenuItem(value: 'female', child: Text('أنثى')),
              ],
              onChanged: _editing ? (v) => setState(() => _gender = v) : null,
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: _editing ? _pickBirthDate : null,
              borderRadius: MqRadius.brMd,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الميلاد',
                  prefixIcon: Icon(Icons.cake_outlined),
                  isDense: true,
                ),
                child: Text(_fmtDate(_birthDate),
                    style: context.text.bodyMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(BuildContext context) {
    return _SectionCard(
      title: 'الموقع الجغرافي',
      icon: Icons.map_outlined,
      child: TeacherLocationPicker(
        latitude: _latitude,
        longitude: _longitude,
        enabled: _editing,
        onChanged: (lat, lng) {
          _latitude = lat;
          _longitude = lng;
        },
      ),
    );
  }

  Widget _editActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MqButton.secondary(
            label: 'إلغاء',
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      _editing = false;
                      _hydrateForm();
                    });
                  },
          ),
        ),
        const SizedBox(width: MqSpacing.md),
        Expanded(
          child: MqButton(
            label: _saving ? 'جارٍ الحفظ…' : 'حفظ التعديلات',
            icon: _saving ? null : Icons.save_outlined,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );
  }

  Widget _logoutButton(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.error.withValues(alpha: 0.10),
      borderRadius: MqRadius.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _confirmLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: MqSpacing.md),
          decoration: BoxDecoration(
            borderRadius: MqRadius.brMd,
            border: Border.all(color: mq.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 18, color: mq.error),
              const SizedBox(width: MqSpacing.sm),
              Text('تسجيل الخروج',
                  style: context.text.labelLarge?.copyWith(
                      color: mq.error, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xs),
      child: Material(
        color: mq.fill,
        shape: RoundedRectangleBorder(
          borderRadius: MqRadius.brMd,
          side: BorderSide(color: mq.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: MqSize.iconSm, color: mq.ink2),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: mq.accentSoft, borderRadius: MqRadius.brSm),
                child: Icon(icon, size: MqSize.iconSm, color: mq.accent),
              ),
              const SizedBox(width: MqSpacing.sm),
              Text(title, style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.validator,
    this.icon,
    this.keyboardType,
    this.last = false,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? Function(String?)? validator;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : MqSpacing.md),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          isDense: true,
        ),
        validator: validator,
      ),
    );
  }
}
