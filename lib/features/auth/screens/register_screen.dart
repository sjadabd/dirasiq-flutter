import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import 'package:dirasiq/features/auth/screens/email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _schoolNameController = TextEditingController();

  String? _gender; // male | female
  String? _gradeId; // selected grade
  DateTime? _birthDate;

  List<Map<String, dynamic>> _grades = [];
  bool _loading = false;

  bool _sendLocation = false; // ✅ CheckBox value
  double? _latitude;
  double? _longitude;

  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  Future<void> _fetchGrades() async {
    try {
      final grades = await _apiService.fetchGrades();

      setState(() {
        _grades = grades;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("فشل تحميل الصفوف: $e")));
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2007, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("خدمة الموقع غير مفعلة")));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("تم رفض إذن الموقع")));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("صلاحية الموقع مرفوضة دائمًا")),
        );
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("فشل الحصول على الموقع: $e")));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("الرجاء ملء جميع الحقول")));
      return;
    }

    setState(() => _loading = true);

    // إذا المستخدم اختار إرسال الموقع
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
      "birthDate": _birthDate!.toIso8601String().split("T").first, // YYYY-MM-DD
      if (_sendLocation) ...{
        "latitude": _latitude ?? 33.37771840,
        "longitude": _longitude ?? 44.51151040,
      },
    };

    try {
      final errorMessage = await _authService.registerStudent(payload);
      if (errorMessage == null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل حساب جديد")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AuthTextField(controller: _nameController, label: "الاسم الكامل"),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _emailController,
              label: "البريد الإلكتروني",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _passwordController,
              label: "كلمة المرور",
              obscureText: true,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _studentPhoneController,
              label: "هاتف الطالب",
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _parentPhoneController,
              label: "هاتف ولي الأمر",
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _schoolNameController,
              label: "اسم المدرسة",
            ),
            const SizedBox(height: 12),

            // Gender select
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "الجنس"),
              initialValue: _gender,
              items: const [
                DropdownMenuItem(value: "male", child: Text("ذكر")),
                DropdownMenuItem(value: "female", child: Text("أنثى")),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 12),

            // Grades select
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "الصف"),
              initialValue: _gradeId,
              items: _grades
                  .map(
                    (g) => DropdownMenuItem<String>(
                      value: g["id"] as String,
                      child: Text(g["name"] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _gradeId = v),
            ),
            const SizedBox(height: 12),

            // Birthdate picker
            InkWell(
              onTap: _pickBirthDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: "تاريخ الميلاد"),
                child: Text(
                  _birthDate == null
                      ? "اختر التاريخ"
                      : "${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}",
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ CheckBox لإرسال الموقع
            CheckboxListTile(
              title: const Text("إرسال موقعي الحالي"),
              value: _sendLocation,
              onChanged: (val) {
                setState(() {
                  _sendLocation = val ?? false;
                });
              },
            ),

            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : AuthButton(text: "تسجيل", onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
