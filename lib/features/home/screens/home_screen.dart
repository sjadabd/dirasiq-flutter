import 'package:mulhimiq/features/home/widgets/student_calendar.dart';
import 'package:flutter/material.dart';
import 'package:mulhimiq/features/home/widgets/news_carousel.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/features/teachers/screens/suggested_teachers_screen.dart';
import 'package:mulhimiq/core/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _StatCard extends StatelessWidget {
  final String title;
  final double percent; // 0..1
  final Color background;
  final Color foreground;
  final Color barColor;
  final Color trackColor;

  const _StatCard({
    required this.title,
    required this.percent,
    required this.background,
    required this.foreground,
    required this.barColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = percent.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth * pct;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: w,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${(pct * 100).round()}%",
              style: TextStyle(
                color: foreground.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _refreshToken = 0;
  Key _refreshKey = UniqueKey();
  double? _progressPercent;
  double? _attendancePercent;
  Map<String, dynamic>? _nextSession;
  Map<String, dynamic>? _nextExam;
  bool _loadingOverview = false;
  String? _overviewError;

  String _timeUntil(DateTime dateTime) {
    final now = DateTime.now();
    final diff = dateTime.difference(now);

    if (diff.inDays > 0) {
      return "متبقي ${diff.inDays} يوم";
    } else if (diff.inHours > 0) {
      return "متبقي ${diff.inHours} ساعة";
    } else if (diff.inMinutes > 0) {
      return "متبقي ${diff.inMinutes} دقيقة";
    } else {
      return "بدأ أو انتهى للتو";
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOverview();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() {
      _refreshToken++;
      _refreshKey = UniqueKey();
    });
    await _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loadingOverview = true;
      _overviewError = null;
    });
    try {
      final resp = await ApiService().fetchStudentDashboardOverview();
      // resp قد يكون هو نفسه data، أو قد يحتوي على المفتاح 'data'
      final Map<String, dynamic> data = (resp['data'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(resp['data'] as Map)
          : Map<String, dynamic>.from(resp);

      final prog = (data['progressPercent'] ?? 0).toDouble();
      final att = (data['attendancePercent'] ?? 0).toDouble();

      if (!mounted) return;
      setState(() {
        _progressPercent = prog;
        _attendancePercent = att;
        _nextSession = data['nextSession'];
        _nextExam = data['nextMonthlyExam'];
        _loadingOverview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _overviewError = e.toString();
        _loadingOverview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const GlobalAppBar(title: "الرئيسية - درس عراق"),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: KeyedSubtree(
          key: _refreshKey,
          child: Container(
            color: cs.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  NewsCarousel(refreshToken: _refreshToken),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "الاقتراحات",
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // صف الكورسات والمعلمين والأصدقاء
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SuggestionTile(
                            color: const Color(0xFFBFE6FF),
                            foregroundColor: const Color(0xFF1F2A37),
                            icon: Icons.menu_book_rounded,
                            title: 'الكورسات المقترحة',
                            onTap: () => Get.toNamed('/suggested-courses'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SuggestionTile(
                            color: const Color(0xFFCFEEDB),
                            foregroundColor: const Color(0xFF1F2A37),
                            icon: Icons.person_search_rounded,
                            title: 'المعلمين المقترحين',
                            onTap: () =>
                                Get.to(() => const SuggestedTeachersScreen()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SuggestionTile(
                            color: const Color(0xFFFFD7B3),
                            foregroundColor: const Color(0xFF1F2A37),
                            icon: Icons.group_add_rounded,
                            title: 'الأصدقاء المقترحين',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('سيضاف لاحقاً')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 5),
                  if (_loadingOverview)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.0),
                      child: LinearProgressIndicator(),
                    ),
                  if (_overviewError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 4,
                      ),
                      child: Text(
                        _overviewError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),

                  const SizedBox(height: 3),

                  // ===== كروت التقدم والحضور =====
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "التقدم والحضور",
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 100,
                            child: _StatCard(
                              title: 'التقدّم الدراسي',
                              percent: ((_progressPercent ?? 0) / 100).clamp(
                                0.0,
                                1.0,
                              ),
                              background: const Color(0xFF2F4B6D),
                              foreground: Colors.white,
                              barColor: const Color(0xFFA5DBE8),
                              trackColor: const Color(0x33FFFFFF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 100,
                            child: _StatCard(
                              title: 'نسبة الحضور',
                              percent: ((_attendancePercent ?? 0) / 100).clamp(
                                0.0,
                                1.0,
                              ),
                              background: const Color(0xFFCFEEDB),
                              foreground: const Color(0xFF1F2A37),
                              barColor: const Color(0xFF6B8F7E),
                              trackColor: const Color(0x33000000),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ===== أقرب محاضرة + أقرب امتحان =====
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "تذكيرات",
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: SizedBox(
                      height: 90, // 👈 ارتفاع ثابت للكروت
                      child: Row(
                        children: [
                          // ===== كارت المحاضرة =====
                          Expanded(
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.15),
                                  width: 1.2,
                                ),
                              ),
                              child: _nextSession != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'أقرب محاضرة : ${_nextSession?['courseName']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "المعلم: ${_nextSession!['teacher']['name']}",
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _timeUntil(
                                              DateTime.parse(
                                                _nextSession!['nextOccurrence'],
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.blueAccent,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Center(
                                      child: Text(
                                        "لا توجد محاضرات قادمة",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // ===== كارت الامتحان =====
                          Expanded(
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.15),
                                  width: 1.2,
                                ),
                              ),
                              child: _nextExam != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'أقرب امتحان : ${_nextExam?['courseName']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "المعلم: ${_nextExam!['teacher']['name']}",
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _timeUntil(
                                              DateTime.parse(
                                                _nextExam!['examDate'],
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.redAccent,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Center(
                                      child: Text(
                                        "لا توجد امتحانات قادمة",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, bottom: 3.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "المحاضرات",
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  StudentCalendar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final Color color;
  final Color? foregroundColor;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SuggestionTile({
    required this.color,
    this.foregroundColor,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg =
        foregroundColor ??
        (color.computeLuminance() > 0.5
            ? const Color(0xFF0F172A)
            : cs.onPrimaryContainer);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
