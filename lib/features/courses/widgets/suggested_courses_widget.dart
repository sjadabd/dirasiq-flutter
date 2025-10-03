import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class SuggestedCoursesCompact extends StatefulWidget {
  const SuggestedCoursesCompact({super.key});

  @override
  State<SuggestedCoursesCompact> createState() =>
      _SuggestedCoursesCompactState();
}

class _SuggestedCoursesCompactState extends State<SuggestedCoursesCompact> {
  List<Map<String, dynamic>> courses = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadSuggestedCourses();
  }

  Future<void> _loadSuggestedCourses() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final apiService = ApiService();
      final fetchedCourses = await apiService.fetchSuggestedCourses(
        page: 1,
        limit: 3, // عرض 3 كورسات فقط في الصفحة الرئيسية
        maxDistance: 10.0,
      );

      setState(() {
        courses = fetchedCourses;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.recommend,
                  color: cs.primary,
                  size: 16,
                ), // أيقونة أصغر
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "الكورسات المقترحة لك",
                    style: TextStyle(
                      fontSize: 12, // أصغر من 18
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Get.toNamed("/suggested-courses");
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4, // زر أصغر
                    ),
                    minimumSize: Size(0, 28), // يمنع التوسع
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "عرض المزيد",
                        style: TextStyle(
                          fontSize: 12, // أصغر
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12, // أيقونة أصغر
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // محتوى الكورسات
          if (isLoading)
            _buildLoadingWidget()
          else if (error != null)
            _buildErrorWidget()
          else if (courses.isEmpty)
            _buildEmptyWidget()
          else
            _buildCompactCoursesList(),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 32),
          const SizedBox(height: 8),
          Text(
            "حدث خطأ في تحميل الكورسات",
            style: TextStyle(
              color: cs.onErrorContainer,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadSuggestedCourses,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("إعادة المحاولة"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.school_outlined, color: cs.onSurfaceVariant, size: 48),
          const SizedBox(height: 12),
          Text(
            "لا توجد كورسات مقترحة حالياً",
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCoursesList() {
    return Column(
      children: courses
          .map((course) => _buildCompactCourseCard(course))
          .toList(),
    );
  }

  Widget _buildCompactCourseCard(Map<String, dynamic> course) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          try {
            if (mounted) {
              final courseId = course['id'];
              if (courseId != null) {
                Get.toNamed("/course-details", arguments: courseId);
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('حدث خطأ في التنقل'),
                  backgroundColor: cs.error,
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // صورة الكورس المختصرة
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: cs.surfaceVariant,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildCompactCourseImage(course),
                ),
              ),
              const SizedBox(width: 12),

              // معلومات الكورس
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم الكورس
                    Text(
                      course['course_name'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // اسم المدرس
                    Text(
                      course['teacher_name'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // السعر والمسافة
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${NumberFormat('#,###').format(double.tryParse(course['price'].toString()) ?? 0)} د.ع",
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on, size: 12, color: cs.primary),
                        const SizedBox(width: 2),
                        Text(
                          "${course['distance'].toStringAsFixed(1)} كم",
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // زر عرض التفاصيل
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCourseImage(Map<String, dynamic> course) {
    // Prefer course image, then teacher profile image
    final courseImages = course['course_images'] as List<dynamic>?;
    String? candidate;
    if (courseImages != null && courseImages.isNotEmpty) {
      candidate = courseImages.first.toString();
    }
    candidate ??= course['teacher_profile_image_path']?.toString();

    if (candidate != null && candidate.isNotEmpty) {
      final url = candidate.startsWith('http')
          ? candidate
          : '${AppConfig.serverBaseUrl}$candidate';
      return Image.network(
        url,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackIcon();
        },
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Icon(Icons.school, size: 24, color: cs.onSurfaceVariant),
    );
  }
}
