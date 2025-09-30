import 'package:dirasiq/features/courses/widgets/suggested_courses_widget.dart';
import 'package:flutter/material.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/features/home/widgets/news_carousel.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _refreshToken = 0; // لتمريره للويدجتس لإعادة التحميل
  // مفتاح لإجبار إعادة بناء عناصر الصفحة بشكل كامل عند السحب للتحديث
  Key _refreshKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Unread notifications are handled by GlobalAppBar
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(title: "الرئيسية - درس عراق"),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: KeyedSubtree(
          key: _refreshKey,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.background, AppColors.surfaceVariant],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  NewsCarousel(refreshToken: _refreshToken),

                  SuggestedCoursesCompact(),

                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      elevation: 1.5,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(.1),
                          child: Icon(Icons.school, color: AppColors.primary),
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
