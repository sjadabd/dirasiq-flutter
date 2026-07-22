// Course Hub — Billing section.
//
// Surfaces invoices for this course (all statuses). Tapping "عرض الكل"
// opens StudentInvoicesScreen filtered by courseId.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/features/invoices/screens/invoice_details_screen.dart';
import 'package:mulhimiq/features/invoices/screens/student_invoices_screen.dart';

class CourseHubBillingSection extends StatefulWidget {
  const CourseHubBillingSection({super.key});

  @override
  State<CourseHubBillingSection> createState() => _CourseHubBillingSectionState();
}

class _CourseHubBillingSectionState extends State<CourseHubBillingSection> {
  CourseHubController get _c => Get.find<CourseHubController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force refresh so stale empty/zero rows from older hub logic are replaced.
      _c.ensureSectionLoaded(CourseHubSection.billing, force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final archive = _c.isArchiveMode;
      Widget body;
      final loading = _c.invoicesLoading.value && _c.invoices.isEmpty;
      final err = _c.invoicesError.value;
      if (loading) {
        body = const CourseHubSectionLoading();
      } else if (err.isNotEmpty && _c.invoices.isEmpty) {
        body = CourseHubSectionError(
          message: err,
          onRetry: () => _c.ensureSectionLoaded(CourseHubSection.billing),
        );
      } else if (_c.invoices.isEmpty) {
        body = Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            archive
                ? 'لا توجد فواتير في أرشيف هذه الدورة.'
                : 'لا توجد فواتير لهذه الدورة.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        );
      } else {
        body = Column(
          children: _c.invoices.take(5).map(_buildInvoiceRow).toList(),
        );
      }

      return CourseHubSectionShell(
        icon: Icons.receipt_long_outlined,
        iconColor: Colors.deepOrange,
        title: archive ? 'أرشيف الفواتير' : 'الفواتير',
        action: TextButton(
          onPressed: () => Get.to(
            () => const StudentInvoicesScreen(),
            arguments: {'courseId': _c.courseId},
          ),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('عرض الكل', style: TextStyle(fontSize: 12)),
        ),
        child: body,
      );
    });
  }

  Widget _buildInvoiceRow(Map<String, dynamic> invoice) {
    final due = _toDouble(
      invoice['amount_due'] ?? invoice['amountDue'] ?? invoice['amount'],
    );
    final paid = _toDouble(
      invoice['amount_paid'] ?? invoice['amountPaid'] ?? invoice['paid'],
    );
    // remaining_amount is a generated DB column; fall back to due - paid.
    var remain = _toDouble(
      invoice['remaining_amount'] ??
          invoice['remainingAmount'] ??
          invoice['remaining'],
    );
    if (remain <= 0 && due > 0 && paid < due) {
      remain = due - paid;
    }
    final status = (invoice['invoice_status'] ??
            invoice['invoiceStatus'] ??
            invoice['status'] ??
            '')
        .toString()
        .toLowerCase();
    final id = (invoice['id'] ?? '').toString();
    final courseName =
        (invoice['course_name'] ?? invoice['courseName'] ?? '').toString();

    return CourseHubRow(
      icon: Icons.payments_outlined,
      label: courseName.isNotEmpty
          ? courseName
          : 'فاتورة بـ ${_fmt(due)} د.ع',
      subtitle:
          'قيمة الفاتورة: ${_fmt(due)} د.ع · المدفوع: ${_fmt(paid)} د.ع · المتبقّي: ${_fmt(remain)} د.ع',
      trailing: CourseHubBadge(
        label: _statusLabel(status),
        color: _statusColor(status),
      ),
      onTap: id.isEmpty
          ? null
          : () => Get.to(() => InvoiceDetailsScreen(invoiceId: id)),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '').trim();
    return double.tryParse(s) ?? 0;
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) {
      final n = v.toInt().toString();
      final buf = StringBuffer();
      for (var i = 0; i < n.length; i++) {
        final fromEnd = n.length - i;
        buf.write(n[i]);
        if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
      }
      return buf.toString();
    }
    return v.toStringAsFixed(0);
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'paid':
        return 'مدفوع';
      case 'partial':
        return 'جزئي';
      case 'overdue':
        return 'متأخر';
      case 'pending':
        return 'قيد السداد';
      case 'cancelled':
      case 'canceled':
        return 'ملغاة';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'pending':
        return Colors.blueGrey;
      default:
        return Colors.blueGrey;
    }
  }
}
