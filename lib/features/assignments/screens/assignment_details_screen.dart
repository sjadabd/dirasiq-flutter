// Student → Assignment details (MulhimIQ design-system pass).
//
// Route: pushed via Get.to / MaterialPageRoute from the assignments list
// (AssignmentDetailsScreen(assignmentId)). Backed by
// ApiService.fetchAssignmentById / fetchMyAssignmentSubmission /
// submitAssignment. ALL behaviour — the fetch, the submission window /
// type validation, the file picker + base64 upload, the submit API call, the
// view-submission dialog, and the two conditional buttons' visibility rules —
// is UNCHANGED. Only the presentation was migrated from AppColors to the
// design system, and loading-skeleton / error / unavailable states were added.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/utils/time_format.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  final String assignmentId;
  const AssignmentDetailsScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentDetailsScreen> createState() =>
      _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? assignment;
  Map<String, dynamic>? mySubmission;
  bool _loading = true;
  String? _error;

  ThemeData _ds(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? MqTheme.dark()
      : MqTheme.light();

  // ───────────────────────── data (UNCHANGED) ────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final res = await _api.fetchAssignmentById(widget.assignmentId);
      final data = res['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['data'])
          : <String, dynamic>{};
      // The API returns the student's submission under `meta.mySubmission`
      // (the canonical envelope); older builds read it from the top level.
      // Accept both so the grade/feedback/status actually show.
      final meta = res['meta'] is Map
          ? Map<String, dynamic>.from(res['meta'] as Map)
          : const <String, dynamic>{};
      final subRaw = res['mySubmission'] ?? meta['mySubmission'];
      final sub = subRaw is Map ? Map<String, dynamic>.from(subRaw) : null;
      setState(() {
        assignment = data;
        mySubmission = sub;
        _loading = false;
      });
    } catch (e) {
      final msg = _cleanErrorMessage(e);
      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  String _cleanErrorMessage(Object e) {
    var s = e.toString();
    s = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
    s = s.replaceFirst(RegExp(r'^DioException.*?:\s*'), '');
    if (s.trim().isEmpty) return 'حدث خطأ غير متوقع';
    return s;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      return '$day/$month/${d.year} - ${formatTime12(d)}';
    } catch (_) {
      return iso;
    }
  }

  String _getSubmissionTypeLabel(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'text':
        return 'نصّي';
      case 'file':
        return 'ملف';
      case 'link':
        return 'رابط';
      case 'mixed':
        return 'متعدّد';
      case 'paper':
      case 'physical':
        return 'ورقي';
      case 'online':
      case 'electronic':
        return 'إلكتروني';
      default:
        return (type == null || type.isEmpty) ? '-' : type;
    }
  }

  String _toAbsoluteUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r"/+$"), '');
    if (!s.startsWith('/')) s = '/$s';
    return '$base$s';
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
          _showMessage('لا يمكن فتح الرابط');
        }
      }
    } catch (e) {
      _showMessage('خطأ في فتح الرابط: $e');
    }
  }

  // ─── status mapping ─────────────────────────────────────────────────────────

  (String, MqBadgeTone, IconData) _submissionStatusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'graded':
        return ('مُقَيَّم', MqBadgeTone.success, Icons.check_circle_rounded);
      case 'submitted':
        return ('مُسَلَّم', MqBadgeTone.accent, Icons.upload_file_rounded);
      case 'pending':
        return (
          'قيد المراجعة',
          MqBadgeTone.orange,
          Icons.hourglass_bottom_rounded,
        );
      case 'rejected':
        return ('مرفوض', MqBadgeTone.error, Icons.cancel_rounded);
      default:
        return (
          status.isEmpty ? 'لم يُسلَّم' : status,
          MqBadgeTone.neutral,
          Icons.info_outline_rounded,
        );
    }
  }

  // ───────────────────────── build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _ds(context),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            appBar: AppBar(title: const Text('تفاصيل الواجب')),
            body: _loading
                ? _skeleton(context)
                : _error != null
                ? _errorView(context)
                : assignment == null
                ? _unavailable(context)
                : RefreshIndicator(onRefresh: _fetch, child: _content(context)),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        MqSpacing.lg,
        MqSpacing.lg,
        MqSpacing.lg,
        MqSpacing.xxxl,
      ),
      children: [
        _headerCard(context),
        MqSpacing.gapMd,
        _infoCard(context),
        if (_attachmentsCard(context) case final w?) ...[MqSpacing.gapMd, w],
        if (_resourcesCard(context) case final w?) ...[MqSpacing.gapMd, w],
        if (_evaluationCard(context) case final w?) ...[MqSpacing.gapMd, w],
        ..._actionButtons(context),
      ],
    );
  }

  // ─── header (title + course/teacher + status + description) ──────────────────

  Widget _headerCard(BuildContext context) {
    final m = context.mq;
    final a = assignment!;
    final title = a['title']?.toString() ?? 'واجب';
    final desc = (a['description']?.toString() ?? '').trim();
    final courseName =
        (a['course_name'] ??
                a['courseName'] ??
                (a['course'] is Map ? a['course']['name'] : null) ??
                '')
            .toString()
            .trim();
    final teacherName =
        (a['teacher_name'] ??
                a['teacherName'] ??
                (a['teacher'] is Map ? a['teacher']['name'] : null) ??
                '')
            .toString()
            .trim();
    final subStatus = (mySubmission?['status']?.toString() ?? '').toLowerCase();
    final (label, tone, icon) = _submissionStatusMeta(subStatus);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: m.accentSoft,
                  borderRadius: MqRadius.brMd,
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: m.accent,
                  size: MqSize.iconMd,
                ),
              ),
              MqSpacing.gapMd,
              Expanded(child: Text(title, style: context.text.titleMedium)),
              MqSpacing.gapSm,
              MqBadge(label: label, tone: tone, icon: icon),
            ],
          ),
          if (courseName.isNotEmpty || teacherName.isNotEmpty) ...[
            MqSpacing.gapSm,
            Wrap(
              spacing: MqSpacing.xs,
              runSpacing: MqSpacing.xxs,
              children: [
                if (courseName.isNotEmpty)
                  MqBadge(
                    label: courseName,
                    tone: MqBadgeTone.neutral,
                    icon: Icons.menu_book_outlined,
                  ),
                if (teacherName.isNotEmpty)
                  MqBadge(
                    label: teacherName,
                    tone: MqBadgeTone.neutral,
                    icon: Icons.person_outline_rounded,
                  ),
              ],
            ),
          ],
          if (desc.isNotEmpty) ...[
            MqSpacing.gapSm,
            Text(desc, style: context.text.bodyMedium?.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }

  // ─── info card (dates / type / max score) ───────────────────────────────────

  Widget _infoCard(BuildContext context) {
    final m = context.mq;
    final a = assignment!;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, 'معلومات الواجب', Icons.info_outline_rounded),
          MqSpacing.gapSm,
          _infoRow(
            context,
            Icons.calendar_today_rounded,
            'تاريخ الإسناد',
            _formatDate(a['assigned_date']?.toString()),
            m.accent,
          ),
          _infoRow(
            context,
            Icons.event_rounded,
            'تاريخ التسليم',
            _formatDate(a['due_date']?.toString()),
            m.orange,
          ),
          _infoRow(
            context,
            Icons.upload_file_rounded,
            'نوع التسليم',
            _getSubmissionTypeLabel(a['submission_type']?.toString()),
            m.accent,
          ),
          if (a['max_score'] != null)
            _infoRow(
              context,
              Icons.star_rounded,
              'الدرجة القصوى',
              a['max_score'].toString(),
              m.success,
            ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: MqRadius.brSm,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          MqSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall),
                Text(
                  value,
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── assignment attachments (images grid + files) ───────────────────────────

  Widget? _attachmentsCard(BuildContext context) {
    final m = context.mq;
    final attachments = assignment!['attachments'];
    if (attachments is! Map) return null;
    final files = attachments['files'];
    if (files is! List || files.isEmpty) return null;

    final images = files
        .where(
          (f) => f is Map && (f['type']?.toString().toLowerCase() == 'image'),
        )
        .toList();
    final others = files
        .where(
          (f) =>
              !(f is Map && (f['type']?.toString().toLowerCase() == 'image')),
        )
        .toList();

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, 'المرفقات', Icons.attach_file_rounded),
          MqSpacing.gapSm,
          if (images.isNotEmpty) ...[
            Text('الصور', style: context.text.labelMedium),
            MqSpacing.gapXs,
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemCount: images.length,
              itemBuilder: (_, i) {
                final it = images[i] as Map;
                final imgUrl = _toAbsoluteUrl((it['url'] ?? '').toString());
                return GestureDetector(
                  onTap: () => _openImagePreview(imgUrl),
                  child: ClipRRect(
                    borderRadius: MqRadius.brMd,
                    child: Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: m.fill2,
                        child: Icon(Icons.broken_image, color: m.ink3),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (others.isNotEmpty) MqSpacing.gapSm,
          ],
          if (others.isNotEmpty) ...[
            Text('ملفات', style: context.text.labelMedium),
            MqSpacing.gapXs,
            ...others.map((f) => _attachmentItem(context, f)),
          ],
        ],
      ),
    );
  }

  Widget _attachmentItem(BuildContext context, dynamic file) {
    final m = context.mq;
    if (file is! Map) return const SizedBox.shrink();
    final url = file['url']?.toString() ?? '';
    final name = file['name']?.toString() ?? 'ملف';
    final type = file['type']?.toString() ?? '';
    if (type == 'image') return const SizedBox.shrink();
    final isPdf = type == 'pdf';
    final color = isPdf ? m.error : m.ink3;

    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.xs),
      child: MqSurface(
        tone: MqSurfaceTone.neutral,
        padding: const EdgeInsets.all(MqSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: MqRadius.brSm,
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.insert_drive_file_rounded,
                color: color,
                size: 16,
              ),
            ),
            MqSpacing.gapSm,
            Expanded(
              child: Text(
                name,
                style: context.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => _launchUrl(_toAbsoluteUrl(url)),
              icon: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.open_in_new_rounded,
                size: 18,
                color: m.accent,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── resources / links ──────────────────────────────────────────────────────

  Widget? _resourcesCard(BuildContext context) {
    final resources = assignment!['resources'];
    if (resources is! List || resources.isEmpty) return null;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, 'المصادر والروابط', Icons.link_rounded),
          MqSpacing.gapSm,
          ...resources.map((r) => _resourceItem(context, r)),
        ],
      ),
    );
  }

  Widget _resourceItem(BuildContext context, dynamic resource) {
    final m = context.mq;
    if (resource is! Map) return const SizedBox.shrink();
    final url = resource['url']?.toString() ?? '';
    final title = resource['title']?.toString() ?? 'رابط';
    final type = (resource['type']?.toString() ?? 'link').toLowerCase();

    final (IconData icon, Color color) = switch (type) {
      'video' => (Icons.play_circle_outline_rounded, m.error),
      'pdf' => (Icons.picture_as_pdf_rounded, m.error),
      'image' => (Icons.image_rounded, m.success),
      'doc' || 'article' => (Icons.description_rounded, m.orange),
      _ => (Icons.link_rounded, m.accent),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.xs),
      child: MqSurface(
        tone: MqSurfaceTone.neutral,
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: MqRadius.brMd,
          onTap: () => _launchUrl(_toAbsoluteUrl(url)),
          child: Padding(
            padding: const EdgeInsets.all(MqSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: MqRadius.brSm,
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                MqSpacing.gapSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        url,
                        style: context.text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── evaluation (grade / status / feedback) ─────────────────────────────────

  Widget? _evaluationCard(BuildContext context) {
    final m = context.mq;
    final sub = mySubmission;
    if (sub == null) return null;

    final maxScore = assignment?['max_score'];
    final score = sub['score'];
    final feedback = (sub['feedback']?.toString() ?? '').trim();
    final status = (sub['status']?.toString() ?? '').toLowerCase();
    final (statusLabel, tone, icon) = _submissionStatusMeta(status);
    final color = _toneColor(context, tone);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, 'تقييم المعلم', Icons.grading_rounded),
          MqSpacing.gapSm,
          _infoRow(
            context,
            Icons.star_rounded,
            'الدرجة',
            (score != null && maxScore != null)
                ? '$score / $maxScore'
                : (score?.toString() ?? '-'),
            m.orange,
          ),
          _infoRow(context, icon, 'الحالة', statusLabel, color),
          if (feedback.isNotEmpty) ...[
            MqSpacing.gapXs,
            MqSurface(
              tone: MqSurfaceTone.accent,
              padding: const EdgeInsets.all(MqSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.comment_rounded, size: 14, color: m.accent),
                  MqSpacing.gapXs,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملاحظة المعلم',
                          style: context.text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(feedback, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── action buttons (visibility logic UNCHANGED) ────────────────────────────

  List<Widget> _actionButtons(BuildContext context) {
    final out = <Widget>[];

    // "عرض إجابتي" — show when a submission exists (paper mode requires content).
    final showView = (() {
      String deliveryMode = '';
      final atts = assignment?['attachments'];
      if (atts is Map) {
        final meta = atts['meta'];
        if (meta is Map) {
          deliveryMode = (meta['delivery_mode'] ?? meta['deliveryMode'] ?? '')
              .toString()
              .toLowerCase();
        }
      }
      if (mySubmission == null) return false;
      if (deliveryMode == 'paper') {
        final content = (mySubmission?['content_text']?.toString() ?? '')
            .trim();
        final link = (mySubmission?['link_url']?.toString() ?? '').trim();
        final sAtts = mySubmission?['attachments'];
        final hasAtts = sAtts is List && sAtts.isNotEmpty;
        return content.isNotEmpty || link.isNotEmpty || hasAtts;
      }
      return true;
    })();

    // "إرسال إجابتي" — hidden when graded or paper delivery.
    final showSubmit = (() {
      final status = (mySubmission?['status']?.toString() ?? '').toLowerCase();
      final isGraded = status == 'graded';
      String deliveryMode = '';
      final atts = assignment?['attachments'];
      if (atts is Map) {
        final meta = atts['meta'];
        if (meta is Map) {
          deliveryMode = (meta['delivery_mode'] ?? meta['deliveryMode'] ?? '')
              .toString()
              .toLowerCase();
        }
      }
      final isPaper = deliveryMode == 'paper';
      return !(isGraded || isPaper);
    })();

    if (showView) {
      out
        ..add(MqSpacing.gapMd)
        ..add(
          MqButton(
            label: 'عرض إجابتي',
            icon: Icons.visibility_rounded,
            variant: MqButtonVariant.secondary,
            onPressed: _openViewSubmission,
          ),
        );
    }
    if (showSubmit) {
      out
        ..add(MqSpacing.gapSm)
        ..add(
          MqButton(
            label: 'إرسال إجابتي',
            icon: Icons.assignment_turned_in_rounded,
            onPressed: _openSubmitBottomSheet,
          ),
        );
    }
    return out;
  }

  // ───────────────────────── helpers ─────────────────────────────────────────

  Widget _cardHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: MqSize.iconSm, color: context.mq.accent),
        MqSpacing.gapXs,
        Text(title, style: context.text.titleSmall),
      ],
    );
  }

  Color _toneColor(BuildContext context, MqBadgeTone tone) {
    final m = context.mq;
    return switch (tone) {
      MqBadgeTone.orange => m.orange,
      MqBadgeTone.accent => m.accent,
      MqBadgeTone.success => m.success,
      MqBadgeTone.error => m.error,
      MqBadgeTone.neutral => m.ink3,
    };
  }

  // ───────────────────────── states ──────────────────────────────────────────

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxxl),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
              MqSpacing.gapMd,
              Text(
                _error ?? 'حدث خطأ',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
              MqSpacing.gapMd,
              MqButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                expand: false,
                onPressed: _fetch,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _unavailable(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxxl),
        Center(
          child: Column(
            children: [
              Icon(Icons.assignment_outlined, size: 44, color: m.ink3),
              MqSpacing.gapMd,
              Text('الواجب غير متاح', style: context.text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    Widget block(double h) => Container(
      height: h,
      decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brLg),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        block(110),
        MqSpacing.gapMd,
        block(150),
        MqSpacing.gapMd,
        block(90),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Submission flows — LOGIC UNCHANGED, chrome restyled to the design system.
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _openImagePreview(String url) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openViewSubmission() async {
    final assignmentId = assignment?['id']?.toString() ?? widget.assignmentId;
    Map<String, dynamic>? sub;
    try {
      sub = await _api.fetchMyAssignmentSubmission(assignmentId);
    } catch (e) {
      sub = mySubmission;
      _showMessage(_cleanErrorMessage(e));
    }
    if (sub == null) {
      _showMessage('لا يوجد تسليم لعرضه');
      return;
    }
    if (mounted) setState(() => mySubmission = sub);
    if (!mounted) return;

    final String contentText = (sub['content_text']?.toString() ?? '').trim();
    final String linkUrl = (sub['link_url']?.toString() ?? '').trim();
    final List atts = (sub['attachments'] is List)
        ? List.from(sub['attachments'])
        : const [];

    await showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: _ds(ctx),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (ctx) {
              final m = ctx.mq;
              return Dialog(
                backgroundColor: m.card,
                shape: RoundedRectangleBorder(borderRadius: MqRadius.brXl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(MqSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              Icons.assignment_turned_in_rounded,
                              color: m.accent,
                              size: MqSize.iconMd,
                            ),
                            MqSpacing.gapSm,
                            Text('إجابتي', style: ctx.text.titleMedium),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MqSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (contentText.isNotEmpty) ...[
                                Text(
                                  'النص',
                                  style: ctx.text.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(contentText, style: ctx.text.bodySmall),
                                MqSpacing.gapSm,
                              ],
                              if (linkUrl.isNotEmpty) ...[
                                Text(
                                  'الرابط',
                                  style: ctx.text.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () =>
                                      _launchUrl(_toAbsoluteUrl(linkUrl)),
                                  child: Text(
                                    linkUrl,
                                    style: ctx.text.bodySmall?.copyWith(
                                      color: m.accent,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                MqSpacing.gapSm,
                              ],
                              if (atts.isNotEmpty) ...[
                                Text(
                                  'المرفقات',
                                  style: ctx.text.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...atts.map(
                                  (a) => _submissionAttachment(ctx, a),
                                ),
                              ],
                              if (contentText.isEmpty &&
                                  linkUrl.isEmpty &&
                                  atts.isEmpty)
                                Text(
                                  'لا توجد تفاصيل للإجابة.',
                                  style: ctx.text.bodySmall,
                                ),
                              MqSpacing.gapSm,
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(MqSpacing.md),
                        child: MqButton(
                          label: 'إغلاق',
                          variant: MqButtonVariant.secondary,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _submissionAttachment(BuildContext ctx, dynamic a) {
    final m = ctx.mq;
    if (a is! Map) return const SizedBox.shrink();
    final String type = (a['type']?.toString() ?? '').toLowerCase();
    final String name = a['name']?.toString() ?? 'ملف';
    final String url = (a['url']?.toString() ?? '').trim();
    final String base64 = (a['base64']?.toString() ?? '').trim();

    if (type == 'image') {
      Widget? imageWidget;
      if (url.isNotEmpty) {
        final abs = _toAbsoluteUrl(url);
        imageWidget = GestureDetector(
          onTap: () => _openImagePreview(abs),
          child: ClipRRect(
            borderRadius: MqRadius.brMd,
            child: Image.network(
              abs,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                color: m.fill2,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image, size: 36, color: m.ink3),
              ),
            ),
          ),
        );
      } else if (base64.isNotEmpty) {
        final bytes = UriData.parse(base64).contentAsBytes();
        imageWidget = GestureDetector(
          onTap: () => showDialog(
            context: ctx,
            builder: (c2) => Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: MqRadius.brMd,
            child: Image.memory(
              bytes,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );
      }
      if (imageWidget == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: MqSpacing.xs),
        child: imageWidget,
      );
    }

    final isPdf = type == 'pdf';
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.xs),
      child: MqSurface(
        tone: MqSurfaceTone.neutral,
        padding: const EdgeInsets.all(MqSpacing.sm),
        child: Row(
          children: [
            Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.insert_drive_file_rounded,
              size: 18,
              color: isPdf ? m.error : m.ink3,
            ),
            MqSpacing.gapSm,
            Expanded(
              child: Text(
                name,
                style: ctx.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () {
                if (url.isNotEmpty) {
                  _launchUrl(_toAbsoluteUrl(url));
                } else if (base64.isNotEmpty) {
                  _showMessage('لا يمكن فتح الملف المضغوط هنا');
                } else {
                  _showMessage('لا يمكن فتح المرفق');
                }
              },
              icon: Icon(Icons.open_in_new_rounded, size: 18, color: m.accent),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmitBottomSheet() async {
    final assignmentId = assignment?['id']?.toString() ?? widget.assignmentId;

    Map<String, dynamic>? existing;
    try {
      existing = await _api.fetchMyAssignmentSubmission(assignmentId);
    } catch (e) {
      _showMessage(_cleanErrorMessage(e));
    }

    final contentController = TextEditingController(
      text: existing?['content_text']?.toString() ?? '',
    );
    final linkController = TextEditingController(
      text: existing?['link_url']?.toString() ?? '',
    );
    String status = (existing?['status']?.toString() ?? 'submitted');

    String submissionType =
        (assignment?['submission_type']?.toString() ??
                assignment?['submissionType']?.toString() ??
                '')
            .toLowerCase();
    const allowedTypes = {'text', 'link', 'file', 'mixed'};
    if (!allowedTypes.contains(submissionType) ||
        submissionType == 'electronic' ||
        submissionType == 'online') {
      submissionType = 'mixed';
    }

    final assignedIso =
        (assignment?['assigned_date'] ??
                assignment?['assigned_at'] ??
                assignment?['assignedAt'])
            ?.toString();
    final dueIso =
        (assignment?['due_date'] ??
                assignment?['due_at'] ??
                assignment?['dueAt'])
            ?.toString();
    final bool isActive =
        (assignment?['is_active'] == true) || (assignment?['isActive'] == true);

    DateTime? assignedAt;
    DateTime? dueAt;
    try {
      assignedAt = assignedIso != null
          ? DateTime.parse(assignedIso).toLocal()
          : null;
    } catch (_) {}
    try {
      dueAt = dueIso != null ? DateTime.parse(dueIso).toLocal() : null;
    } catch (_) {}

    bool submitting = false;
    final List<Map<String, dynamic>> attachments = [];

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: _ds(ctx),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (ctx) {
              final m = ctx.mq;
              return Container(
                decoration: BoxDecoration(
                  color: m.card,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + MqSpacing.md,
                  left: MqSpacing.lg,
                  right: MqSpacing.lg,
                  top: MqSpacing.md,
                ),
                child: StatefulBuilder(
                  builder: (context, setModal) {
                    final bool showText =
                        submissionType == 'text' || submissionType == 'mixed';
                    final bool showLink =
                        submissionType == 'link' || submissionType == 'mixed';
                    final bool showFiles =
                        submissionType == 'file' || submissionType == 'mixed';

                    Future<void> pickFiles({required bool images}) async {
                      try {
                        final res = await FilePicker.platform.pickFiles(
                          type: images ? FileType.image : FileType.custom,
                          allowMultiple: true,
                          allowedExtensions: images ? null : ['pdf'],
                          withData: true,
                        );
                        if (res == null) return;
                        for (final f in res.files) {
                          final name = f.name;
                          final ext = (f.extension ?? '').toLowerCase();
                          final bytes =
                              f.bytes ??
                              (f.path != null
                                  ? await File(f.path!).readAsBytes()
                                  : null);
                          if (bytes == null) continue;
                          final b64 = base64Encode(bytes);
                          String type;
                          String mime;
                          if (images ||
                              ext == 'png' ||
                              ext == 'jpg' ||
                              ext == 'jpeg') {
                            type = 'image';
                            mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                          } else {
                            type = 'pdf';
                            mime = 'application/pdf';
                          }
                          final dataUri = 'data:$mime;base64,$b64';
                          setModal(
                            () => attachments.add({
                              'type': type,
                              'name': name,
                              'base64': dataUri,
                            }),
                          );
                        }
                      } catch (e) {
                        _showMessage('فشل اختيار الملفات: $e');
                      }
                    }

                    String? validateInputs() {
                      if (!isActive) return 'الواجب غير مفعّل حالياً';
                      final now = DateTime.now();
                      if (assignedAt != null && now.isBefore(assignedAt))
                        return 'لم يبدأ وقت التسليم بعد';
                      if (dueAt != null && now.isAfter(dueAt))
                        return 'انتهى وقت التسليم';

                      final textVal = contentController.text.trim();
                      final linkVal = linkController.text.trim();
                      final hasText = textVal.isNotEmpty;
                      final hasLink = linkVal.isNotEmpty;
                      final hasFiles = attachments.isNotEmpty;
                      final hasAny = hasText || hasLink || hasFiles;

                      switch (submissionType) {
                        case 'text':
                          if (!hasText)
                            return 'نوع التسليم نصي، يرجى إدخال نص الإجابة';
                          break;
                        case 'link':
                          if (!hasLink)
                            return 'نوع التسليم رابط، يرجى إدخال رابط صحيح';
                          break;
                        case 'file':
                          if (!hasFiles)
                            return 'هذا الواجب يتطلب رفع ملفات (صورة أو PDF)';
                          break;
                        case 'mixed':
                          if (!hasAny)
                            return 'يرجى إدخال نص أو رابط (أو مرفقات) للتسليم';
                          break;
                      }
                      return null;
                    }

                    Future<void> doSubmit() async {
                      if (submitting) return;
                      final err = validateInputs();
                      if (err != null) {
                        _showMessage(err);
                        return;
                      }
                      setModal(() => submitting = true);
                      try {
                        final nav = Navigator.of(context);
                        final res = await _api.submitAssignment(
                          assignmentId: assignmentId,
                          contentText: contentController.text.trim().isEmpty
                              ? null
                              : contentController.text.trim(),
                          linkUrl: linkController.text.trim().isEmpty
                              ? null
                              : linkController.text.trim(),
                          attachments: attachments,
                          status: status.isEmpty ? 'submitted' : status,
                        );
                        final data = res['data'] is Map<String, dynamic>
                            ? Map<String, dynamic>.from(res['data'])
                            : null;
                        if (!mounted) return;
                        if (data != null) setState(() => mySubmission = data);
                        if (nav.mounted) nav.pop();
                        _showMessage('تم إرسال الإجابة بنجاح');
                        if (!mounted) return;
                        await _fetch();
                      } catch (e) {
                        _showMessage(_cleanErrorMessage(e));
                      } finally {
                        if (context.mounted) setModal(() => submitting = false);
                      }
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: m.line,
                                borderRadius: MqRadius.brPill,
                              ),
                            ),
                          ),
                          MqSpacing.gapMd,
                          Row(
                            children: [
                              Icon(
                                Icons.assignment_turned_in_rounded,
                                color: m.accent,
                                size: MqSize.iconMd,
                              ),
                              MqSpacing.gapSm,
                              Text('إرسال إجابتي', style: ctx.text.titleMedium),
                            ],
                          ),
                          MqSpacing.gapMd,
                          if (showText) ...[
                            TextField(
                              controller: contentController,
                              maxLines: 4,
                              style: ctx.text.bodyMedium,
                              decoration: _fieldDecoration(ctx, 'نص الإجابة'),
                            ),
                            MqSpacing.gapSm,
                          ],
                          if (showLink) ...[
                            TextField(
                              controller: linkController,
                              style: ctx.text.bodyMedium,
                              decoration: _fieldDecoration(
                                ctx,
                                'رابط خارجي',
                                hint: 'https://...',
                              ),
                            ),
                            MqSpacing.gapSm,
                          ],
                          if (showFiles)
                            MqSurface(
                              tone: MqSurfaceTone.neutral,
                              padding: const EdgeInsets.all(MqSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.attach_file_rounded,
                                        size: 14,
                                        color: m.accent,
                                      ),
                                      MqSpacing.gapXs,
                                      Text(
                                        'المرفقات (اختياري)',
                                        style: ctx.text.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  MqSpacing.gapSm,
                                  Row(
                                    children: [
                                      MqButton(
                                        label: 'صورة',
                                        icon: Icons.image_rounded,
                                        variant: MqButtonVariant.secondary,
                                        size: MqButtonSize.small,
                                        expand: false,
                                        onPressed: () =>
                                            pickFiles(images: true),
                                      ),
                                      MqSpacing.gapSm,
                                      MqButton(
                                        label: 'PDF',
                                        icon: Icons.picture_as_pdf_rounded,
                                        variant: MqButtonVariant.secondary,
                                        size: MqButtonSize.small,
                                        expand: false,
                                        onPressed: () =>
                                            pickFiles(images: false),
                                      ),
                                    ],
                                  ),
                                  if (attachments.isNotEmpty) ...[
                                    MqSpacing.gapSm,
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: attachments.asMap().entries.map(
                                        (e) {
                                          final i = e.key;
                                          final it = e.value;
                                          final name = (it['name'] ?? 'ملف')
                                              .toString();
                                          final type = (it['type'] ?? '')
                                              .toString();
                                          return Chip(
                                            label: Text(
                                              name,
                                              style: ctx.text.labelSmall,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            avatar: Icon(
                                              type == 'pdf'
                                                  ? Icons.picture_as_pdf_rounded
                                                  : Icons.image_rounded,
                                              size: 14,
                                            ),
                                            deleteIcon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                            ),
                                            onDeleted: () => setModal(
                                              () => attachments.removeAt(i),
                                            ),
                                            backgroundColor: m.fill,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          );
                                        },
                                      ).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          MqSpacing.gapMd,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('الحالة:', style: ctx.text.labelSmall),
                                  MqSpacing.gapXs,
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: MqSpacing.sm,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: m.accentSoft,
                                      borderRadius: MqRadius.brSm,
                                    ),
                                    child: DropdownButton<String>(
                                      value: status,
                                      underline: const SizedBox.shrink(),
                                      isDense: true,
                                      style: ctx.text.labelMedium?.copyWith(
                                        color: m.ink,
                                      ),
                                      dropdownColor: m.card,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'submitted',
                                          child: Text('مُسَلَّم'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'pending',
                                          child: Text('قيد المراجعة'),
                                        ),
                                      ],
                                      onChanged: (v) => setModal(
                                        () => status = v ?? 'submitted',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MqButton(
                                    label: 'إلغاء',
                                    variant: MqButtonVariant.text,
                                    size: MqButtonSize.small,
                                    expand: false,
                                    onPressed: submitting
                                        ? null
                                        : () => Navigator.of(ctx).pop(),
                                  ),
                                  MqSpacing.gapXs,
                                  MqButton(
                                    label: 'إرسال',
                                    icon: Icons.send_rounded,
                                    size: MqButtonSize.small,
                                    expand: false,
                                    loading: submitting,
                                    onPressed: submitting ? null : doSubmit,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: MqSpacing.xl),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext ctx,
    String label, {
    String? hint,
  }) {
    final m = ctx.mq;
    return InputDecoration(
      labelText: label,
      labelStyle: ctx.text.labelMedium,
      hintText: hint,
      hintStyle: ctx.text.labelSmall,
      filled: true,
      fillColor: m.fill,
      contentPadding: const EdgeInsets.all(MqSpacing.sm),
      border: OutlineInputBorder(
        borderRadius: MqRadius.brMd,
        borderSide: BorderSide(color: m.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: MqRadius.brMd,
        borderSide: BorderSide(color: m.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: MqRadius.brMd,
        borderSide: BorderSide(color: m.accent),
      ),
    );
  }
}
