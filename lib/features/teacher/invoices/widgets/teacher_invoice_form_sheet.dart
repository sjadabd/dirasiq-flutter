// Create-invoice sheet — Flutter mirror of the dashboard's create-invoice.vue.
//
// Restyled to the Teacher Design System as an animated bottom sheet. Captures
// the POST /api/teacher/invoices payload: studentId, courseId, studyYear,
// paymentMode ('cash' | 'installments'), amountDue, optional discountAmount /
// invoiceDate / dueDate / notes, and — for installments — the auto-split trio
// installmentsCount / installmentIntervalDays / installmentFirstDueDate.
//
// The "advanced manual installment plan" of the dashboard is intentionally
// left to the web (per the screen's own note); this sheet covers cash + the
// default auto-split flow, which is what teachers use from mobile.
//
// On success the backend fires a best-effort push notification to the student,
// so nothing extra is needed client-side. Returns `true` via Navigator.pop.
//
// Open with `showModalBottomSheet<bool>(... builder: (_) =>
// TeacherInvoiceFormSheet(api: ..., studyYears: ..., initialStudyYear: ...))`.

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/services/teacher_api_service.dart';
import '../../shared/design/teacher_design.dart';

class TeacherInvoiceFormSheet extends StatefulWidget {
  const TeacherInvoiceFormSheet({
    super.key,
    required this.api,
    required this.studyYear,
    this.existing,
    this.existingInstallments,
  });

  final TeacherApiService api;

  /// The active study year — auto-selected, read-only (the teacher can't pick
  /// another year from mobile).
  final String studyYear;

  /// When set, the sheet is in EDIT mode: course/student/year are locked and
  /// the fields are prefilled from this invoice row. On save it calls
  /// `updateInvoiceFull` (PUT) instead of `createInvoice` (POST).
  final Map<String, dynamic>? existing;

  /// The invoice's current installment rows — used to prefill count / interval
  /// / first-due in edit mode.
  final List<Map<String, dynamic>>? existingInstallments;

  @override
  State<TeacherInvoiceFormSheet> createState() =>
      _TeacherInvoiceFormSheetState();
}

class _TeacherInvoiceFormSheetState extends State<TeacherInvoiceFormSheet> {
  final _api = TeacherApiService();
  final _formKey = GlobalKey<FormState>();

  final _amountDue = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _installmentsCount = TextEditingController(text: '4');
  final _intervalDays = TextEditingController(text: '30');

  List<Map<String, dynamic>> _courses = [];
  Map<String, String> _subjectsById = const {}; // subject_id -> name
  List<Map<String, dynamic>> _students = [];
  bool _loadingCourses = true;
  bool _loadingStudents = false;
  bool _allInvoiced = false; // every student in the course already has an invoice

  String? _courseId;
  Map<String, dynamic>? _course; // the selected course row (price/grade/subject)
  String? _studentId;
  late final String _studyYear;
  DateTime? _invoiceDate;
  DateTime? _dueDate;
  DateTime? _firstDueDate;
  String _paymentMode = 'installments'; // 'cash' | 'installments'

  bool _submitting = false;
  String _error = '';
  bool _disposed = false;

  static final _iso = DateFormat('yyyy-MM-dd');

