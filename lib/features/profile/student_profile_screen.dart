import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/features/student_home/controller/student_home_controller.dart';
import 'package:mulhimiq/shared/controllers/global_controller.dart';
import 'package:mulhimiq/shared/controllers/theme_controller.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

/// Enrollment statuses that count as an *active in-person (physical) course*.
/// In this domain `course_bookings` (enrollments) are inherently physical —
/// video courses are a separate library — so an active booking is an active
/// physical course. Used to lock academic-stage changes.
const Set<String> _kActivePhysicalStatuses = {'confirmed', 'approved', 'enrolled', 'active'};

/// Student profile — restyled with the MulhimIQ design system to match the
/// Student Home visual language. A standalone pushed route, so it owns its
/// Scaffold + back AppBar (no RootShell nav here). Keeps all existing
/// behaviour (view/edit fields, image, location, delete) and adds the account
/// overview, learning summary, shortcuts, theme toggle, and logout.
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _authService = AuthService();
  final _api = ApiService();

  Map<String, dynamic>? _user;
  final _nameController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _schoolNameController = TextEditingController();

  bool _loading = false;
  bool _editing = false;
  String? _gender;
  DateTime? _birthDate;
  XFile? _pickedImage;
  String? _profileImageBase64;

  bool _sendLocation = false;
  bool _locationLoading = false;
  double? _latitude;
  double? _longitude;

  // Learning summary (existing endpoint — /student/enrollments).
  int _coursesCount = 0;
  int _teachersCount = 0;

  // Academic stage (grade).
  List<Map<String, dynamic>> _grades = const [];
  String? _currentGradeId;
  String? _selectedGradeId;
  bool _gradesLoading = false;

  /// True when the student has at least one active in-person enrollment —
  /// while true, the academic stage is locked.
  bool _hasActivePhysical = false;

  bool get _stageLocked => _hasActivePhysical;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSummary();
    _loadGrades();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentPhoneController.dispose();
    _parentPhoneController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  // ── data ───────────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getUser();
      if (user != null && mounted) {
        setState(() {
          _user = user;
          _nameController.text = user['name'] ?? '';
          _studentPhoneController.text = user['studentPhone'] ?? '';
          _parentPhoneController.text = user['parentPhone'] ?? '';
          _schoolNameController.text = user['schoolName'] ?? '';
          _gender = user['gender'];
          if (user['birthDate'] != null) {
            _birthDate = DateTime.tryParse(user['birthDate']);
          }
          _profileImageBase64 = user['profileImageBase64'];
          _pickedImage = null;
          _currentGradeId = _resolveCurrentGradeId(user);
          _selectedGradeId ??= _currentGradeId;

          final lat = user['latitude'];
          final lng = user['longitude'];
          if (lat != null && lng != null) {
            final dLat = double.tryParse(lat.toString());
            final dLng = double.tryParse(lng.toString());
            if (dLat != null && dLng != null) {
              _latitude = dLat;
              _longitude = dLng;
              _sendLocation = true;
            }
          }
        });
      }
    } catch (_) {
      Get.snackbar('خطأ', 'فشل في تحميل بيانات المستخدم');
    }
  }

  String? _resolveCurrentGradeId(Map<String, dynamic> user) {
    final top = user['gradeId']?.toString();
    if (top != null && top.isNotEmpty) return top;
    final g = user['studentGrades'];
    if (g is List && g.isNotEmpty && g.first is Map) {
      final id = (g.first as Map)['gradeId']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<void> _loadSummary() async {
    try {
      final res = await _api.fetchStudentEnrollments(limit: 100);
      final data = res['data'];
      final list = data is List
          ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final teacherIds = <String>{};
      var activePhysical = false;
      for (final e in list) {
        final t = e['teacher'];
        final id = t is Map ? t['id']?.toString() : null;
        if (id != null && id.isNotEmpty) teacherIds.add(id);
        final status = (e['status'] ?? '').toString().toLowerCase();
        if (_kActivePhysicalStatuses.contains(status)) activePhysical = true;
      }
      if (mounted) {
        setState(() {
          _coursesCount = list.length;
          _teachersCount = teacherIds.length;
          _hasActivePhysical = activePhysical;
        });
      }
    } catch (_) {
      // Summary is optional — degrade to hidden (counts stay 0).
    }
  }

  Future<void> _loadGrades() async {
    setState(() => _gradesLoading = true);
    try {
      final grades = await _api.fetchGrades();
      if (mounted) setState(() => _grades = grades);
    } catch (_) {
      // Stage list optional — the field hides when empty.
    } finally {
      if (mounted) setState(() => _gradesLoading = false);
    }
  }

  // ── actions ─────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedImage = image;
          _profileImageBase64 = base64Encode(bytes);
          _editing = true;
        });
      }
    } catch (_) {
      Get.snackbar('خطأ', 'تعذر اختيار الصورة');
    }
  }

  Future<void> _pickBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2008),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _birthDate = date);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال الاسم');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    // Only attempt a stage change when it isn't locked and actually changed.
    // The backend independently re-validates this (UI gating is not enough).
    final stageChanged = !_stageLocked &&
        _selectedGradeId != null &&
        _selectedGradeId!.isNotEmpty &&
        _selectedGradeId != _currentGradeId;
    try {
      if (_sendLocation && (_latitude == null || _longitude == null)) {
        await _getLocation();
      }
      final res = await _authService.updateProfile({
        'name': _nameController.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate?.toIso8601String(),
        'studentPhone': _studentPhoneController.text.trim(),
        'parentPhone': _parentPhoneController.text.trim(),
        'schoolName': _schoolNameController.text.trim(),
        if (stageChanged) 'gradeId': _selectedGradeId,
        if (_sendLocation) ...{
          'latitude': _latitude ?? 33.36871840,
          'longitude': _longitude ?? 44.51151040,
        },
        if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty)
          'profileImageBase64': _profileImageBase64,
      });
      if (res['success'] == true) {
        Get.snackbar('تم الحفظ', 'تم تحديث بياناتك بنجاح');
        if (mounted) setState(() => _editing = false);
        await _loadUserData();
        if (stageChanged) _refreshRecommendations();
      } else {
        // Surfaces backend messages, e.g. the stage-lock rule.
        Get.snackbar('تعذّر الحفظ', (res['message'] ?? 'فشل في حفظ البيانات').toString());
      }
    } catch (_) {
      Get.snackbar('خطأ', 'فشل في حفظ البيانات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// After an academic-stage change, refresh the home recommendations if the
  /// Student Home controller is alive (it stays registered under RootShell).
  void _refreshRecommendations() {
    if (Get.isRegistered<StudentHomeController>()) {
      Get.find<StudentHomeController>().refreshAll();
    }
  }

  Future<void> _getLocation() async {
    setState(() => _locationLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        Get.snackbar('الموقع', 'خدمة الموقع غير مفعلة');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar('الموقع', 'تم رفض إذن الموقع');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        Get.snackbar('الموقع', 'إذن الموقع مرفوض نهائياً');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (_) {
      Get.snackbar('الموقع', 'خطأ في جلب الموقع');
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final err = context.mq.error;
    Get.defaultDialog(
      title: 'تسجيل الخروج',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText: 'هل تريد تسجيل الخروج من حسابك؟',
      textCancel: 'إلغاء',
      textConfirm: 'خروج',
      confirmTextColor: Colors.white,
      buttonColor: err,
      onConfirm: () async {
        Get.back();
        await _logout();
      },
    );
  }

  /// Reuses the existing logout pipeline (GlobalController → AuthService:
  /// clears token+user, OneSignal unbind, realtime disconnect) then returns to
  /// the login flow.
  Future<void> _logout() async {
    setState(() => _loading = true);
    try {
      if (Get.isRegistered<GlobalController>()) {
        await Get.find<GlobalController>().logout();
      } else {
        await _authService.logout();
      }
    } catch (_) {}
    Get.offAllNamed('/login');
  }

  Future<void> _confirmDelete() async {
    final err = context.mq.error;
    Get.defaultDialog(
      title: 'حذف الحساب',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText: 'هل أنت متأكد من حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.',
      textCancel: 'إلغاء',
      textConfirm: 'حذف',
      confirmTextColor: Colors.white,
      buttonColor: err,
      onConfirm: () async {
        Get.back();
        await _deleteAccount();
      },
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _loading = true);
    try {
      final res = await _authService.deleteAccount();
      if (res['success'] == true) {
        Get.snackbar('تم', res['message'] ?? 'تم حذف الحساب بنجاح');
        Get.offAllNamed('/login');
      } else {
        Get.snackbar('خطأ', res['message'] ?? 'فشل حذف الحساب');
      }
    } catch (_) {
      Get.snackbar('خطأ', 'فشل حذف الحساب');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── derived ──────────────────────────────────────────────────────────────────

  String get _name => (_user?['name'] ?? '').toString().trim();
  String? get _email {
    final v = _user?['email']?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get _gradeName {
    final g = _user?['studentGrades'];
    if (g is List && g.isNotEmpty && g.first is Map) {
      final n = (g.first as Map)['gradeName']?.toString().trim();
      if (n != null && n.isNotEmpty) return n;
    }
    final alt = (_user?['gradeName'] ?? _user?['grade'])?.toString().trim();
    return (alt == null || alt.isEmpty) ? null : alt;
  }

  String? get _genderLabel {
    final g = (_gender ?? _user?['gender'])?.toString();
    if (g == 'male') return 'ذكر';
    if (g == 'female') return 'أنثى';
    return null;
  }

  String? get _birthDateLabel {
    final d = _birthDate ?? DateTime.tryParse(_user?['birthDate']?.toString() ?? '');
    return d == null ? null : DateFormat('yyyy/MM/dd').format(d);
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              backgroundColor: context.mq.page,
              appBar: AppBar(title: const Text('ملفي الشخصي')),
              body: _user == null
                  ? Center(child: CircularProgressIndicator(color: context.mq.accent))
                  : _content(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final summaryCard = _summaryCard(context);
    final accountCard = _accountCard(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
      children: [
        _headerCard(context),
        if (accountCard != null) ...[const SizedBox(height: MqSpacing.lg), accountCard],
        if (summaryCard != null) ...[const SizedBox(height: MqSpacing.lg), summaryCard],
        const SizedBox(height: MqSpacing.lg),
        _shortcutsCard(context),
        const SizedBox(height: MqSpacing.lg),
        _editCard(context),
        const SizedBox(height: MqSpacing.xl),
        _dangerButton(
          context,
          label: 'تسجيل الخروج',
          icon: Icons.logout_rounded,
          onTap: _loading ? null : _confirmLogout,
        ),
        const SizedBox(height: MqSpacing.sm),
        _textDanger(context, label: 'حذف الحساب', onTap: _loading ? null : _confirmDelete),
      ],
    );
  }

  // ── header ────────────────────────────────────────────────────────────────────

  Widget _headerCard(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [mq.accent, mq.accentDeep],
        ),
        borderRadius: MqRadius.brXl,
        boxShadow: [BoxShadow(color: mq.accentShadow, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
                ),
                child: ClipOval(child: _avatar(context)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: _pickImage,
                  borderRadius: MqRadius.brPill,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: mq.orange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    child: const Icon(Icons.edit, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          MqSpacing.gapLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_name.isEmpty ? 'طالبنا العزيز' : _name,
                    style: context.text.titleLarge?.copyWith(color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (_email != null) ...[
                  const SizedBox(height: 2),
                  Text(_email!,
                      style: context.text.bodySmall?.copyWith(color: Colors.white70),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (_gradeName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: MqRadius.brPill,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(_gradeName!, style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final provider = _imageProvider();
    if (provider != null) {
      return Image(image: provider, fit: BoxFit.cover, width: 72, height: 72, errorBuilder: (_, _, _) => _avatarFallback(context));
    }
    return _avatarFallback(context);
  }

  Widget _avatarFallback(BuildContext context) {
    final initials = _name.isEmpty
        ? '؟'
        : _name.trim().split(RegExp(r'\s+')).map((e) => e.characters.first).take(2).join();
    return Container(
      color: Colors.white.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(initials, style: context.text.titleLarge?.copyWith(color: Colors.white)),
    );
  }

  // ── account info ───────────────────────────────────────────────────────────────

  Widget? _accountCard(BuildContext context) {
    final rows = <_InfoItem>[
      _InfoItem(Icons.email_outlined, 'البريد الإلكتروني', _email),
      _InfoItem(Icons.class_outlined, 'الصف الدراسي', _gradeName),
      _InfoItem(Icons.wc_outlined, 'الجنس', _genderLabel),
      _InfoItem(Icons.cake_outlined, 'تاريخ الميلاد', _birthDateLabel),
      _InfoItem(Icons.phone_outlined, 'هاتف الطالب', _user?['studentPhone']?.toString()),
      _InfoItem(Icons.contact_phone_outlined, 'هاتف ولي الأمر', _user?['parentPhone']?.toString()),
      _InfoItem(Icons.apartment_outlined, 'المدرسة', _user?['schoolName']?.toString()),
    ].where((r) => r.value != null && r.value!.trim().isNotEmpty).toList();

    if (rows.isEmpty) return null;

    return _sectionCard(
      context,
      title: 'بيانات الحساب',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: MqSpacing.lg),
            _infoRow(context, rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, _InfoItem item) {
    final mq = context.mq;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
          child: Icon(item.icon, size: MqSize.iconSm, color: mq.accent),
        ),
        MqSpacing.gapSm,
        Text(item.label, style: context.text.bodySmall),
        const Spacer(),
        Flexible(
          child: Text(item.value ?? '',
              textAlign: TextAlign.left,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── learning summary ───────────────────────────────────────────────────────────

  Widget? _summaryCard(BuildContext context) {
    final hasCourses = _coursesCount > 0;
    final hasTeachers = _teachersCount > 0;
    if (!hasCourses && !hasTeachers) return null;

    return _sectionCard(
      context,
      title: 'نشاطي الدراسي',
      icon: Icons.insights_outlined,
      child: Row(
        children: [
          if (hasCourses)
            Expanded(child: _statTile(context, Icons.menu_book_rounded, _coursesCount, 'دوراتي', () => Get.toNamed('/enrollments'))),
          if (hasCourses && hasTeachers) MqSpacing.gapMd,
          if (hasTeachers)
            Expanded(child: _statTile(context, Icons.cast_for_education_rounded, _teachersCount, 'معلّموني', () => Get.toNamed('/enrollments'))),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, IconData icon, int count, String label, VoidCallback onTap) {
    final mq = context.mq;
    return Material(
      color: mq.fill,
      shape: RoundedRectangleBorder(borderRadius: MqRadius.brMd, side: BorderSide(color: mq.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MqSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: mq.accent, size: MqSize.iconMd),
              MqSpacing.gapSm,
              Text('$count', style: context.text.titleLarge),
              MqSpacing.gapSm,
              Expanded(child: Text(label, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(Icons.chevron_left_rounded, size: 18, color: mq.ink3),
            ],
          ),
        ),
      ),
    );
  }

  // ── shortcuts + theme toggle ─────────────────────────────────────────────────────

  Widget _shortcutsCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'الإعدادات والاختصارات',
      icon: Icons.settings_outlined,
      child: Column(
        children: [
          _actionRow(context, Icons.notifications_outlined, 'الإشعارات',
              onTap: () => Get.toNamed('/notifications')),
          const Divider(height: MqSpacing.lg),
          _themeToggleRow(context),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context, IconData icon, String label, {required VoidCallback onTap, Widget? trailing}) {
    final mq = context.mq;
    return InkWell(
      onTap: onTap,
      borderRadius: MqRadius.brSm,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
            child: Icon(icon, size: MqSize.iconSm, color: mq.accent),
          ),
          MqSpacing.gapSm,
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          trailing ?? Icon(Icons.chevron_left_rounded, size: 20, color: mq.ink3),
        ],
      ),
    );
  }

  Widget _themeToggleRow(BuildContext context) {
    final mq = context.mq;
    final hasController = Get.isRegistered<ThemeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
          child: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: MqSize.iconSm, color: mq.accent),
        ),
        MqSpacing.gapSm,
        Expanded(child: Text('الوضع الداكن', style: context.text.bodyMedium)),
        Switch(
          value: isDark,
          activeThumbColor: mq.accent,
          onChanged: hasController ? (_) => ThemeController.to.toggleDarkLight() : null,
        ),
      ],
    );
  }

  // ── edit personal data ────────────────────────────────────────────────────────────

  Widget _editCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'تعديل البيانات الشخصية',
      icon: Icons.edit_note_rounded,
      trailing: MqBadge(
        label: _editing ? 'قيد التعديل' : 'اضغط للتعديل',
        tone: _editing ? MqBadgeTone.orange : MqBadgeTone.neutral,
      ),
      onHeaderTap: () => setState(() => _editing = !_editing),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        crossFadeState: _editing ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: const SizedBox(width: double.infinity),
        secondChild: Column(
          children: [
            const SizedBox(height: MqSpacing.sm),
            _field(_nameController, 'الاسم الكامل', Icons.person_outline_rounded),
            _genderField(context),
            _stageField(context),
            _dateField(context),
            _field(_studentPhoneController, 'هاتف الطالب', Icons.phone_outlined, keyboard: TextInputType.phone),
            _field(_parentPhoneController, 'هاتف ولي الأمر', Icons.contact_phone_outlined, keyboard: TextInputType.phone),
            _field(_schoolNameController, 'اسم المدرسة', Icons.apartment_outlined),
            _locationRow(context),
            const SizedBox(height: MqSpacing.md),
            MqButton(
              label: 'حفظ التغييرات',
              icon: Icons.save_rounded,
              loading: _loading,
              onPressed: _loading ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Widget _genderField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: _gender == 'male' || _gender == 'female' ? _gender : null,
        items: const [
          DropdownMenuItem(value: 'male', child: Text('ذكر')),
          DropdownMenuItem(value: 'female', child: Text('أنثى')),
        ],
        decoration: const InputDecoration(labelText: 'الجنس', prefixIcon: Icon(Icons.wc_outlined)),
        onChanged: (v) => setState(() => _gender = v),
      ),
    );
  }

  /// Academic stage (grade). Editable only when there is no active in-person
  /// enrollment; otherwise the field is disabled and a lock message is shown.
  /// The backend re-validates the same rule on save.
  Widget _stageField(BuildContext context) {
    if (_gradesLoading && _grades.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: MqSpacing.md),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_grades.isEmpty) return const SizedBox.shrink();

    final value = _grades.any((g) => g['id']?.toString() == _selectedGradeId) ? _selectedGradeId : null;
    final locked = _stageLocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'المرحلة الدراسية',
              prefixIcon: const Icon(Icons.school_outlined),
              suffixIcon: locked ? Icon(Icons.lock_outline_rounded, size: 18, color: context.mq.ink3) : null,
            ),
            items: _grades
                .map((g) => DropdownMenuItem<String>(
                      value: g['id']?.toString(),
                      child: Text((g['name'] ?? '').toString(), overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: locked ? null : (v) => setState(() => _selectedGradeId = v),
          ),
          if (locked) ...[
            const SizedBox(height: MqSpacing.sm),
            MqSurface(
              tone: MqSurfaceTone.orange,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: MqSize.iconSm, color: context.mq.orangeDeep),
                  MqSpacing.gapSm,
                  Expanded(
                    child: Text(
                      'لا يمكن تغيير المرحلة الدراسية أثناء وجود دورة حضورية مفعّلة. يمكنك تغييرها بعد انتهاء الدورة.',
                      style: context.text.bodySmall?.copyWith(color: context.mq.ink2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: InkWell(
        onTap: _pickBirthDate,
        borderRadius: MqRadius.brMd,
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'تاريخ الميلاد', prefixIcon: Icon(Icons.cake_outlined)),
          child: Text(_birthDateLabel ?? 'اختر التاريخ', style: context.text.bodyMedium),
        ),
      ),
    );
  }

  Widget _locationRow(BuildContext context) {
    final mq = context.mq;
    final subtitle = _locationLoading
        ? 'جاري الحصول على الموقع…'
        : (_latitude != null && _longitude != null)
            ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
            : 'يساعد على تخصيص تجربتك التعليمية';
    return MqSurface(
      tone: MqSurfaceTone.neutral,
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.md, vertical: MqSpacing.sm),
      child: Row(
        children: [
          _locationLoading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: mq.accent))
              : Icon(Icons.location_on_outlined, color: mq.accent, size: MqSize.iconMd),
          MqSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('إرسال موقعي الحالي', style: context.text.bodyMedium),
                Text(subtitle, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Switch(
            value: _sendLocation,
            activeThumbColor: mq.accent,
            onChanged: _locationLoading
                ? null
                : (val) async {
                    if (val) {
                      setState(() => _sendLocation = true);
                      await _getLocation();
                    } else {
                      setState(() => _sendLocation = false);
                    }
                  },
          ),
        ],
      ),
    );
  }

  // ── shared scaffolding ────────────────────────────────────────────────────────────

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    VoidCallback? onHeaderTap,
  }) {
    final mq = context.mq;
    final header = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
          child: Icon(icon, size: MqSize.iconSm, color: mq.accent),
        ),
        MqSpacing.gapSm,
        Expanded(child: Text(title, style: context.text.titleSmall)),
        if (trailing != null) trailing,
        if (onHeaderTap != null) ...[
          MqSpacing.gapXs,
          Icon(Icons.expand_more_rounded, size: 20, color: mq.ink3),
        ],
      ],
    );
    return MqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          onHeaderTap == null
              ? header
              : InkWell(onTap: onHeaderTap, borderRadius: MqRadius.brSm, child: header),
          const SizedBox(height: MqSpacing.md),
          child,
        ],
      ),
    );
  }

  /// Outlined destructive button (logout) — not the primary blue CTA.
  Widget _dangerButton(BuildContext context, {required String label, required IconData icon, VoidCallback? onTap}) {
    final mq = context.mq;
    return Material(
      color: mq.error.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: MqRadius.brMd, side: BorderSide(color: mq.error.withValues(alpha: 0.5))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: MqSize.buttonHeight,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: MqSize.iconMd, color: mq.error),
              MqSpacing.gapSm,
              Text(label, style: context.text.labelLarge?.copyWith(color: mq.error)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textDanger(BuildContext context, {required String label, VoidCallback? onTap}) {
    final mq = context.mq;
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.delete_outline_rounded, size: 18, color: mq.error),
        label: Text(label, style: context.text.labelMedium?.copyWith(color: mq.error)),
      ),
    );
  }

  // ── image resolution (preserved) ───────────────────────────────────────────────────

  ImageProvider<Object>? _imageProvider() {
    if (_pickedImage != null && _profileImageBase64 != null) {
      try {
        return MemoryImage(base64Decode(_profileImageBase64!));
      } catch (_) {}
    }
    const base64Keys = ['profileImageBase64', 'avatarBase64', 'photoBase64', 'imageBase64'];
    for (final key in base64Keys) {
      final raw = _user?[key]?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          final pure = raw.contains(',') ? raw.split(',').last : raw;
          return MemoryImage(base64Decode(pure));
        } catch (_) {}
      }
    }
    const urlKeys = [
      'profileImagePath', 'profileImageUrl', 'avatarUrl', 'photoUrl',
      'imageUrl', 'profileImage', 'avatar', 'photo', 'image',
    ];
    for (final key in urlKeys) {
      final url = _user?[key]?.toString();
      if (url != null && url.isNotEmpty) return NetworkImage(_normalizeImageUrl(url));
    }
    return null;
  }

  String _normalizeImageUrl(String raw) {
    String s = raw.trim();
    if (s.isEmpty) return s;
    if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('data:image')) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('//')) {
      final scheme = Uri.parse(AppConfig.serverBaseUrl).scheme;
      return '$scheme:$s';
    }
    String path = s.replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base$path';
  }
}

class _InfoItem {
  const _InfoItem(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String? value;
}
