import 'package:dirasiq/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';

class BookingsListScreen extends StatefulWidget {
  final void Function(int index)? onNavigateToTab;

  const BookingsListScreen({super.key, this.onNavigateToTab});

  @override
  State<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends State<BookingsListScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String? _statusFilter;
  String? _studyYear;
  int _page = 1;
  final int _limit = 10;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  static const Map<String, String> statusLabels = {
    'pending': 'قيد الانتظار',
    'pre_approved': 'موافقة أولية',
    'confirmed': 'تم التأكيد',
    'rejected': 'مرفوض',
    'cancelled': 'ملغي',
  };

  static const Map<String, IconData> statusIcons = {
    'pending': Icons.schedule_rounded,
    'pre_approved': Icons.task_alt_rounded,
    'confirmed': Icons.verified_rounded,
    'approved': Icons.check_circle_rounded,
    'rejected': Icons.cancel_rounded,
    'cancelled': Icons.block_rounded,
    'canceled': Icons.block_rounded,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _studyYear ??= DateTime.now().month >= 9
        ? '${DateTime.now().year}-${DateTime.now().year + 1}'
        : '${DateTime.now().year - 1}-${DateTime.now().year}';
    _loadInitial();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _page = 1;
      _items = [];
      _hasMore = true;
      _error = null;
    });
    await _fetchPage(reset: true);
    _animationController.forward();
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (_loading || (!_hasMore && !reset)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchStudentBookings(
        studyYear: _studyYear,
        page: _page,
        limit: _limit,
        status: _statusFilter,
      );

      List<dynamic> list = [];
      if (res['data'] is List) {
        list = res['data'] as List;
      } else if (res['data'] is Map) {
        final data = res['data'] as Map<String, dynamic>;
        list = (data['items'] ?? data['data'] ?? []) as List;
      } else {
        list = [];
      }

      final items = List<Map<String, dynamic>>.from(list);
      setState(() {
        if (_page == 1) {
          _items = items;
        } else {
          _items.addAll(items);
        }
        _hasMore = items.length >= _limit;
        if (_hasMore) _page++;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    _animationController.reset();
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: const GlobalAppBar(title: 'حجوزاتي', centerTitle: true),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildFilters(isDark),
                      const SizedBox(height: 10),
                      if (_error != null) _buildError(isDark),
                    ],
                  ),
                ),
              ),
              if (_items.isEmpty && !_loading && _error == null)
                SliverFillRemaining(child: _buildEmpty(isDark))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index < _items.length) {
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        curve: Curves.easeOutCubic,
                        child: _buildBookingCard(_items[index], index, isDark),
                      );
                    } else if (index == _items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (_loading)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            if (!_loading && _hasMore)
                              Center(
                                child: TextButton.icon(
                                  onPressed: _fetchPage,
                                  icon: const Icon(
                                    Icons.expand_more_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'تحميل المزيد',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    }
                    return null;
                  }, childCount: _items.length + 1),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 8,
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
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'تصفية الحجوزات',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatusDropdown(isDark),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: DropdownButtonFormField<String?>(
        value: _statusFilter,
        isExpanded: true,
        dropdownColor: isDark ? AppColors.darkSurface : AppColors.surface,
        style: TextStyle(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          fontSize: 12,
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(
              'كل الحالات',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...statusLabels.entries.map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusIcons[e.key],
                    size: 12,
                    color: _getStatusColor(e.key, isDark),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      e.value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        decoration: InputDecoration(
          labelText: 'الحالة',
          labelStyle: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            fontSize: 11,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onChanged: (v) {
          setState(() => _statusFilter = v);
          _page = 1;
          _items = [];
          _hasMore = true;
          _fetchPage(reset: true);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b, int index, bool isDark) {
    final status = (b['status'] ?? '').toString();
    final statusLabel = statusLabels[status] ?? status;

    final courseName = b['courseName'] ?? 'دورة غير محددة';
    final teacherName = b['teacher_name'] ?? 'غير محدد';
    final studentName = b['student_name'] ?? 'غير محدد';
    final price = b['price']?.toString() ?? '';
    final bookingDate = b['bookingDate']?.toString() ?? '';
    final studyYear = b['studyYear']?.toString() ?? '';
    final studentMessage = b['studentMessage']?.toString() ?? '';
    final courseImage =
        (b['courseImages'] is List && b['courseImages'].isNotEmpty)
        ? b['courseImages'][0]
        : null;

    final statusColor = _getStatusColor(status, isDark);
    final statusIcon = statusIcons[status] ?? Icons.help_outline_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(
            context,
            '/booking-details',
            arguments: b['id'],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة الدورة
                if (courseImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      "${AppConfig.serverBaseUrl}$courseImage",
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported_rounded,
                            size: 32,
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // العنوان + الحالة
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        courseName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // تفاصيل مختصرة
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        Icons.person_rounded,
                        'المدرس',
                        teacherName,
                        AppColors.primary,
                      ),
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        Icons.person_outline_rounded,
                        'الطالب',
                        studentName,
                        AppColors.info,
                      ),
                      if (price.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          Icons.attach_money_rounded,
                          'السعر',
                          '$price د.ع',
                          AppColors.success,
                        ),
                      ],
                      if (bookingDate.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          Icons.event_rounded,
                          'تاريخ الحجز',
                          _formatDate(bookingDate),
                          AppColors.warning,
                        ),
                      ],
                      if (studyYear.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          Icons.school_rounded,
                          'السنة الدراسية',
                          studyYear,
                          AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ),

                if (studentMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.message_rounded,
                          size: 12,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            studentMessage,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                              fontSize: 10,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // العمليات
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/booking-details',
                          arguments: b['id'],
                        ),
                        icon: Icon(
                          Icons.visibility_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          'عرض التفاصيل',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                    if (status == 'pending') ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _showCancelDialog(b['id']),
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                          label: const Text(
                            'إلغاء',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 10,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 10,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حدث خطأ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _error ?? '',
                  style: TextStyle(color: AppColors.error, fontSize: 10),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _loadInitial,
            child: Text(
              'إعادة',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 48,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد حجوزات حتى الآن',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر حجوزاتك هنا عند إنشائها',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigateToTab?.call(1),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'تصفح الدورات',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, bool isDark) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'pre_approved':
        return AppColors.info;
      case 'confirmed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'cancelled':
        return isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
      default:
        return AppColors.info;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showCancelDialog(String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'إلغاء الحجز',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في إلغاء هذا الحجز؟',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              Navigator.pop(context);
              // TODO: إضافة منطق الإلغاء الفعلي
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
              'تأكيد الإلغاء',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
