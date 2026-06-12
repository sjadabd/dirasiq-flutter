// Teacher application — multi-step form (Teacher Design System pass).
//
// Single screen with 4 steps:
//   1. Basic info     (name, contact, password, gender, birth, location)
//   2. Teaching info  (subject, stage, experience, workplace, capacity)
//   3. Profile        (bio + social handles, all optional)
//   4. Uploads        (5 file slots, all optional; submit happens here)
//
// On final submit:
//   - validate form
//   - POST /api/teacher-applications → get applicationId + uploadToken
//   - for each chosen file: POST /api/teacher-applications/:id/files
//   - navigate to the success/OTP screen
//
// The submit/upload pipeline, validation, catalog loading and Google
// identity flow are UNCHANGED — this pass only restyles the shell (custom
// step indicator + design-system cards/fields in place of the Material
// Stepper).
//
// File pickers:
//   - profile_image, national_id_image    → image_picker (gallery)
//   - certificate_image, optional_attach  → file_picker (image OR pdf)
//   - intro_video                         → image_picker (video)

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mulhimiq/core/services/google_auth_service.dart';
import 'package:mulhimiq/core/services/notification_service.dart';
import 'package:mulhimiq/core/services/teacher_application_api_service.dart';

import '../../teacher/shared/design/teacher_design.dart';
import '../widgets/join_widgets.dart';
import 'teacher_application_otp_screen.dart';
import 'teacher_application_success_screen.dart';

const String _kOtherOption = 'أخرى';

const List<String> _kStepTitles = [
  'المعلومات الأساسية',
  'معلومات التدريس',
  'الملف الشخصي',
  'المستندات والإرسال',
];

class TeacherApplicationFormScreen extends StatefulWidget {
  const TeacherApplicationFormScreen({super.key});

  @override
  State<TeacherApplicationFormScreen> createState() =>
      _TeacherApplicationFormScreenState();
}

