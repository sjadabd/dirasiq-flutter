// Student → "My Teachers" (معلّموني) — the teachers linked to the student
// through their course enrollments. MulhimIQ design-system page.
//
// Backed by existing endpoints only (no backend change):
//   • ApiService.fetchStudentEnrollments() → enrollments, grouped by teacher
//   • ChatApiService.openPrivate(teacherId) → open/reuse 1:1 chat (existing)
//
// Standalone pushed route (own Scaffold + back AppBar). The MyTeacher model is
// reused from the Student Home data layer so grouping stays consistent.
//
// NOTE on filters: enrollments are in-person course bookings and carry no
// course-type field, so حضوري/مرئي can't be distinguished from this data and
// are intentionally omitted. الكل / نشط / منتهي are derived from booking status.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/features/student/chat/screens/student_conversation_screen.dart';
import 'package:mulhimiq/features/student_home/data/models/student_home_data.dart'
    show MyTeacher, TeacherCourseRef, resolveAssetUrl;
import 'package:mulhimiq/features/teacher/chat/services/chat_api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

enum _Filter { all, active, ended }

class MyTeachersScreen extends StatefulWidget {
  const MyTeachersScreen({super.key});

  @override
  State<MyTeachersScreen> createState() => _MyTeachersScreenState();
}

class _MyTeachersScreenState extends State<MyTeachersScreen> {
  final _api = ApiService();
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<MyTeacher> _teachers = const [];
  _Filter _filter = _Filter.all;
  String _query = '';

