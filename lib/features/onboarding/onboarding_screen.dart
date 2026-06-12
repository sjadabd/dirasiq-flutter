// First-launch onboarding (MulhimIQ design-system pass).
//
// 6 feature-intro pages → "ابدأ الآن" sets the seen flag and goes to /login.
// Presentation only: the SharedPreferences flag logic, the Next/Prev/Skip
// navigation, and the /login redirect are UNCHANGED. Every slide shares the
// one brand navy hero gradient (resolved from design tokens, dark-mode aware)
// so the carousel reads as one cohesive product rather than a rainbow.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    final isLast = _index == _slides.length - 1;

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            final m = context.mq;
            return Scaffold(
              backgroundColor: m.page,
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(MqSpacing.sm, MqSpacing.sm, MqSpacing.sm, 0),
                      child: Row(children: [
                        if (_index > 0)
                          IconButton(onPressed: _prev, icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18), tooltip: 'السابق')
                        else
                          const SizedBox(width: 48),
                        const Spacer(),
                        if (!isLast)
                          MqButton.text(label: 'تخطّي', size: MqButtonSize.small, onPressed: _finish),
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
                      padding: const EdgeInsets.symmetric(vertical: MqSpacing.md),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < _slides.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 8,
                            width: i == _index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: i == _index ? m.accent : m.line,
                              borderRadius: MqRadius.brPill,
                            ),
                          ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, 0, MqSpacing.lg, MqSpacing.lg),
                      child: MqButton(
                        label: isLast ? 'ابدأ الآن' : 'التالي',
                        icon: isLast ? Icons.rocket_launch_outlined : Icons.arrow_back_rounded,
                        onPressed: _next,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.icon, required this.title, required this.subtitle, required this.points});
  final IconData icon;
  final String title, subtitle;
  final List<String> points;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final m = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          MqSpacing.gapLg,
          AspectRatio(
            aspectRatio: 1.2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [m.accentDeep, m.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: MqRadius.brXl,
                boxShadow: [BoxShadow(color: m.accent.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Positioned(top: -30, left: -30, child: Container(width: 120, height: 120,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle))),
                Positioned(bottom: -40, right: -20, child: Container(width: 160, height: 160,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle))),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Icon(slide.icon, size: 80, color: Colors.white),
                ),
              ]),
            ),
          ),
          MqSpacing.gapXl,
          Text(slide.title, textAlign: TextAlign.center, style: context.text.headlineSmall),
          MqSpacing.gapXs,
          Text(slide.subtitle, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: m.ink3)),
          MqSpacing.gapLg,
          ...slide.points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: MqSpacing.sm),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 14, color: m.accent),
                  ),
                  MqSpacing.gapSm,
                  Expanded(child: Text(p, style: context.text.bodyMedium?.copyWith(height: 1.4))),
                ]),
              )),
          MqSpacing.gapMd,
        ]),
      ),
    );
  }
}
