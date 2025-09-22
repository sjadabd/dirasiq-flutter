import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/services/auth_service.dart';

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

  // Controllers
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
  String? _studyYear = "2025-2026";
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

  void _updateBirthDateDisplay() {
    if (_birthDate != null) {
      _birthDateController.text = "${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}";
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
        _showErrorSnackBar("خدمة الموقع غير مفعلة");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar("تم رفض إذن الموقع");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar("إذن الموقع مرفوض نهائياً");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
        _showSuccessSnackBar("تم الحصول على الموقع بنجاح");
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("خطأ في جلب الموقع: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _locationLoading = false);
      }
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) return false;

    if (_gender == null || _gradeId == null || _birthDate == null) {
      _showErrorSnackBar("الرجاء ملء جميع الحقول المطلوبة");
      return false;
    }
    return true;
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;

    setState(() => _loading = true);

    // Get location if user opted to send it
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
        _showSuccessSnackBar("تم حفظ البيانات بنجاح ✅");
        Get.offAllNamed("/home");
      } else {
        _showErrorSnackBar(result["message"] ?? "فشل حفظ البيانات ❌");
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("خطأ في الاتصال: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).cardColor,
        ),
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        validator: required
            ? (v) => v == null || v.isEmpty ? "مطلوب" : null
            : null,
      ),
    );
  }

  Widget _buildGradeDropdown(List<Map<String, dynamic>> grades) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: "المرحلة / الصف *",
          border: OutlineInputBorder(),
          filled: true,
        ),
        value: _gradeId,
        isExpanded: true,
        items: grades
            .map((g) => DropdownMenuItem<String>(
          value: g["id"] as String,
          child: Text(g["name"] as String),
        ))
            .toList(),
        onChanged: (v) {
          if (v != _gradeId) {
            setState(() => _gradeId = v);
          }
        },
        validator: (v) => v == null ? "اختر الصف" : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إكمال البيانات الشخصية"),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _gradesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("جاري تحميل البيانات..."),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text("خطأ في تحميل البيانات: ${snapshot.error}"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _gradesFuture = _apiService.fetchGrades();
                        });
                      },
                      child: const Text("إعادة المحاولة"),
                    ),
                  ],
                ),
              );
            }

            final grades = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Contact Information Section
                _buildSectionHeader("معلومات التواصل"),
                _buildTextField(
                  controller: _studentPhoneController,
                  label: "هاتف الطالب",
                  required: true,
                  keyboardType: TextInputType.phone,
                ),
                _buildTextField(
                  controller: _parentPhoneController,
                  label: "هاتف ولي الأمر",
                  keyboardType: TextInputType.phone,
                ),
                _buildTextField(
                  controller: _schoolNameController,
                  label: "اسم المدرسة",
                ),

                // Educational Information Section
                _buildSectionHeader("المعلومات التعليمية"),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "الجنس *",
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    value: _gender,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "male", child: Text("ذكر")),
                      DropdownMenuItem(value: "female", child: Text("أنثى")),
                    ],
                    onChanged: (v) {
                      if (v != _gender) {
                        setState(() => _gender = v);
                      }
                    },
                    validator: (v) => v == null ? "اختر الجنس" : null,
                  ),
                ),

                _buildGradeDropdown(grades),

                _buildTextField(
                  controller: _birthDateController,
                  label: "تاريخ الميلاد",
                  required: true,
                  readOnly: true,
                  onTap: _pickBirthDate,
                ),

                // Address Section
                _buildSectionHeader("العنوان"),
                _buildTextField(controller: _addressController, label: "العنوان"),
                // Location Section
                _buildSectionHeader("الموقع"),
                Card(
                  child: CheckboxListTile(
                    title: const Text("إرسال موقعي الحالي"),
                    subtitle: _locationLoading
                        ? const Text("جاري الحصول على الموقع...")
                        : _latitude != null && _longitude != null
                        ? Text("تم الحصول على الموقع: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}")
                        : null,
                    value: _sendLocation,
                    onChanged: _locationLoading ? null : (val) {
                      setState(() => _sendLocation = val ?? false);
                      if (_sendLocation) _getLocation();
                    },
                    secondary: _locationLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.location_on),
                  ),
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  height: 50,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("حفظ البيانات"),
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
