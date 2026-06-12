// Auth → Complete profile (MulhimIQ design-system pass).
//
// Shown after sign-in for students whose profile isn't complete (gated by the
// RoleRouter / profile-completion guard) before reaching /home. Presentation
// only: the stored-user prefill, geolocation, birth-date picker, form
// validation, the exact completeProfile payload, AuthService.completeProfile,
// and the Get.offAllNamed("/home") redirect are all UNCHANGED.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/shared/controllers/theme_controller.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _apiService = ApiService();

  late Future<List<Map<String, dynamic>>> _gradesFuture;

  final _studentPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _formattedAddressController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipcodeController = TextEditingController();
  final _streetNameController = TextEditingController();
  final _suburbController = TextEditingController();
  final _birthDateController = TextEditingController();

  String? _gender;
  String? _gradeId;
  final String _studyYear = "2025-2026";
  DateTime? _birthDate;

  bool _sendLocation = false;
  double? _latitude;
  double? _longitude;

  bool _loading = false;
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _gradesFuture = _apiService.fetchGrades();
    _prefillFromStoredUser();
  }

  @override
  void dispose() {
    _studentPhoneController.dispose();
    _parentPhoneController.dispose();
    _schoolNameController.dispose();
    _addressController.dispose();
    _formattedAddressController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipcodeController.dispose();
    _streetNameController.dispose();
    _suburbController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // ─── logic (UNCHANGED) ──────────────────────────────────────────────────────

  void _updateBirthDateDisplay() {
    if (_birthDate != null) {
      _birthDateController.text =
          "${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}";
    } else {
      _birthDateController.text = "";
    }
  }

  Future<void> _prefillFromStoredUser() async {
    final user = await _authService.getUser();
    if (user == null) return;
    setState(() {
      _studentPhoneController.text = (user['studentPhone'] ?? '').toString();
      _parentPhoneController.text = (user['parentPhone'] ?? '').toString();
      _schoolNameController.text = (user['schoolName'] ?? '').toString();
      _addressController.text = (user['address'] ?? '').toString();
      _formattedAddressController.text = (user['formattedAddress'] ?? '').toString();
      _countryController.text = (user['country'] ?? '').toString();
      _cityController.text = (user['city'] ?? '').toString();
      _stateController.text = (user['state'] ?? '').toString();
      _zipcodeController.text = (user['zipcode'] ?? '').toString();
      _streetNameController.text = (user['streetName'] ?? '').toString();
      _suburbController.text = (user['suburb'] ?? '').toString();
      _gender = (user['gender'] ?? '') == '' ? null : user['gender'];
      _gradeId = (user['gradeId'] ?? '') == '' ? null : user['gradeId'];
      final bd = user['birthDate'];
      if (bd != null && bd.toString().isNotEmpty) {
        try {
          _birthDate = DateTime.tryParse(bd) ?? _birthDate;
        } catch (_) {}
      }
      _updateBirthDateDisplay();
    });
  }

  Future<void> _getLocation() async {
    setState(() => _locationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack("خدمة الموقع غير مفعلة", error: true);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _snack("تم رفض إذن الموقع", error: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _snack("إذن الموقع مرفوض نهائياً", error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
        _snack("تم الحصول على الموقع بنجاح");
      }
    } catch (e) {
      if (mounted) _snack("خطأ في جلب الموقع: $e", error: true);
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2007, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      locale: const Locale('ar', 'SA'),
      helpText: 'اختر تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _updateBirthDateDisplay();
      });
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) return false;
    if (_gender == null || _gradeId == null || _birthDate == null) {
      _snack("الرجاء ملء جميع الحقول المطلوبة", error: true);
      return false;
    }
    return true;
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;
    setState(() => _loading = true);

    if (_sendLocation && (_latitude == null || _longitude == null)) {
      await _getLocation();
    }

    final payload = {
      "gradeId": _gradeId,
      "studyYear": _studyYear,
      "latitude": _sendLocation ? _latitude ?? 33.36871840 : 33.36871840,
      "longitude": _sendLocation ? _longitude ?? 44.51151040 : 44.51151040,
      "studentPhone": _studentPhoneController.text.trim(),
      "parentPhone": _parentPhoneController.text.trim(),
      "schoolName": _schoolNameController.text.trim(),
      "gender": _gender,
      "birthDate": _birthDate!.toIso8601String().split("T").first,
      "address": _addressController.text.trim(),
      "formattedAddress": _formattedAddressController.text.trim(),
      "country": _countryController.text.trim(),
      "city": _cityController.text.trim(),
      "state": _stateController.text.trim(),
      "zipcode": _zipcodeController.text.trim(),
      "streetName": _streetNameController.text.trim(),
      "suburb": _suburbController.text.trim(),
    };

    try {
      final result = await _authService.completeProfile(payload);
      if (!mounted) return;
      if (result["success"] == true) {
        _snack("تم حفظ البيانات بنجاح ✅");
        Get.offAllNamed("/home");
      } else {
        _snack(result["message"] ?? "فشل حفظ البيانات ❌", error: true);
      }
    } catch (e) {
      if (mounted) _snack("خطأ في الاتصال: $e", error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            final m = context.mq;
            return Scaffold(
              backgroundColor: m.page,
              appBar: AppBar(
                title: const Text('إكمال البيانات الشخصية'),
                actions: [
                  Obx(() => IconButton(
                        icon: Icon(ThemeController.to.themeMode.value == ThemeMode.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined),
                        onPressed: () => ThemeController.to.toggleDarkLight(),
                        tooltip: ThemeController.to.themeMode.value == ThemeMode.dark ? 'الوضع النهاري' : 'الوضع الليلي',
                      )),
                ],
              ),
              body: Form(
                key: _formKey,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _gradesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _loadingView(context);
                    }
                    if (snapshot.hasError) {
                      return _errorView(context, '${snapshot.error}');
                    }
                    final grades = snapshot.data ?? [];
                    return ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
                      children: [
                        _sectionCard(context, 'معلومات التواصل', Icons.contact_phone_outlined, [
                          _field(context, _studentPhoneController, 'هاتف الطالب', required: true, keyboardType: TextInputType.phone, icon: Icons.phone_outlined),
                          MqSpacing.gapMd,
                          _field(context, _parentPhoneController, 'هاتف ولي الأمر', keyboardType: TextInputType.phone, icon: Icons.contact_phone_outlined),
                          MqSpacing.gapMd,
                          _field(context, _schoolNameController, 'اسم المدرسة', icon: Icons.business_outlined),
                        ]),
                        MqSpacing.gapMd,
                        _sectionCard(context, 'المعلومات التعليمية', Icons.school_outlined, [
                          _dropdown(context, 'الجنس', Icons.wc_outlined, _gender,
                              const [DropdownMenuItem(value: 'male', child: Text('ذكر')), DropdownMenuItem(value: 'female', child: Text('أنثى'))],
                              (v) => setState(() => _gender = v), validatorMsg: 'اختر الجنس'),
                          MqSpacing.gapMd,
                          _dropdown(context, 'المرحلة / الصف', Icons.school_outlined, _gradeId,
                              grades.map((g) => DropdownMenuItem<String>(value: g['id'] as String, child: Text(g['name'] as String))).toList(),
                              (v) => setState(() => _gradeId = v), validatorMsg: 'اختر الصف'),
                          MqSpacing.gapMd,
                          _field(context, _birthDateController, 'تاريخ الميلاد', required: true, readOnly: true, onTap: _pickBirthDate, icon: Icons.cake_outlined),
                        ]),
                        MqSpacing.gapMd,
                        _sectionCard(context, 'العنوان', Icons.location_city_outlined, [
                          _field(context, _addressController, 'العنوان', icon: Icons.home_outlined),
                        ]),
                        MqSpacing.gapMd,
                        _sectionCard(context, 'الموقع', Icons.location_on_outlined, [_locationTile(context)]),
                        MqSpacing.gapLg,
                        MqButton(label: 'حفظ البيانات', icon: Icons.save_outlined, loading: _loading, onPressed: _handleSubmit),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, String title, IconData icon, List<Widget> children) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, size: MqSize.iconSm, color: context.mq.accent),
            MqSpacing.gapXs,
            Text(title, style: context.text.titleSmall),
          ]),
          MqSpacing.gapMd,
          ...children,
        ],
      ),
    );
  }

  OutlineInputBorder _border(BuildContext context, Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: c, width: w));

  InputDecoration _decoration(BuildContext context, String label, IconData icon, {bool required = false}) {
    final m = context.mq;
    return InputDecoration(
      labelText: required ? '$label *' : label,
      labelStyle: context.text.bodySmall,
      prefixIcon: Icon(icon, size: MqSize.iconSm, color: m.ink3),
      filled: true,
      fillColor: m.fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: MqSpacing.md, vertical: MqSpacing.sm),
      border: _border(context, m.line),
      enabledBorder: _border(context, m.line),
      focusedBorder: _border(context, m.accent, 1.6),
      errorBorder: _border(context, m.error),
      focusedErrorBorder: _border(context, m.error, 1.6),
    );
  }

  Widget _field(BuildContext context, TextEditingController controller, String label,
      {bool required = false, TextInputType? keyboardType, bool readOnly = false, VoidCallback? onTap, IconData? icon}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: context.text.bodyMedium,
      decoration: _decoration(context, label, icon ?? Icons.edit_outlined, required: required),
      validator: required ? (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null : null,
    );
  }

  Widget _dropdown(BuildContext context, String label, IconData icon, String? value,
      List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged, {required String validatorMsg}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: context.mq.card,
      style: context.text.bodyMedium,
      decoration: _decoration(context, label, icon, required: true),
      items: items,
      onChanged: onChanged,
      validator: (v) => v == null ? validatorMsg : null,
    );
  }

  Widget _locationTile(BuildContext context) {
    final m = context.mq;
    return MqSurface(
      tone: MqSurfaceTone.neutral,
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: m.accent,
            value: _sendLocation,
            onChanged: _locationLoading
                ? null
                : (val) {
                    setState(() => _sendLocation = val);
                    if (_sendLocation) _getLocation();
                  },
            secondary: _locationLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.location_on_outlined, color: m.accent),
            title: Text('إرسال موقعي الحالي', style: context.text.bodyMedium),
            subtitle: Text('يساعدنا على تخصيص التجربة التعليمية في منطقتك.', style: context.text.labelSmall),
          ),
          if (_locationLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: MqSpacing.sm),
              child: Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                MqSpacing.gapSm,
                Text('جاري الحصول على الموقع...', style: context.text.labelSmall),
              ]),
            )
          else if (_latitude != null && _longitude != null)
            Padding(
              padding: const EdgeInsets.only(bottom: MqSpacing.sm),
              child: Align(
                alignment: Alignment.centerRight,
                child: MqBadge(
                  label: 'تم: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                  tone: MqBadgeTone.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loadingView(BuildContext context) {
    final m = context.mq;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: m.accent),
        MqSpacing.gapMd,
        Text('جاري تحميل البيانات...', style: context.text.bodyMedium),
      ]),
    );
  }

  Widget _errorView(BuildContext context, String error) {
    final m = context.mq;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MqSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
          MqSpacing.gapMd,
          Text('خطأ في تحميل البيانات', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text(error, textAlign: TextAlign.center, style: context.text.bodySmall),
          MqSpacing.gapMd,
          MqButton(
            label: 'إعادة المحاولة',
            icon: Icons.refresh_rounded,
            expand: false,
            onPressed: () => setState(() => _gradesFuture = _apiService.fetchGrades()),
          ),
        ]),
      ),
    );
  }
}
