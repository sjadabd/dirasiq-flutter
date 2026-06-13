// Dynamic anti-piracy watermark overlay.
//
// Rendered on TOP of EVERY video playback (free, free-preview, paid, owned —
// there is no unprotected playback mode). It binds the viewer's identity to
// the frame so a screen recording or re-upload is traceable back to the
// student who leaked it, and it asserts ownership by MulhimIQ + the course
// teacher.
//
// The overlay:
//   * reads the signed-in student's identity from GlobalController (name,
//     short id, phone) — no extra plumbing required from callers, so a caller
//     can never accidentally ship an un-watermarked player;
//   * shows a live date/time clock that ticks, so a static crop of one frame
//     is timestamped;
//   * drifts to a new position every few seconds (AnimatedAlign) to defeat a
//     fixed crop/blur and to keep covering different regions of the frame;
//   * is fully non-interactive (IgnorePointer) so it never intercepts the
//     tap-to-toggle-controls gesture or the seek bar underneath it.
//
// It deliberately holds NO playback state and never touches the
// VideoPlayerController — so it cannot affect Bunny/HLS playback, progress
// tracking, or disposal.
//
// FUTURE-SECURITY INTEGRATION POINTS (not implemented here — they need either
// native code or backend support, see the task's security brief):
//   * FLAG_SECURE (block screenshots / screen-record) → MethodChannel to
//     MainActivity.setFlags(FLAG_SECURE); no Flutter plugin in pubspec today.
//   * iOS capture detection + privacy overlays → `VideoSecurityService`
//     MethodChannel backed by AppDelegate.
//   * Concurrent-session limit, device binding, playback-token validation,
//     expiring signed URLs → backend must issue per-device short-TTL tokens;
//     the player already re-mints the URL at play time so the expiring-URL
//     hook exists, the rest needs server support.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/shared/controllers/global_controller.dart';

class VideoWatermark extends StatefulWidget {
  const VideoWatermark({super.key, this.ownerLabel});

  /// Ownership label — typically the course teacher's name. Combined with the
  /// platform mark to assert "content belongs to MulhimIQ + this teacher".
  final String? ownerLabel;

  @override
  State<VideoWatermark> createState() => _VideoWatermarkState();
}

class _VideoWatermarkState extends State<VideoWatermark> {
  // Cycle of anchor points the mark drifts between. Spread across the frame so
  // no single region is ever permanently clear.
  static const List<Alignment> _spots = [
    Alignment(-0.7, -0.6),
    Alignment(0.7, -0.4),
    Alignment(0.0, 0.0),
    Alignment(-0.6, 0.6),
    Alignment(0.7, 0.5),
    Alignment(-0.2, -0.2),
  ];

  Timer? _ticker;
  int _spot = 0;
  late DateTime _now;

  String _name = '';
  String _phone = '';
  String _idShort = '';

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadIdentity();
    // Drift + clock refresh on the same cadence; movement discourages a fixed
    // crop while the ticking clock timestamps any captured frame.
    _ticker = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _spot = (_spot + 1) % _spots.length;
        _now = DateTime.now();
      });
    });
  }

  void _loadIdentity() {
    try {
      if (!Get.isRegistered<GlobalController>()) return;
      final u = Get.find<GlobalController>().user.value;
      if (u == null) return;
      _name = (u['name'] ?? u['fullName'] ?? u['full_name'] ?? '').toString();
      _phone = (u['phone'] ??
              u['studentPhone'] ??
              u['phoneNumber'] ??
              u['phone_number'] ??
              '')
          .toString();
      final id = (u['id'] ?? u['_id'] ?? '').toString();
      if (id.isNotEmpty) {
        _idShort = id.length > 8 ? id.substring(id.length - 8) : id;
      }
    } catch (_) {
      // Identity is best-effort; the platform/ownership mark still renders.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _clock {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${_now.year}/${two(_now.month)}/${two(_now.day)} '
        '${two(_now.hour)}:${two(_now.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final identity = <String>[
      if (_name.isNotEmpty) _name,
      if (_phone.isNotEmpty) _phone,
    ].join(' · ');
    final trace = <String>[
      if (_idShort.isNotEmpty) '#$_idShort',
      _clock,
    ].join(' · ');
    final owner = (widget.ownerLabel?.trim().isNotEmpty ?? false)
        ? 'حقوق المحتوى محفوظة للمنصة والأستاذ ${widget.ownerLabel!.trim()}'
        : 'حقوق المحتوى محفوظة للمنصة والأستاذ';

    const shadow = [
      Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1)),
    ];

    return IgnorePointer(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeInOut,
        alignment: _spots[_spot],
        child: Opacity(
          opacity: 0.42,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 12, color: Colors.white, shadows: shadow),
                    SizedBox(width: 4),
                    Text(
                      'ملهم IQ • محتوى محمي',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        shadows: shadow,
                      ),
                    ),
                  ],
                ),
                if (identity.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    identity,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      shadows: shadow,
                    ),
                  ),
                ],
                const SizedBox(height: 1),
                Text(
                  trace,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    shadows: shadow,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  owner,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    shadows: shadow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
