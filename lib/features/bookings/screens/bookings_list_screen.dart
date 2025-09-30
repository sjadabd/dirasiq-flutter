import 'package:dirasiq/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';

class BookingsListScreen extends StatefulWidget {
  final void Function(int index)? onNavigateToTab; // 👈 الكولباك

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
    'pre_approved': 'موافقة أولية من المدرس',
    'confirmed': 'تم تأكيد الحجز',
    'rejected': 'مرفوض',
    'cancelled': 'ملغي',
  };

  static const Map<String, IconData> statusIcons = {
    'pending': Icons.schedule,
    'pre_approved': Icons.task_alt,
    'confirmed': Icons.verified,
    'approved': Icons.check_circle,
    'rejected': Icons.cancel,
    'cancelled': Icons.block,
    'canceled': Icons.block,
  };

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

      print('[v0] API Response: $res');

      // Handle different response structures
      List<dynamic> list = [];
      if (res['data'] is List) {
        // Direct array in data field
        list = res['data'] as List;
      } else if (res['data'] is Map) {
        // Nested structure with items or data field
        final data = res['data'] as Map<String, dynamic>;
        list = (data['items'] ?? data['data'] ?? []) as List;
      } else {
        // Fallback to empty list
        list = [];
      }

      print('[v0] Parsed list length: ${list.length}');

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

      print('[v0] Items in state: ${_items.length}');
    } catch (e) {
      print('[v0] Error in _fetchPage: $e');
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
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildFilters(),
                      const SizedBox(height: 16),
                      if (_error != null) _buildError(),
                    ],
                  ),
                ),
              ),
              if (_items.isEmpty && !_loading && _error == null)
                SliverFillRemaining(child: _buildEmpty())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index < _items.length) {
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300 + (index * 100)),
                        curve: Curves.easeOutBack,
                        child: _buildBookingCard(_items[index], index),
                      );
                    } else if (index == _items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (_loading)
                              const Center(child: CircularProgressIndicator()),
                            if (!_loading && _hasMore)
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: _fetchPage,
                                  icon: const Icon(Icons.more_horiz),
                                  label: const Text('تحميل المزيد'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
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

  Widget _buildFilters() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'تصفية الحجوزات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                // Use Column layout for small screens
                return Column(children: [_buildStatusDropdown()]);
              } else {
                // Use Row layout for larger screens
                return Row(children: [Expanded(child: _buildStatusDropdown())]);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String?>(
        initialValue: _statusFilter,
        isExpanded: true,
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('كل الحالات', overflow: TextOverflow.ellipsis),
          ),
          ...statusLabels.entries.map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusIcons[e.key],
                    size: 14,
                    color: _getStatusColor(e.key),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      e.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        decoration: const InputDecoration(
          labelText: 'الحالة',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildBookingCard(Map<String, dynamic> b, int index) {
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

    final statusColor = _getStatusColor(status);
    final statusIcon = statusIcons[status] ?? Icons.help;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(
            context,
            '/booking-details',
            arguments: b['id'], // 👈 مرر الـ id فقط
          ),

          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [AppColors.white, AppColors.white.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة الكورس
                if (courseImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      "${AppConfig.serverBaseUrl}$courseImage",
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // العنوان + الحالة
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        courseName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // تفاصيل مختصرة
                _buildDetailRow('المدرس', teacherName, Icons.person),
                _buildDetailRow('الطالب', studentName, Icons.person_outline),
                if (price.isNotEmpty)
                  _buildDetailRow('السعر', '$price د.ع', Icons.attach_money),
                if (bookingDate.isNotEmpty)
                  _buildDetailRow(
                    'تاريخ الحجز',
                    _formatDate(bookingDate),
                    Icons.event,
                  ),
                if (studyYear.isNotEmpty)
                  _buildDetailRow('السنة الدراسية', studyYear, Icons.school),

                if (studentMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.message,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            studentMessage,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // العمليات
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/booking-details',
                        arguments: b['id'],
                      ),

                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('عرض التفاصيل'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                    if (status == 'pending')
                      TextButton.icon(
                        onPressed: () => _showCancelDialog(b['id']),
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('إلغاء'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 👈 يخلي النصوص تلتف تحت
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Flexible(
            // 👈 بدل Expanded
            child: Text(
              '$label: $value',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              softWrap: true, // يسمح يلف
              overflow: TextOverflow.clip, // يقص لو زاد
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حدث خطأ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                Text(
                  _error ?? '',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _loadInitial,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد حجوزات حتى الآن',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر حجوزاتك هنا عند إنشائها',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                widget.onNavigateToTab?.call(1), // 👈 يروح لتبويب الدورات
            icon: const Icon(Icons.add),
            label: const Text('تصفح الدورات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange; // قيد الانتظار
      case 'pre_approved':
        return AppColors.info; // موافقة أولية
      case 'confirmed':
        return AppColors.success; // تم التأكيد
      case 'rejected':
        return AppColors.error; // مرفوض
      case 'cancelled':
        return Colors.grey; // ملغي
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
        title: const Text('إلغاء الحجز'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الحجز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }
}
