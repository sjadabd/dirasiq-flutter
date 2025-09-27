import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';

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
          'منصة تعليمية متطورة تساعدك على تنظيم دراستك والوصول إلى دروسك بسهولة وفعالية.',
      icon: Icons.school,
      gradient: AppColors.gradientWelcome,
      features: ['دروس تفاعلية', 'متابعة التقدم', 'مجتمع تعليمي'],
    ),
    _IntroPageData(
      title: 'تعلّم بخطوات بسيطة',
      subtitle:
          'استكشف الدورات المتنوعة، تابع تقدمك اليومي، وتواصل مع أفضل المُدرّسين في مجالك.',
      icon: Icons.auto_graph,
      gradient: AppColors.gradientSuccess,
      features: ['دورات متخصصة', 'تقييم مستمر', 'شهادات معتمدة'],
    ),
    _IntroPageData(
      title: 'جاهز للبدء؟',
      subtitle:
          'أنشئ حسابًا مجانيًا أو سجّل دخولك وابدأ رحلتك التعليمية المثيرة الآن!',
      icon: Icons.rocket_launch,
      gradient: AppColors.gradientMotivation,
      features: ['بدء فوري', 'محتوى مجاني', 'دعم 24/7'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        curve: Curves.easeInOutCubic,
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
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _pages[_currentIndex].gradient[0].withOpacity(0.1),
              _pages[_currentIndex].gradient[1].withOpacity(0.05),
              // استخدام لون الخلفية النفسية المريح
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentIndex > 0)
                      AnimatedOpacity(
                        opacity: _currentIndex > 0 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: TextButton.icon(
                          onPressed: _previous,
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          label: const Text('السابق'),
                          style: TextButton.styleFrom(
                            foregroundColor: _pages[_currentIndex].gradient[0],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 80),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _pages[_currentIndex].gradient,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _pages[_currentIndex].gradient[0]
                                .withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_currentIndex + 1} من ${_pages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        'تخطي',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
                    return AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: p.gradient,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: p.gradient[0].withOpacity(0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                        BoxShadow(
                                          color: p.gradient[1].withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, -5),
                                          spreadRadius: -5,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      p.icon,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: p.gradient,
                                    ).createShader(bounds),
                                    child: Text(
                                      p.title,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  Text(
                                    p.subtitle,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.6,
                                          fontSize: 16,
                                        ),
                                  ),
                                  const SizedBox(height: 32),

                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: p.features.map((feature) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.gradient[0].withOpacity(
                                            0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: p.gradient[0].withOpacity(
                                              0.2,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: p.gradient[0].withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          feature,
                                          style: TextStyle(
                                            color: p.gradient[0],
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
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    height: 8,
                    width: _currentIndex == i ? 32 : 8,
                    decoration: BoxDecoration(
                      gradient: _currentIndex == i
                          ? LinearGradient(
                              colors: _pages[_currentIndex].gradient,
                            )
                          : null,
                      color: _currentIndex != i
                          ? _pages[_currentIndex].gradient[0].withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _currentIndex == i
                          ? [
                              BoxShadow(
                                color: _pages[_currentIndex].gradient[0]
                                    .withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _pages[_currentIndex].gradient,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _pages[_currentIndex].gradient[0].withOpacity(
                          0.4,
                        ),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: _pages[_currentIndex].gradient[1].withOpacity(
                          0.2,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentIndex == _pages.length - 1
                              ? 'ابدأ الآن'
                              : 'التالي',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentIndex == _pages.length - 1
                              ? Icons.rocket_launch
                              : Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPageData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final List<String> features;

  const _IntroPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.features,
  });
}
