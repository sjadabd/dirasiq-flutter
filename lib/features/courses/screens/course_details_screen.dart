// Student → Physical course details (MulhimIQ design-system pass).
//
// Standalone pushed route /course-details (arg: courseId). Backed by
// ApiService.fetchCourseDetails → GET /student/courses/:id. The booking /
// enrollment flow, the booking-status translation, and all navigation are
// UNCHANGED — only the presentation was restyled.
//
// The course object exposes: course_name, course_images, description,
// start_date, end_date, price, seats_count, study_year, subject{name},
// grade{name}, teacher{id,name,bio,experienceYears,distance}, bookingStatus,
// isSubscribed. The courses table has NO status, location/hall, or
// lecture-count columns, and the endpoint returns no schedule/sessions list
// and no teacher rating/photo — so those fields, the schedule section, and the
// teacher rating are intentionally not rendered (no fake data, no empty
// sections). All courses on this endpoint are in-person → a "حضوري" badge.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/features/course_hub/screens/course_hub_screen.dart';
import 'package:mulhimiq/features/teachers/screens/teacher_details_screen.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/app_network_image.dart';

class CourseDetailsScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailsScreen({super.key, required this.courseId});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  Map<String, dynamic>? course;
  bool isLoading = true;
  String? error;

  final _money = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
  }

  Future<void> _fetchCourseDetails() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      final api = ApiService();
      final result = await api.fetchCourseDetails(widget.courseId);
      setState(() {
        course = result['course'];
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        error = 'حدث خطأ في تحميل تفاصيل الدورة';
        isLoading = false;
      });
    }
  }

  // ─── booking logic (UNCHANGED) ──────────────────────────────────────────────

  String _translateBookingStatus(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'pre_approved':
        return 'موافقة أولية';
      case 'confirmed':
        return 'تم التأكيد';
      case 'approved':
        return 'مقبول نهائيًا';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  Future<void> _onEnrollPressed() async {
    final message = await _askMessage();
    if (message == null) return;
    try {
      final api = ApiService();
      await api.createCourseBooking(
        courseId: course?['id'] ?? widget.courseId,
        studentMessage: message,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الحجز بنجاح'), behavior: SnackBarBehavior.floating),
      );
      Navigator.pushNamed(context, '/bookings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<String?> _askMessage() async {
    final controller = TextEditingController();
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إرسال طلب حجز'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظة للمدرس (اختياري)',
            hintText: 'اكتب ملاحظة قصيرة...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              result = controller.text.isEmpty ? 'أرغب بالانضمام إلى هذا الكورس' : controller.text;
              Navigator.pop(ctx);
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    return result;
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  double _priceOf(Map<String, dynamic> c) => double.tryParse(c['price'].toString()) ?? 0;

  String _priceLabel(Map<String, dynamic> c) {
    final p = _priceOf(c);
    return p <= 0 ? 'مجاني' : '${_money.format(p)} د.ع';
  }

  String _fmtDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      return DateFormat('yyyy/MM/dd').format(DateTime.parse(date.toString()).toLocal());
    } catch (_) {
      return date.toString();
    }
  }

  String _imageUrl(Map<String, dynamic> c) {
    final imgs = c['course_images'] as List?;
    if (imgs != null && imgs.isNotEmpty) {
      final p = imgs.first.toString();
      return p.startsWith('http') ? p : '${AppConfig.serverBaseUrl}$p';
    }
    return '';
  }

  bool get _isEnrolled {
    final c = course;
    if (c == null) return false;
    return c['isSubscribed'] == true || c['bookingStatus'] == 'confirmed' || c['bookingStatus'] == 'approved';
  }

  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            body: RefreshIndicator(
              onRefresh: _fetchCourseDetails,
              child: isLoading
                  ? _skeleton(context)
                  : error != null
                      ? _errorView(context)
                      : course == null
                          ? _emptyView(context)
                          : _content(context, course!),
            ),
            bottomNavigationBar: course == null ? null : _bottomBar(context, course!),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> c) {
    final m = context.mq;
    final teacher = (c['teacher'] is Map) ? Map<String, dynamic>.from(c['teacher']) : <String, dynamic>{};
    final desc = (c['description'] ?? '').toString().trim();
    final startStr = _fmtDate(c['start_date']);
    final endStr = _fmtDate(c['end_date']);
    final seatsRaw = c['seats_count'];
    final seats = (seatsRaw is num) ? seatsRaw.toInt() : int.tryParse(seatsRaw?.toString() ?? '') ?? 0;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          stretch: true,
          backgroundColor: m.page,
          foregroundColor: m.ink,
          title: Text(c['course_name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(url: _imageUrl(c), fit: BoxFit.cover, fallbackIcon: Icons.school_rounded),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black38, Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                Positioned(
                  top: kToolbarHeight, right: MqSpacing.lg,
                  child: MqBadge(label: 'حضوري', tone: MqBadgeTone.accent, solid: true, icon: Icons.location_city_rounded),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroCard(context, c, teacher),
                MqSpacing.gapMd,
                _quickInfo(context, startStr, endStr, seats),
                MqSpacing.gapMd,
                _teacherSection(context, teacher),
                if (desc.isNotEmpty) ...[
                  MqSpacing.gapMd,
                  _descriptionCard(context, desc),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroCard(BuildContext context, Map<String, dynamic> c, Map<String, dynamic> teacher) {
    final m = context.mq;
    final subject = (c['subject'] is Map ? c['subject']['name'] : null)?.toString() ?? '';
    final grade = (c['grade'] is Map ? c['grade']['name'] : null)?.toString() ?? '';
    final studyYear = (c['study_year'] ?? '').toString();
    final teacherName = (teacher['name'] ?? '').toString();
    final isFree = _priceOf(c) <= 0;

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c['course_name']?.toString() ?? 'دورة', style: context.text.titleLarge),
          if (teacherName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 14, color: m.ink3),
              MqSpacing.gapXxs,
              Text(teacherName, style: context.text.bodySmall),
            ]),
          ],
          MqSpacing.gapSm,
          Wrap(spacing: MqSpacing.xs, runSpacing: MqSpacing.xs, children: [
            MqBadge(label: 'حضوري', tone: MqBadgeTone.accent, icon: Icons.location_city_rounded),
            if (subject.isNotEmpty) MqBadge(label: subject, tone: MqBadgeTone.neutral, icon: Icons.book_outlined),
            if (grade.isNotEmpty) MqBadge(label: grade, tone: MqBadgeTone.neutral, icon: Icons.school_outlined),
            if (studyYear.isNotEmpty) MqBadge(label: studyYear, tone: MqBadgeTone.neutral, icon: Icons.event_outlined),
          ]),
          MqSpacing.gapMd,
          MqSurface(
            tone: MqSurfaceTone.neutral,
            padding: const EdgeInsets.all(MqSpacing.sm),
            child: Row(children: [
              Icon(Icons.payments_rounded, size: MqSize.iconSm, color: isFree ? m.success : m.orange),
              MqSpacing.gapXs,
              Text(_priceLabel(c),
                  style: context.text.titleSmall?.copyWith(color: isFree ? m.success : m.orange, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _quickInfo(BuildContext context, String startStr, String endStr, int seats) {
    final m = context.mq;
    final cards = <Widget>[];
    if (startStr.isNotEmpty) {
      cards.add(_infoCard(context, Icons.play_circle_outline_rounded, 'تاريخ البدء', startStr, m.accent));
    }
    if (endStr.isNotEmpty) {
      cards.add(_infoCard(context, Icons.flag_outlined, 'تاريخ الانتهاء', endStr, m.orange));
    }
    if (seats > 0) {
      cards.add(_infoCard(context, Icons.event_seat_outlined, 'المقاعد', '$seats مقعد', m.success));
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    final spaced = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      if (i > 0) spaced.add(MqSpacing.gapSm);
      spaced.add(Expanded(child: cards[i]));
    }
    // Do not use CrossAxisAlignment.stretch here: this Row lives inside a
    // scrollable Column, so stretch gets infinite max height and breaks layout
    // (blank page + unbounded scroll).
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: spaced);
  }

  Widget _infoCard(BuildContext context, IconData icon, String label, String value, Color color) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: MqSize.iconMd),
          MqSpacing.gapXs,
          Text(value,
              style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _teacherSection(BuildContext context, Map<String, dynamic> t) {
    final m = context.mq;
    final teacherId = t['id']?.toString();
    final name = (t['name'] ?? 'غير معروف').toString();
    final bio = (t['bio'] ?? '').toString().trim();
    final exp = t['experienceYears'] ?? t['experience_years'];
    final expYears = (exp is num) ? exp.toInt() : int.tryParse(exp?.toString() ?? '') ?? 0;
    final distance = t['distance'];
    final distStr = distance is num ? '${distance.toStringAsFixed(1)} كم' : '';

    void openTeacher() {
      if (teacherId == null || teacherId.isEmpty) return;
      Get.to(() => TeacherDetailsScreen(teacherId: teacherId));
    }

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الأستاذ', style: context.text.titleSmall),
          MqSpacing.gapSm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.person_rounded, color: m.accent, size: 30),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(bio, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    if (expYears > 0 || distStr.isNotEmpty) ...[
                      MqSpacing.gapXs,
                      Wrap(spacing: MqSpacing.xs, runSpacing: MqSpacing.xxs, children: [
                        if (expYears > 0)
                          MqBadge(label: '$expYears سنوات خبرة', tone: MqBadgeTone.accent, icon: Icons.workspace_premium_outlined),
                        if (distStr.isNotEmpty)
                          MqBadge(label: distStr, tone: MqBadgeTone.neutral, icon: Icons.location_on_outlined),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (teacherId != null && teacherId.isNotEmpty) ...[
            MqSpacing.gapSm,
            Align(
              alignment: Alignment.centerLeft,
              child: MqButton(
                label: 'عرض الأستاذ',
                icon: Icons.arrow_back_rounded,
                size: MqButtonSize.small,
                variant: MqButtonVariant.tonal,
                expand: false,
                onPressed: openTeacher,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _descriptionCard(BuildContext context, String desc) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.menu_book_rounded, size: MqSize.iconSm, color: context.mq.accent),
            MqSpacing.gapXs,
            Text('وصف الدورة', style: context.text.titleSmall),
          ]),
          MqSpacing.gapSm,
          Text(desc, style: context.text.bodyMedium?.copyWith(height: 1.6)),
        ],
      ),
    );
  }

  // ─── bottom action bar (enrollment — logic preserved) ───────────────────────

  Widget _bottomBar(BuildContext context, Map<String, dynamic> c) {
    final m = context.mq;
    final bookingStatus = c['bookingStatus']?.toString();

    Widget child;
    if (_isEnrolled) {
      // Already enrolled → status line + open Course Hub.
      child = Row(children: [
        Icon(Icons.check_circle_rounded, color: m.success, size: MqSize.iconMd),
        MqSpacing.gapSm,
        Expanded(child: Text('أنت مسجل في هذه الدورة',
            style: context.text.titleSmall?.copyWith(color: m.success))),
        MqSpacing.gapSm,
        MqButton(
          label: 'بيئة الدورة',
          icon: Icons.dashboard_customize_outlined,
          size: MqButtonSize.small,
          expand: false,
          onPressed: () => Get.to(() => CourseHubScreen(
                courseId: (c['id'] ?? widget.courseId).toString(),
                courseName: c['course_name']?.toString(),
                teacherId: (c['teacher'] is Map ? c['teacher']['id'] : null)?.toString(),
              )),
        ),
      ]);
    } else if (bookingStatus != null && bookingStatus.isNotEmpty) {
      // A booking is in progress (pending / pre_approved / rejected / …).
      final (tone, color) = _statusTone(context, bookingStatus);
      child = Row(children: [
        Icon(Icons.info_outline_rounded, color: color, size: MqSize.iconMd),
        MqSpacing.gapSm,
        Expanded(child: Text('طلبك: ${_translateBookingStatus(bookingStatus)}', style: context.text.titleSmall)),
        MqBadge(label: _translateBookingStatus(bookingStatus), tone: tone),
      ]);
    } else {
      // Not enrolled, no request → enrollment CTA (preserved flow).
      child = MqButton(
        label: 'التسجيل في الدورة • ${_priceLabel(c)}',
        icon: Icons.school_outlined,
        onPressed: _onEnrollPressed,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: m.card,
        border: Border(top: BorderSide(color: m.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(MqSpacing.md),
          child: child,
        ),
      ),
    );
  }

  (MqBadgeTone, Color) _statusTone(BuildContext context, String s) {
    final m = context.mq;
    return switch (s) {
      'confirmed' || 'approved' => (MqBadgeTone.success, m.success),
      'pre_approved' => (MqBadgeTone.accent, m.accent),
      'rejected' || 'cancelled' => (MqBadgeTone.error, m.error),
      _ => (MqBadgeTone.orange, m.orange),
    };
  }

  // ─── states ─────────────────────────────────────────────────────────────────

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
          MqSpacing.gapMd,
          Text(error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _fetchCourseDetails),
        ])),
      ],
    );
  }

  Widget _emptyView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxxl),
        Center(child: Column(children: [
          Icon(Icons.school_outlined, size: 44, color: m.ink3),
          MqSpacing.gapMd,
          Text('الدورة غير متاحة حالياً', style: context.text.bodyMedium),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    Widget block(double h) => Container(height: h, decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brLg));
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Container(height: 240, color: m.fill2),
        Padding(
          padding: const EdgeInsets.all(MqSpacing.lg),
          child: Column(children: [
            block(120),
            MqSpacing.gapMd,
            Row(children: [Expanded(child: block(72)), MqSpacing.gapSm, Expanded(child: block(72)), MqSpacing.gapSm, Expanded(child: block(72))]),
            MqSpacing.gapMd,
            block(110),
          ]),
        ),
      ],
    );
  }
}
