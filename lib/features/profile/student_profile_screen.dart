import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../core/services/auth_service.dart';
import 'package:dirasiq/core/config/app_config.dart';
import '../../shared/themes/app_colors.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:intl/intl.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _user;
  final _nameController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _schoolNameController = TextEditingController();
  bool _loading = false;
  String? _gender;
  DateTime? _birthDate;
  XFile? _pickedImage;
  String? _profileImageBase64; // what will be sent to server

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  ImageProvider<Object>? _buildProfileImageProvider() {
    // Priority: picked image (base64) -> server base64 (supports data URL) -> url/path (supports relative)
    if (_pickedImage != null && _profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_profileImageBase64!));
      } catch (_) {}
    }

    // base64 from server (various keys)
    final possibleB64Keys = [
      'profileImageBase64', 'avatarBase64', 'photoBase64', 'imageBase64'
    ];
    for (final k in possibleB64Keys) {
      final raw = (_profileImageBase64 ?? _user?[k])?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          final pure = raw.contains(',') ? raw.split(',').last : raw;
          return MemoryImage(base64Decode(pure));
        } catch (_) {}
      }
    }

    // url/path from server (various keys)
    final possibleUrlKeys = [
      'profileImageUrl', 'profileImagePath', 'avatarUrl', 'photoUrl', 'imageUrl', 'profileImage', 'avatar', 'photo', 'image'
    ];
    for (final k in possibleUrlKeys) {
      final url = _user?[k]?.toString();
      if (url != null && url.isNotEmpty) {
        if (url.startsWith('http')) return NetworkImage(url);
        if (url.startsWith('/')) return NetworkImage('${AppConfig.serverBaseUrl}$url');
      }
    }
    return null;
  }

  Widget? _buildAvatarFallback() {
    // Show initials if no image
    if (_buildProfileImageProvider() != null) return null;
    final name = _user?['name']?.toString() ?? '';
    final parts = name.trim().split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    String initials = '?';
    if (parts.isNotEmpty) {
      final first = parts[0].substring(0, 1);
      final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
      initials = (first + second).toUpperCase();
    }
    return Text(
      initials,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
    );
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getUser();
      if (user != null) {
        setState(() {
          _user = user;
          _nameController.text = user['name']?.toString() ?? '';
          _studentPhoneController.text = user['studentPhone']?.toString() ?? '';
          _parentPhoneController.text = user['parentPhone']?.toString() ?? '';
          _schoolNameController.text = user['schoolName']?.toString() ?? '';
          _gender = user['gender']?.toString();
          if (user['birthDate'] != null) {
            _birthDate = DateTime.tryParse(user['birthDate'].toString());
          }
          // Preload base64 if exists from server to keep when not changing
          final srvB64 = user['profileImageBase64']?.toString();
          if (srvB64 != null && srvB64.isNotEmpty) {
            _profileImageBase64 = srvB64;
          }
        });
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحميل بيانات المستخدم');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedImage = image;
          _profileImageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر اختيار الصورة');
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال الاسم');
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.updateProfile({
        'name': _nameController.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate?.toIso8601String(),
        'studentPhone': _studentPhoneController.text.trim(),
        'parentPhone': _parentPhoneController.text.trim(),
        'schoolName': _schoolNameController.text.trim(),
        if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty)
          'profileImageBase64': _profileImageBase64,
      });

      Get.snackbar('نجح', 'تم حفظ البيانات بنجاح');
      await _loadUserData();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في حفظ البيانات');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 15)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _birthDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(title: 'ملف الطالب', centerTitle: true),
      body: _user == null
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Enhanced Header Card with avatar
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradientLearning,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                backgroundImage: _buildProfileImageProvider(),
                                child: _buildAvatarFallback(),
                              ),
                              Positioned(
                                bottom: -2,
                                left: -2,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      await showModalBottomSheet(
                                        context: context,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                        ),
                                        builder: (_) => SafeArea(
                                          child: SizedBox(
                                            height: 130,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _pickImage(ImageSource.camera);
                                                  },
                                                  icon: const Icon(Icons.photo_camera),
                                                  label: const Text('الكاميرا'),
                                                ),
                                                TextButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _pickImage(ImageSource.gallery);
                                                  },
                                                  icon: const Icon(Icons.photo_library_outlined),
                                                  label: const Text('المعرض'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(Icons.edit, size: 16, color: AppColors.primary),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user?['name']?.toString() ??
                                      'الاسم غير معروف',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _user?['email']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Enhanced Editable Fields Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.gradientMotivation,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'البيانات القابلة للتعديل',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildEnhancedTextField(
                            controller: _nameController,
                            label: 'الاسم الكامل',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildEnhancedDropdown(),
                          const SizedBox(height: 16),
                          _buildEnhancedDatePicker(),
                          const SizedBox(height: 16),
                          _buildEnhancedTextField(
                            controller: _studentPhoneController,
                            label: 'هاتف الطالب',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          _buildEnhancedTextField(
                            controller: _parentPhoneController,
                            label: 'هاتف ولي الأمر',
                            icon: Icons.contact_phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          _buildEnhancedTextField(
                            controller: _schoolNameController,
                            label: 'اسم المدرسة',
                            icon: Icons.school_outlined,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.gradientSuccess,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _loading ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'حفظ التغييرات',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Enhanced Readonly Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.gradientLearning,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'بيانات الحساب (غير قابلة للتعديل)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _EnhancedReadonlyTile(
                            title: 'البريد الإلكتروني',
                            value: _user?['email']?.toString(),
                            icon: Icons.email_outlined,
                          ),
                          _EnhancedReadonlyTile(
                            title: 'الصف',
                            value:
                                (_user?['studentGrades'] != null &&
                                    (_user?['studentGrades'] as List)
                                        .isNotEmpty)
                                ? _user!['studentGrades'][0]['gradeName']
                                      .toString()
                                : 'غير متوفر',
                            icon: Icons.class_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          labelStyle: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildEnhancedDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'الجنس',
          prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          labelStyle: TextStyle(color: AppColors.textSecondary),
        ),
        initialValue: _gender,
        items: const [
          DropdownMenuItem(value: 'male', child: Text('ذكر')),
          DropdownMenuItem(value: 'female', child: Text('أنثى')),
        ],
        onChanged: (v) => setState(() => _gender = v),
      ),
    );
  }

  Widget _buildEnhancedDatePicker() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _pickBirthDate,
        borderRadius: BorderRadius.circular(15),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'تاريخ الميلاد',
            prefixIcon: Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.outline),
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            labelStyle: TextStyle(color: AppColors.textSecondary),
          ),
          child: Text(
            _birthDate == null
                ? 'اختر التاريخ'
                : DateFormat('yyyy-MM-dd').format(_birthDate!),
            style: TextStyle(
              color: _birthDate == null
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EnhancedReadonlyTile extends StatelessWidget {
  final String title;
  final String? value;
  final IconData icon;

  const _EnhancedReadonlyTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceVariant,
            AppColors.surfaceVariant.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value?.isNotEmpty == true ? value! : 'غير متوفر',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