  String? _myUserId;
  String? _chatBusyId;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _fetch();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
  }

  @override
  void dispose() {
    _search.dispose();
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

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchStudentEnrollments(limit: 100);
      final data = res['data'];
      final list = data is List
          ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _teachers = _group(list);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذّر تحميل معلّميك';
        _loading = false;
      });
    }
  }

  List<MyTeacher> _group(List<Map<String, dynamic>> enrollments) {
    final groups = <String, MyTeacher>{};
    for (final e in enrollments) {
      final t = e['teacher'] is Map ? Map<String, dynamic>.from(e['teacher']) : <String, dynamic>{};
      final id = t['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final c = e['course'] is Map ? Map<String, dynamic>.from(e['course']) : <String, dynamic>{};
      groups.putIfAbsent(
        id,
        () => MyTeacher(
          id: id,
          name: (t['name'] ?? '').toString(),
          imageUrl: resolveAssetUrl(t['profileImagePath'] ?? t['profile_image_path'] ?? t['avatar']),
          courses: [],
        ),
      );
      groups[id]!.courses.add(TeacherCourseRef(
        id: (c['id'] ?? '').toString(),
        name: (c['name'] ?? '').toString(),
        bookingId: (e['bookingId'] ?? e['booking_id'] ?? '').toString(),
        status: (e['status'] ?? '').toString(),
      ));
    }
    return groups.values.toList();
  }

  // ── filtering ─────────────────────────────────────────────────────────────

  List<MyTeacher> get _filtered {
    final q = _query.toLowerCase();
    return _teachers.where((t) {
      if (_filter == _Filter.active && !t.isActive) return false;
      if (_filter == _Filter.ended && t.isActive) return false;
      if (q.isEmpty) return true;
      final inName = t.name.toLowerCase().contains(q);
      final inCourse = t.courses.any((c) => c.name.toLowerCase().contains(q));
      return inName || inCourse;
    }).toList();
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void _openDetails(MyTeacher t) {
    if (t.id.isNotEmpty) Get.toNamed('/teacher-details', arguments: t.id);
  }

  Future<void> _openChat(MyTeacher t) async {
    if (_chatBusyId != null) return;

    var myId = _myUserId;
    if (myId == null || myId.isEmpty) {
      await _loadMe();
      myId = _myUserId;
    }
    if (myId == null || myId.isEmpty) {
      _snack('تعذّر التحقق من حسابك. يرجى تسجيل الدخول مجدداً.');
      return;
    }

    setState(() => _chatBusyId = t.id);
    try {
      final res = await ChatApiService.instance.openPrivate(t.id);
      final data = res['data'] is Map
          ? Map<String, dynamic>.from(res['data'])
          : Map<String, dynamic>.from(res);
      final conv = data['conversation'] is Map
          ? Map<String, dynamic>.from(data['conversation'])
          : data;
      final convId = (conv['id'] ??
              data['conversationId'] ??
              data['id'] ??
              data['_id'])
          ?.toString();
      if (convId == null || convId.isEmpty) {
        _snack('تم فتح المحادثة، لكن تعذّر قراءة بياناتها. حاول مرة أخرى.');
        return;
      }
      await Get.to(() => StudentConversationScreen(
            conversationId: convId,
            initialTitle: t.name.isEmpty ? 'المعلّم' : t.name,
            myUserId: myId!,
          ));
    } on ChatApiException catch (e) {
      _snack(_chatErrorMessage(e));
    } catch (_) {
      _snack('تعذّر الاتصال بخدمة المحادثات. تحقق من الإنترنت وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => _chatBusyId = null);
    }
  }

  String _chatErrorMessage(ChatApiException e) {
    if (e.statusCode == 401) {
      return 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مجدداً.';
    }
    if (e.statusCode == 403) {
      return 'المراسلة متاحة فقط للطلاب المرتبطين بدورة مع هذا الأستاذ.';
    }
    final msg = e.message.trim();
    if (msg.isNotEmpty && msg != 'فشل في معالجة الطلب') return msg;
    return 'لا يمكنك مراسلة هذا المعلّم حالياً.';
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

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
            appBar: AppBar(
              title: const Text('معلّموني'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: MqSpacing.sm),
                  child: Text('الأساتذة المرتبطون بدوراتك', style: context.text.bodySmall),
                ),
              ),
            ),
            body: Column(
              children: [
                _searchField(context),
                _filterRow(context),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return Container(
      color: context.mq.page,
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.sm),
      child: TextField(
        controller: _search,
        decoration: const InputDecoration(
          hintText: 'ابحث عن أستاذ أو دورة…',
          prefixIcon: Icon(Icons.search_rounded),
          isDense: true,
        ),
      ),
    );
  }

  Widget _filterRow(BuildContext context) {
    const items = [
      (_Filter.all, 'الكل'),
      (_Filter.active, 'نشط'),
      (_Filter.ended, 'منتهي'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: context.mq.page,
        border: Border(bottom: BorderSide(color: context.mq.line)),
      ),
      padding: const EdgeInsets.only(bottom: MqSpacing.sm),
      child: SizedBox(
        height: MqSize.chipHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.xs),
          itemBuilder: (_, i) {
            final (f, label) = items[i];
            return MqChip(label: label, selected: _filter == f, onTap: () => setState(() => _filter = f));
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return _skeleton();
    if (_error != null) return _error_(context);
    if (_teachers.isEmpty) return _empty(context, isSearch: false);

    final items = _filtered;
    if (items.isEmpty) return _empty(context, isSearch: true);

    final children = <Widget>[];
    void cards(List<MyTeacher> list) {
      for (final t in list) {
        children.add(Padding(padding: const EdgeInsets.only(bottom: MqSpacing.sm), child: _card(context, t)));
      }
    }

    if (_filter == _Filter.all) {
      final active = items.where((t) => t.isActive).toList();
      final ended = items.where((t) => !t.isActive).toList();
      if (active.isNotEmpty) {
        children.add(_groupHeader(context, 'أساتذة نشطون', active.length));
        cards(active);
      }
      if (ended.isNotEmpty) {
        if (active.isNotEmpty) children.add(const SizedBox(height: MqSpacing.sm));
        children.add(_groupHeader(context, 'أساتذة سابقون', ended.length));
        cards(ended);
      }
    } else {
      cards(items);
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl),
        children: children,
      ),
    );
  }

  Widget _groupHeader(BuildContext context, String title, int count) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.sm, top: MqSpacing.xs),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: mq.accent, borderRadius: MqRadius.brPill)),
          MqSpacing.gapSm,
          Text(title, style: context.text.titleSmall),
          MqSpacing.gapXs,
          MqBadge(label: '$count', tone: MqBadgeTone.neutral),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, MyTeacher t) {
    final mq = context.mq;
    final main = t.mainCourseName;
    final busy = _chatBusyId == t.id;

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  _Avatar(name: t.name, url: t.imageUrl),
                  if (t.isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13, height: 13,
                        decoration: BoxDecoration(
                          color: mq.success, shape: BoxShape.circle,
                          border: Border.all(color: mq.card, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.name.isEmpty ? 'المعلّم' : t.name,
                        style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (main.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(main, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              MqBadge(
                label: '${t.courses.length} دورات',
                tone: MqBadgeTone.accent,
                icon: Icons.menu_book_outlined,
              ),
            ],
          ),
          if (t.isActive) ...[
            MqSpacing.gapSm,
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: mq.success, shape: BoxShape.circle)),
                MqSpacing.gapXs,
                Text('نشط الآن', style: context.text.labelSmall?.copyWith(color: mq.success)),
              ],
            ),
          ],
          MqSpacing.gapMd,
          Row(
            children: [
              Expanded(
                child: MqButton(
                  label: 'عرض التفاصيل',
                  size: MqButtonSize.small,
                  onPressed: () => _openDetails(t),
                ),
              ),
              MqSpacing.gapSm,
              Expanded(
                child: MqButton.tonal(
                  label: 'مراسلة',
                  icon: Icons.chat_bubble_outline_rounded,
                  size: MqButtonSize.small,
                  loading: busy,
                  onPressed: () => _openChat(t),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── states ──────────────────────────────────────────────────────────────────

  Widget _empty(BuildContext context, {required bool isSearch}) {
    final mq = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(MqSpacing.lg),
                decoration: BoxDecoration(color: mq.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.cast_for_education_outlined, size: 44, color: mq.accent),
              ),
              MqSpacing.gapMd,
              Text(isSearch ? 'لا نتائج' : 'لا يوجد أساتذة بعد', style: context.text.titleMedium),
              MqSpacing.gapXs,
              Text(
                isSearch
                    ? 'جرّب كلمة بحث أخرى أو غيّر الفلتر.'
                    : 'سيظهر هنا أساتذتك بعد الانضمام إلى دوراتك.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _error_(BuildContext context) {
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
              Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
              MqSpacing.gapMd,
              MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _fetch),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return Builder(builder: (context) {
      final mq = context.mq;
      Widget bar(double w, double h) =>
          Container(width: w, height: h, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm));
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
        itemBuilder: (_, _) => MqCard(
          padding: const EdgeInsets.all(MqSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle)),
                  MqSpacing.gapMd,
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                      children: [bar(140, 12), const SizedBox(height: 8), bar(180, 10)])),
                ],
              ),
              MqSpacing.gapMd,
              bar(double.infinity, 36),
            ],
          ),
        ),
      );
    });
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.url});
  final String name;
  final String url;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final fallback = Container(
      color: mq.accentSoft,
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name.characters.first : '؟',
          style: context.text.titleMedium?.copyWith(color: mq.accent)),
    );
    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
        child: url.isEmpty ? fallback : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}
