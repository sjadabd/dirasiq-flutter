import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/auth_service.dart';
import 'package:mulhimiq/shared/themes/app_colors.dart';
import 'package:mulhimiq/shared/controllers/theme_controller.dart';

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
      _formattedAddressController.text = (user['formattedAddress'] ?? '')
          .toString();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2007, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      locale: const Locale('ar', 'SA'),
      helpText: 'اختر تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: isDark ? AppColors.darkPrimary : AppColors.primary,
              onPrimary: Colors.white,
              surface: isDark ? AppColors.darkSurface : AppColors.surface,
              onSurface: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _updateBirthDateDisplay();
      });
    }
  }

  void _showErrorSnackBar(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkAccent : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkSecondary : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? AppColors.gradientWelcome
                    .map((c) => isDark ? AppColors.darkPrimary : c)
                    .toList()
              : AppColors.gradientWelcome,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.darkPrimary : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
        ],
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
    IconData? prefixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.outline,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        validator: required
            ? (v) => v == null || v.isEmpty ? "مطلوب" : null
            : null,
      ),
    );
  }

  Widget _buildGradeDropdown(List<Map<String, dynamic>> grades) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: "المرحلة / الصف *",
          prefixIcon: Icon(
            Icons.school,
            color: isDark ? AppColors.darkPrimary : AppColors.primary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.outline,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        initialValue: _gradeId,
        isExpanded: true,
        dropdownColor: isDark ? AppColors.darkSurface : AppColors.surface,
        style: TextStyle(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        items: grades
            .map(
              (g) => DropdownMenuItem<String>(
                value: g["id"] as String,
                child: Text(
                  g["name"] as String,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            )
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

  Widget _buildGenderDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: "الجنس *",
          prefixIcon: Icon(
            Icons.person,
            color: isDark ? AppColors.darkPrimary : AppColors.primary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.outline,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        initialValue: _gender,
        isExpanded: true,
        dropdownColor: isDark ? AppColors.darkSurface : AppColors.surface,
        style: TextStyle(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        items: [
          DropdownMenuItem(
            value: "male",
            child: Text(
              "ذكر",
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          DropdownMenuItem(
            value: "female",
            child: Text(
              "أنثى",
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
        onChanged: (v) {
          if (v != _gender) {
            setState(() => _gender = v);
          }
        },
        validator: (v) => v == null ? "اختر الجنس" : null,
      ),
    );
  }

  Widget _buildLocationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.black.withValues(alpha: 0.3)
                : AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CheckboxListTile(
        isThreeLine:
            _locationLoading || (_latitude != null && _longitude != null),
        title: Text(
          "إرسال موقعي الحالي",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        subtitle: _locationLoading
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "جاري الحصول على الموقع...",
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              )
            : _latitude != null && _longitude != null
            ? Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSecondary : AppColors.success)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "تم الحصول على الموقع: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}",
                  style: TextStyle(
                    color: isDark ? AppColors.darkSecondary : AppColors.success,
                    fontSize: 12,
                  ),
                ),
              )
            : null,
        value: _sendLocation,
        onChanged: _locationLoading
            ? null
            : (val) {
                setState(() => _sendLocation = val ?? false);
                if (_sendLocation) _getLocation();
              },
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkPrimary : AppColors.primary)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _locationLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                  ),
                )
              : Icon(
                  Icons.location_on,
                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                ),
        ),
        activeColor: isDark ? AppColors.darkPrimary : AppColors.primary,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(
          "إكمال البيانات الشخصية",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Obx(
            () => IconButton(
              icon: Icon(
                ThemeController.to.themeMode.value == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                color: Colors.white,
              ),
              onPressed: () => ThemeController.to.toggleDarkLight(),
              tooltip: ThemeController.to.themeMode.value == ThemeMode.dark
                  ? "التبديل للوضع النهاري"
                  : "التبديل للوضع الليلي",
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? AppColors.gradientWelcome
                        .map((c) => AppColors.darkPrimary)
                        .toList()
                  : AppColors.gradientWelcome,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _gradesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.darkBackground, AppColors.darkSurface]
                        : [AppColors.background, AppColors.surfaceVariant],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? AppColors.darkPrimary : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "جاري تحميل البيانات...",
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              (isDark ? AppColors.darkAccent : AppColors.error)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "خطأ في تحميل البيانات",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _gradesFuture = _apiService.fetchGrades();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("إعادة المحاولة"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.darkPrimary.withValues(alpha: 0.1)
                              : AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final grades = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Contact Information Section
                _buildSectionHeader("معلومات التواصل", Icons.contact_phone),
                _buildTextField(
                  controller: _studentPhoneController,
                  label: "هاتف الطالب",
                  required: true,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone,
                ),
                _buildTextField(
                  controller: _parentPhoneController,
                  label: "هاتف ولي الأمر",
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_android,
                ),
                _buildTextField(
                  controller: _schoolNameController,
                  label: "اسم المدرسة",
                  prefixIcon: Icons.school,
                ),

                // Educational Information Section
                _buildSectionHeader("المعلومات التعليمية", Icons.school),
                _buildGenderDropdown(),
                _buildGradeDropdown(grades),
                _buildTextField(
                  controller: _birthDateController,
                  label: "تاريخ الميلاد",
                  required: true,
                  readOnly: true,
                  onTap: _pickBirthDate,
                  prefixIcon: Icons.calendar_today,
                ),

                // Address Section
                _buildSectionHeader("العنوان", Icons.location_city),
                _buildTextField(
                  controller: _addressController,
                  label: "العنوان",
                  prefixIcon: Icons.home,
                ),

                // Location Section
                _buildSectionHeader("الموقع", Icons.location_on),
                _buildLocationCard(),

                const SizedBox(height: 32),

                // Submit Button
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isDark ? AppColors.darkPrimary : AppColors.primary)
                                .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _loading
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? AppColors.gradientWelcome
                                        .map((c) => AppColors.darkPrimary)
                                        .toList()
                                  : AppColors.gradientWelcome,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.save, size: 20),
                          label: const Text(
                            "حفظ البيانات",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _handleSubmit,
                          style:
                              ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: AppColors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ).copyWith(
                                backgroundColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
