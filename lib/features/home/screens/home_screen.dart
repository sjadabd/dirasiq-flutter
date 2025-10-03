import 'package:flutter/material.dart';
import 'package:dirasiq/features/home/widgets/news_carousel.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:get/get.dart';
import 'package:dirasiq/features/teachers/screens/suggested_teachers_screen.dart';
import 'package:dirasiq/core/services/api_service.dart';

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
            color: Colors.black.withOpacity(0.06),
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
          // Track
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
                color: foreground.withOpacity(0.9),
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
  int _refreshToken = 0; // لتمريره للويدجتس لإعادة التحميل
  // مفتاح لإجبار إعادة بناء عناصر الصفحة بشكل كامل عند السحب للتحديث
  Key _refreshKey = UniqueKey();
  double? _progressPercent; // 0..100 من الخادم
  double? _attendancePercent; // 0..100 من الخادم
  bool _loadingOverview = false;
  String? _overviewError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Unread notifications are handled by GlobalAppBar
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
      _refreshToken++; // لإعادة تحميل الأبناء مثل NewsCarousel
      _refreshKey = UniqueKey(); // إجبار إعادة بناء كامل للواجهة
    });
    await _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loadingOverview = true;
      _overviewError = null;
    });
    try {
      final data = await ApiService().fetchStudentDashboardOverview();
      final prog = (data['progressPercent'] ?? data['progress'] ?? 0)
          .toDouble();
      final att = (data['attendancePercent'] ?? data['attendance'] ?? 0)
          .toDouble();
      if (!mounted) return;
      setState(() {
        _progressPercent = prog;
        _attendancePercent = att;
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
      backgroundColor: cs.background,
      appBar: const GlobalAppBar(title: "الرئيسية - درس عراق"),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: KeyedSubtree(
          key: _refreshKey,
          child: Container(
            color: cs.background,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  NewsCarousel(refreshToken: _refreshToken),

                  // Compact suggestion tiles row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SuggestionTile(
                            color: const Color(0xFFBFE6FF), // أزرق فاتح
                            foregroundColor: const Color(0xFF1F2A37),
                            icon: Icons.menu_book_rounded,
                            title: 'الكورسات المقترحة',
                            onTap: () => Get.toNamed('/suggested-courses'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SuggestionTile(
                            color: const Color(0xFFCFEEDB), // أخضر نعناعي
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
                            color: const Color(0xFFFFD7B3), // برتقالي خوخي
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

                  const SizedBox(height: 12),
                  if (_loadingOverview)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: LinearProgressIndicator(),
                    ),
                  if (_overviewError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
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
                  // Two stat cards similar to the reference image
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 120, // 👈 ارتفاع ثابت
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
                            height: 120, // 👈 نفس الارتفاع
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
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      elevation: 1.5,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primary.withOpacity(.1),
                          child: Icon(Icons.school, color: cs.primary),
                        ),
                        title: const Text('دوراتي المسجّلة'),
                        subtitle: const Text(
                          'اعرض الدروس والمحاضرات والحضور لكل دورة',
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () {
                          Navigator.pushNamed(context, '/enrollments');
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const SizedBox(height: 20),
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
