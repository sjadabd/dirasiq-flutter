// Intro-video card for the teacher profile — Bunny upload + status badge.
//
// Spec: MP4, ≤50MB, ≤60s, 720p–1080p when metadata is available.
// Flow: mint Bunny contract → PUT bytes → sync → awaiting_review.

import 'dart:io';

import 'package:dio/dio.dart' show DioException;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/teacher_api_service.dart';
import '../../shared/design/teacher_design.dart';

const int _kMaxBytes = 50 * 1024 * 1024;
const int _kMaxDurationSec = 60;
const int _kMinHeight = 720;
const int _kMaxHeight = 1080;

class TeacherIntroVideoCard extends StatefulWidget {
  const TeacherIntroVideoCard({super.key});

  @override
  State<TeacherIntroVideoCard> createState() => _TeacherIntroVideoCardState();
}

class _TeacherIntroVideoCardState extends State<TeacherIntroVideoCard> {
  final _api = TeacherApiService();

  bool _loading = true;
  bool _uploading = false;
  int _progress = 0;
  String _phase = '';
  String _error = '';
  Map<String, dynamic> _intro = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await _api.getIntroVideo();
      if (!mounted) return;
      setState(() => _intro = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _status => (_intro['status'] ?? 'none').toString();

  (String, Color, IconData) _statusVisual(BuildContext context) {
    final t = context.teacher;
    final mq = context.mq;
    switch (_status) {
      case 'approved':
        return ('معتمد — ظاهر للطلاب', t.success, Icons.verified_rounded);
      case 'awaiting_review':
      case 'ready':
        return (
          'بانتظار مراجعة الإدارة',
          t.warning,
          Icons.hourglass_top_rounded
        );
      case 'processing':
      case 'uploaded':
      case 'pending':
        return ('قيد المعالجة…', mq.accent, Icons.autorenew_rounded);
      case 'rejected':
        return ('مرفوض — ارفع فيديو جديداً', t.danger, Icons.cancel_rounded);
      case 'failed':
        return ('فشل المعالجة', t.danger, Icons.error_outline_rounded);
      default:
        return ('لا يوجد فيديو تعريفي', mq.ink3, Icons.videocam_off_outlined);
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    setState(() {
      _error = '';
      _phase = '';
      _progress = 0;
    });

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4'],
      allowMultiple: false,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;

    final file = File(path);
    final size = await file.length();
    if (size > _kMaxBytes) {
      setState(() => _error = 'حجم الفيديو يجب ألا يتجاوز 50 ميغابايت');
      return;
    }

    final name = picked.files.single.name.toLowerCase();
    if (!name.endsWith('.mp4')) {
      setState(() => _error = 'الصيغة المسموحة: MP4 فقط');
      return;
    }

    try {
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      final dur = ctrl.value.duration.inSeconds;
      final h = ctrl.value.size.height.round();
      await ctrl.dispose();
      if (dur > _kMaxDurationSec) {
        setState(() => _error =
            'مدة الفيديو يجب ألا تتجاوز 60 ثانية (المدة الحالية: $dur ث)');
        return;
      }
      if (h > 0 && (h < _kMinHeight || h > _kMaxHeight)) {
        setState(() => _error =
            'الدقة يجب أن تكون بين 720p و 1080p (الارتفاع الحالي: $h)');
        return;
      }
    } catch (_) {
      // Metadata unavailable — continue; webhook enforces duration.
    }

    setState(() {
      _uploading = true;
      _phase = 'تجهيز الرفع على Bunny…';
    });

    try {
      final start = await _api.startBunnyIntroVideoUpload();
      final upload = (start['upload'] is Map)
          ? Map<String, dynamic>.from(start['upload'])
          : <String, dynamic>{};
      if (upload['url'] == null) {
        throw Exception('استجابة الخادم غير صالحة لبدء الرفع');
      }

      setState(() => _phase = 'رفع الفيديو…');
      await _api.putToBunny(
        uploadContract: upload,
        filePath: path,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      setState(() => _phase = 'تحديث الحالة…');
      try {
        final synced = await _api.syncIntroVideo();
        if (mounted) setState(() => _intro = synced);
      } catch (_) {
        await _load();
      }

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _phase = 'تم الرفع. سيُراجع الفيديو من الإدارة بعد اكتمال المعالجة.';
        _progress = 100;
      });
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = _humanize(e);
        _phase = '';
      });
    }
  }

  String _humanize(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'تحقق من اتصال الإنترنت وحاول مرة أخرى';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final (label, color, icon) = _statusVisual(context);
    final notes = (_intro['reviewNotes'] ?? '').toString().trim();
    final duration = _intro['durationSeconds'];

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mq.accentSoft,
                  borderRadius: MqRadius.brSm,
                ),
                child: Icon(Icons.video_camera_front_outlined,
                    size: MqSize.iconSm, color: mq.accent),
              ),
              const SizedBox(width: MqSpacing.sm),
              Text('الفيديو التعريفي', style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: context.text.titleSmall
                                ?.copyWith(color: color)),
                        if (duration != null) ...[
                          const SizedBox(height: 2),
                          Text('المدة: ${duration}ث',
                              style: context.text.bodySmall
                                  ?.copyWith(color: mq.ink3)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: _uploading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            if (notes.isNotEmpty && _status == 'rejected') ...[
              const SizedBox(height: 10),
              Text('ملاحظة الإدارة: $notes',
                  style: context.text.bodySmall?.copyWith(color: t.danger)),
            ],
            const SizedBox(height: 10),
            Text(
              'الشروط: MP4 · حد أقصى 60 ثانية · حتى 50MB · دقة 720–1080p',
              style: context.text.bodySmall?.copyWith(color: mq.ink3),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error,
                  style: context.text.bodySmall?.copyWith(color: t.danger)),
            ],
            if (_uploading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress / 100),
              const SizedBox(height: 6),
              Text('$_phase ($_progress%)', style: context.text.bodySmall),
            ] else if (_phase.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_phase,
                  style: context.text.bodySmall?.copyWith(color: t.success)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: Icon(_status == 'none'
                  ? Icons.upload_rounded
                  : Icons.swap_horiz_rounded),
              label: Text(_status == 'none' || _status == 'failed'
                  ? 'رفع فيديو تعريفي'
                  : 'استبدال الفيديو'),
            ),
          ],
        ],
      ),
    );
  }
}
