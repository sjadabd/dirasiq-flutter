import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/features/search/screens/student_unified_search_screen.dart';
import 'package:mulhimiq/features/teachers/screens/my_teachers_screen.dart';
import 'package:mulhimiq/shared/controllers/global_controller.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/status_views.dart';

import '../../controller/student_home_controller.dart';
import '../../data/models/student_home_data.dart';
import '../widgets/academic_progress_card.dart';
import '../widgets/discovery_cards.dart';
import '../widgets/home_skeleton.dart';
import '../widgets/my_teachers_section.dart';
import '../widgets/news_section.dart';
import '../widgets/recommended_courses_section.dart';
import '../widgets/recommended_teachers_section.dart';
import '../widgets/sh_common.dart';
import '../widgets/sh_header.dart';
import '../widgets/upcoming_cards.dart';
import '../widgets/video_courses_section.dart';
import '../widgets/weekly_schedule_card.dart';
import '../widgets/welcome_hero_card.dart';

/// Student Home — the composed dashboard built from [Components.html] / the
/// MulhimIQ design system. Active students get a learning-focused layout;
/// brand-new students (no courses/teachers/schedule) get a discovery layout.
///
/// The screen self-applies [MqTheme] so the design system governs it even
/// before the app's global theme is migrated.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    this.embedded = false,
  });

  /// When true the screen renders only its themed RTL body — no [Scaffold],
  /// no [MqBottomNav], no outer [SafeArea] — so a host (e.g. RootShell) owns
  /// the app chrome and bottom navigation. Standalone (false) keeps all three.
  final bool embedded;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late final StudentHomeController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(StudentHomeController());
  }

  @override
  void dispose() {
    Get.delete<StudentHomeController>();
    super.dispose();
  }

  int get _unread =>
      Get.isRegistered<GlobalController>() ? Get.find<GlobalController>().unreadCount.value : 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => widget.embedded ? _body(context) : _scaffold(context),
        ),
      ),
    );
  }

  /// Themed body only — used when [StudentHomeScreen.embedded] is true. The
  /// host supplies the Scaffold, SafeArea, and bottom navigation.
  Widget _body(BuildContext context) {
    // When embedded, the host (RootShell) uses SafeArea(top: false) and this
    // screen has no AppBar — so fold the status-bar / notch inset into the
    // scroll content padding (not a SafeArea/Scaffold). Standalone keeps 0:
    // its own SafeArea already covers the top.
    final topInset = widget.embedded ? MediaQuery.viewPaddingOf(context).top : 0.0;
    return Obx(() {
      // Observe the 30s ticker so countdown labels (upcoming lecture/exam)
      // refresh without a manual reload.
      _c.tick.value;
      switch (_c.status.value) {
        case StudentHomeStatus.loading:
          return StudentHomeSkeleton(topInset: topInset);
        case StudentHomeStatus.error:
          return Padding(
            padding: EdgeInsets.only(top: topInset),
            child: StatusView.error(message: _c.errorMessage.value, onAction: _c.refreshAll),
          );
        case StudentHomeStatus.ready:
          return _Content(
            data: _c.data.value!,
            unread: _unread,
            onRefresh: _c.refreshAll,
            topInset: topInset,
          );
      }
    });
  }

  /// Standalone chrome — Scaffold + SafeArea + MqBottomNav.
  Widget _scaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mq.page,
      body: SafeArea(bottom: false, child: _body(context)),
      bottomNavigationBar: MqBottomNav(
        currentIndex: 0,
        items: const [
          MqNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'الرئيسية'),
          MqNavItem(icon: Icons.menu_book_outlined, label: 'الدورات'),
          MqNavItem(icon: Icons.chat_bubble_outline_rounded, label: 'المحادثة'),
          MqNavItem(icon: Icons.grid_view_outlined, label: 'المزيد'),
        ],
        onTap: _onNavTap,
      ),
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 1:
        Get.toNamed('/suggested-courses');
      case 2:
        Get.toNamed('/chat/conversations');
      case 3:
        Get.toNamed('/student-profile');
    }
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.data,
    required this.unread,
    required this.onRefresh,
    this.topInset = 0,
  });

  final StudentHomeData data;
  final int unread;
  final Future<void> Function() onRefresh;
  final double topInset;

  // ── navigation ──────────────────────────────────────────────────────────
  void _openCourse(String id) {
    if (id.isNotEmpty) Get.toNamed('/course-details', arguments: id);
  }

  void _openTeacher(String id) {
    if (id.isNotEmpty) Get.toNamed('/teacher-details', arguments: id);
  }

  void _openVideoCourse(String id) {
    if (id.isNotEmpty) Get.toNamed('/student/video-course-details', arguments: id);
  }

  void _openMyTeacher(MyTeacher t) {
    if (t.courses.length == 1 && t.courses.first.id.isNotEmpty) {
      Get.toNamed('/course-hub', arguments: {'courseId': t.courses.first.id, 'teacherId': t.id});
    } else {
      _openTeacher(t.id);
    }
  }

  int get _activeCourses => data.myTeachers.fold<int>(0, (sum, t) => sum + t.courses.length);

  @override
  Widget build(BuildContext context) {
    final header = ShHeader(
      unread: unread,
      onProfile: () => Get.toNamed('/student-profile'),
      onNotifications: () => Get.toNamed('/notifications'),
      onChat: () => Get.toNamed('/chat/conversations'),
      onSearch: () => Get.to(() => const StudentUnifiedSearchScreen()),
    );

    final hero = WelcomeHeroCard(
      profile: data.profile,
      streakDays: data.streakDays,
      weeklyProgress: data.progress?.overall,
      activeCourses: _activeCourses,
      onProfile: () => Get.toNamed('/student-profile'),
    );

    final sections = data.isNewStudent ? _newStudentSections(context) : _activeStudentSections(context);
    final mq = context.mq;

    return Column(
      children: [
        // Pinned header — stays fixed while the content below scrolls. Its
        // opaque page background (incl. the status-bar inset) hides content
        // sliding underneath; a hairline separates it from the scroll area.
        Container(
          decoration: BoxDecoration(
            color: mq.page,
            border: Border(bottom: BorderSide(color: mq.line)),
          ),
          padding: EdgeInsets.fromLTRB(
            MqSpacing.lg, MqSpacing.md + topInset, MqSpacing.lg, MqSpacing.md),
          child: header,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Bottom padding clears RootShell's NavigationBar so the last
              // card isn't tight against it.
              padding: const EdgeInsets.fromLTRB(
                  MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
              children: [
                hero,
                for (final s in sections) ...[const SizedBox(height: MqSpacing.xl), s],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Wraps a bento card/row with the design's section header.
  Widget _titled(String title, {String? subtitle, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShSectionHeader(title: title, subtitle: subtitle),
        child,
      ],
    );
  }

  /// Section priority for an active student.
  List<Widget> _activeStudentSections(BuildContext context) {
    final lecture = data.upcomingLecture;
    final exam = data.upcomingExam;

    return [
      // Upcoming lecture + exam (only the ones present).
      if (lecture != null || exam != null)
        _titled(
          'أحداثك القادمة',
          subtitle: 'محاضراتك واختباراتك القريبة',
          // Full-width stacked cards. A side-by-side Row squeezed each card to
          // half-width, wrapping the Arabic title vertically (one char/line).
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lecture != null)
                UpcomingLectureCard(
                  lecture: lecture,
                  onOpen: () => _openCourse(lecture.courseId ?? ''),
                  onEnded: onRefresh,
                ),
              if (lecture != null && exam != null)
                const SizedBox(height: MqSpacing.md),
              if (exam != null) UpcomingExamCard(exam: exam),
            ],
          ),
        ),

      if (data.hasProgress)
        _titled('تقدّمك الأكاديمي', subtitle: 'هذا الفصل الدراسي', child: AcademicProgressCard(progress: data.progress!)),

      if (data.hasWeeklySchedule)
        _titled('جدولك الأسبوعي', subtitle: 'دروسك في كل يوم', child: WeeklyScheduleCard(days: data.weeklySchedule)),

      if (data.myTeachers.isNotEmpty)
        MyTeachersSection(
          teachers: data.myTeachers,
          onOpen: _openMyTeacher,
          onMessage: (_) => Get.toNamed('/chat/conversations'),
          onSeeAll: () => Get.to(() => const MyTeachersScreen()),
        ),

      if (data.myVideoCourses.isNotEmpty)
        VideoCoursesSection(
          title: 'متابعة المشاهدة',
          subtitle: 'دوراتي المرئية',
          items: data.myVideoCourses,
          showProgress: true,
          onOpen: (v) => _openVideoCourse(v.id),
          actionLabel: 'الكل',
          onAction: () => Get.toNamed('/student/video-courses'),
        ),

      if (data.news.isNotEmpty) NewsSection(items: data.news, onOpen: (_) {}),

      if (data.recommendedTeachers.isNotEmpty)
        RecommendedTeachersSection(
          teachers: data.recommendedTeachers,
          onOpen: (t) => _openTeacher(t.id),
          onSeeAll: () => Get.toNamed('/suggested-teachers'),
        ),

      if (data.recommendedCourses.isNotEmpty)
        RecommendedCoursesSection(
          courses: data.recommendedCourses,
          onOpen: (c) => _openCourse(c.id),
          onSeeAll: () => Get.toNamed('/suggested-courses'),
        ),

      if (data.recommendedVideoCourses.isNotEmpty)
        VideoCoursesSection(
          title: 'دورات مرئية موصى بها',
          items: data.recommendedVideoCourses,
          onOpen: (v) => _openVideoCourse(v.id),
          actionLabel: 'الكل',
          onAction: () => Get.toNamed('/student/video-marketplace'),
        ),
    ];
  }

  /// Discovery-focused layout for brand-new students.
  List<Widget> _newStudentSections(BuildContext context) {
    return [
      StartLearningCard(onExplore: () => Get.toNamed('/suggested-courses')),
      ExploreSearchBar(onTap: () => Get.toNamed('/suggested-courses')),

      if (data.news.isNotEmpty) NewsSection(items: data.news, onOpen: (_) {}),

      if (data.recommendedTeachers.isNotEmpty)
        RecommendedTeachersSection(
          teachers: data.recommendedTeachers,
          onOpen: (t) => _openTeacher(t.id),
          onSeeAll: () => Get.toNamed('/suggested-teachers'),
        ),

      if (data.recommendedCourses.isNotEmpty)
        RecommendedCoursesSection(
          courses: data.recommendedCourses,
          onOpen: (c) => _openCourse(c.id),
          onSeeAll: () => Get.toNamed('/suggested-courses'),
        ),

      if (data.recommendedVideoCourses.isNotEmpty)
        VideoCoursesSection(
          title: 'دورات مرئية موصى بها',
          items: data.recommendedVideoCourses,
          onOpen: (v) => _openVideoCourse(v.id),
          actionLabel: 'الكل',
          onAction: () => Get.toNamed('/student/video-marketplace'),
        ),
    ];
  }
}
