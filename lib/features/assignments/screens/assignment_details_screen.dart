import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

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
  Timer? _notifTimer;
  bool _gradedNotified = false;
  // Feature flag: auto-refresh by polling notifications (disabled by default)
  final bool _enableAutoRefresh = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    // Poll for graded notification while on this screen (disabled by default)
    if (_enableAutoRefresh) {
      _notifTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _checkGradedNotice();
      });
    }
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkGradedNotice() async {
    // If already graded or we already refreshed due to a notice, skip
    final status = (mySubmission?['status']?.toString() ?? '').toLowerCase();
    if (status == 'graded' || _gradedNotified) return;
    try {
      final res = await _api.fetchMyNotifications(
        page: 1,
        limit: 10,
        type: 'homework',
      );
      final data = Map<String, dynamic>.from(res);
      final list = List<Map<String, dynamic>>.from(
        (data['items'] ?? data['notifications'] ?? data['data'] ?? []) as List,
      );
      final aid = widget.assignmentId;
      bool hit = false;
      for (final n in list) {
        final title = (n['title'] ?? '').toString();
        final msg = (n['message'] ?? '').toString();
        final ndata = n['data'] is Map<String, dynamic>
            ? n['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        final nid = (ndata['assignmentId'] ?? ndata['assignment_id'] ?? '')
            .toString();
        if ((title.contains('نتيجة واجبك') || msg.contains('نتيجة واجبك')) &&
            nid == aid) {
          hit = true;
          break;
        }
      }
      if (hit) {
        _gradedNotified = true;
        await _fetch();
      }
    } catch (_) {
      // ignore polling errors silently
    }
  }

  Future<void> _openViewSubmission() async {
    // Always try to fetch the latest submission from the server
    final assignmentId = assignment?['id']?.toString() ?? widget.assignmentId;
    Map<String, dynamic>? sub;
    try {
      sub = await _api.fetchMyAssignmentSubmission(assignmentId);
    } catch (e) {
      // Fallback to the locally cached submission if available
      sub = mySubmission;
      _showMessage(_cleanErrorMessage(e));
    }
    if (sub == null) {
      _showMessage('لا يوجد تسليم لعرضه');
      return;
    }
    // keep local state in sync with the latest fetched data
    if (mounted) {
      setState(() {
        mySubmission = sub;
      });
    }
    final String contentText = (sub['content_text']?.toString() ?? '').trim();
    final String linkUrl = (sub['link_url']?.toString() ?? '').trim();
    final List atts = (sub['attachments'] is List)
        ? List.from(sub['attachments'])
        : const [];

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('إجابتي'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (contentText.isNotEmpty) ...[
                  const Text(
                    'النص:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(contentText),
                  const SizedBox(height: 12),
                ],
                if (linkUrl.isNotEmpty) ...[
                  const Text(
                    'الرابط:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _launchUrl(_toAbsoluteUrl(linkUrl)),
                    child: Text(
                      linkUrl,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (atts.isNotEmpty) ...[
                  const Text(
                    'المرفقات:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...atts.map((a) {
                    if (a is! Map) return const SizedBox.shrink();
                    final String type = (a['type']?.toString() ?? '')
                        .toLowerCase();
                    final String name = a['name']?.toString() ?? 'ملف';
                    final String url = (a['url']?.toString() ?? '').trim();
                    final String base64 = (a['base64']?.toString() ?? '')
                        .trim();

                    // عرض الصور داخل التطبيق
                    if (type == 'image') {
                      Widget? imageWidget;
                      if (url.isNotEmpty) {
                        final abs = _toAbsoluteUrl(url);
                        imageWidget = GestureDetector(
                          onTap: () => _openImagePreview(abs),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              abs,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                color: Colors.grey.shade300,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                          ),
                        );
                      } else if (base64.isNotEmpty) {
                        final bytes = UriData.parse(base64).contentAsBytes();
                        imageWidget = GestureDetector(
                          onTap: () async {
                            await showDialog(
                              context: context,
                              builder: (c2) => Dialog(
                                insetPadding: const EdgeInsets.all(12),
                                child: InteractiveViewer(
                                  minScale: 0.5,
                                  maxScale: 4,
                                  child: Image.memory(
                                    bytes,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              bytes,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }
                      if (imageWidget == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: imageWidget,
                      );
                    }

                    // ملفات غير الصور: عرض زر لفتح الملف (مثلاً PDF)
                    final IconData icon = type == 'pdf'
                        ? Icons.picture_as_pdf
                        : Icons.insert_drive_file;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () async {
                          if (url.isNotEmpty) {
                            _launchUrl(_toAbsoluteUrl(url));
                          } else if (base64.isNotEmpty) {
                            _showMessage(
                              'لا يمكن فتح الملف المضغوط هنا، يرجى إعادة الرفع كرابط',
                            );
                          } else {
                            _showMessage('لا يمكن فتح المرفق');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(icon, size: 18),
                        label: const Text('عرض الملف'),
                      ),
                    );
                  }).toList(),
                ],
                if (contentText.isEmpty && linkUrl.isEmpty && atts.isEmpty)
                  const Text('لا توجد تفاصيل للإجابة.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  String _toAbsoluteUrl(String raw) {
    var s = (raw).trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    // Ensure single slash joining with serverBaseUrl (no encoding here)
    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r"/+$$"), '');
    if (!s.startsWith('/')) s = '/$s';
    return '$base$s';
  }

  Future<void> _openImagePreview(String url) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade300,
              child: const Center(child: Icon(Icons.broken_image, size: 48)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSubmitBottomSheet() async {
    final assignmentId = assignment?['id']?.toString() ?? widget.assignmentId;
    // حاول جلب إرسال الطالب الحالي لعرضه وتعديله
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
    // Normalize submission_type to allowed values: text|link|file|mixed
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
    // Accept multiple key variants coming from backend
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

    // Persist bottom sheet state across rebuilds
    bool submitting = false;
    final List<Map<String, dynamic>> attachments = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              // Show fields based on submission_type
              final bool showText =
                  submissionType == 'text' || submissionType == 'mixed';
              final bool showLink =
                  submissionType == 'link' || submissionType == 'mixed';
              final bool showFiles =
                  submissionType == 'file' || submissionType == 'mixed';
              Future<void> _pickFiles({required bool images}) async {
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
                      // Guess mime by extension
                      mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                    } else {
                      type = 'pdf';
                      mime = 'application/pdf';
                    }
                    final dataUri = 'data:$mime;base64,$b64';
                    setModal(() {
                      attachments.add({
                        'type': type,
                        'name': name,
                        'base64': dataUri,
                      });
                    });
                  }
                } catch (e) {
                  _showMessage('فشل اختيار الملفات: $e');
                }
              }

              String? validateInputs() {
                // Active state check
                if (!isActive) {
                  debugPrint('[submit] blocked: assignment not active');
                  return 'الواجب غير مفعّل حالياً';
                }
                // Time window checks
                final now = DateTime.now();
                if (assignedAt != null && now.isBefore(assignedAt)) {
                  debugPrint('[submit] blocked: before assigned time');
                  return 'لم يبدأ وقت التسليم بعد';
                }
                if (dueAt != null && now.isAfter(dueAt)) {
                  debugPrint('[submit] blocked: after due time');
                  return 'انتهى وقت التسليم';
                }
                final textVal = contentController.text.trim();
                final linkVal = linkController.text.trim();
                final hasText = textVal.isNotEmpty;
                final hasLink = linkVal.isNotEmpty;
                final hasFiles = attachments.isNotEmpty;
                final hasAny = hasText || hasLink || hasFiles;

                switch (submissionType) {
                  case 'text':
                    if (!hasText) {
                      debugPrint(
                        '[submit] blocked: submissionType=text requires text',
                      );
                      return 'نوع التسليم نصي، يرجى إدخال نص الإجابة';
                    }
                    break;
                  case 'link':
                    if (!hasLink) {
                      debugPrint(
                        '[submit] blocked: submissionType=link requires link',
                      );
                      return 'نوع التسليم رابط، يرجى إدخال رابط صحيح';
                    }
                    break;
                  case 'file':
                    if (!hasFiles) {
                      debugPrint(
                        '[submit] blocked: submissionType=file requires file',
                      );
                      return 'هذا الواجب يتطلب رفع ملفات (صورة أو PDF)';
                    }
                    break;
                  case 'mixed':
                    if (!hasAny) {
                      debugPrint(
                        '[submit] blocked: submissionType=mixed requires any of text/link/file',
                      );
                      return 'يرجى إدخال نص أو رابط (أو مرفقات) للتسليم';
                    }
                    break;
                  default:
                    // No strict requirement
                    break;
                }
                debugPrint('[submit] validation OK');
                return null;
              }

              Future<void> doSubmit() async {
                debugPrint('[submit] button pressed');
                if (submitting) return;
                final err = validateInputs();
                if (err != null) {
                  debugPrint(
                    '[submit] aborted due to validation error: ' + err,
                  );
                  _showMessage(err);
                  return;
                }
                setModal(() => submitting = true);
                try {
                  debugPrint(
                    '[submit] calling ApiService.submitAssignment ...',
                  );
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
                  if (data != null) {
                    setState(() {
                      mySubmission = data;
                    });
                  }
                  debugPrint('[submit] success');
                  if (mounted) Navigator.of(ctx).pop();
                  _showMessage('تم إرسال الإجابة بنجاح');
                  await _fetch();
                } catch (e) {
                  debugPrint('[submit] error: ' + e.toString());
                  _showMessage(_cleanErrorMessage(e));
                } finally {
                  debugPrint('[submit] done, resetting submitting=false');
                  if (mounted) setModal(() => submitting = false);
                }
              }

              return SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.assignment_turned_in),
                          SizedBox(width: 8),
                          Text(
                            'إرسال إجابتي',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (showText) ...[
                        TextField(
                          controller: contentController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'نص الإجابة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (showLink) ...[
                        TextField(
                          controller: linkController,
                          decoration: const InputDecoration(
                            labelText: 'رابط خارجي',
                            hintText: 'https://...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Attachments UI
                      if (showFiles)
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.attach_file),
                                    SizedBox(width: 6),
                                    Text(
                                      'المرفقات (اختياري)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _pickFiles(images: true),
                                      icon: const Icon(Icons.image),
                                      label: const Text('إضافة صورة'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _pickFiles(images: false),
                                      icon: const Icon(Icons.picture_as_pdf),
                                      label: const Text('إضافة PDF'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                                if (attachments.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: attachments.asMap().entries.map((
                                      e,
                                    ) {
                                      final i = e.key;
                                      final it = e.value;
                                      final name = (it['name'] ?? 'ملف')
                                          .toString();
                                      final type = (it['type'] ?? '')
                                          .toString();
                                      return Chip(
                                        label: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        avatar: Icon(
                                          type == 'pdf'
                                              ? Icons.picture_as_pdf
                                              : Icons.image,
                                          size: 18,
                                        ),
                                        deleteIcon: const Icon(Icons.close),
                                        onDeleted: () => setModal(() {
                                          attachments.removeAt(i);
                                        }),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runAlignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('الحالة:'),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: status,
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
                                onChanged: (v) =>
                                    setModal(() => status = v ?? 'submitted'),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: submitting
                                    ? null
                                    : () => Navigator.of(ctx).pop(),
                                icon: const Icon(Icons.close),
                                label: const Text('إلغاء'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: submitting ? null : doSubmit,
                                icon: submitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                label: const Text('إرسال'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEvaluationCard() {
    final sub = mySubmission;
    if (sub == null) return const SizedBox.shrink();

    final maxScore = assignment?['max_score'];
    final score = sub['score'];
    final feedback = (sub['feedback']?.toString() ?? '').trim();
    final status = (sub['status']?.toString() ?? '').toLowerCase();

    IconData icon;
    Color color;
    String statusLabel;
    switch (status) {
      case 'graded':
        icon = Icons.check_circle;
        color = Colors.green;
        statusLabel = 'مُقَيَّم';
        break;
      case 'submitted':
        icon = Icons.upload_file;
        color = Colors.blue;
        statusLabel = 'مُسَلَّم';
        break;
      case 'pending':
        icon = Icons.hourglass_bottom;
        color = Colors.orange;
        statusLabel = 'قيد المراجعة';
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = Colors.red;
        statusLabel = 'مرفوض';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        statusLabel = status.isEmpty ? '-' : status;
        break;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                const Text(
                  'تقييم المعلم',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.star,
              'الدرجة',
              (score != null && maxScore != null)
                  ? '$score / $maxScore'
                  : (score?.toString() ?? '-'),
              Colors.amber,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.assignment_turned_in,
              'الحالة',
              statusLabel,
              color,
            ),
            if (feedback.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.comment,
                      color: Colors.indigo,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملاحظة المعلم',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feedback,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
      final sub = res['mySubmission'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['mySubmission'])
          : null;
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
      // أظهر رسالة واضحة للطالب بما حدث حسب رد الخادم
      _showMessage(msg);
    }
  }

  // تنظيف نص الخطأ لإزالة بادئات تقنية مثل "Exception: "
  String _cleanErrorMessage(Object e) {
    var s = e.toString();
    s = s.replaceFirst(RegExp(r'^Exception:\\s*'), '');
    s = s.replaceFirst(RegExp(r'^DioException.*?:\\s*'), '');
    if (s.trim().isEmpty) return 'حدث خطأ غير متوقع';
    return s;
  }

  // عرض SnackBar برسالة ودّية
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy - hh:mm a', 'ar').format(d);
    } catch (_) {
      return iso;
    }
  }

  String _getSubmissionTypeLabel(String? type) {
    switch (type) {
      case 'online':
        return 'تسليم إلكتروني';
      case 'physical':
        return 'تسليم ورقي';
      case 'mixed':
        return 'تسليم مختلط';
      default:
        return type ?? '-';
    }
  }

  Color _getSubmissionTypeColor(String? type) {
    switch (type) {
      case 'online':
      case 'physical':
        return Colors.orange;
      case 'mixed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);

      // جرّب أول شي بالمتصفح الخارجي
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // fallback: داخل التطبيق
        if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('لا يمكن فتح الرابط')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في فتح الرابط: $e')));
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  assignment!['title']?.toString() ?? 'واجب',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if ((assignment!['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              assignment!['description'].toString(),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final assignedDate = assignment!['assigned_date'];
    final dueDate = assignment!['due_date'];
    final submissionType = assignment!['submission_type'];
    final maxScore = assignment!['max_score'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات الواجب',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.calendar_today,
              'تاريخ الإسناد',
              _formatDate(assignedDate?.toString()),
              Colors.blue,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.event,
              'تاريخ التسليم',
              _formatDate(dueDate?.toString()),
              Colors.red,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.upload_file,
              'نوع التسليم',
              _getSubmissionTypeLabel(submissionType?.toString()),
              _getSubmissionTypeColor(submissionType?.toString()),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.star,
              'الدرجة القصوى',
              maxScore?.toString() ?? '-',
              Colors.amber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsCard() {
    final attachments = assignment!['attachments'];
    if (attachments == null || attachments is! Map)
      return const SizedBox.shrink();

    final files = attachments['files'];
    if (files == null || files is! List || files.isEmpty)
      return const SizedBox.shrink();

    // Split into images and other files
    final List images = files
        .where(
          (f) => (f is Map) && (f['type']?.toString().toLowerCase() == 'image'),
        )
        .toList();
    final List others = files
        .where(
          (f) =>
              !(f is Map && (f['type']?.toString().toLowerCase() == 'image')),
        )
        .toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'المرفقات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (images.isNotEmpty) ...[
              const Text(
                'الصور',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: images.length,
                itemBuilder: (_, i) {
                  final it = images[i] as Map;
                  final imgUrl = _toAbsoluteUrl((it['url'] ?? '').toString());
                  return GestureDetector(
                    onTap: () => _openImagePreview(imgUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            if (others.isNotEmpty) ...[
              const Text(
                'ملفات',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...others.map((file) => _buildAttachmentItem(file)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(dynamic file) {
    if (file is! Map) return const SizedBox.shrink();

    final url = file['url']?.toString() ?? '';
    final name = file['name']?.toString() ?? 'ملف';
    final type = file['type']?.toString() ?? '';

    IconData icon;
    Color color;

    if (type == 'image') {
      icon = Icons.image;
      color = Colors.green;
    } else if (type == 'pdf') {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    // For images we already render in the grid above, so skip here
    if (type.toLowerCase() == 'image') return const SizedBox.shrink();

    final absUrl = _toAbsoluteUrl(url);

    // PDF button similar to notifications, others use a generic open button
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(type.toUpperCase()),
        trailing: SizedBox(
          width: 48,
          height: 40,
          child: ElevatedButton(
            onPressed: () => _launchUrl(absUrl),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(), // زر دائري
            ),
            child: Icon(
              type.toLowerCase() == 'pdf'
                  ? Icons.picture_as_pdf
                  : Icons.open_in_new,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourcesCard() {
    final resources = assignment!['resources'];
    if (resources == null || resources is! List || resources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'المصادر والروابط',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...resources.map((resource) => _buildResourceItem(resource)),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceItem(dynamic resource) {
    if (resource is! Map) return const SizedBox.shrink();

    final url = resource['url']?.toString() ?? '';
    final title = resource['title']?.toString() ?? 'رابط';
    final type = resource['type']?.toString() ?? 'link';

    // Use type to customize leading icon and color
    IconData leadIcon;
    Color leadColor;
    switch (type.toLowerCase()) {
      case 'video':
        leadIcon = Icons.play_circle_outline;
        leadColor = Colors.redAccent;
        break;
      case 'pdf':
        leadIcon = Icons.picture_as_pdf;
        leadColor = Colors.red;
        break;
      case 'image':
        leadIcon = Icons.image;
        leadColor = Colors.green;
        break;
      case 'doc':
      case 'article':
        leadIcon = Icons.description;
        leadColor = Colors.orange;
        break;
      case 'link':
      default:
        leadIcon = Icons.link;
        leadColor = Colors.blue;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[50]!, Colors.blue[100]!]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: leadColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(leadIcon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          url,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 48,
          height: 40,
          child: ElevatedButton(
            onPressed: () => _launchUrl(_toAbsoluteUrl(url)),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(), // زر دائري
            ),
            child: const Icon(Icons.link, size: 22),
          ),
        ),

        onTap: () => _launchUrl(_toAbsoluteUrl(url)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الواجب'), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _fetch,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : assignment == null
          ? const Center(child: Text('لا توجد بيانات'))
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildAttachmentsCard(),
                  const SizedBox(height: 16),
                  _buildResourcesCard(),
                  const SizedBox(height: 16),
                  _buildEvaluationCard(),
                  // Show "عرض إجابتي" depending on delivery_mode
                  if ((() {
                    // read delivery_mode from attachments.meta
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
                      final content = (mySubmission?['content_text']?.toString() ?? '').trim();
                      final link = (mySubmission?['link_url']?.toString() ?? '').trim();
                      final sAtts = mySubmission?['attachments'];
                      final hasAtts = sAtts is List && sAtts.isNotEmpty;
                      return content.isNotEmpty || link.isNotEmpty || hasAtts;
                    }
                    // non-paper: show if there is a submission record at all
                    return true;
                  })()) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openViewSubmission,
                        icon: const Icon(Icons.visibility),
                        label: const Text('عرض إجابتي'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Hide submit button if already graded OR delivery_mode=paper (ورقي)
                  if ((() {
                    final status = (mySubmission?['status']?.toString() ?? '')
                        .toLowerCase();
                    final isGraded = status == 'graded';
                    String deliveryMode = '';
                    final atts = assignment?['attachments'];
                    if (atts is Map) {
                      final meta = atts['meta'];
                      if (meta is Map) {
                        deliveryMode =
                            (meta['delivery_mode'] ??
                                    meta['deliveryMode'] ??
                                    '')
                                .toString()
                                .toLowerCase();
                      }
                    }
                    final isPaper = deliveryMode == 'paper';
                    return !(isGraded || isPaper);
                  })())
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openSubmitBottomSheet,
                        icon: const Icon(Icons.assignment_turned_in),
                        label: const Text('إرسال إجابتي'),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
