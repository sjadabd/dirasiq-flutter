import 'package:mulhimiq/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/shared/themes/app_colors.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String? bookingId;
  const BookingDetailsScreen({super.key, this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  String? _resolveBookingId() {
    return widget.bookingId ??
        (Get.arguments is String ? Get.arguments as String : null) ??
        (ModalRoute.of(context)?.settings.arguments as String?);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final id = _resolveBookingId();
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'معرف الحجز غير متوفر';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchBookingDetails(id);
      if (!mounted) return;
      setState(() {
        _data = res['data'] ?? res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    final id = _data?['id']?.toString();
    if (id == null) return;
    final reason = await _askForReason();
    if (reason == null) return;
    try {
      await _api.cancelBooking(bookingId: id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إلغاء الحجز', style: TextStyle(fontSize: 11)),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل الإلغاء: $e',
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _reactivate() async {
    final id = _data?['id']?.toString();
    if (id == null) return;
    try {
      final res = await _api.reactivateBooking(id);
      if (!mounted) return;
      final msg = (res['message'] ?? 'تم إعادة إرسال الطلب').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontSize: 11)),
          backgroundColor: AppColors.success,
        ),
      );
      final warning = res['warning'];
      if (warning is Map<String, dynamic>) {
        final wMsg = warning['message']?.toString() ?? 'تنبيه';
        final note = warning['note']?.toString();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurface
                : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              wMsg,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            content: note != null
                ? Text(
                    note,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  )
                : null,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'حسناً',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: const TextStyle(fontSize: 11)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _askForReason() async {
    final controller = TextEditingController();
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'سبب الإلغاء',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'اذكر سبب الإلغاء',
            hintStyle: TextStyle(
              fontSize: 11,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              result = controller.text.trim();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'تأكيد',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result;
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'غير محدد';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار';
      case 'pre_approved':
        return 'موافقة أولية';
      case 'confirmed':
        return 'تم التأكيد';
      case 'approved':
        return 'موافق نهائياً';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغي';
      case 'canceled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'pre_approved':
        return AppColors.info;
      case 'confirmed':
        return Colors.blue;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'cancelled':
        return Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
      case 'canceled':
        return Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
      default:
        return Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _error == null && _loading) {
      // Initial load is triggered from initState via addPostFrameCallback
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: const GlobalAppBar(title: 'تفاصيل الحجز', centerTitle: true),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final booking = _data!;
    final status = (booking['status'] ?? '').toString();
    final student = booking['student'] as Map<String, dynamic>?;
    final course = booking['course'] as Map<String, dynamic>?;
    final teacher = booking['teacher'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildStatusCard(booking, status, isDark),
        const SizedBox(height: 10),

        if (course != null) _buildCourseCard(course, isDark),
        const SizedBox(height: 10),

        if (student != null) _buildStudentCard(student, isDark),
        const SizedBox(height: 10),

        if (teacher != null) _buildTeacherCard(teacher, isDark),
        const SizedBox(height: 10),

        _buildMessagesCard(booking, isDark),
        const SizedBox(height: 10),

        _buildTimelineCard(booking, isDark),
        const SizedBox(height: 10),

        _buildActionButtons(status, booking, isDark),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildStatusCard(
    Map<String, dynamic> booking,
    String status,
    bool isDark,
  ) {
    final statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bookmark_rounded,
                  color: statusColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'حالة الحجز',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _row(
                  Icons.school_rounded,
                  'السنة الدراسية',
                  booking['studyYear']?.toString() ?? 'غير محدد',
                  AppColors.primary,
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.event_rounded,
                  'تاريخ الحجز',
                  _formatDateTime(booking['bookingDate']?.toString()),
                  AppColors.info,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, bool isDark) {
    final images = course['courseImages'] as List<dynamic>?;
    final hasReservation = course['hasReservation'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'معلومات الكورس',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (images != null && images.isNotEmpty) ...[
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 90,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: NetworkImage(
                          '${AppConfig.serverBaseUrl}${images[index]}',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _row(
                  Icons.book_rounded,
                  'اسم الكورس',
                  course['courseName']?.toString() ?? 'غير محدد',
                  AppColors.primary,
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.description_rounded,
                  'الوصف',
                  course['description']?.toString() ?? 'غير متوفر',
                  AppColors.info,
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.attach_money_rounded,
                  'السعر',
                  '${course['price'] ?? '0'} دينار',
                  AppColors.success,
                ),
                if (hasReservation == true ||
                    hasReservation?.toString() == 'true') ...[
                  const SizedBox(height: 6),
                  _row(
                    Icons.payment_rounded,
                    'مبلغ الحجز',
                    '${course['reservationAmount'] ?? '0'} دينار',
                    AppColors.warning,
                  ),
                ],
                const SizedBox(height: 6),
                _row(
                  Icons.event_seat_rounded,
                  'عدد المقاعد',
                  course['seatsCount']?.toString() ?? 'غير محدد',
                  AppColors.primary,
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.play_circle_rounded,
                  'تاريخ البداية',
                  _formatDateTime(course['startDate']?.toString()),
                  AppColors.success,
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.stop_circle_rounded,
                  'تاريخ النهاية',
                  _formatDateTime(course['endDate']?.toString()),
                  AppColors.error,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.info.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.info,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'معلومات الطالب',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _row(
                  Icons.badge_rounded,
                  'الاسم',
                  student['name']?.toString() ?? 'غير محدد',
                  AppColors.info,
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.email_rounded,
                  'البريد الإلكتروني',
                  student['email']?.toString() ?? 'غير محدد',
                  AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.success,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'معلومات المدرس',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _row(
                  Icons.badge_rounded,
                  'الاسم',
                  teacher['name']?.toString() ?? 'غير محدد',
                  AppColors.success,
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.email_rounded,
                  'البريد الإلكتروني',
                  teacher['email']?.toString() ?? 'غير محدد',
                  AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesCard(Map<String, dynamic> booking, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.message_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'الرسائل والتواصل',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (booking['studentMessage'] != null)
            _messageBox(
              'رسالة الطالب',
              booking['studentMessage'].toString(),
              AppColors.info,
              Icons.message_rounded,
            ),
          if (booking['teacherResponse'] != null)
            _messageBox(
              'رد المدرس',
              booking['teacherResponse'].toString(),
              AppColors.success,
              Icons.reply_rounded,
            ),
          if (booking['rejectionReason'] != null)
            _messageBox(
              'سبب الرفض',
              booking['rejectionReason'].toString(),
              AppColors.error,
              Icons.cancel_rounded,
            ),
          if (booking['cancellationReason'] != null)
            _messageBox(
              'سبب الإلغاء',
              booking['cancellationReason'].toString(),
              AppColors.warning,
              Icons.block_rounded,
            ),
          if (booking['studentMessage'] == null &&
              booking['teacherResponse'] == null &&
              booking['rejectionReason'] == null &&
              booking['cancellationReason'] == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'لا توجد رسائل',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> booking, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.timeline_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'التسلسل الزمني',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _row(
                  Icons.add_circle_rounded,
                  'تاريخ الإنشاء',
                  _formatDateTime(booking['createdAt']?.toString()),
                  AppColors.primary,
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.update_rounded,
                  'آخر تحديث',
                  _formatDateTime(booking['updatedAt']?.toString()),
                  AppColors.info,
                ),
                if (booking['approvedAt'] != null) ...[
                  const SizedBox(height: 6),
                  _row(
                    Icons.check_circle_rounded,
                    'تاريخ الموافقة',
                    _formatDateTime(booking['approvedAt'].toString()),
                    AppColors.success,
                  ),
                ],
                if (booking['rejectedAt'] != null) ...[
                  const SizedBox(height: 6),
                  _row(
                    Icons.cancel_rounded,
                    'تاريخ الرفض',
                    _formatDateTime(booking['rejectedAt'].toString()),
                    AppColors.error,
                  ),
                ],
                if (booking['cancelledAt'] != null) ...[
                  const SizedBox(height: 6),
                  _row(
                    Icons.block_rounded,
                    'تاريخ الإلغاء',
                    _formatDateTime(booking['cancelledAt'].toString()),
                    AppColors.warning,
                  ),
                ],
                if (booking['reactivatedAt'] != null) ...[
                  const SizedBox(height: 6),
                  _row(
                    Icons.restart_alt_rounded,
                    'تاريخ إعادة التفعيل',
                    _formatDateTime(booking['reactivatedAt'].toString()),
                    AppColors.success,
                  ),
                ],
                if (booking['cancelledBy'] != null) ...[
                  const SizedBox(height: 6),
                  _row(
                    Icons.person_rounded,
                    'ألغي بواسطة',
                    booking['cancelledBy'].toString(),
                    AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    String status,
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final rejectedBy = booking['rejectedBy']?.toString().toLowerCase();
    final rejectedByTeacher = rejectedBy == 'teacher';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (status == 'pending' || status == 'approved')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text(
                    'إلغاء الحجز',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            if ((status == 'rejected' ||
                    status == 'canceled' ||
                    status == 'cancelled') &&
                !rejectedByTeacher) ...[
              if (status == 'pending' || status == 'approved')
                const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reactivate,
                  icon: Icon(
                    Icons.restart_alt_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    'إعادة الإرسال',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (status == 'rejected' && rejectedByTeacher) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم رفض طلبك من قبل المدرس. يرجى مراجعة الأستاذ لمعرفة أسباب الرفض.',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _messageBox(String title, String message, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 10,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
