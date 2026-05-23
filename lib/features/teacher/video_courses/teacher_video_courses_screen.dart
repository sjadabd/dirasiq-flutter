// Teacher → "الدورات المرئية" — list view + create dialog.
//
// Matches the dashboard's /teacher/video-courses index:
//   - Status tabs (all / pending_review / approved / hidden / rejected).
//   - Compact card grid (2 cols on phone, 3 on tablet).
//   - "Create new course" dialog where subject + teachingStage are
//     DROPDOWNS sourced from the teacher's own subjects + grades.
//
// Per-course tap → teacher_video_course_detail_screen.dart.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../../../core/utils/content_url.dart';
import 'teacher_video_course_detail_screen.dart';

class TeacherVideoCoursesScreen extends StatefulWidget {
  const TeacherVideoCoursesScreen({super.key});

  @override
  State<TeacherVideoCoursesScreen> createState() => _TeacherVideoCoursesScreenState();
}

class _TeacherVideoCoursesScreenState extends State<TeacherVideoCoursesScreen> {
  static const _statuses = <Map<String, dynamic>>[
    {'value': 'all',            'label': 'الكل',              'color': Colors.grey},
    {'value': 'pending_review', 'label': 'بانتظار المراجعة', 'color': Colors.orange},
    {'value': 'approved',       'label': 'مقبولة',           'color': Colors.green},
    {'value': 'hidden',         'label': 'مخفية',            'color': Colors.blueGrey},
    {'value': 'rejected',       'label': 'مرفوضة',           'color': Colors.red},
  ];

  final _api = TeacherApiService();

