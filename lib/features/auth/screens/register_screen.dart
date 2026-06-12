// Auth → Register (student) (MulhimIQ design-system pass).
//
// Presentation only. fetchGrades, the birth-date picker, geolocation, the
// required-field validation, AuthService.registerStudent, and navigation to
// EmailVerificationScreen are all UNCHANGED. (Students only — teachers apply
// via /join-as-teacher; there is no confirm-password / terms / role field, so
// none is shown.)

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import '../widgets/auth_text_field.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _schoolNameController = TextEditingController();

  String? _gender;
  String? _gradeId;
  DateTime? _birthDate;
  List<Map<String, dynamic>> _grades = [];

  bool _loading = false;
  bool _sendLocation = false;
  double? _latitude;
  double? _longitude;

  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentPhoneController.dispose();
    _parentPhoneController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _fetchGrades() async {
    try {
      final grades = await _apiService.fetchGrades();
      if (mounted) setState(() => _grades = grades);
    } catch (e) {
      _snack('فشل تحميل الصفوف: $e');
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2007, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('خدمة الموقع غير مفعلة');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _snack('تم رفض إذن الموقع');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _snack('صلاحية الموقع مرفوضة دائمًا');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (e) {
      _snack('فشل الحصول على الموقع: $e');
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final studentPhone = _studentPhoneController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();
    final schoolName = _schoolNameController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        studentPhone.isEmpty ||
        parentPhone.isEmpty ||
        schoolName.isEmpty ||
        _gender == null ||
        _gradeId == null ||
        _birthDate == null) {
      _snack('الرجاء ملء جميع الحقول');
      return;
    }

    setState(() => _loading = true);

    if (_sendLocation && (_latitude == null || _longitude == null)) {
      await _getLocation();
    }

    final payload = {
      "name": name,
      "email": email,
      "password": password,
      "studentPhone": studentPhone,
      "parentPhone": parentPhone,
      "schoolName": schoolName,
      "gender": _gender,
      "gradeId": _gradeId,
      "birthDate": _birthDate!.toIso8601String().split("T").first,
      if (_sendLocation) ...{
        "latitude": _latitude ?? 33.37771840,
        "longitude": _longitude ?? 44.51151040,
      },
    };

    try {
      final errorMessage = await _authService.registerStudent(payload);
      if (errorMessage == null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: email)),
        );
      } else if (mounted) {
        _snack(errorMessage ?? 'حدث خطأ');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
              appBar: AppBar(title: const Text('إنشاء حساب جديد')),
              body: SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(color: m.accentSoft, borderRadius: MqRadius.brXl),
                            child: Icon(Icons.person_add_alt_1_rounded, size: 40, color: m.accent),
                          ),
                          MqSpacing.gapSm,
                          Text('أنشئ حسابك الآن', style: context.text.titleLarge),
                          Text('انضم إلى منصة ملهم IQ', style: context.text.bodySmall),
                        ]),
                      ),
                      MqSpacing.gapLg,
                      MqCard(
                        padding: const EdgeInsets.all(MqSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthTextField(controller: _nameController, label: 'الاسم الكامل', prefixIcon: Icons.person_outline_rounded),
                            MqSpacing.gapMd,
                            AuthTextField(controller: _emailController, label: 'البريد الإلكتروني', keyboardType: TextInputType.emailAddress, prefixIcon: Icons.alternate_email_rounded),
                            MqSpacing.gapMd,
                            AuthTextField(controller: _passwordController, label: 'كلمة المرور', obscureText: true, prefixIcon: Icons.lock_outline_rounded),
                            MqSpacing.gapMd,
                            AuthTextField(controller: _studentPhoneController, label: 'هاتف الطالب', keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined),
                            MqSpacing.gapMd,
                            AuthTextField(controller: _parentPhoneController, label: 'هاتف ولي الأمر', keyboardType: TextInputType.phone, prefixIcon: Icons.contact_phone_outlined),
                            MqSpacing.gapMd,
                            AuthTextField(controller: _schoolNameController, label: 'اسم المدرسة', prefixIcon: Icons.business_outlined),
                            MqSpacing.gapMd,
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: _dropDecoration(context, 'الجنس', Icons.wc_outlined),
                              dropdownColor: m.card,
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('ذكر')),
                                DropdownMenuItem(value: 'female', child: Text('أنثى')),
                              ],
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                            MqSpacing.gapMd,
                            DropdownButtonFormField<String>(
                              initialValue: _gradeId,
                              isExpanded: true,
                              decoration: _dropDecoration(context, 'الصف الدراسي', Icons.school_outlined),
                              dropdownColor: m.card,
                              items: _grades
                                  .map((g) => DropdownMenuItem<String>(value: g['id'] as String, child: Text(g['name'] as String)))
                                  .toList(),
                              onChanged: (v) => setState(() => _gradeId = v),
                            ),
                            MqSpacing.gapMd,
                            InkWell(
                              onTap: _pickBirthDate,
                              borderRadius: MqRadius.brMd,
                              child: InputDecorator(
                                decoration: _dropDecoration(context, 'تاريخ الميلاد', Icons.cake_outlined),
                                child: Text(
                                  _birthDate == null
                                      ? 'اختر التاريخ'
                                      : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                                  style: context.text.bodyMedium?.copyWith(color: _birthDate == null ? m.ink3 : m.ink),
                                ),
                              ),
                            ),
                            MqSpacing.gapSm,
                            MqSurface(
                              tone: MqSurfaceTone.neutral,
                              padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeTrackColor: m.accent,
                                value: _sendLocation,
                                onChanged: (v) => setState(() => _sendLocation = v),
                                title: Text('إرسال موقعي الحالي', style: context.text.bodyMedium),
                                subtitle: Text('يساعدنا على تخصيص التجربة التعليمية في منطقتك.', style: context.text.labelSmall),
                              ),
                            ),
                            MqSpacing.gapMd,
                            MqButton(label: 'تسجيل', icon: Icons.app_registration_rounded, loading: _loading, onPressed: _submit),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _dropDecoration(BuildContext context, String label, IconData icon) {
    final m = context.mq;
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      labelText: label,
      labelStyle: context.text.bodySmall,
      prefixIcon: Icon(icon, size: MqSize.iconSm, color: m.ink3),
      filled: true,
      fillColor: m.fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: MqSpacing.md, vertical: MqSpacing.sm),
      border: b(m.line),
      enabledBorder: b(m.line),
      focusedBorder: b(m.accent, 1.6),
    );
  }
}
