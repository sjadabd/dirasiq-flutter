import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';

class CourseDetailsScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailsScreen({super.key, required this.courseId});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  Map<String, dynamic>? course;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
  }

  Future<void> _fetchCourseDetails() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final api = ApiService();
      final result = await api.fetchCourseDetails(widget.courseId);
      setState(() {
        course = result['course'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  String _translateBookingStatus(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'pre_approved':
        return 'موافقة أولية';
      case 'confirmed':
        return 'تم التأكيد';
      case 'approved':
        return 'مقبول نهائيًا';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        top: true,
        bottom: true,
        child: isLoading
            ? _buildLoading()
            : error != null
            ? _buildError(theme)
            : course == null
            ? _buildEmpty(theme)
            : _buildContent(theme, isDark),
      ),
      bottomNavigationBar: course == null
          ? null
          : _buildBottomButton(theme, course!),
    );
  }

  Widget _buildLoading() =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));

  Widget _buildError(ThemeData theme) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 60),
        const SizedBox(height: 8),
        Text(
          "حدث خطأ في تحميل تفاصيل الكورس",
          style: TextStyle(color: theme.colorScheme.error),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _fetchCourseDetails,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text("إعادة المحاولة"),
        ),
      ],
    ),
  );

  Widget _buildEmpty(ThemeData theme) => Center(
    child: Text(
      "الكورس غير متاح حالياً",
      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
    ),
  );

  Widget _buildContent(ThemeData theme, bool isDark) {
    final c = course!;
    final teacher = c['teacher'] ?? {};
    final price = NumberFormat(
      '#,###',
    ).format(double.tryParse(c['price'].toString()) ?? 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            stretch: true,

            // ✅ اجعل الخلفية ديناميكية حسب الوضع
            backgroundColor: isDark
                ? Colors.black.withOpacity(0.85)
                : theme
                      .colorScheme
                      .surfaceContainerHighest, // لون ناعم متناسق في النهار
            // ✅ اجعل الأيقونات واضحة في الوضعين
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : Colors.black87,
            ),

            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final top = constraints.biggest.height;
                final zoomFactor = (top - kToolbarHeight) / 340;
                final zoom = zoomFactor > 1 ? zoomFactor : 1.0;

                return FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  title: AnimatedOpacity(
                    opacity: top < 350 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      c['course_name'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ✅ تأثير Zoom-in للصورة
                      Transform.scale(scale: zoom, child: _buildImage(c)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // السعر والمعلومات
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$price د.ع",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.people_outline,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${c['seats_count']} طالب",
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // الصف والمادة
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(theme, c['subject']['name'] ?? 'غير معروف'),
                      _chip(
                        theme,
                        c['grade']['name'] ?? 'غير محدد',
                        color: theme.colorScheme.secondary,
                      ),
                      _chip(
                        theme,
                        c['study_year'] ?? '',
                        color: theme.colorScheme.tertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _teacherCard(theme, teacher),
                  const SizedBox(height: 20),

                  if (c['description'] != null &&
                      c['description'].toString().isNotEmpty)
                    _sectionCard(
                      theme,
                      title: "وصف الكورس",
                      content: c['description'],
                      icon: Icons.menu_book_rounded,
                    ),
                  const SizedBox(height: 20),

                  _sectionCard(
                    theme,
                    title: "المواعيد",
                    content:
                        "يبدأ في ${_formatDate(c['start_date'])} وينتهي في ${_formatDate(c['end_date'])}",
                    icon: Icons.calendar_month_outlined,
                  ),
                  const SizedBox(height: 20),

                  _sectionCard(
                    theme,
                    title: "تفاصيل إضافية",
                    content:
                        "عدد المقاعد: ${c['seats_count']}\nالحالة: ${_translateBookingStatus(c['status'] ?? '')}",
                    icon: Icons.info_outline_rounded,
                  ),

                  // ✅ مسافة أمان من الأسفل للصفحة
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(Map<String, dynamic> c) {
    final imgs = c['course_images'] as List?;
    String url;
    if (imgs != null && imgs.isNotEmpty) {
      final p = imgs.first.toString();
      url = p.startsWith('http') ? p : '${AppConfig.serverBaseUrl}$p';
    } else {
      url = '${AppConfig.serverBaseUrl}/uploads/default-course.jpg';
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.school_rounded, size: 60, color: Colors.white),
      ),
    );
  }

  Widget _chip(ThemeData theme, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _teacherCard(ThemeData theme, Map<String, dynamic> t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Icon(
              Icons.person_rounded,
              color: theme.colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['name'] ?? 'غير معروف',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${t['experienceYears'] ?? 0} سنوات خبرة",
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (t['distance'] != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${t['distance'].toStringAsFixed(1)} كم",
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(ThemeData theme, Map<String, dynamic> c) {
    final bookingStatus = c['bookingStatus'];
    final price = NumberFormat(
      '#,###',
    ).format(double.tryParse(c['price'].toString()) ?? 0);

    if (bookingStatus != null) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.info, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "طلبك: ${_translateBookingStatus(bookingStatus)}",
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.school_outlined),
          label: Text("التسجيل في الكورس - $price د.ع"),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _onEnrollPressed,
        ),
      ),
    );
  }

  Future<void> _onEnrollPressed() async {
    final message = await _askMessage();
    if (message == null) return;

    try {
      final api = ApiService();
      await api.createCourseBooking(
        courseId: course?['id'] ?? widget.courseId,
        studentMessage: message,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إرسال طلب الحجز بنجاح"),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushNamed(context, '/bookings');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("حدث خطأ: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _askMessage() async {
    final controller = TextEditingController();
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إرسال طلب حجز"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: "ملاحظة للمدرس (اختياري)",
            hintText: "اكتب ملاحظة قصيرة...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              result = controller.text.isEmpty
                  ? 'أرغب بالانضمام إلى هذا الكورس'
                  : controller.text;
              Navigator.pop(ctx);
            },
            child: const Text("إرسال"),
          ),
        ],
      ),
    );
    return result;
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date);
      return DateFormat('yyyy/MM/dd').format(d);
    } catch (_) {
      return date;
    }
  }
}
