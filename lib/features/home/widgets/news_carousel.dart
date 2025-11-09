import 'package:mulhimiq/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:mulhimiq/shared/themes/app_colors.dart';
import 'package:mulhimiq/core/services/api_service.dart';

class NewsCarousel extends StatefulWidget {
  final int refreshToken; // تغيير خارجي لإعادة التحميل
  const NewsCarousel({super.key, this.refreshToken = 0});

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.78);
  List<Map<String, dynamic>> _newsList = [];
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

    _fetchLatestNews();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant NewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إعادة التحميل عند تغيّر قيمة refreshToken
    if (widget.refreshToken != oldWidget.refreshToken) {
      _fetchLatestNews();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _newsList.isNotEmpty) {
        final nextIndex = (_currentIndex + 1) % _newsList.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
        _startAutoSlide();
      }
    });
  }

  Future<void> _fetchLatestNews() async {
    try {
      final api = ApiService(); // ✅ استدعاء الخدمة
      final newsList = await api.fetchLatestNews(page: 1, limit: 5);

      if (mounted) {
        setState(() {
          _newsList = newsList;
          _isLoading = false;
        });

        // إذا عندك AnimationController
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "❌ خطأ أثناء تحميل الأخبار: $e";
          _isLoading = false;
        });
      }
    }
  }

  String _getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return 'https://via.placeholder.com/400x200/4F46E5/FFFFFF?text=أخبار+درس+عراق';
    }
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    return '${AppConfig.serverBaseUrl}$imageUrl';
  }

  void _showNewsDetails(Map<String, dynamic> news) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final cs = Theme.of(context).colorScheme;
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface, // خلفية تتبع الثيم
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== Header Section =====
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary, // يتبع الثيم
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.article_rounded,
                            color: cs.onPrimary,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "تفاصيل الخبر",
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(30),
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                color: cs.onPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ===== Content Section =====
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image
                            Container(
                              height: 200,
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  _getImageUrl(news['imageUrl']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: AppColors.gradientLearning,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.image_not_supported_rounded,
                                          color: (cs.onSurface).withValues(
                                            alpha: 0.7,
                                          ),
                                          size: 44,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Title
                            Text(
                              news['title'] ?? 'عنوان الخبر',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Date Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 15,
                                    color: cs.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatDate(news['publishedAt']),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Details
                            Text(
                              news['details'] ?? 'تفاصيل الخبر غير متوفرة',
                              style: TextStyle(
                                fontSize: 15,
                                color: cs.onSurface.withValues(alpha: 0.8),
                                height: 1.6,
                              ),
                            ),

                            const SizedBox(height: 26),

                            // Close Button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 3,
                                ),
                                icon: Icon(
                                  Icons.check_rounded,
                                  color: cs.onPrimary,
                                ),
                                label: Text(
                                  "إغلاق",
                                  style: TextStyle(
                                    color: cs.onPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Container(
        height: 130,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                "جاري تحميل الأخبار...",
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _newsList.isEmpty) {
      return Container(
        height: 130,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.newspaper_outlined,
                  size: 48,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error ?? "لا توجد أخبار متاحة حالياً",
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: 100,
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    padEnds: false,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemCount: _newsList.length,
                    itemBuilder: (context, index) {
                      final news = _newsList[index];
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double scale = 1.0;
                          if (_pageController.position.haveDimensions) {
                            final page =
                                _pageController.page ??
                                _currentIndex.toDouble();
                            scale = (1 - ((page - index).abs() * 0.15)).clamp(
                              0.85,
                              1.0,
                            );
                          }
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showNewsDetails(news),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned.fill(
                                      child: Image.network(
                                        _getImageUrl(news['imageUrl']),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors:
                                                    AppColors.gradientLearning,
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                size: 40,
                                                color: AppColors.white
                                                    .withValues(alpha: 0.85),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // Dark overlay
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Inner outline
                                    Positioned.fill(
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Subtle side icons
                                    Positioned(
                                      left: 18,
                                      top: 0,
                                      bottom: 0,
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        size: 44,
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 18,
                                      top: 0,
                                      bottom: 0,
                                      child: Icon(
                                        Icons.laptop_mac_rounded,
                                        size: 44,
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    // Centered title (2 lines)
                                    Positioned.fill(
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                          ),
                                          child: Text(
                                            news['title'] ?? 'عنوان الخبر',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  if (_newsList.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              _newsList.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                width: _currentIndex == index ? 18 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: _currentIndex == index ? 1.0 : 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return 'منذ ${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return 'منذ ${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return 'منذ ${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      return '';
    }
  }
}
