import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<_IntroPageData> _pages = const [
    _IntroPageData(
      title: 'مرحبًا بك في ديراسِق',
      subtitle:
          'منصتك التعليمية الذكية لتنظيم دراستك والتواصل مع أفضل الأساتذة بسهولة واحترافية.',
      icon: Icons.school_rounded,
      features: ['تعلّم بمرونة', 'تابع تقدمك', 'كن جزءاً من مجتمع تعليمي'],
    ),
    _IntroPageData(
      title: 'كل ما تحتاجه في مكان واحد',
      subtitle:
          'دروس مباشرة، اختبارات، تقييمات وتقارير الأداء – كل ذلك ضمن تجربة تعليمية متكاملة.',
      icon: Icons.auto_graph_rounded,
      features: ['اختبارات فورية', 'تقييم ذكي', 'إحصائيات دقيقة'],
    ),
    _IntroPageData(
      title: 'جاهز للانطلاق؟',
      subtitle:
          'ابدأ رحلتك التعليمية اليوم وحقق أهدافك بخطوات واثقة وسهلة مع ديراسِق.',
      icon: Icons.rocket_launch_rounded,
      features: ['ابدأ الآن', 'محتوى مجاني', 'دعم متواصل'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    Get.offAllNamed('/login');
  }

  void _next() {
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _animationController.reset();
      _animationController.forward();
    } else {
      _finishOnboarding();
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    // Dispose controllers to avoid active ticker leaks
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentIndex > 0)
                    TextButton.icon(
                      onPressed: _previous,
                      icon: const Icon(Icons.arrow_back_ios, size: 14),
                      label: const Text('السابق'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.primary,
                      ),
                    )
                  else
                    const SizedBox(width: 70),
                  Text(
                    '${_currentIndex + 1} / ${_pages.length}',
                    style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'تخطي',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) {
                  setState(() => _currentIndex = i);
                  _animationController.reset();
                  _animationController.forward();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final p = _pages[index];
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                p.icon,
                                color: scheme.primary,
                                size: 52,
                              ),
                            ),
                            const SizedBox(height: 24),

                            Text(
                              p.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 14),

                            Text(
                              p.subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurface.withOpacity(0.7),
                                    height: 1.6,
                                  ),
                            ),
                            const SizedBox(height: 26),

                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: p.features.map((f) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: scheme.primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 🔹 Page Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: _currentIndex == i ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? scheme.primary
                          : scheme.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),

            // 🔹 Next Button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentIndex == _pages.length - 1
                            ? 'ابدأ الآن'
                            : 'التالي',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _currentIndex == _pages.length - 1
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPageData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> features;

  const _IntroPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.features,
  });
}
