import 'package:flutter/material.dart';

import '../design/teacher_design.dart';
import '../teacher_helpers.dart' show fmtNum;

/// Loud, persistent warning that the teacher still has unsettled student
/// invoices and/or pending reservation deposits for a course (or globally).
///
/// Intentionally hard to ignore: solid danger fill, bold copy, dual CTAs.
class TeacherCourseDebtBanner extends StatelessWidget {
  const TeacherCourseDebtBanner({
    super.key,
    required this.unpaidInvoiceAmount,
    required this.unpaidInvoiceCount,
    required this.pendingDepositAmount,
    required this.pendingDepositCount,
    this.isEnded = false,
    this.courseName,
    this.courseSummaries = const [],
    this.onOpenInvoices,
    this.onOpenDeposits,
    this.onOpenCourse,
  });

  final double unpaidInvoiceAmount;
  final int unpaidInvoiceCount;
  final double pendingDepositAmount;
  final int pendingDepositCount;
  final bool isEnded;
  final String? courseName;

  /// Optional list of `{courseName, isEnded, totalOutstanding}` for home.
  final List<Map<String, dynamic>> courseSummaries;

  final VoidCallback? onOpenInvoices;
  final VoidCallback? onOpenDeposits;
  final void Function(Map<String, dynamic> course)? onOpenCourse;

  bool get hasDebt =>
      unpaidInvoiceAmount > 0 ||
      pendingDepositAmount > 0 ||
      unpaidInvoiceCount > 0 ||
      pendingDepositCount > 0;

  @override
  Widget build(BuildContext context) {
    if (!hasDebt) return const SizedBox.shrink();

    final mq = context.mq;
    final t = context.teacher;
    final total = unpaidInvoiceAmount + pendingDepositAmount;
    final title = isEnded
        ? 'تحذير عاجل — دورة منتهية بمستحقات معلّقة'
        : 'تحذير — مستحقات وعربونات غير مسدّدة';

    final scope = (courseName != null && courseName!.trim().isNotEmpty)
        ? 'لكورس «${courseName!.trim()}»'
        : 'على حسابك';

    final body = isEnded
        ? 'انتهى تاريخ الدورة وما زال $scope يحتوي على مبالغ غير مسدّدة. سَدّد فواتير الطلاب وعربوناتهم الآن حتى تُغلق الدورة بحسابات نظيفة بلا نواقص.'
        : 'يوجد $scope مبالغ مستحقة لم تُسجَّل كمدفوعة. سَدّدها قبل انتهاء الدورة حتى لا تُؤرشف وهي ناقصة.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        color: mq.error.withValues(alpha: 0.12),
        borderRadius: MqRadius.brLg,
        border: Border.all(color: mq.error, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: mq.error.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mq.error,
                  borderRadius: MqRadius.brMd,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(
                        color: mq.error,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: context.text.bodySmall?.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          Wrap(
            spacing: MqSpacing.sm,
            runSpacing: MqSpacing.sm,
            children: [
              if (unpaidInvoiceCount > 0 || unpaidInvoiceAmount > 0)
                _Chip(
                  icon: Icons.receipt_long_outlined,
                  label:
                      'فواتير: ${fmtNum(unpaidInvoiceAmount)} د.ع ($unpaidInvoiceCount)',
                  color: mq.error,
                ),
              if (pendingDepositCount > 0 || pendingDepositAmount > 0)
                _Chip(
                  icon: Icons.savings_outlined,
                  label:
                      'عربونات: ${fmtNum(pendingDepositAmount)} د.ع ($pendingDepositCount)',
                  color: t.warning,
                ),
              _Chip(
                icon: Icons.account_balance_wallet_outlined,
                label: 'الإجمالي: ${fmtNum(total)} د.ع',
                color: mq.ink,
              ),
            ],
          ),
          if (courseSummaries.isNotEmpty) ...[
            const SizedBox(height: MqSpacing.md),
            ...courseSummaries.take(4).map((c) {
              final name = (c['courseName'] ?? c['course_name'] ?? 'دورة').toString();
              final ended = c['isEnded'] == true || c['is_ended'] == true;
              final amt = _num(c['totalOutstanding'] ?? c['total_outstanding']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: onOpenCourse == null ? null : () => onOpenCourse!(c),
                  borderRadius: MqRadius.brSm,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: MqSpacing.md,
                      vertical: MqSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: mq.page,
                      borderRadius: MqRadius.brSm,
                      border: Border.all(color: mq.error.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          ended
                              ? Icons.archive_outlined
                              : Icons.menu_book_outlined,
                          size: 18,
                          color: mq.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ended ? '$name (منتهية)' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${fmtNum(amt)} د.ع',
                          style: context.text.labelMedium?.copyWith(
                            color: mq.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: MqSpacing.md),
          Row(
            children: [
              if (onOpenInvoices != null &&
                  (unpaidInvoiceCount > 0 || unpaidInvoiceAmount > 0))
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenInvoices,
                    style: FilledButton.styleFrom(
                      backgroundColor: mq.error,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('تسوية الفواتير'),
                  ),
                ),
              if (onOpenInvoices != null &&
                  onOpenDeposits != null &&
                  (unpaidInvoiceCount > 0 || unpaidInvoiceAmount > 0) &&
                  (pendingDepositCount > 0 || pendingDepositAmount > 0))
                const SizedBox(width: MqSpacing.sm),
              if (onOpenDeposits != null &&
                  (pendingDepositCount > 0 || pendingDepositAmount > 0))
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenDeposits,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mq.error,
                      side: BorderSide(color: mq.error, width: 1.4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: const Text('تسوية العربون'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: MqRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