class _TeacherApplicationFormScreenState
    extends State<TeacherApplicationFormScreen> {
  // -- step state -------------------------------------------------------------

  int _currentStep = 0;
  final _stepKeys = List.generate(4, (_) => GlobalKey<FormState>());
  final _api = TeacherApplicationApiService();

  // -- field controllers ------------------------------------------------------

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _gender = 'male';
  DateTime? _birthDate;
  final _city = TextEditingController();
  final _area = TextEditingController();

  // Phase 8 — dual auth path. Defaults to 'email' for back-compat; the user
  // can switch to 'google' on the first step.
  String _authProvider = 'email';
  String? _googleToken;       // captured after Google sign-in (one-shot)
  String? _googleEmail;       // read-only email pulled from the Google account
  bool _googleSigningIn = false;
  String? _googleError;

  // Public catalogs — subject list (legacy free-text) + grades. Grades now
  // come from the super-admin-managed `grades` table and replace the old
  // free-text teachingStage dropdown.
  List<String> _subjectsCatalog = const [];
  List<TeacherApplicationGrade> _gradesCatalog = const [];
  bool _catalogLoading = true;
  String? _catalogError;

  // Selection state.
  String? _selectedSubject;
  final Set<String> _selectedGradeIds = <String>{};

  // Free-text fallback for subject when the user picks "أخرى".
  final _customSubject = TextEditingController();

  final _yearsExp = TextEditingController(text: '0');
  final _currentWorkplace = TextEditingController();
  bool _hasPhysical = false;
  final _estStudents = TextEditingController(text: '0');

  final _bio = TextEditingController();
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();
  final _telegram = TextEditingController();
  final _tiktok = TextEditingController();
  final _youtube = TextEditingController();

  // -- file slots -------------------------------------------------------------

  static const _kindProfile = 'profile_image';
  static const _kindCert = 'certificate_image';
  static const _kindNationalId = 'national_id_image';
  static const _kindOptional = 'optional_attachment';
  static const _kindVideo = 'intro_video';

  final Map<String, _PickedFile?> _files = {
    _kindProfile: null,
    _kindCert: null,
    _kindNationalId: null,
    _kindOptional: null,
    _kindVideo: null,
  };
  final Map<String, double> _progress = {
    _kindProfile: 0,
    _kindCert: 0,
    _kindNationalId: 0,
    _kindOptional: 0,
    _kindVideo: 0,
  };
  final Map<String, String?> _uploadError = {};

  // -- submit state -----------------------------------------------------------

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _phone, _email, _password,
      _city, _area,
      _customSubject,
      _yearsExp, _currentWorkplace, _estStudents,
      _bio, _facebook, _instagram, _telegram, _tiktok, _youtube,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // -- catalog loading --------------------------------------------------------

  Future<void> _loadCatalogs() async {
    try {
      final subjects = await _api.getSubjects();
      final grades = await _api.getActiveGrades();
      if (!mounted) return;
      setState(() {
        _subjectsCatalog = subjects;
        _gradesCatalog = grades;
        _catalogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogLoading = false;
        _catalogError =
            'تعذر تحميل قوائم المواد والمراحل — أعد المحاولة لاحقاً.';
      });
    }
  }

  // -- Google identity assertion (Phase 8 dual-auth) --------------------------

  Future<void> _signInWithGoogle() async {
    if (_googleSigningIn) return;
    setState(() {
      _googleSigningIn = true;
      _googleError = null;
    });
    try {
      final assertion = await GoogleAuthService().getIdTokenAndEmail();
      if (!mounted) return;
      if (assertion == null) {
        // User cancelled — quiet no-op.
        return;
      }
      setState(() {
        _googleToken = assertion.idToken;
        _googleEmail = assertion.email;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _googleError = 'تعذر تسجيل الدخول عبر Google: $e');
    } finally {
      if (mounted) setState(() => _googleSigningIn = false);
    }
  }

  // -- step navigation --------------------------------------------------------

  void _next() {
    final formOk = _stepKeys[_currentStep].currentState?.validate() ?? true;
    if (!formOk) return;
    if (_currentStep == 0) {
      if (_birthDate == null) {
        _showSnack('يرجى اختيار تاريخ الميلاد');
        return;
      }
      if (_authProvider == 'google' &&
          (_googleToken == null || (_googleEmail ?? '').isEmpty)) {
        _showSnack('يرجى تسجيل الدخول عبر Google قبل المتابعة');
        return;
      }
    }
    if (_currentStep == 1) {
      if (_selectedSubject == _kOtherOption &&
          _customSubject.text.trim().isEmpty) {
        _showSnack('يرجى تحديد المادة');
        return;
      }
      if (_selectedGradeIds.isEmpty) {
        _showSnack('يرجى اختيار مرحلة دراسية واحدة على الأقل');
        return;
      }
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prev() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // -- submit + upload pipeline ----------------------------------------------

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      // 1) playerId is optional — best-effort grab from the SDK.
      String? playerId;
      try {
        playerId = await NotificationService.instance.getPlayerId();
      } catch (_) {
        playerId = null;
      }

      // 2) compose payload. Phase 8: branch on _authProvider — the email
      //    path sends email+password, the google path sends a googleToken
      //    instead (server verifies + extracts the email from the token).
      final subjectFinal = _selectedSubject == _kOtherOption
          ? _customSubject.text.trim()
          : (_selectedSubject ?? '').trim();
      final emailForReceipts = _authProvider == 'google'
          ? (_googleEmail ?? '').trim()
          : _email.text.trim();

      final payload = <String, dynamic>{
        'authProvider': _authProvider,
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'phone': _phone.text.trim(),
        if (_authProvider == 'email') ...{
          'email': _email.text.trim(),
          'password': _password.text,
        },
        if (_authProvider == 'google') 'googleToken': _googleToken!,
        'gender': _gender,
        'birthDate': _birthDate!.toIso8601String().split('T').first,
        'city': _city.text.trim(),
        'area': _area.text.trim(),
        'subject': subjectFinal,
        'gradeIds': _selectedGradeIds.toList(growable: false),
        'yearsOfExperience': int.tryParse(_yearsExp.text.trim()) ?? 0,
        'currentWorkplace': _currentWorkplace.text.trim(),
        'hasPhysicalCourses': _hasPhysical,
        'estimatedStudentCount': int.tryParse(_estStudents.text.trim()) ?? 0,
        'bio': _bio.text.trim(),
        'facebookUrl': _facebook.text.trim(),
        'instagramUrl': _instagram.text.trim(),
        'telegramUrl': _telegram.text.trim(),
        'tiktokUrl': _tiktok.text.trim(),
        'youtubeUrl': _youtube.text.trim(),
        if (playerId != null && playerId.isNotEmpty)
          'oneSignalPlayerId': playerId,
      }..removeWhere((k, v) => v is String && v.isEmpty);

      final created = await _api.submit(payload);

      // 3) upload chosen files sequentially with progress
      //
      // The application row is already CREATED at this point — POST
      // /api/teacher-applications has succeeded above. From here on out,
      // ANY file-upload failure must be recorded per-file and the loop
      // must keep going. Letting an exception escape would skip the OTP
      // navigation below and leave the user staring at the form thinking
      // their submission failed, when in fact the backend already has it
      // (and a retry would be rejected by the unique email/phone index).
      //
      // The two failure modes worth distinguishing:
      //   - TeacherApplicationApiException → server rejected the upload
      //     (size, mime, kind, token, ...). Use the server's message.
      //   - Any other Object → almost always a local I/O issue. The most
      //     common one in the wild is `PathNotFoundException` thrown by
      //     `MultipartFile.fromFile` when Android cleaned the file-picker
      //     cache between pick + submit. We also pre-check `exists()` to
      //     turn that race into a clean per-file error.
      for (final kind in _files.keys) {
        final f = _files[kind];
        if (f == null) continue;
        try {
          if (!await f.file.exists()) {
            throw const FileSystemException(
              'انتهت صلاحية الملف المخبأ — يرجى إعادة اختياره',
            );
          }
          await _api.uploadFile(
            applicationId: created.applicationId,
            uploadToken: created.uploadToken,
            kind: kind,
            file: f.file,
            declaredMimeType: f.mimeType,
            onProgress: (p) {
              if (!mounted) return;
              setState(() => _progress[kind] = p);
            },
          );
          if (mounted) setState(() => _progress[kind] = 1);
        } on TeacherApplicationApiException catch (e) {
          if (mounted) setState(() => _uploadError[kind] = e.message);
        } on FileSystemException catch (e) {
          if (mounted) {
            setState(() => _uploadError[kind] = e.message);
          }
        } catch (e) {
          if (mounted) setState(() => _uploadError[kind] = 'فشل رفع الملف: $e');
        }
      }

      if (!mounted) return;

      // 4) Branch the post-submit destination:
      //    - email path: row exists but email is unverified + super-admin
      //      not yet notified. Push the OTP screen which on verify fires
      //      onSubmitted server-side and lands on the success screen.
      //    - google path: server already fired onSubmitted (email is
      //      Google-verified). Go straight to success.
      if (_authProvider == 'email') {
        Get.off(() => TeacherApplicationOtpScreen(
              applicationId: created.applicationId,
              email: emailForReceipts,
            ));
      } else {
        Get.off(() => TeacherApplicationSuccessScreen(email: emailForReceipts));
      }
    } on TeacherApplicationApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = 'حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // -- file pickers -----------------------------------------------------------

  Future<void> _pickImage(String kind) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final mime = _mimeFromExt(picked.path);
      if (mime == null) {
        _showSnack('صيغة الملف غير مدعومة');
        return;
      }
      setState(() {
        _files[kind] = _PickedFile(file: File(picked.path), mimeType: mime);
        _progress[kind] = 0;
        _uploadError.remove(kind);
      });
    } catch (e) {
      _showSnack('تعذر اختيار الصورة: $e');
    }
  }

  Future<void> _pickDocOrImage(String kind) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: false,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      if (f.path == null) return;
      final mime = _mimeFromExt(f.path!);
      if (mime == null) {
        _showSnack('صيغة الملف غير مدعومة');
        return;
      }
      setState(() {
        _files[kind] = _PickedFile(file: File(f.path!), mimeType: mime);
        _progress[kind] = 0;
        _uploadError.remove(kind);
      });
    } catch (e) {
      _showSnack('تعذر اختيار الملف: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() {
        _files[_kindVideo] = _PickedFile(file: File(picked.path), mimeType: 'video/mp4');
        _progress[_kindVideo] = 0;
        _uploadError.remove(_kindVideo);
      });
    } catch (e) {
      _showSnack('تعذر اختيار الفيديو: $e');
    }
  }

  String? _mimeFromExt(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      default:
        return null;
    }
  }

  // -- UI ---------------------------------------------------------------------

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
            appBar: const JoinAppBar(title: 'طلب الانضمام كأستاذ'),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  _stepIndicator(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(MqSpacing.lg),
                      child: _stepBody(context),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _bottomBar(context),
          );
        }),
      ),
    );
  }

  Widget _stepIndicator(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.lg, vertical: MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        border: Border(bottom: BorderSide(color: mq.line)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            _stepDot(context, i),
            if (i < 3)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i < _currentStep ? mq.accent : mq.line,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stepDot(BuildContext context, int i) {
    final mq = context.mq;
    final done = i < _currentStep;
    final active = i == _currentStep;
    final bg = done || active ? mq.accent : mq.fill;
    final fg = done || active ? mq.onAccent : mq.ink3;
    return GestureDetector(
      onTap: _submitting ? null : () => setState(() => _currentStep = i),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: active ? Border.all(color: mq.accentLine, width: 3) : null,
        ),
        child: done
            ? Icon(Icons.check, size: 16, color: fg)
            : Text('${i + 1}',
                style: context.text.labelMedium
                    ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
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
                    color: context.mq.accentSoft, borderRadius: MqRadius.brSm),
                child: Icon(_stepIcon(_currentStep),
                    size: MqSize.iconSm, color: context.mq.accent),
              ),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: Text(_kStepTitles[_currentStep],
                    style: context.text.titleMedium),
              ),
              Text('${_currentStep + 1}/4',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.mq.ink3)),
            ],
          ),
          const SizedBox(height: MqSpacing.lg),
          switch (_currentStep) {
            0 => _basicStep(context),
            1 => _teachingStep(context),
            2 => _profileStep(context),
            _ => _uploadsStep(context),
          },
        ],
      ),
    );
  }

  IconData _stepIcon(int i) => switch (i) {
        0 => Icons.person_outline,
        1 => Icons.school_outlined,
        2 => Icons.badge_outlined,
        _ => Icons.upload_file_outlined,
      };

  // -- steps ------------------------------------------------------------------

  Widget _basicStep(BuildContext context) => Form(
        key: _stepKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _authMethodToggle(context),
            const SizedBox(height: MqSpacing.md),
            Row(children: [
              Expanded(child: _tf(_firstName, 'الاسم الأول', isRequired: true)),
              const SizedBox(width: MqSpacing.sm),
              Expanded(child: _tf(_lastName, 'الاسم الأخير', isRequired: true)),
            ]),
            _tf(_phone, 'رقم الهاتف (10–15 رقم)',
                isRequired: true, keyboard: TextInputType.phone),
            if (_authProvider == 'email') ...[
              _tf(_email, 'البريد الإلكتروني',
                  isRequired: true, keyboard: TextInputType.emailAddress),
              _tf(_password, 'كلمة المرور (6 أحرف على الأقل)',
                  isRequired: true, obscure: true, minLen: 6),
            ] else
              _googleIdentityRow(context),
            _genderDropdown(context),
            _datePickerField(context),
            Row(children: [
              Expanded(child: _tf(_city, 'المدينة', isRequired: true)),
              const SizedBox(width: MqSpacing.sm),
              Expanded(child: _tf(_area, 'المنطقة', isRequired: true)),
            ]),
          ],
        ),
      );

  Widget _teachingStep(BuildContext context) => Form(
        key: _stepKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_catalogError != null) ...[
              JoinErrorBox(message: _catalogError!),
              const SizedBox(height: MqSpacing.md),
            ],
            _catalogDropdown(
              context,
              label: 'المادة التي تُدرّسها',
              value: _selectedSubject,
              items: _subjectsCatalog,
              onChanged: (v) => setState(() {
                _selectedSubject = v;
                if (v != _kOtherOption) _customSubject.clear();
              }),
            ),
            if (_selectedSubject == _kOtherOption)
              _tf(_customSubject, 'حدّد المادة', isRequired: true),
            _gradesMultiSelect(context),
            Row(children: [
              Expanded(
                  child: _tf(_yearsExp, 'سنوات الخبرة',
                      isRequired: true, keyboard: TextInputType.number)),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                  child: _tf(_estStudents, 'عدد الطلاب المتوقّع',
                      keyboard: TextInputType.number)),
            ]),
            _tf(_currentWorkplace, 'مكان العمل الحالي (اختياري)'),
            const SizedBox(height: MqSpacing.sm),
            _physicalToggle(context),
          ],
        ),
      );

  Widget _profileStep(BuildContext context) => Form(
        key: _stepKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tf(_bio, 'نبذة عنك (اختياري)', maxLines: 4),
            _tf(_facebook, 'Facebook (اختياري)', keyboard: TextInputType.url),
            _tf(_instagram, 'Instagram (اختياري)', keyboard: TextInputType.url),
            _tf(_telegram, 'Telegram (اختياري)'),
            _tf(_tiktok, 'TikTok (اختياري)', keyboard: TextInputType.url),
            _tf(_youtube, 'YouTube (اختياري)', keyboard: TextInputType.url),
          ],
        ),
      );

  Widget _uploadsStep(BuildContext context) {
    final mq = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'كل المرفقات اختيارية، لكنّها تُسرّع المراجعة. الأنواع المدعومة: JPG / PNG / WEBP / PDF (للمستندات) و MP4 (للفيديو).',
          style: context.text.bodySmall?.copyWith(color: mq.ink2),
        ),
        const SizedBox(height: MqSpacing.md),
        _fileTile(context, _kindProfile, 'الصورة الشخصية',
            'JPG/PNG/WEBP — حتى 5MB',
            onPick: () => _pickImage(_kindProfile)),
        _fileTile(context, _kindCert, 'شهادة التدريس',
            'JPG/PNG/WEBP/PDF — حتى 10MB',
            onPick: () => _pickDocOrImage(_kindCert)),
        _fileTile(context, _kindNationalId, 'الهوية الوطنية',
            'JPG/PNG/WEBP — حتى 5MB',
            onPick: () => _pickImage(_kindNationalId)),
        _fileTile(context, _kindOptional, 'مرفق إضافي (اختياري)',
            'JPG/PNG/WEBP/PDF — حتى 10MB',
            onPick: () => _pickDocOrImage(_kindOptional)),
        _fileTile(context, _kindVideo, 'فيديو تعريفي', 'MP4 — حتى 50MB',
            onPick: _pickVideo),
        if (_submitError != null) ...[
          const SizedBox(height: MqSpacing.md),
          JoinErrorBox(message: _submitError!),
        ],
      ],
    );
  }

  Widget _fileTile(BuildContext context, String kind, String title, String hint,
      {required Future<void> Function() onPick}) {
    final mq = context.mq;
    final picked = _files[kind];
    final progress = _progress[kind] ?? 0.0;
    final err = _uploadError[kind];
    final isPdf = picked != null && picked.mimeType == 'application/pdf';
    return Container(
      margin: const EdgeInsets.only(bottom: MqSpacing.sm),
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: picked != null ? mq.accentSoft.withValues(alpha: 0.4) : mq.fill,
        border: Border.all(color: picked != null ? mq.accentLine : mq.line),
        borderRadius: MqRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: mq.card, borderRadius: MqRadius.brSm),
                child: Icon(
                  kind == _kindVideo
                      ? Icons.videocam_outlined
                      : (isPdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined),
                  color: mq.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.labelLarge),
                    Text(hint,
                        style: context.text.labelSmall
                            ?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
              if (_submitting && picked != null && progress > 0 && progress < 1)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else if (picked != null && progress == 1)
                Icon(Icons.check_circle, color: mq.success)
              else
                MqButton.text(
                  label: picked == null ? 'إرفاق' : 'استبدال',
                  icon: Icons.attach_file,
                  size: MqButtonSize.small,
                  onPressed: _submitting ? null : () => onPick(),
                ),
            ],
          ),
          if (picked != null) ...[
            const SizedBox(height: MqSpacing.xs),
            Text(
              picked.file.uri.pathSegments.last,
              style: context.text.labelSmall?.copyWith(color: mq.ink2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_submitting && progress > 0)
              Padding(
                padding: const EdgeInsets.only(top: MqSpacing.xs),
                child: ClipRRect(
                  borderRadius: MqRadius.brPill,
                  child: LinearProgressIndicator(
                      value: progress, backgroundColor: mq.line),
                ),
              ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: MqSpacing.xs),
                child: Text(err,
                    style: context.text.labelSmall?.copyWith(color: mq.error)),
              ),
          ],
        ],
      ),
    );
  }

  // -- bottom action bar ------------------------------------------------------

  Widget _bottomBar(BuildContext context) {
    final mq = context.mq;
    final isLast = _currentStep == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        border: Border(top: BorderSide(color: mq.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: MqButton.secondary(
                  label: 'السابق',
                  onPressed: _submitting ? null : _prev,
                ),
              ),
              const SizedBox(width: MqSpacing.md),
            ],
            Expanded(
              flex: 2,
              child: MqButton(
                label: _submitting
                    ? 'جارٍ الإرسال…'
                    : (isLast ? 'إرسال الطلب' : 'التالي'),
                icon: _submitting
                    ? null
                    : (isLast
                        ? Icons.send_rounded
                        : Icons.arrow_forward_rounded),
                loading: _submitting && isLast,
                onPressed: _submitting ? null : _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- small field helpers ----------------------------------------------------

  Widget _tf(TextEditingController c, String label,
      {bool isRequired = false,
      bool obscure = false,
      int? minLen,
      int? maxLines,
      TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        maxLines: obscure ? 1 : (maxLines ?? 1),
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
        ),
        validator: (v) {
          final s = (v ?? '').trim();
          if (isRequired && s.isEmpty) return 'هذا الحقل مطلوب';
          if (minLen != null && s.length < minLen) {
            return 'الحد الأدنى $minLen أحرف';
          }
          return null;
        },
      ),
    );
  }

  Widget _authMethodToggle(BuildContext context) {
    final mq = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('طريقة التسجيل',
            style: context.text.labelMedium?.copyWith(color: mq.ink2)),
        const SizedBox(height: MqSpacing.sm),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: mq.fill, borderRadius: MqRadius.brMd),
          child: Row(
            children: [
              _segment(context, 'email', 'البريد الإلكتروني',
                  Icons.email_outlined),
              _segment(
                  context, 'google', 'Google', Icons.account_circle_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _segment(
      BuildContext context, String value, String label, IconData icon) {
    final mq = context.mq;
    final selected = _authProvider == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _authProvider = value;
          if (_authProvider == 'email') {
            // Clear Google state so a re-selection re-prompts the user.
            _googleToken = null;
            _googleEmail = null;
            _googleError = null;
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? mq.card : Colors.transparent,
            borderRadius: MqRadius.brSm,
            boxShadow: selected ? mq.cardShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: MqSize.iconSm,
                  color: selected ? mq.accent : mq.ink2),
              const SizedBox(width: MqSpacing.xs),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: selected ? mq.accent : mq.ink2,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleIdentityRow(BuildContext context) {
    final mq = context.mq;
    final connected = _googleToken != null && (_googleEmail?.isNotEmpty ?? false);
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(MqSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: connected ? mq.accent : mq.line),
          borderRadius: MqRadius.brMd,
          color: connected ? mq.accentSoft.withValues(alpha: 0.5) : mq.fill,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(
                connected ? Icons.check_circle : Icons.account_circle_outlined,
                color: connected ? mq.success : mq.ink2,
              ),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: Text(
                  connected
                      ? 'تم ربط حساب Google: $_googleEmail'
                      : 'سجّل الدخول عبر Google لتأكيد بريدك الإلكتروني',
                  style: context.text.bodyMedium?.copyWith(
                      fontWeight:
                          connected ? FontWeight.w600 : FontWeight.normal),
                ),
              ),
              MqButton.text(
                label: connected ? 'تغيير' : 'دخول',
                icon: _googleSigningIn ? null : Icons.login,
                size: MqButtonSize.small,
                loading: _googleSigningIn,
                onPressed: _googleSigningIn ? null : _signInWithGoogle,
              ),
            ]),
            if (_googleError != null) ...[
              const SizedBox(height: MqSpacing.xs),
              Text(_googleError!,
                  style: context.text.labelSmall?.copyWith(color: mq.error)),
            ],
            if (!connected)
              Padding(
                padding: const EdgeInsets.only(top: MqSpacing.xs),
                child: Text(
                  'لن نرى كلمة مرور حساب Google الخاص بك. نحتاج فقط إلى تأكيد عنوان بريدك.',
                  style: context.text.labelSmall?.copyWith(color: mq.ink3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Multi-select grade picker. Renders chips for every active grade pulled
  // from the public catalog; tap toggles selection. At least one selection
  // is required to advance past step 2 (validated in _next()).
  Widget _gradesMultiSelect(BuildContext context) {
    final mq = context.mq;

    if (_catalogLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: MqSpacing.md),
        child: Row(children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: MqSpacing.sm),
          Text('جارٍ تحميل المراحل…',
              style: context.text.bodySmall?.copyWith(color: mq.ink2)),
        ]),
      );
    }

    if (_gradesCatalog.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: MqSpacing.md),
        child: Text('لا توجد مراحل متاحة حالياً — تواصل مع الدعم.',
            style: context.text.bodySmall?.copyWith(color: mq.error)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المراحل الدراسية التي تُدرّسها *',
              style: context.text.labelMedium?.copyWith(color: mq.ink2)),
          const SizedBox(height: 2),
          Text('يمكنك اختيار أكثر من مرحلة',
              style: context.text.labelSmall?.copyWith(color: mq.ink3)),
          const SizedBox(height: MqSpacing.sm),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: [
              for (final g in _gradesCatalog)
                MqChip(
                  label: g.name,
                  selected: _selectedGradeIds.contains(g.id),
                  onTap: () => setState(() {
                    if (_selectedGradeIds.contains(g.id)) {
                      _selectedGradeIds.remove(g.id);
                    } else {
                      _selectedGradeIds.add(g.id);
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _catalogDropdown(
    BuildContext context, {
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final mq = context.mq;
    if (_catalogLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: MqSpacing.md),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, isDense: true),
          child: Row(children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: MqSpacing.sm),
            Text('جارٍ التحميل…',
                style: context.text.bodySmall?.copyWith(color: mq.ink2)),
          ]),
        ),
      );
    }
    final entries = [...items, _kOtherOption];
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: mq.card,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          for (final e in entries)
            DropdownMenuItem(value: e, child: Text(e)),
        ],
        onChanged: onChanged,
        validator: (v) => (v == null || v.isEmpty) ? 'هذا الحقل مطلوب' : null,
      ),
    );
  }

  Widget _genderDropdown(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: MqSpacing.md),
        child: DropdownButtonFormField<String>(
          initialValue: _gender,
          dropdownColor: context.mq.card,
          decoration: const InputDecoration(labelText: 'الجنس', isDense: true),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('ذكر')),
            DropdownMenuItem(value: 'female', child: Text('أنثى')),
          ],
          onChanged: (v) => setState(() => _gender = v ?? 'male'),
        ),
      );

  Widget _datePickerField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: InkWell(
        borderRadius: MqRadius.brMd,
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _birthDate ?? DateTime(now.year - 30),
            firstDate: DateTime(now.year - 80),
            lastDate: now,
            locale: const Locale('ar'),
          );
          if (picked != null) setState(() => _birthDate = picked);
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'تاريخ الميلاد',
            isDense: true,
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            _birthDate == null
                ? 'اضغط لاختيار التاريخ'
                : DateFormat('yyyy-MM-dd').format(_birthDate!),
            style: context.text.bodyMedium?.copyWith(
                color: _birthDate == null ? context.mq.ink3 : context.mq.ink),
          ),
        ),
      ),
    );
  }

  Widget _physicalToggle(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md, vertical: MqSpacing.xs),
      decoration: BoxDecoration(
        color: mq.fill,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('أُقدّم كورسات حضورية',
                style: context.text.bodyMedium),
          ),
          Switch(
            value: _hasPhysical,
            activeTrackColor: mq.accent,
            onChanged: (v) => setState(() => _hasPhysical = v),
          ),
        ],
      ),
    );
  }
}

class _PickedFile {
  _PickedFile({required this.file, required this.mimeType});
  final File file;
  final String mimeType;
}
