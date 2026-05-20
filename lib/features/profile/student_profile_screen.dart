import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../core/services/auth_service.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:geolocator/geolocator.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with TickerProviderStateMixin {
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
  String? _profileImageBase64;

  bool _sendLocation = false;
  bool _locationLoading = false;
  double? _latitude;
  double? _longitude;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // ✅ تهيئة الأنيميشن بشكل صحيح
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _confirmDelete() async {
    Get.defaultDialog(
      title: 'حذف الحساب',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText: 'هل أنت متأكد من حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.',
      textCancel: 'إلغاء',
      textConfirm: 'حذف',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
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
      setState(() => _loading = false);
    }
  }

  Widget _buildDeleteButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _confirmDelete,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.delete_forever),
        label: const Text('حذف الحساب'),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _studentPhoneController.dispose();
    _parentPhoneController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  // ===== تحميل بيانات المستخدم =====
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getUser();
      if (user != null) {
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

          // Prefill stored location if available
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
    } catch (_) {
      Get.snackbar('خطأ', 'تعذر اختيار الصورة');
    }
  }

  Future<void> _confirmAndSave() async {
    FocusScope.of(context).unfocus(); // إغلاق الكيبورد
    Get.defaultDialog(
      title: 'تأكيد التعديل',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText: 'هل أنت متأكد من حفظ التغييرات؟',
      textCancel: 'إلغاء',
      textConfirm: 'تأكيد',
      confirmTextColor: Colors.white,
      buttonColor: Theme.of(context).colorScheme.primary,
      onConfirm: () {
        Get.back();
        _save();
      },
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال الاسم');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_sendLocation && (_latitude == null || _longitude == null)) {
        await _getLocation();
      }
      await _authService.updateProfile({
        'name': _nameController.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate?.toIso8601String(),
        'studentPhone': _studentPhoneController.text.trim(),
        'parentPhone': _parentPhoneController.text.trim(),
        'schoolName': _schoolNameController.text.trim(),
        if (_sendLocation) ...{
          'latitude': _latitude ?? 33.36871840,
          'longitude': _longitude ?? 44.51151040,
        },
        if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty)
          'profileImageBase64': _profileImageBase64,
      });

      Get.snackbar('تم الحفظ', 'تم تحديث بياناتك بنجاح');
      await _loadUserData();
    } catch (_) {
      Get.snackbar('خطأ', 'فشل في حفظ البيانات');
    } finally {
      setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: const GlobalAppBar(title: 'ملف الطالب', centerTitle: true),
        body: _user == null
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildAvatarCard(cs),
                    const SizedBox(height: 16),
                    _buildEditableFields(cs),
                    const SizedBox(height: 16),
                    _buildSaveButton(cs),
                    const SizedBox(height: 16),
                    _buildReadonlySection(Theme.of(context), Get.isDarkMode),
                    const SizedBox(height: 16),
                    _buildDeleteButton(cs),
                  ],
                ),
              ),
      ),
    );
  }

  // ===== قسم الصورة =====
  Widget _buildAvatarCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Get.isDarkMode ? 0.5 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage:
                    (_pickedImage != null &&
                        _profileImageBase64 != null &&
                        _profileImageBase64!.isNotEmpty)
                    ? MemoryImage(base64Decode(_profileImageBase64!))
                    : _buildProfileImageProvider(),
                backgroundColor: cs.primaryContainer,
                child: _buildAvatarFallback(),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: () => _pickImage(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?['name'] ?? 'الاسم غير معروف',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _user?['email'] ?? '',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields(ColorScheme cs) {
    return _buildSmallCard(
      title: 'البيانات الشخصية',
      child: Column(
        children: [
          _buildField(_nameController, 'الاسم الكامل', Icons.person_outline),
          _buildDropdown(),
          _buildDatePicker(),
          const SizedBox(height: 12),
          _buildField(_studentPhoneController, 'هاتف الطالب', Icons.phone),
          _buildField(
            _parentPhoneController,
            'هاتف ولي الأمر',
            Icons.contact_phone,
          ),
          _buildField(
            _schoolNameController,
            'اسم المدرسة',
            Icons.school_outlined,
          ),
          const SizedBox(height: 8),
          _buildLocationSection(cs),
        ],
      ),
    );
  }

  Widget _buildLocationSection(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        activeColor: cs.primary,
        secondary: _locationLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(Icons.location_on, color: cs.primary),
        title: Text(
          'إرسال موقعي الحالي',
          style: TextStyle(color: cs.onSurface),
        ),
        subtitle: _locationLoading
            ? Text(
                'جاري الحصول على الموقع...',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              )
            : (_latitude != null && _longitude != null)
            ? Text(
                '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              )
            : Text(
                'يساعد على تخصيص التجربة التعليمية',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
        value: _sendLocation,
        onChanged: _locationLoading
            ? null
            : (val) async {
                final wantSend = val ?? false;
                if (wantSend) {
                  // If already selected, treat tap as a refresh and upload new location
                  if (_sendLocation) {
                    await _getLocation();
                    if (_latitude != null && _longitude != null) {
                      await _uploadLocation(_latitude!, _longitude!);
                    }
                  } else {
                    setState(() => _sendLocation = true);
                    await _getLocation();
                    if (_latitude != null && _longitude != null) {
                      await _uploadLocation(_latitude!, _longitude!);
                    }
                  }
                } else {
                  setState(() => _sendLocation = false);
                }
              },
      ),
    );
  }

  Future<void> _getLocation() async {
    setState(() => _locationLoading = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (e) {
      Get.snackbar('الموقع', 'خطأ في جلب الموقع');
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _uploadLocation(double lat, double lng) async {
    try {
      await _authService.updateProfile({'latitude': lat, 'longitude': lng});
      Get.snackbar('الموقع', 'تم تحديث موقعك بنجاح');
      await _loadUserData();
    } catch (_) {
      Get.snackbar('الموقع', 'تعذر إرسال الموقع إلى الخادم');
    }
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: cs.primary),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cs.outline),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: _gender,
        items: const [
          DropdownMenuItem(value: 'male', child: Text('ذكر')),
          DropdownMenuItem(value: 'female', child: Text('أنثى')),
        ],
        decoration: InputDecoration(
          labelText: 'الجنس',
          prefixIcon: Icon(Icons.wc, color: cs.primary),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cs.outline),
          ),
        ),
        onChanged: (v) => setState(() => _gender = v),
      ),
    );
  }

  Widget _buildDatePicker() {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _pickBirthDate,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'تاريخ الميلاد',
          prefixIcon: Icon(Icons.calendar_today_outlined, color: cs.primary),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cs.outline),
          ),
        ),
        child: Text(
          _birthDate == null
              ? 'اختر التاريخ'
              : DateFormat('yyyy-MM-dd').format(_birthDate!),
          style: TextStyle(color: cs.onSurface),
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme cs) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : _confirmAndSave,
      icon: const Icon(Icons.save_rounded, color: Colors.white),
      label: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('حفظ التغييرات'),
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSmallCard({required String title, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  ImageProvider<Object>? _buildProfileImageProvider() {
    // ✅ إذا المستخدم اختار صورة جديدة محليًا
    if (_pickedImage != null && _profileImageBase64 != null) {
      try {
        final img = MemoryImage(base64Decode(_profileImageBase64!));
        debugPrint(
          '[ProfileImage] Using PICKED base64 (${_profileImageBase64!.length} bytes)',
        );
        return img;
      } catch (_) {}
    }

    // ✅ إذا الخادم أعاد Base64 مباشرة
    final base64Keys = [
      'profileImageBase64',
      'avatarBase64',
      'photoBase64',
      'imageBase64',
    ];
    for (final key in base64Keys) {
      final raw = _user?[key]?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          final pure = raw.contains(',') ? raw.split(',').last : raw;
          debugPrint(
            '[ProfileImage] Found Base64 in "$key" (${pure.length} chars)',
          );
          return MemoryImage(base64Decode(pure));
        } catch (_) {}
      }
    }

    // ✅ المفاتيح الخاصة بالروابط (الآن تشمل profileImagePath)
    final urlKeys = [
      'profileImagePath', // 👈 تمت إضافتها هنا
      'profileImageUrl',
      'avatarUrl',
      'photoUrl',
      'imageUrl',
      'profileImage',
      'avatar',
      'photo',
      'image',
    ];

    for (final key in urlKeys) {
      final url = _user?[key]?.toString();
      if (url != null && url.isNotEmpty) {
        final normalized = _normalizeImageUrl(url);
        debugPrint('[ProfileImage] Found URL in "$key" -> $normalized');
        return NetworkImage(normalized);
      }
    }

    // ✅ فحص كائنات داخلية إذا وُجدت
    final nestedKeys = [
      ['profile', 'imageUrl'],
      ['profile', 'avatar'],
      ['account', 'profileImage'],
      ['data', 'image'],
    ];
    for (final path in nestedKeys) {
      dynamic val = _user;
      for (final key in path) {
        val = (val is Map) ? val[key] : null;
      }
      if (val is String && val.isNotEmpty) {
        final normalized = _normalizeImageUrl(val);
        debugPrint(
          '[ProfileImage] Found nested URL in ${path.join('.')} -> $normalized',
        );
        return NetworkImage(normalized);
      }
    }

    debugPrint('[ProfileImage] No image found, using fallback initials');
    return null;
  }

  Widget? _buildAvatarFallback() {
    final name = _user?['name'] ?? '?';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';
    return Text(initials, style: const TextStyle(color: Colors.white));
  }

  // ===== قسم البيانات غير القابلة للتعديل =====
  Widget _buildReadonlySection(ThemeData theme, bool isDark) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _slideController,
              curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
            ),
          ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3E)]
                  : [Colors.white, const Color(0xFFF7F8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'بيانات الحساب',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _CompactReadonlyTile(
                title: 'البريد الإلكتروني',
                value: _user?['email']?.toString(),
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 8),
              _CompactReadonlyTile(
                title: 'الصف الدراسي',
                value:
                    (_user?['studentGrades'] != null &&
                        (_user?['studentGrades'] as List).isNotEmpty)
                    ? _user!['studentGrades'][0]['gradeName'].toString()
                    : 'غير متوفر',
                icon: Icons.class_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Normalizes various image URL formats into a full absolute URL we can load.
  // Handles:
  // - data URLs (returned as-is)
  // - absolute http/https URLs (returned as-is)
  // - protocol-relative URLs (//host/path)
  // - relative paths ("/uploads/x.png" or "uploads/x.png")
  String _normalizeImageUrl(String raw) {
    String s = raw.trim();
    if (s.isEmpty) return s;

    // Remove accidental surrounding quotes
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }

    // Already a data URL
    if (s.startsWith('data:image')) return s;

    // Already absolute
    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    // Protocol-relative: //host/path
    if (s.startsWith('//')) {
      final scheme = Uri.parse(AppConfig.serverBaseUrl).scheme;
      return '$scheme:$s';
    }

    // Normalize backslashes and ensure a single leading slash for relative paths
    String path = s.replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';

    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base$path';
  }
}

class _CompactReadonlyTile extends StatelessWidget {
  final String title;
  final String? value;
  final IconData icon;

  const _CompactReadonlyTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cs.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value?.isNotEmpty == true ? value! : 'غير متوفر',
              textAlign: TextAlign.left,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