  String _status = 'all';
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await _api.fetchMyVideoCourses(status: _status);
      final list = res['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
    } catch (e) {
      _error = 'تعذّر تحميل الدورات';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final id = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _VideoCourseFormDialog(),
    );
    if (id != null && mounted) {
      Get.to(() => TeacherVideoCourseDetailScreen(courseId: id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('دوراتي المرئية'),
        backgroundColor: scheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _fetch,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('دورة جديدة'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final selected = _status == s['value'];
                return ChoiceChip(
                  label: Text(s['label']),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _status = s['value']);
                    _fetch();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: TextStyle(color: scheme.error)))
                    : _items.isEmpty
                        ? const _EmptyState()
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 220,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (_, i) {
                                final c = _items[i];
                                return _CourseCard(
                                  course: c,
                                  onTap: () async {
                                    await Get.to(() => TeacherVideoCourseDetailScreen(
                                          courseId: c['id'].toString(),
                                        ));
                                    _fetch();
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          Text('لا توجد دورات في هذه الحالة',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  Map<String, dynamic> _statusVisuals(String s) {
    switch (s) {
      case 'pending_review': return {'label': 'بانتظار المراجعة', 'color': Colors.orange};
      case 'approved':       return {'label': 'مقبولة',           'color': Colors.green};
      case 'hidden':         return {'label': 'مخفية',            'color': Colors.blueGrey};
      case 'rejected':       return {'label': 'مرفوضة',           'color': Colors.red};
      default:               return {'label': s,                  'color': Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = course['coverImage']?.toString() ?? '';
    final status = course['status']?.toString() ?? '';
    final sv = _statusVisuals(status);
    final isFree = course['isFree'] == true;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover.isNotEmpty
                      ? Image.network(
                          resolveContentUrl(cover),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverFallback(scheme),
                        )
                      : _coverFallback(scheme),
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (sv['color'] as Color).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(sv['label'],
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course['subject'] ?? '—'} · ${course['teachingStage'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isFree ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isFree ? 'مجاني' : '${course['price'] ?? 0} د.ع',
                          style: TextStyle(
                            color: isFree ? Colors.green.shade700 : Colors.orange.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.movie_outlined, color: scheme.outline, size: 36),
      );
}

// ---------------------------------------------------------------------------
// Create-course dialog (returns the new course id on success, else null)
// ---------------------------------------------------------------------------

class _VideoCourseFormDialog extends StatefulWidget {
  const _VideoCourseFormDialog();
  @override
  State<_VideoCourseFormDialog> createState() => _VideoCourseFormDialogState();
}

class _VideoCourseFormDialogState extends State<_VideoCourseFormDialog> {
  final _api = TeacherApiService();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '0');

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _grades = [];
  bool _loadingCatalogs = true;
  String? _selectedSubject;
  String? _selectedGradeId;
  String _selectedGradeName = '';

  bool _isFree = true;
  String _visibility = 'private';

  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final results = await Future.wait([
        _api.fetchMySubjectsCatalog(),
        _api.fetchMyGradesCatalog(),
      ]);
      if (!mounted) return;
      setState(() {
        _subjects = results[0];
        _grades = results[1];
        _loadingCatalogs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCatalogs = false);
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) { setState(() => _error = 'العنوان مطلوب'); return; }
    if (_selectedSubject == null) { setState(() => _error = 'يجب اختيار المادة'); return; }
    if (_selectedGradeId == null) { setState(() => _error = 'يجب اختيار المرحلة'); return; }
    setState(() { _submitting = true; _error = ''; });
    try {
      final payload = <String, dynamic>{
        'title': title,
        'subject': _selectedSubject,
        'teachingStage': _selectedGradeName,
        'gradeId': _selectedGradeId,
        'isFree': _isFree,
        'price': _isFree ? 0 : (int.tryParse(_price.text.trim()) ?? 0),
        'visibility': _visibility,
      };
      if (_description.text.trim().isNotEmpty) {
        payload['description'] = _description.text.trim();
      }
      final res = await _api.createVideoCourse(payload);
      final id = res['data']?['course']?['id']?.toString();
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر إنشاء الدورة');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = _loadingCatalogs
        ? ''
        : _subjects.isEmpty && _grades.isEmpty
            ? 'لم تضِف بعد مواد أو مراحل. أضِفها من قسم المواد والمراحل قبل إنشاء دورة.'
            : _subjects.isEmpty
                ? 'أضِف مادة على الأقل قبل إنشاء دورة.'
                : _grades.isEmpty
                    ? 'أضِف مرحلة على الأقل قبل إنشاء دورة.'
                    : '';
    return AlertDialog(
      title: const Text('إنشاء دورة مرئية جديدة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(hint, style: const TextStyle(fontSize: 12)),
              ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'عنوان الدورة *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المادة *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _subjects
                  .map((s) {
                    final v = (s['name'] ?? s['title'] ?? s['subject'])?.toString();
                    if (v == null || v.isEmpty) return null;
                    return DropdownMenuItem<String>(value: v, child: Text(v));
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: _subjects.isEmpty ? null : (v) => setState(() => _selectedSubject = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedGradeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المرحلة *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _grades
                  .map((g) {
                    final id = g['id']?.toString();
                    final name = (g['name'] ?? g['gradeName'] ?? g['title'])?.toString();
                    if (id == null || name == null) return null;
                    return DropdownMenuItem<String>(value: id, child: Text(name));
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: _grades.isEmpty ? null : (v) {
                final g = _grades.firstWhere((g) => g['id']?.toString() == v, orElse: () => {});
                setState(() {
                  _selectedGradeId = v;
                  _selectedGradeName = (g['name'] ?? g['gradeName'] ?? g['title'] ?? '').toString();
                });
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('مجاني'),
              value: _isFree,
              onChanged: (v) => setState(() => _isFree = v),
            ),
            if (!_isFree)
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر (د.ع)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الرؤية',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'private', child: Text('خاصة')),
                DropdownMenuItem(value: 'public',  child: Text('عامة')),
              ],
              onChanged: (v) => setState(() => _visibility = v ?? 'private'),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error, style: TextStyle(color: scheme.error, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, null),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: (_submitting || _subjects.isEmpty || _grades.isEmpty) ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('إنشاء'),
        ),
      ],
    );
  }
}
