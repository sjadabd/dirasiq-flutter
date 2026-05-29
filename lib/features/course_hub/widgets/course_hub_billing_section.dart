// Course Hub — Billing section.
//
// Surfaces unpaid + partial invoices for this course as a compact list.
// Tapping the section CTA opens the full invoices screen filtered by
// courseId.

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
            'لا توجد فواتير معلّقة لهذه الدورة.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        );
      } else {
        body = Column(
          children: _c.invoices.take(3).map(_buildInvoiceRow).toList(),
        );
      }

      return CourseHubSectionShell(
        icon: Icons.receipt_long_outlined,
        iconColor: Colors.deepOrange,
        title: 'الفواتير',
        action: TextButton(
          onPressed: () => Get.to(() => const StudentInvoicesScreen()),
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
    final amount = (invoice['amount'] ?? invoice['total'] ?? 0).toString();
    final remaining = (invoice['remaining'] ?? invoice['remainingAmount'] ?? 0).toString();
    final status = (invoice['status'] ?? invoice['invoiceStatus'] ?? '').toString();
    final id = (invoice['id'] ?? '').toString();

    return CourseHubRow(
      icon: Icons.payments_outlined,
      label: 'فاتورة بـ $amount د.ع',
      subtitle: 'المتبقّي: $remaining د.ع',
      trailing: CourseHubBadge(
        label: _statusLabel(status),
        color: _statusColor(status),
      ),
      onTap: id.isEmpty
          ? null
          : () => Get.to(() => InvoiceDetailsScreen(invoiceId: id)),
    );
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
      default:
        return 'معلّق';
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
