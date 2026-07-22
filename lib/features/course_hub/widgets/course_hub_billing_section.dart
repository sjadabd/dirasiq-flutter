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
      _c.ensureSectionLoaded(CourseHubSection.billing);
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
    final amount = _money(
      invoice['amount_due'] ??
          invoice['amountDue'] ??
          invoice['amount'] ??
          invoice['total'],
    );
    final remaining = _money(
      invoice['remaining_amount'] ??
          invoice['remainingAmount'] ??
          invoice['remaining'],
    );
    final paid = _money(
      invoice['amount_paid'] ?? invoice['amountPaid'] ?? invoice['paid'],
    );
    final status = (invoice['invoice_status'] ??
            invoice['invoiceStatus'] ??
            invoice['status'] ??
            '')
        .toString();
    final id = (invoice['id'] ?? '').toString();
    final courseName =
        (invoice['course_name'] ?? invoice['courseName'] ?? '').toString();

    return CourseHubRow(
      icon: Icons.payments_outlined,
      label: courseName.isNotEmpty ? courseName : 'فاتورة بـ $amount د.ع',
      subtitle: 'المدفوع: $paid د.ع · المتبقّي: $remaining د.ع',
      trailing: CourseHubBadge(
        label: _statusLabel(status),
        color: _statusColor(status),
      ),
      onTap: id.isEmpty
          ? null
          : () => Get.to(() => InvoiceDetailsScreen(invoiceId: id)),
    );
  }

  String _money(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(0);
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
        return 'معلّق';
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
      default:
        return Colors.blueGrey;
    }
  }
}
