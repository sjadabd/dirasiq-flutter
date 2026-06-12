// Student → Teacher details / profile (MulhimIQ design-system pass).
//
// Opened from "My Teachers" (multi-course path) and from recommended teachers /
// search. Backed by existing endpoints — no backend change:
//   • fetchTeacherSubjectsCourses(teacherId) → teacher + subjects + courses
//   • fetchTeacherIntroVideo(teacherId)       → intro video
//   • ChatApiService.openPrivate(teacherId)   → open/reuse 1:1 chat (existing)
//
// Every field is probed defensively and only rendered when present (rating,
// verified, bio, grade, course type). Sections without data are hidden.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/features/student/chat/screens/student_conversation_screen.dart';
import 'package:mulhimiq/features/teacher/chat/services/chat_api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/unified_video_player/unified_video_player.dart';

class TeacherDetailsScreen extends StatefulWidget {
  final String teacherId;
  const TeacherDetailsScreen({super.key, required this.teacherId});

  @override
  State<TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends State<TeacherDetailsScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();
  final _coursesKey = GlobalKey();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _teacher;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _courses = [];

  // Intro video state
  Map<String, dynamic>? _introData;
  String? _contentBase;

  // Relationship aggregate (only when the student has a booking with this
  // teacher — backend returns 404 otherwise). Best-effort; null = hidden.
  Map<String, dynamic>? _aggregate;

