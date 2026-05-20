import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/themes/app_colors.dart';

/// First-launch onboarding for students (and the parents helping them set up).
///
/// 6 feature-intro pages. The student moves Next/Next/Next until "ابدأ الآن"
/// on the last page — that sets the seen flag and goes to /login.
/// Skip is also available from the top bar on every page.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const String onboardingFlag = 'has_seen_onboarding_2026_v2';

  final _ctrl = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    _Slide(
      icon: Icons.waving_hand_outlined,
      gradient: [Color(0xFF0B2545), Color(0xFF163E72)],
      title: 'أهلاً بك في ملهم IQ',
      subtitle: 'منصّتك التعليمية الذكية',
      points: [
        'كل ما تحتاجه من معلمك في مكان واحد',
        'تجربة بسيطة لك ولوالديك',
        'متابعة يومية لتقدّمك الدراسي',
      ],
    ),
    _Slide(
      icon: Icons.school_outlined,
      gradient: [Color(0xFF3FA9F5), Color(0xFF1976D2)],
      title: 'كورساتك ومعلموك',
      subtitle: 'تعلّم مع أفضل المعلمين',
      points: [
        'تصفّح الكورسات المقترحة لمرحلتك',
        'تابع معلمك مباشرة من تطبيقك',
        'اشترك بنقرة واحدة عند موافقة المعلم',
      ],
    ),
    _Slide(
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
      title: 'جدولك الأسبوعي',
      subtitle: 'لن تنسى موعد درس مرة أخرى',
      points: [
        'جدول مرتّب يعرض جلسات الأسبوع',
        'تنبيه قبل بداية كل درس',
        'تسجيل حضور بمسح QR من الصف',
      ],
    ),
    _Slide(
      icon: Icons.star_outline,
      gradient: [Color(0xFFFF8A00), Color(0xFFEF6C00)],
      title: 'تقدّمك الدراسي',
      subtitle: 'كل تقييم وكل علامة في صفحتك',
      points: [
        'تقييم معلمك اليومي على 6 محاور',
        'علامات الواجبات والامتحانات',
        'تتبّع حضورك وتقدّمك بسهولة',
      ],
    ),
    _Slide(
      icon: Icons.notifications_active_outlined,
      gradient: [Color(0xFF9333EA), Color(0xFF7C3AED)],
      title: 'إشعارات وواجبات',
      subtitle: 'ابقَ على تواصل دائم مع معلمك',
      points: [
        'إشعار فوري عند نشر واجب أو امتحان',
        'تذكير قبل موعد التسليم',
        'رسائل ومرفقات مباشرة من معلمك',
      ],
    ),
    _Slide(
      icon: Icons.receipt_long_outlined,
      gradient: [Color(0xFFE53935), Color(0xFFC62828)],
      title: 'فواتيرك ومدفوعاتك',
      subtitle: 'كل شيء واضح لك ولوالديك',
      points: [
        'فواتير الكورسات والأقساط بسهولة',
        'حالة الدفع: مدفوع / متبقّي / متأخّر',
        'إيصالات مباشرة عند كل دفعة',
      ],
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingFlag, true);
    // Mark the legacy v1 flag too so the splash doesn't try to re-show it.
    await prefs.setBool('has_seen_onboarding_2025_v1', true);
    if (!mounted) return;
    Get.offAllNamed('/login');
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_index > 0) {
      _ctrl.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                if (_index > 0)
                  IconButton(onPressed: _prev, icon: const Icon(Icons.arrow_forward_ios, size: 18), tooltip: 'السابق')
                else
                  const SizedBox(width: 48),
                const Spacer(),
                if (!isLast)
                  TextButton(onPressed: _finish, child: const Text('تخطّي', style: TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (ctx, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 8,
                    width: i == _index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.primary : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: AppColors.primary,
                  ),
                  icon: Icon(isLast ? Icons.rocket_launch_outlined : Icons.arrow_back, size: 20),
                  label: Text(isLast ? 'ابدأ الآن' : 'التالي',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.icon, required this.gradient, required this.title, required this.subtitle, required this.points});
  final IconData icon;
  final List<Color> gradient;
  final String title, subtitle;
  final List<String> points;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: slide.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: slide.gradient.first.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Positioned(top: -30, left: -30, child: Container(width: 120, height: 120,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle))),
                Positioned(bottom: -40, right: -20, child: Container(width: 160, height: 160,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle))),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(slide.icon, size: 80, color: Colors.white),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 32),
          Text(slide.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(slide.subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ...slide.points.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: slide.gradient.first.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.check, size: 14, color: slide.gradient.first),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(p, style: const TextStyle(fontSize: 14, height: 1.4))),
            ]),
          )),
        ]),
      ),
    );
  }
}
