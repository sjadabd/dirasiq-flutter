import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';

/// Create or edit a teacher advertisement (draft / pending only).
class TeacherAdFormScreen extends StatefulWidget {
  const TeacherAdFormScreen({super.key, this.adId, this.initial});

  final String? adId;
  final Map<String, dynamic>? initial;

  @override
  State<TeacherAdFormScreen> createState() => _TeacherAdFormScreenState();
}

class _TeacherAdFormScreenState extends State<TeacherAdFormScreen> {
  final _api = TeacherApiService();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController(text: '10000');
  String _visibility = 'public';
  String? _coverDataUrl;
  bool _saving = false;

  bool get _isEdit => widget.adId != null && widget.adId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _title.text = (init['title'] ?? '').toString();
      _description.text = (init['description'] ?? '').toString();
      _budget.text = (init['budgetTotal'] ?? init['budget_total'] ?? '10000').toString();
      _visibility = (init['visibility'] ?? 'public').toString();
      _coverDataUrl = init['coverImageUrl'] ?? init['cover_image_url']?.toString();
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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
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
        'budgetTotal': double.tryParse(_budget.text.trim()) ?? 0,
        if (_coverDataUrl != null) 'coverImageUrl': _coverDataUrl,
      };
      Map<String, dynamic> ad;
      if (_isEdit) {
        ad = await _api.updateAdvertisement(widget.adId!, body);
      } else {
        ad = await _api.createAdvertisement(body);
      }
      final id = (ad['id'] ?? widget.adId ?? '').toString();
      if (submit && id.isNotEmpty) {
        await _api.submitAdvertisement(id);
        Get.snackbar('تم', 'تم إرسال الإعلان للمراجعة');
      } else {
        Get.snackbar('تم', _isEdit ? 'تم تحديث المسودة' : 'تم إنشاء المسودة');
      }
      Get.back(result: true);
    } catch (e) {
      Get.snackbar('خطأ', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: TeacherAppBar(title: _isEdit ? 'تعديل إعلان' : 'إعلان جديد'),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(MqSpacing.lg),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'العنوان'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'الوصف'),
                maxLines: 5,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budget,
                decoration: const InputDecoration(labelText: 'الميزانية (د.ع)'),
                keyboardType: TextInputType.number,
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'أدخل ميزانية صحيحة' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'الظهور'),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('عام — كل الطلاب')),
                  DropdownMenuItem(value: 'governorate_only', child: Text('محافظتي فقط')),
                ],
                onChanged: (v) => setState(() => _visibility = v ?? 'public'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_coverDataUrl == null ? 'اختيار صورة الغلاف' : 'تغيير الصورة'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : () => _save(),
                child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ مسودة'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving ? null : () => _save(submit: true),
                child: const Text('حفظ وإرسال للمراجعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
