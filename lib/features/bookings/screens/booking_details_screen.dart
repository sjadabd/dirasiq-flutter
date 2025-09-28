import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';

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

  String? _resolveBookingId(BuildContext context) {
    return widget.bookingId ??
        (Get.arguments is String ? Get.arguments as String : null) ??
        (ModalRoute.of(context)?.settings.arguments as String?);
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _load(BuildContext context) async {
    final id = _resolveBookingId(context);
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
      setState(() {
        _data = res['data'] ?? res;
        _loading = false;
      });
    } catch (e) {
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
          content: const Text('تم إلغاء الحجز'),
          backgroundColor: AppColors.success,
        ),
      );
      _load(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الإلغاء: $e'),
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
        SnackBar(content: Text(msg), backgroundColor: AppColors.success),
      );
      final warning = res['warning'];
      if (warning is Map<String, dynamic>) {
        final wMsg = warning['message']?.toString() ?? 'تنبيه';
        final note = warning['note']?.toString();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(wMsg),
            content: note != null ? Text(note) : null,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
      _load(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  Future<String?> _askForReason() async {
    final controller = TextEditingController();
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الإلغاء'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'اذكر سبب الإلغاء'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              result = controller.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد'),
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
        return 'موافقة أولية من المدرس';
      case 'confirmed':
        return 'تم تأكيد الحجز';
      case 'approved':
        return 'موافق عليه نهائياً';
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
        return Colors.orange; // قيد الانتظار
      case 'pre_approved':
        return AppColors.info; // موافقة أولية
      case 'confirmed':
        return Colors.blue; // تم التأكيد
      case 'approved':
        return AppColors.success; // موافق نهائياً
      case 'rejected':
        return AppColors.error; // مرفوض
      case 'cancelled':
        return Colors.grey; // ملغي
      case 'canceled':
        return Colors.grey; // ملغي
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _error == null && _loading) {
      Future.microtask(() => _load(context));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تفاصيل الحجز'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _load(context),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
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
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(booking, status),
        const SizedBox(height: 16),

        if (course != null) _buildCourseCard(course),
        const SizedBox(height: 16),

        if (student != null) _buildStudentCard(student),
        const SizedBox(height: 16),

        if (teacher != null) _buildTeacherCard(teacher),
        const SizedBox(height: 16),

        _buildMessagesCard(booking),
        const SizedBox(height: 16),

        _buildTimelineCard(booking),
        const SizedBox(height: 16),

        _buildActionButtons(status),
      ],
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> booking, String status) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'حالة الحجز',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor(status)),
              ),
              child: Text(
                _getStatusText(status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _row(
              'السنة الدراسية',
              booking['studyYear']?.toString() ?? 'غير محدد',
            ),
            _row(
              'تاريخ الحجز',
              _formatDateTime(booking['bookingDate']?.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final images = course['courseImages'] as List<dynamic>?;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'معلومات الكورس',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (images != null && images.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://your-api-base-url${images[index]}',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (images != null && images.isNotEmpty) const SizedBox(height: 12),
            _row('اسم الكورس', course['courseName']?.toString() ?? 'غير محدد'),
            _row('الوصف', course['description']?.toString() ?? 'غير متوفر'),
            _row('السعر', '${course['price'] ?? '0'} دينار'),
            _row('عدد المقاعد', course['seatsCount']?.toString() ?? 'غير محدد'),
            _row(
              'تاريخ البداية',
              _formatDateTime(course['startDate']?.toString()),
            ),
            _row(
              'تاريخ النهاية',
              _formatDateTime(course['endDate']?.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'معلومات الطالب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row('الاسم', student['name']?.toString() ?? 'غير محدد'),
            _row(
              'البريد الإلكتروني',
              student['email']?.toString() ?? 'غير محدد',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'معلومات المدرس',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row('الاسم', teacher['name']?.toString() ?? 'غير محدد'),
            _row(
              'البريد الإلكتروني',
              teacher['email']?.toString() ?? 'غير محدد',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesCard(Map<String, dynamic> booking) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.message, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'الرسائل والتواصل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (booking['studentMessage'] != null)
              _messageBox(
                'رسالة الطالب',
                booking['studentMessage'].toString(),
                Colors.blue,
              ),
            if (booking['teacherResponse'] != null)
              _messageBox(
                'رد المدرس',
                booking['teacherResponse'].toString(),
                Colors.green,
              ),
            if (booking['rejectionReason'] != null)
              _messageBox(
                'سبب الرفض',
                booking['rejectionReason'].toString(),
                Colors.red,
              ),
            if (booking['cancellationReason'] != null)
              _messageBox(
                'سبب الإلغاء',
                booking['cancellationReason'].toString(),
                Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> booking) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'التسلسل الزمني',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(
              'تاريخ الإنشاء',
              _formatDateTime(booking['createdAt']?.toString()),
            ),
            _row(
              'آخر تحديث',
              _formatDateTime(booking['updatedAt']?.toString()),
            ),
            if (booking['approvedAt'] != null)
              _row(
                'تاريخ الموافقة',
                _formatDateTime(booking['approvedAt'].toString()),
              ),
            if (booking['rejectedAt'] != null)
              _row(
                'تاريخ الرفض',
                _formatDateTime(booking['rejectedAt'].toString()),
              ),
            if (booking['cancelledAt'] != null)
              _row(
                'تاريخ الإلغاء',
                _formatDateTime(booking['cancelledAt'].toString()),
              ),
            if (booking['reactivatedAt'] != null)
              _row(
                'تاريخ إعادة التفعيل',
                _formatDateTime(booking['reactivatedAt'].toString()),
              ),
            if (booking['cancelledBy'] != null)
              _row('ألغي بواسطة', booking['cancelledBy'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    return Row(
      children: [
        if (status == 'pending' || status == 'approved')
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.cancel),
              label: const Text('إلغاء الحجز'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (status == 'rejected' ||
            status == 'canceled' ||
            status == 'cancelled') ...[
          if (status == 'pending' || status == 'approved')
            const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _reactivate,
              icon: const Icon(Icons.restart_alt),
              label: const Text('إعادة الإرسال'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _messageBox(String title, String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(message),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