  String? _myUserId;
  bool _chatLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _load();
    _loadIntro();
    _loadAggregate();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user');
      if (raw != null) {
        final u = jsonDecode(raw) as Map<String, dynamic>;
        _myUserId = (u['id'] ?? u['_id'])?.toString();
      }
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([_load(), _loadIntro(), _loadAggregate()]);
  }

  Future<void> _loadAggregate() async {
    try {
      final data = await _api.fetchTeacherAggregate(widget.teacherId);
      if (!mounted) return;
      setState(() => _aggregate = data);
    } catch (_) {
      // 404 (no relationship) or network — relationship sections stay hidden.
      if (mounted) setState(() => _aggregate = null);
    }
  }

  List<Map<String, dynamic>> _aggList(String key) {
    final raw = _aggregate?[key];
    return raw is List ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];
  }

  List<Map<String, dynamic>> get _activeCourses => _aggList('courses');
  List<Map<String, dynamic>> get _assignments => _aggList('assignments');
  List<Map<String, dynamic>> get _exams => _aggList('exams');
  List<Map<String, dynamic>> get _alerts => _aggList('alerts');
  bool get _hasRelationship => _aggregate != null;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchTeacherSubjectsCourses(widget.teacherId);
      setState(() {
        _teacher = Map<String, dynamic>.from(data['teacher'] ?? {});
        _subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
        _courses = List<Map<String, dynamic>>.from(data['courses'] ?? []);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadIntro() async {
    try {
      final res = await _api.fetchTeacherIntroVideo(widget.teacherId);
      final base = (res['content_url']?.toString() ?? '').replaceAll(RegExp(r"/+$"), '');
      if (!mounted) return;
      setState(() {
        _introData = Map<String, dynamic>.from(res['data'] ?? {});
        _contentBase = base.isEmpty ? AppConfig.serverBaseUrl : base;
      });
    } catch (_) {
      // Intro is optional — section hides on failure.
    }
  }

  String _absFromContent(String? p) {
    if (p == null || p.isEmpty) return '';
    final base = (_contentBase ?? AppConfig.serverBaseUrl).replaceAll(RegExp(r"/+$"), '');
    if (p.startsWith('http')) return p;
    return p.startsWith('/') ? '$base$p' : '$base/$p';
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // ── actions ─────────────────────────────────────────────────────────────────

  Future<void> _openChat() async {
    if (_chatLoading) return;
    if (_myUserId == null || _myUserId!.isEmpty) {
      _snack('تعذّر فتح المحادثة');
      return;
    }
    setState(() => _chatLoading = true);
    try {
      final res = await ChatApiService.instance.openPrivate(widget.teacherId);
      final data = res['data'] is Map ? Map<String, dynamic>.from(res['data']) : res;
      final convId = (data['id'] ?? data['conversationId'] ?? data['_id'])?.toString();
      if (convId == null || convId.isEmpty) {
        _snack('تعذّر فتح المحادثة');
        return;
      }
      await Get.to(() => StudentConversationScreen(
            conversationId: convId,
            initialTitle: _name.isEmpty ? 'المعلّم' : _name,
            myUserId: _myUserId!,
          ));
    } catch (_) {
      _snack('لا يمكنك مراسلة هذا المعلّم حالياً');
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  void _scrollToCourses() {
    final ctx = _coursesKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
    }
  }

  Future<void> _openOnMaps() async {
    final lat = _toDouble(_teacher?['latitude']);
    final lng = _toDouble(_teacher?['longitude']);
    if (lat == null || lng == null) return;
    final q = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    final app = Uri.parse('comgooglemaps://?q=$q');
    final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    try {
      if (await canLaunchUrl(app)) {
        await launchUrl(app, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(web, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      _snack('تعذر فتح الخرائط');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── derived ─────────────────────────────────────────────────────────────────

  String get _name => (_teacher?['name'] ?? _teacher?['full_name'] ?? '').toString().trim();
  String? get _photo {
    final p = (_teacher?['profileImagePath'] ?? _teacher?['profile_image_path'] ?? _teacher?['image'] ?? _teacher?['avatar'])?.toString();
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return p.startsWith('/') ? '$base$p' : '$base/$p';
  }

  String? get _specialization {
    final names = _subjects.map((s) => (s['name'] ?? '').toString().trim()).where((e) => e.isNotEmpty).toList();
    if (names.isNotEmpty) return names.take(3).join(' • ');
    final s = (_teacher?['specialization'] ?? _teacher?['bio'])?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  double? get _rating {
    final r = _teacher?['rating'] ?? _teacher?['avgRating'] ?? _teacher?['average_rating'];
    return r is num ? r.toDouble() : double.tryParse('${r ?? ''}');
  }

  bool get _verified =>
      _teacher?['isVerified'] == true || _teacher?['verified'] == true || _teacher?['is_verified'] == true;

  String? get _bio {
    final b = (_teacher?['bio'] ?? _teacher?['about'] ?? _teacher?['description'])?.toString().trim();
    return (b == null || b.isEmpty) ? null : b;
  }

  bool get _hasLocation => _toDouble(_teacher?['latitude']) != null && _toDouble(_teacher?['longitude']) != null;

  bool get _introReady => (_introData?['status']?.toString() == 'ready') &&
      (_introData?['manifestUrl']?.toString().isNotEmpty ?? false);

  // ── build ─────────────────────────────────────────────────────────────────

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
            appBar: AppBar(title: Text(_name.isEmpty ? 'تفاصيل المعلّم' : _name)),
            body: RefreshIndicator(
              onRefresh: _refreshAll,
              child: _loading && _teacher == null
                  ? _skeleton(context)
                  : (_error != null && _teacher == null)
                      ? _errorView(context)
                      : _content(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
      children: [
        _hero(context),
        MqSpacing.gapLg,
        _quickActions(context),
        if (_bio != null) ...[
          MqSpacing.gapLg,
          _sectionTitle(context, 'نبذة', Icons.info_outline_rounded),
          MqSpacing.gapSm,
          MqCard(child: Text(_bio!, style: context.text.bodyMedium?.copyWith(height: 1.5))),
        ],
        if (_subjects.isNotEmpty) ...[
          MqSpacing.gapLg,
          _sectionTitle(context, 'التخصص', Icons.workspace_premium_outlined),
          MqSpacing.gapSm,
          Wrap(
            spacing: MqSpacing.xs,
            runSpacing: MqSpacing.xs,
            children: [for (final s in _subjects) MqChip(label: (s['name'] ?? '').toString())],
          ),
        ],
        if (_introReady) ...[
          MqSpacing.gapLg,
          _sectionTitle(context, 'الفيديو التعريفي', Icons.play_circle_outline_rounded),
          MqSpacing.gapSm,
          _introCard(context),
        ],
        // Active courses with this teacher (relationship aggregate) when the
        // student is enrolled; otherwise the teacher's offered courses.
        MqSpacing.gapLg,
        KeyedSubtree(
          key: _coursesKey,
          child: _sectionTitle(
            context,
            _hasRelationship ? 'الدورات النشطة مع هذا الأستاذ' : 'الدورات',
            Icons.menu_book_rounded,
            count: _hasRelationship ? _activeCourses.length : _courses.length,
          ),
        ),
        MqSpacing.gapSm,
        if (_hasRelationship)
          if (_activeCourses.isEmpty)
            _emptyHint(context, 'لا توجد دورات نشطة مع هذا الأستاذ')
          else
            for (final c in _activeCourses)
              Padding(padding: const EdgeInsets.only(bottom: MqSpacing.sm), child: _activeCourseCard(context, c))
        else if (_courses.isEmpty)
          _emptyHint(context, 'لا توجد دورات حالياً')
        else
          for (final c in _courses)
            Padding(padding: const EdgeInsets.only(bottom: MqSpacing.sm), child: _courseCard(context, c)),

        if (_assignments.isNotEmpty) ...[
          MqSpacing.gapLg,
          _sectionTitle(context, 'الواجبات من هذا الأستاذ', Icons.edit_note_outlined, count: _assignments.length),
          MqSpacing.gapSm,
          for (final a in _assignments.take(6))
            Padding(padding: const EdgeInsets.only(bottom: MqSpacing.sm), child: _assignmentCard(context, a)),
        ],

        if (_exams.isNotEmpty) ...[
          MqSpacing.gapLg,
          _sectionTitle(context, 'الامتحانات من هذا الأستاذ', Icons.quiz_outlined, count: _exams.length),
          MqSpacing.gapSm,
          for (final e in _exams.take(6))
            Padding(padding: const EdgeInsets.only(bottom: MqSpacing.sm), child: _examCard(context, e)),
        ],

        if (_alerts.isNotEmpty) ...[
          MqSpacing.gapLg,
          _sectionTitle(context, 'إعلانات الأستاذ', Icons.campaign_outlined, count: _alerts.length),
          MqSpacing.gapSm,
          for (final al in _alerts.take(6))
            Padding(padding: const EdgeInsets.only(bottom: MqSpacing.sm), child: _alertCard(context, al)),
        ],
      ],
    );
  }

  Widget _emptyHint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: MqSpacing.lg),
        child: Center(child: Text(text, style: context.text.bodySmall)),
      );

  Widget _activeCourseCard(BuildContext context, Map<String, dynamic> c) {
    final mq = context.mq;
    final name = (c['name'] ?? c['course_name'] ?? c['title'] ?? '').toString();
    final stage = (c['gradeName'] ?? c['grade_name'] ?? c['grade'])?.toString();
    final type = _courseType(c);
    final progressRaw = c['progressPercent'] ?? c['attendancePercent'] ?? c['progress'];
    final progress = progressRaw is num ? progressRaw.toDouble() : double.tryParse('${progressRaw ?? ''}');
    final nextRaw = c['nextLecture'] ?? c['nextOccurrence'] ?? c['next_lecture'];
    final next = nextRaw == null ? null : DateTime.tryParse(nextRaw.toString());
    final id = (c['id'] ?? '').toString();

    return MqCard(
      onTap: id.isEmpty ? null : () => Get.toNamed('/course-details', arguments: id),
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
                child: Icon(Icons.menu_book_rounded, color: mq.accent, size: MqSize.iconMd),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name.isEmpty ? 'دورة' : name,
                        style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (type != null || (stage != null && stage.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: MqSpacing.xs, children: [
                        if (type != null) MqBadge(label: type, tone: MqBadgeTone.accent),
                        if (stage != null && stage.isNotEmpty) MqBadge(label: stage, tone: MqBadgeTone.neutral),
                      ]),
                    ],
                  ],
                ),
              ),
              if (id.isNotEmpty) Icon(Icons.chevron_left_rounded, color: mq.ink3),
            ],
          ),
          if (progress != null) ...[
            MqSpacing.gapSm,
            MqLinearProgress(value: (progress / 100).clamp(0, 1), height: 6, showLabel: true),
          ],
          if (next != null) ...[
            MqSpacing.gapSm,
            Row(children: [
              Icon(Icons.event_outlined, size: 13, color: mq.ink3),
              MqSpacing.gapXxs,
              Text('المحاضرة القادمة: ${DateFormat('dd/MM • HH:mm').format(next.toLocal())}',
                  style: context.text.labelSmall),
            ]),
          ],
          MqSpacing.gapSm,
          MqButton(label: 'عرض تفاصيل الدورة', size: MqButtonSize.small,
              onPressed: id.isEmpty ? null : () => Get.toNamed('/course-details', arguments: id)),
        ],
      ),
    );
  }

  Widget _assignmentCard(BuildContext context, Map<String, dynamic> a) {
    final mq = context.mq;
    final title = (a['title'] ?? 'واجب').toString();
    final due = a['dueDate'] ?? a['due_date'];
    final dueStr = due == null ? null : (DateTime.tryParse(due.toString()) != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(due.toString()).toLocal())
        : due.toString());
    final st = _subStatus((a['submissionStatus'] ?? a['status'] ?? 'pending').toString());
    return _infoRow(context, Icons.edit_note_outlined, mq.accent, title,
        dueStr == null ? null : 'موعد التسليم: $dueStr', st);
  }

  Widget _examCard(BuildContext context, Map<String, dynamic> e) {
    final mq = context.mq;
    final type = (e['examType'] ?? e['type'] ?? '').toString();
    final title = type == 'monthly' ? 'امتحان شهري' : (type == 'daily' ? 'امتحان يومي' : 'امتحان');
    final date = e['examDate'] ?? e['exam_date'] ?? e['date'];
    final dateStr = date == null ? null : (DateTime.tryParse(date.toString()) != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(date.toString()).toLocal())
        : date.toString());
    return _infoRow(context, Icons.quiz_outlined, mq.orange, title,
        dateStr == null ? null : 'التاريخ: $dateStr', null);
  }

  Widget _alertCard(BuildContext context, Map<String, dynamic> al) {
    final mq = context.mq;
    final title = (al['title'] ?? al['message'] ?? al['body'] ?? al['text'] ?? 'إعلان').toString();
    final sub = (al['message'] ?? al['body'] ?? al['description'])?.toString();
    return _infoRow(context, Icons.campaign_outlined, mq.orangeDeep, title,
        (sub != null && sub != title) ? sub : null, null);
  }

  Widget _infoRow(BuildContext context, IconData icon, Color color, String title, String? subtitle,
      ({String label, MqBadgeTone tone})? status) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
            child: Icon(icon, color: color, size: MqSize.iconSm),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (status != null) MqBadge(label: status.label, tone: status.tone),
        ],
      ),
    );
  }

  ({String label, MqBadgeTone tone}) _subStatus(String s) {
    switch (s) {
      case 'submitted':
        return (label: 'مُسلَّم', tone: MqBadgeTone.success);
      case 'graded':
        return (label: 'مُصحَّح', tone: MqBadgeTone.accent);
      case 'late':
        return (label: 'متأخر', tone: MqBadgeTone.error);
      case 'returned':
        return (label: 'مُعاد', tone: MqBadgeTone.orange);
      default:
        return (label: 'بانتظارك', tone: MqBadgeTone.orange);
    }
  }

  Widget _hero(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [mq.accent, mq.accentDeep],
        ),
        borderRadius: MqRadius.brXl,
        boxShadow: [BoxShadow(color: mq.accentShadow, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: _photo == null
                    ? Container(color: Colors.white.withValues(alpha: 0.18), alignment: Alignment.center,
                        child: Text(_name.isNotEmpty ? _name.characters.first : '؟',
                            style: context.text.titleLarge?.copyWith(color: Colors.white)))
                    : Image.network(_photo!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: Colors.white.withValues(alpha: 0.18),
                            alignment: Alignment.center,
                            child: Icon(Icons.person, color: Colors.white))),
              ),
            ),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_name.isEmpty ? 'المعلّم' : _name,
                          style: context.text.titleLarge?.copyWith(color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (_verified) ...[
                      MqSpacing.gapXs,
                      Icon(Icons.verified_rounded, size: 18, color: Colors.white),
                    ],
                  ],
                ),
                if (_specialization != null) ...[
                  const SizedBox(height: 4),
                  Text(_specialization!,
                      style: context.text.bodySmall?.copyWith(color: Colors.white70),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (_rating != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: MqRadius.brPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: mq.orange),
                        const SizedBox(width: 4),
                        Text(_rating!.toStringAsFixed(1),
                            style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MqButton(
            label: 'مراسلة',
            icon: Icons.chat_bubble_outline_rounded,
            loading: _chatLoading,
            onPressed: _openChat,
          ),
        ),
        MqSpacing.gapSm,
        Expanded(
          child: MqButton.tonal(
            label: 'الدورات',
            icon: Icons.menu_book_outlined,
            onPressed: _scrollToCourses,
          ),
        ),
        if (_hasLocation) ...[
          MqSpacing.gapSm,
          _IconAction(icon: Icons.map_outlined, onTap: _openOnMaps),
        ],
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon, {int? count}) {
    final mq = context.mq;
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: mq.accent, borderRadius: MqRadius.brPill)),
        MqSpacing.gapSm,
        Icon(icon, size: MqSize.iconSm, color: mq.ink3),
        MqSpacing.gapXs,
        Text(title, style: context.text.titleSmall),
        if (count != null && count > 0) ...[
          MqSpacing.gapXs,
          MqBadge(label: '$count', tone: MqBadgeTone.neutral),
        ],
      ],
    );
  }

  Widget _introCard(BuildContext context) {
    final manifest = _absFromContent(_introData?['manifestUrl']?.toString());
    final thumb = _introData?['thumbnailUrl']?.toString();
    return MqCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: MqRadius.brLg,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: UnifiedVideoPlayer(
            videoUrl: manifest,
            videoId: 'teacher-intro:${widget.teacherId}',
            thumbnailUrl: thumb == null || thumb.isEmpty ? null : _absFromContent(thumb),
            autoPlay: false,
          ),
        ),
      ),
    );
  }

  Widget _courseCard(BuildContext context, Map<String, dynamic> c) {
    final mq = context.mq;
    final name = (c['course_name'] ?? c['courseName'] ?? c['name'] ?? '').toString();
    final images = c['course_images'] is List ? (c['course_images'] as List) : const [];
    final imgRaw = images.isNotEmpty ? images.first?.toString() : null;
    final img = (imgRaw == null || imgRaw.isEmpty)
        ? null
        : (imgRaw.startsWith('http') ? imgRaw : '${AppConfig.serverBaseUrl}$imgRaw');
    final subject = c['subject'] is Map ? (c['subject']['name'] ?? '').toString() : (c['subject_name'] ?? '').toString();
    final grade = (c['gradeName'] ?? c['grade_name'] ?? c['grade'])?.toString();
    final price = c['price'];
    final priceStr = price == null ? null : '${NumberFormat('#,###').format(_toDouble(price) ?? 0)} د.ع';
    final type = _courseType(c);
    final id = (c['id'] ?? '').toString();

    return MqCard(
      onTap: id.isEmpty ? null : () => Get.toNamed('/course-details', arguments: id),
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: MqRadius.brMd,
            child: SizedBox(
              width: 56, height: 56,
              child: img == null
                  ? Container(color: mq.fill2, child: Icon(Icons.menu_book_rounded, color: mq.ink3))
                  : Image.network(img, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: mq.fill2, child: Icon(Icons.menu_book_rounded, color: mq.ink3))),
            ),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subject.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subject, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                MqSpacing.gapXs,
                Wrap(
                  spacing: MqSpacing.xs,
                  runSpacing: MqSpacing.xxs,
                  children: [
                    if (type != null) MqBadge(label: type, tone: MqBadgeTone.accent),
                    if (grade != null && grade.isNotEmpty) MqBadge(label: grade, tone: MqBadgeTone.neutral),
                    if (priceStr != null) MqBadge(label: priceStr, tone: MqBadgeTone.orange),
                  ],
                ),
              ],
            ),
          ),
          if (id.isNotEmpty) Icon(Icons.chevron_left_rounded, color: mq.ink3),
        ],
      ),
    );
  }

  String? _courseType(Map<String, dynamic> c) {
    final raw = (c['courseType'] ?? c['course_type'] ?? c['type'] ?? c['delivery'])?.toString().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('video') || raw.contains('مرئي')) return 'مرئي';
    if (raw.contains('live') || raw.contains('مباشر')) return 'مباشر';
    return 'حضوري';
  }

  // ── states ──────────────────────────────────────────────────────────────────

  Widget _errorView(BuildContext context) {
    final mq = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 44, color: mq.error),
              MqSpacing.gapMd,
              Text('تعذّر تحميل بيانات المعلّم', style: context.text.titleMedium, textAlign: TextAlign.center),
              MqSpacing.gapMd,
              MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _load),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final mq = context.mq;
    Widget bar(double w, double h) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm));
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        Container(height: 96, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brXl)),
        MqSpacing.gapLg,
        Row(children: [Expanded(child: bar(0, 48)), MqSpacing.gapSm, Expanded(child: bar(0, 48))]),
        MqSpacing.gapLg,
        bar(140, 16),
        MqSpacing.gapMd,
        for (var i = 0; i < 3; i++) ...[
          MqCard(
            padding: const EdgeInsets.all(MqSpacing.md),
            child: Row(
              children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brMd)),
                MqSpacing.gapMd,
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                    children: [bar(140, 12), const SizedBox(height: 8), bar(200, 10)])),
              ],
            ),
          ),
          const SizedBox(height: MqSpacing.sm),
        ],
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.fill,
      shape: RoundedRectangleBorder(borderRadius: MqRadius.brMd, side: BorderSide(color: mq.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MqSpacing.md),
          child: Icon(icon, color: mq.ink2, size: MqSize.iconMd),
        ),
      ),
    );
  }
}
