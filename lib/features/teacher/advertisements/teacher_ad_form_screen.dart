import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import 'teacher_ad_ui.dart';

/// Create, edit draft, or re-publish a ended advertisement.
class TeacherAdFormScreen extends StatefulWidget {
  const TeacherAdFormScreen({
    super.key,
    this.adId,
    this.initial,
    this.republishMode = false,
  });

  final String? adId;
  final Map<String, dynamic>? initial;

  /// Re-publish creates a **new** ad from [initial] content + new budget, then submits.
  final bool republishMode;

  @override
  State<TeacherAdFormScreen> createState() => _TeacherAdFormScreenState();
}

class _TeacherAdFormScreenState extends State<TeacherAdFormScreen> {
  final _api = TeacherApiService();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  String _visibility = 'public';
  String? _coverDataUrl;
  bool _saving = false;
  bool _loadingSettings = true;
  bool _freeClicksEnabled = false;

  bool get _isEdit =>
      !widget.republishMode && widget.adId != null && widget.adId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _title.text = (init['title'] ?? '').toString();
      _description.text = (init['description'] ?? '').toString();
      _visibility = (init['visibility'] ?? 'public').toString();
      _coverDataUrl = adCoverUrl(
        init['coverImageUrl'] ?? init['cover_image_url'],
      );
      if (widget.republishMode) {
        _budget.text = '';
      } else {
        _budget.text = (init['budgetTotal'] ?? init['budget_total'] ?? '10000')
            .toString();
      }
    } else if (!widget.republishMode) {
      _budget.text = '10000';
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _api.fetchAdvertisementSettings();
      if (!mounted) return;
      setState(() {
        _freeClicksEnabled =
            settings['freeClicksEnabled'] == true ||
            settings['free_clicks_enabled'] == true;
        if (_freeClicksEnabled) {
          _budget.clear();
        } else if (_budget.text.trim().isEmpty && !widget.republishMode) {
          _budget.text =
              (settings['minBudget'] ?? settings['min_budget'] ?? 10000)
                  .toString();
        }
      });
    } catch (_) {
      // Safe fallback: keep paid mode so a missing settings response cannot
      // accidentally submit an unbudgeted advertisement.
    } finally {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      _coverDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _save({bool submit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'visibility': _visibility,
        if (!_freeClicksEnabled)
          'budgetTotal': double.tryParse(_budget.text.trim()) ?? 0,
        if (_coverDataUrl != null && _coverDataUrl!.isNotEmpty)
          'coverImageUrl': _coverDataUrl,
      };
      Map<String, dynamic> ad;
      if (_isEdit) {
        ad = await _api.updateAdvertisement(widget.adId!, body);
      } else {
        ad = await _api.createAdvertisement(body);
      }
      final id = (ad['id'] ?? widget.adId ?? '').toString();
      if ((submit || widget.republishMode) && id.isNotEmpty) {
        await _api.submitAdvertisement(id);
        Get.snackbar(
          'تم',
          widget.republishMode
              ? 'تم إرسال طلب إعادة النشر للمراجعة'
              : 'تم إرسال الإعلان للمراجعة',
        );
        if (mounted) completeTeacherAdSubmitFlow(context);
      } else {
        Get.snackbar('تم', _isEdit ? 'تم تحديث المسودة' : 'تم إنشاء المسودة');
        Get.back(result: true);
      }
    } catch (e) {
      Get.snackbar('خطأ', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _titleText {
    if (widget.republishMode) return 'إعادة نشر الإعلان';
    if (_isEdit) return 'متابعة الإعلان';
    return 'إعلان جديد';
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: mq.page,
        appBar: TeacherAppBar(title: _titleText),
        body: Form(
          key: _formKey,
          child: _loadingSettings
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  children: [
                    if (widget.republishMode)
                      Container(
                        margin: const EdgeInsets.only(bottom: MqSpacing.md),
                        padding: const EdgeInsets.all(MqSpacing.md),
                        decoration: BoxDecoration(
                          color: mq.accentSoft,
                          borderRadius: MqRadius.brMd,
                          border: Border.all(color: mq.accentLine),
                        ),
                        child: Text(
                          _freeClicksEnabled
                              ? 'يمكنك تعديل العنوان والوصف والصورة. النشر مجاني حالياً ولا يحتاج إلى ميزانية. سيُرسل الطلب للسوبر أدمن للموافقة قبل النشر.'
                              : 'يمكنك تعديل العنوان والوصف والصورة وتحديد ميزانية جديدة. '
                                    'سيُرسل الطلب للسوبر أدمن للموافقة قبل النشر.',
                          style: context.text.bodySmall?.copyWith(
                            color: mq.ink2,
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (_coverDataUrl != null && _coverDataUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: MqRadius.brMd,
                        child: Image.network(
                          _coverDataUrl!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 160,
                            color: mq.fill,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: mq.ink3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: MqSpacing.sm),
                    ],
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'العنوان'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: MqSpacing.md),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                      maxLines: 5,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: MqSpacing.md),
                    if (_freeClicksEnabled) ...[
                      Container(
                        padding: const EdgeInsets.all(MqSpacing.md),
                        decoration: BoxDecoration(
                          color: mq.accentSoft,
                          borderRadius: MqRadius.brMd,
                          border: Border.all(color: mq.accentLine),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.redeem_outlined, color: mq.accent),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text(
                                'الإعلانات مجانية حالياً — لن تُخصم أي ميزانية مقابل النقرات.',
                                style: context.text.bodySmall?.copyWith(
                                  color: mq.ink2,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: MqSpacing.md),
                    ] else ...[
                      TextFormField(
                        controller: _budget,
                        decoration: InputDecoration(
                          labelText: widget.republishMode
                              ? 'الميزانية الجديدة (د.ع)'
                              : 'الميزانية (د.ع)',
                          hintText: widget.republishMode ? 'مثال: 10000' : null,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                            ? 'أدخل ميزانية صحيحة'
                            : null,
                      ),
                      const SizedBox(height: MqSpacing.md),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _visibility,
                      decoration: const InputDecoration(labelText: 'الظهور'),
                      items: const [
                        DropdownMenuItem(
                          value: 'public',
                          child: Text('عام — كل الطلاب'),
                        ),
                        DropdownMenuItem(
                          value: 'governorate_only',
                          child: Text('محافظتي فقط'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _visibility = v ?? 'public'),
                    ),
                    const SizedBox(height: MqSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _coverDataUrl == null
                            ? 'اختيار صورة الغلاف'
                            : 'تغيير الصورة',
                      ),
                    ),
                    const SizedBox(height: MqSpacing.xl),
                    if (!widget.republishMode) ...[
                      MqButton(
                        label: 'حفظ مسودة',
                        loading: _saving,
                        onPressed: _saving ? null : () => _save(),
                      ),
                      const SizedBox(height: MqSpacing.sm),
                    ],
                    MqButton(
                      label: widget.republishMode
                          ? 'إرسال إعادة النشر للمراجعة'
                          : 'حفظ وإرسال للمراجعة',
                      icon: Icons.send_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : () => _save(submit: true),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