  bool get _isEdit => widget.existing != null;

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _disposed) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _studyYear = widget.studyYear;
    final now = DateTime.now();
    _invoiceDate = DateTime(now.year, now.month, now.day);
    _firstDueDate = _invoiceDate!.add(const Duration(days: 7));
    if (_isEdit) _prefillScalarsForEdit();
    _loadCourses();
  }

  void _prefillScalarsForEdit() {
    final e = widget.existing!;
    _amountDue.text = _fmt(num.tryParse((e['amount_due'] ?? '0').toString()) ?? 0);
    _discount.text = _fmt(num.tryParse((e['discount_total'] ?? '0').toString()) ?? 0);
    _notes.text = (e['notes'] ?? '').toString();
    final pm = (e['payment_mode'] ?? 'installments').toString();
    _paymentMode = (pm == 'cash') ? 'cash' : 'installments';
    final inv = DateTime.tryParse((e['invoice_date'] ?? '').toString());
    if (inv != null) _invoiceDate = inv;
    final due = DateTime.tryParse((e['due_date'] ?? '').toString());
    if (due != null) _dueDate = due;

    // Derive installment count / interval / first-due from the current rows.
    final rows = (widget.existingInstallments ?? [])
        .where((r) => r['due_date'] != null)
        .toList()
      ..sort((a, b) => (a['installment_number'] ?? 0)
          .compareTo(b['installment_number'] ?? 0));
    if (rows.length >= 2) {
      _installmentsCount.text = rows.length.toString();
      final d0 = DateTime.tryParse(rows[0]['due_date'].toString());
      final d1 = DateTime.tryParse(rows[1]['due_date'].toString());
      if (d0 != null) _firstDueDate = d0;
      if (d0 != null && d1 != null) {
        final gap = d1.difference(d0).inDays;
        if (gap > 0) _intervalDays.text = gap.toString();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _amountDue.dispose();
    _discount.dispose();
    _notes.dispose();
    _installmentsCount.dispose();
    _intervalDays.dispose();
    super.dispose();
  }

  // ---- data ----------------------------------------------------------------

  Future<void> _loadCourses() async {
    try {
      // Full rows (not just names) so we can show grade + subject and auto-fill
      // the amount from the course price. We list ALL the teacher's non-deleted
      // courses (like the dashboard's create-invoice) — the study year is
      // locked independently to the active year. The courses endpoint doesn't
      // join subjects, so we fetch the subject catalog and map by id.
      final results = await Future.wait([
        _api.fetchCourses(page: 1, limit: 100, deleted: false),
        _api.fetchMySubjectsCatalog(),
      ]);
      final courses = _listOf(results[0] as Map<String, dynamic>);
      final subjects = results[1] as List<Map<String, dynamic>>;
      _safeSetState(() {
        _courses = courses;
        _subjectsById = {
          for (final s in subjects)
            (s['id'] ?? '').toString(): (s['name'] ?? s['title'] ?? '').toString(),
        };
        _loadingCourses = false;
      });
      if (_isEdit) await _preselectForEdit();
    } catch (_) {
      _safeSetState(() {
        _loadingCourses = false;
        _error = 'تعذّر تحميل الكورسات';
      });
    }
  }

  /// In edit mode, lock onto the invoice's course + student (no price re-fill —
  /// the amount stays whatever the invoice was created with).
  Future<void> _preselectForEdit() async {
    final e = widget.existing!;
    final courseId = (e['course_id'] ?? '').toString();
    final studentId = (e['student_id'] ?? '').toString();
    final course = _courses.firstWhere(
      (c) => _courseId2(c) == courseId,
      orElse: () => <String, dynamic>{},
    );
    _safeSetState(() {
      _courseId = courseId.isEmpty ? null : courseId;
      _course = course.isEmpty ? null : course;
      _loadingStudents = courseId.isNotEmpty;
    });
    if (courseId.isEmpty) return;
    try {
      final res = await _api.fetchStudentsByCourse(courseId);
      final students = _listOf(res);
      _safeSetState(() {
        _students = students;
        _studentId = students.any((s) => _studentId2(s) == studentId)
            ? studentId
            : null;
        _loadingStudents = false;
      });
    } catch (_) {
      _safeSetState(() => _loadingStudents = false);
    }
  }

  Future<void> _onCourseChanged(String? id) async {
    final course = _courses.firstWhere(
      (c) => _courseId2(c) == id,
      orElse: () => <String, dynamic>{},
    );
    final price = num.tryParse((course['price'] ?? '').toString());
    _safeSetState(() {
      _courseId = id;
      _course = course.isEmpty ? null : course;
      _studentId = null;
      _students = [];
      _allInvoiced = false;
      _loadingStudents = id != null;
      // Amount due is fixed to the course price (read-only); the teacher can
      // only reduce the effective total via the discount field.
      _amountDue.text = price != null ? _fmt(price) : '';
    });
    if (id == null) return;
    try {
      // Load the course roster AND the invoices already issued for this course,
      // then drop students who already have one — a student can have only one
      // invoice per course (also enforced server-side).
      final results = await Future.wait([
        _api.fetchStudentsByCourse(id),
        _api.fetchInvoices(studyYear: widget.studyYear, courseId: id, limit: 100),
      ]);
      final roster = _listOf(results[0]);
      final invoicedIds = _listOf(results[1])
          .map((inv) => (inv['student_id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet();
      _safeSetState(() {
        _students =
            roster.where((s) => !invoicedIds.contains(_studentId2(s))).toList();
        _allInvoiced = roster.isNotEmpty && _students.isEmpty;
        _loadingStudents = false;
      });
    } catch (_) {
      _safeSetState(() => _loadingStudents = false);
    }
  }

  List<Map<String, dynamic>> _listOf(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is List) {
      return d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    if (d is Map && d['items'] is List) {
      return (d['items'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  String _courseLabel(Map c) =>
      (c['course_name'] ?? c['name'] ?? c['title'] ?? '—').toString();
  String _courseId2(Map c) => (c['id'] ?? c['course_id'] ?? '').toString();
  String _gradeName(Map c) => (c['grade_name'] ?? '').toString();
  String _subjectName(Map c) {
    final byId = _subjectsById[(c['subject_id'] ?? '').toString()];
    if (byId != null && byId.isNotEmpty) return byId;
    return (c['subject_name'] ?? '').toString();
  }
  String _courseMeta(Map c) =>
      [_gradeName(c), _subjectName(c)].where((s) => s.isNotEmpty).join(' · ');
  String _studentLabel(Map s) =>
      (s['student_name'] ?? s['name'] ?? s['full_name'] ?? '—').toString();
  String _studentId2(Map s) => (s['student_id'] ?? s['id'] ?? '').toString();

  // ---- derived -------------------------------------------------------------

  num get _amount => num.tryParse(_amountDue.text.replaceAll(',', '').trim()) ?? 0;
  num get _disc => num.tryParse(_discount.text.replaceAll(',', '').trim()) ?? 0;
  num get _net {
    final n = _amount - _disc;
    return n < 0 ? 0 : n;
  }

  int get _count => int.tryParse(_installmentsCount.text.trim()) ?? 0;

  (num perInstallment, num lastInstallment) get _split {
    if (_count < 2) return (_net, _net);
    final per = (_net / _count).floor();
    final last = _net - per * (_count - 1);
    return (per, last);
  }

  int get _interval => int.tryParse(_intervalDays.text.trim()) ?? 30;

  /// The concrete installment rows (number + amount + due date) the teacher
  /// sees and that we send to the server as the explicit `installments[]` plan.
  /// The last row absorbs the rounding remainder so the rows sum to [_net].
  List<({int number, num amount, DateTime due})> get _installmentPlan {
    if (_count < 2 || _firstDueDate == null || _net <= 0) return const [];
    final (per, last) = _split;
    return List.generate(_count, (i) {
      final amount = (i == _count - 1) ? last : per;
      final due = _firstDueDate!.add(Duration(days: i * _interval));
      return (number: i + 1, amount: amount, due: due);
    });
  }

  // ---- pickers -------------------------------------------------------------

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('ar'),
    );
    if (picked != null) onPicked(picked);
  }

  // ---- submit --------------------------------------------------------------

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_courseId == null) {
      _safeSetState(() => _error = 'اختر الكورس');
      return;
    }
    if (_studentId == null) {
      _safeSetState(() => _error = 'اختر الطالب');
      return;
    }
    if (_amount <= 0) {
      _safeSetState(() => _error = 'سعر الكورس غير صالح');
      return;
    }
    if (_disc < 0 || _disc > _amount) {
      _safeSetState(() => _error = 'الخصم يجب أن يكون بين 0 والمبلغ المستحق');
      return;
    }
    if (_paymentMode == 'installments') {
      if (_count < 2) {
        _safeSetState(() => _error = 'عدد الأقساط 2 على الأقل');
        return;
      }
      if (_firstDueDate == null) {
        _safeSetState(() => _error = 'حدّد تاريخ أول قسط');
        return;
      }
      final interval = int.tryParse(_intervalDays.text.trim()) ?? 0;
      if (interval < 1) {
        _safeSetState(() => _error = 'الفترة بين الأقساط يوم واحد على الأقل');
        return;
      }
    }

    final payload = <String, dynamic>{
      // student/course/year are immutable on edit — only sent when creating.
      if (!_isEdit) ...{
        'studentId': _studentId,
        'courseId': _courseId,
        'studyYear': _studyYear,
      },
      'paymentMode': _paymentMode,
      'amountDue': _amount,
      'discountAmount': _disc,
      if (_invoiceDate != null) 'invoiceDate': _iso.format(_invoiceDate!),
      if (_dueDate != null) 'dueDate': _iso.format(_dueDate!),
      'notes': _notes.text.trim(),
      if (_paymentMode == 'installments')
        'installments': _installmentPlan
            .map((r) => {
                  'plannedAmount': r.amount,
                  'dueDate': _iso.format(r.due),
                })
            .toList(),
    };

    _safeSetState(() {
      _submitting = true;
      _error = '';
    });
    try {
      if (_isEdit) {
        await _api.updateInvoiceFull(
            widget.existing!['id'].toString(), payload);
      } else {
        await _api.createInvoice(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _safeSetState(() {
        _submitting = false;
        _error = _serverError(e) ??
            'تعذّر إنشاء الفاتورة. تحقّق من الحقول وحاول مجدّداً.';
      });
    }
  }

  /// Surface the server's own message (e.g. validation detail) when available,
  /// so a failure points at the real cause instead of a generic line.
  String? _serverError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final errs = data['errors'];
        if (errs is List && errs.isNotEmpty && errs.first is Map) {
          final m = (errs.first as Map)['message']?.toString();
          if (m != null && m.isNotEmpty) return m;
        }
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    return null;
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: mq.card,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MqRadius.xl)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _handle(context),
                      _header(context),
                      Flexible(
                        child: _loadingCourses
                            ? const Padding(
                                padding: EdgeInsets.all(MqSpacing.xxl),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            : _formBody(context),
                      ),
                      _saveBar(context),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _handle(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: MqSpacing.sm, bottom: MqSpacing.sm),
          decoration: BoxDecoration(
              color: context.mq.line, borderRadius: MqRadius.brPill),
        ),
      );

  Widget _header(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(MqSpacing.lg, 0, MqSpacing.lg, MqSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: mq.accentSoft, borderRadius: MqRadius.brSm),
            child: Icon(Icons.receipt_long_outlined,
                size: MqSize.iconSm, color: mq.accent),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(_isEdit ? 'تعديل الفاتورة' : 'إنشاء فاتورة جديدة',
                style: context.text.titleMedium),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(false),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: mq.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formBody(BuildContext context) {
    final mq = context.mq;
    final noCourses = _courses.isEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noCourses)
              Padding(
                padding: const EdgeInsets.only(bottom: MqSpacing.md),
                child: MqSurface(
                  tone: MqSurfaceTone.orange,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: mq.orangeDeep),
                      const SizedBox(width: MqSpacing.sm),
                      Expanded(
                        child: Text(
                          'لا توجد كورسات. أنشئ كورساً أولاً قبل إصدار فاتورة.',
                          style:
                              context.text.bodySmall?.copyWith(color: mq.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Course
            DropdownButtonFormField<String>(
              initialValue: _courseId,
              isExpanded: true,
              dropdownColor: mq.card,
              decoration: const InputDecoration(
                labelText: 'الكورس *',
                prefixIcon: Icon(Icons.book_outlined),
                isDense: true,
              ),
              selectedItemBuilder: (ctx) => _courses
                  .where((c) => _courseId2(c).isNotEmpty)
                  .map<Widget>((c) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(_courseLabel(c),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              items: _courses
                  .map((c) {
                    final id = _courseId2(c);
                    if (id.isEmpty) return null;
                    final meta = _courseMeta(c);
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_courseLabel(c),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (meta.isNotEmpty)
                            Text(meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.labelSmall
                                    ?.copyWith(color: mq.ink3)),
                        ],
                      ),
                    );
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged:
                  noCourses || _submitting || _isEdit ? null : _onCourseChanged,
            ),
            if (_course != null) ...[
              const SizedBox(height: MqSpacing.sm),
              _courseInfoCard(context),
            ],
            const SizedBox(height: MqSpacing.md),
            // Student
            DropdownButtonFormField<String>(
              initialValue: _studentId,
              isExpanded: true,
              dropdownColor: mq.card,
              decoration: InputDecoration(
                labelText: 'الطالب *',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                isDense: true,
                suffixIcon: _loadingStudents
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
                hintText: _courseId == null ? 'اختر الكورس أولاً' : null,
              ),
              items: _students
                  .map((s) {
                    final id = _studentId2(s);
                    if (id.isEmpty) return null;
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(_studentLabel(s),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: _students.isEmpty || _submitting || _isEdit
                  ? null
                  : (v) => _safeSetState(() => _studentId = v),
            ),
            if (_allInvoiced) ...[
              const SizedBox(height: MqSpacing.sm),
              MqSurface(
                tone: MqSurfaceTone.orange,
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: mq.orangeDeep),
                    const SizedBox(width: MqSpacing.sm),
                    Expanded(
                      child: Text(
                        'كل طلاب هذا الكورس لديهم فواتير بالفعل. لا يمكن إصدار فاتورة ثانية لنفس الطالب في نفس الكورس.',
                        style:
                            context.text.bodySmall?.copyWith(color: mq.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MqSpacing.md),
            // Study year — auto (active year), read-only.
            TextFormField(
              enabled: false,
              initialValue: _studyYear,
              decoration: InputDecoration(
                labelText: 'السنة الدراسية',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                isDense: true,
                suffixIcon: Icon(Icons.lock_outline_rounded,
                    size: 16, color: mq.ink3),
              ),
            ),
            const SizedBox(height: MqSpacing.md),
            // Amount (read-only, from the course price) + discount
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _amountDue,
                  readOnly: true,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المستحق (د.ع)',
                    isDense: true,
                    suffixIcon: Icon(Icons.lock_outline_rounded,
                        size: 16, color: mq.ink3),
                  ),
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _discount,
                  keyboardType: const TextInputType.numberWithOptions(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))
                  ],
                  onChanged: (_) => _safeSetState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'خصم (د.ع)',
                    isDense: true,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: MqSpacing.sm),
            _netRow(context),
            const SizedBox(height: MqSpacing.md),
            // Dates
            Row(children: [
              Expanded(
                child: _DateField(
                  label: 'تاريخ الفاتورة',
                  value: _invoiceDate,
                  onTap: () => _pickDate(
                    current: _invoiceDate,
                    onPicked: (d) => _safeSetState(() => _invoiceDate = d),
                  ),
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              Expanded(
                child: _DateField(
                  label: 'تاريخ الاستحقاق',
                  value: _dueDate,
                  hint: 'اختياري',
                  onTap: () => _pickDate(
                    current: _dueDate,
                    onPicked: (d) => _safeSetState(() => _dueDate = d),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: MqSpacing.md),
            // Payment mode
            Text('طريقة الدفع', style: context.text.labelMedium),
            const SizedBox(height: MqSpacing.sm),
            Row(children: [
              MqChip(
                label: 'أقساط',
                selected: _paymentMode == 'installments',
                onTap: () => _safeSetState(() => _paymentMode = 'installments'),
              ),
              const SizedBox(width: MqSpacing.sm),
              MqChip(
                label: 'كاش (دفعة واحدة)',
                selected: _paymentMode == 'cash',
                onTap: () => _safeSetState(() => _paymentMode = 'cash'),
              ),
            ]),
            if (_paymentMode == 'installments') ...[
              const SizedBox(height: MqSpacing.md),
              _installmentsSection(context),
            ],
            const SizedBox(height: MqSpacing.md),
            // Notes
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                hintText: 'ملاحظة اختيارية...',
                alignLabelWithHint: true,
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: MqSpacing.md),
              MqSurface(
                tone: MqSurfaceTone.neutral,
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 18, color: mq.error),
                    const SizedBox(width: MqSpacing.sm),
                    Expanded(
                      child: Text(_error,
                          style: context.text.bodySmall
                              ?.copyWith(color: mq.error)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _courseInfoCard(BuildContext context) {
    final mq = context.mq;
    final c = _course!;
    final price = num.tryParse((c['price'] ?? '').toString());
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.accentSoft,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.accentLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoLine(context, Icons.book_outlined, 'الكورس', _courseLabel(c)),
          if (_gradeName(c).isNotEmpty) ...[
            const SizedBox(height: MqSpacing.xs),
            _infoLine(context, Icons.school_outlined, 'المرحلة الدراسية',
                _gradeName(c)),
          ],
          if (_subjectName(c).isNotEmpty) ...[
            const SizedBox(height: MqSpacing.xs),
            _infoLine(
                context, Icons.menu_book_outlined, 'المادة', _subjectName(c)),
          ],
          if (price != null) ...[
            const SizedBox(height: MqSpacing.xs),
            _infoLine(context, Icons.payments_outlined, 'سعر الكورس',
                '${_fmt(price)} د.ع'),
          ],
        ],
      ),
    );
  }

  Widget _infoLine(
      BuildContext context, IconData icon, String label, String value) {
    final mq = context.mq;
    return Row(
      children: [
        Icon(icon, size: 16, color: mq.accent),
        const SizedBox(width: MqSpacing.sm),
        Text('$label: ',
            style: context.text.labelSmall?.copyWith(color: mq.ink2)),
        Expanded(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall
                  ?.copyWith(color: mq.ink, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _netRow(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.md, vertical: MqSpacing.sm),
      decoration: BoxDecoration(color: mq.fill, borderRadius: MqRadius.brMd),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, size: 18, color: mq.ink3),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text('صافي الفاتورة بعد الخصم',
                style: context.text.bodySmall?.copyWith(color: mq.ink2)),
          ),
          Text('${_fmt(_net)} د.ع',
              style: MqTypography.mono(
                  color: t.success, size: 14, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _installmentsSection(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.fill,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _installmentsCount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _safeSetState(() {}),
                decoration: const InputDecoration(
                  labelText: 'عدد الأقساط',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: MqSpacing.sm),
            Expanded(
              child: TextFormField(
                controller: _intervalDays,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'الفترة (أيام)',
                  isDense: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: MqSpacing.md),
          _DateField(
            label: 'تاريخ أول قسط',
            value: _firstDueDate,
            onTap: () => _pickDate(
              current: _firstDueDate,
              onPicked: (d) => _safeSetState(() => _firstDueDate = d),
            ),
          ),
          if (_installmentPlan.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.md),
            Divider(height: 1, color: mq.line),
            const SizedBox(height: MqSpacing.sm),
            Row(
              children: [
                Icon(Icons.list_alt_outlined, size: 16, color: mq.ink3),
                const SizedBox(width: MqSpacing.xs),
                Text('دفعات الأقساط',
                    style: context.text.labelMedium?.copyWith(color: mq.ink2)),
              ],
            ),
            const SizedBox(height: MqSpacing.sm),
            for (final r in _installmentPlan)
              Padding(
                padding: const EdgeInsets.only(bottom: MqSpacing.xs),
                child: _InstallmentRow(
                  number: r.number,
                  amount: '${_fmt(r.amount)} د.ع',
                  due: _iso.format(r.due),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context) {
    final mq = context.mq;
    final disabled = _submitting || _courses.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        border: Border(top: BorderSide(color: mq.line)),
      ),
      child: MqButton(
        label: _submitting
            ? 'جارٍ الحفظ…'
            : (_isEdit ? 'حفظ التعديلات' : 'إنشاء الفاتورة'),
        icon: _submitting ? null : Icons.check_rounded,
        loading: _submitting,
        onPressed: disabled ? null : _submit,
      ),
    );
  }

  String _fmt(num n) =>
      NumberFormat.decimalPattern('en').format(n.round());
}

/// Read-only date field that opens a date picker on tap (design-system styled
/// via the active [InputDecorationTheme]).
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    return InkWell(
      onTap: onTap,
      borderRadius: MqRadius.brMd,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(
          value == null ? (hint ?? 'اختر') : fmt.format(value!),
          style: context.text.bodyMedium?.copyWith(
              color: value == null ? context.mq.ink3 : context.mq.ink),
        ),
      ),
    );
  }
}

/// One installment line: number badge + amount + due date (read-only preview
/// of the exact rows sent to the server).
class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.number,
    required this.amount,
    required this.due,
  });

  final int number;
  final String amount, due;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: mq.accentSoft,
            shape: BoxShape.circle,
            border: Border.all(color: mq.accentLine),
          ),
          child: Text('$number',
              style: MqTypography.mono(
                  color: mq.accent, size: 11, weight: FontWeight.w700)),
        ),
        const SizedBox(width: MqSpacing.sm),
        Expanded(
          child: Text(due,
              style: context.text.bodySmall?.copyWith(color: mq.ink2)),
        ),
        Text(amount,
            style: MqTypography.mono(
                color: mq.ink, size: 13, weight: FontWeight.w700)),
      ],
    );
  }
}
