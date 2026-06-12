// Student → QR attendance check-in (MulhimIQ design-system pass).
//
// The scanning + validation logic is UNCHANGED: a `mulhimiq://attend?teacher=<id>`
// code is parsed and the screen pops with the teacherId String (the caller
// performs the check-in API call). Only the chrome, instruction card, scan
// frame, and the permission/camera error states are restyled with the design
// system. The mobile_scanner package and controller are untouched.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:mulhimiq/core/services/permission_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _handled = false; // لمنع الإرسال أكثر من مرة

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── scan validation (UNCHANGED) ────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final raw = codes.first.rawValue ?? codes.first.displayValue;
    if (raw == null || raw.isEmpty) return;

    // توقع: mulhimiq://attend?teacher=<id>
    try {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.scheme == 'mulhimiq' && uri.host == 'attend') {
        final teacherId = uri.queryParameters['teacher'];
        if (teacherId != null && teacherId.isNotEmpty) {
          _handled = true;
          Navigator.pop(context, teacherId);
          return;
        }
      }
      _showSnack('رمز غير معروف. تأكد أن الرمز من نوع الحضور.');
    } catch (_) {
      _showSnack('تعذّر قراءة الرمز');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            final mq = context.mq;
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                title: const Text('تسجيل الحضور'),
                actions: [
                  IconButton(
                    tooltip: 'تبديل الكاميرا',
                    icon: const Icon(Icons.cameraswitch_rounded),
                    onPressed: () => _controller.switchCamera(),
                  ),
                  IconButton(
                    tooltip: 'الفلاش',
                    icon: const Icon(Icons.flash_on_rounded),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                ],
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => _scannerError(context, error.errorCode),
                  ),
                  // Dim + centered scan window with accent corner brackets.
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.72,
                      height: MediaQuery.of(context).size.width * 0.72,
                      decoration: BoxDecoration(
                        borderRadius: MqRadius.brXl,
                        border: Border.all(color: mq.accent, width: 3),
                      ),
                    ),
                  ),
                  // Instruction card at the top.
                  Positioned(
                    top: MqSpacing.lg,
                    left: MqSpacing.lg,
                    right: MqSpacing.lg,
                    child: _InstructionCard(),
                  ),
                  // Bottom hint.
                  Positioned(
                    bottom: MqSpacing.xl,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg, vertical: MqSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: MqRadius.brPill,
                        ),
                        child: Text('وجّه الكاميرا نحو رمز QR',
                            style: context.text.bodySmall?.copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _scannerError(BuildContext context, MobileScannerErrorCode code) {
    final mq = context.mq;
    final (IconData icon, String title, String body, bool canRetryPermission) = switch (code) {
      MobileScannerErrorCode.permissionDenied => (
          Icons.no_photography_outlined,
          'إذن الكاميرا مرفوض',
          'نحتاج إذن الكاميرا لمسح رمز الحضور. فعّل الإذن ثم أعد المحاولة.',
          true,
        ),
      MobileScannerErrorCode.unsupported => (
          Icons.videocam_off_outlined,
          'الكاميرا غير متاحة',
          'هذا الجهاز لا يدعم مسح رموز QR.',
          false,
        ),
      _ => (
          Icons.error_outline_rounded,
          'تعذّر تشغيل الكاميرا',
          'حدث خطأ أثناء تشغيل الكاميرا. أعد المحاولة.',
          false,
        ),
    };

    return Container(
      color: mq.page,
      padding: const EdgeInsets.all(MqSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(MqSpacing.lg),
              decoration: BoxDecoration(color: mq.error.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: mq.error),
            ),
            MqSpacing.gapMd,
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            MqSpacing.gapXs,
            Text(body, textAlign: TextAlign.center, style: context.text.bodySmall),
            MqSpacing.gapLg,
            if (canRetryPermission)
              MqButton(
                label: 'السماح بالكاميرا',
                icon: Icons.lock_open_rounded,
                expand: false,
                onPressed: () async {
                  final ok = await PermissionService.requestCameraPermission();
                  if (ok) await _controller.start();
                },
              )
            else
              MqButton(
                label: 'رجوع',
                icon: Icons.arrow_forward_rounded,
                expand: false,
                onPressed: () => Get.back(),
              ),
          ],
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card.withValues(alpha: 0.95),
        borderRadius: MqRadius.brLg,
        border: Border.all(color: mq.line),
        boxShadow: mq.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
            child: Icon(Icons.qr_code_scanner_rounded, color: mq.accent, size: MqSize.iconMd),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('امسح رمز الحضور', style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text('اطلب رمز QR من أستاذك ووجّه الكاميرا نحوه لتسجيل حضورك.',
                    style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
