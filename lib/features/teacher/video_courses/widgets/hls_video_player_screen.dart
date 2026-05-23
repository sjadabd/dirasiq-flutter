// HlsVideoPlayerScreen — reusable HLS player built on better_player_plus.
//
// Used by both the teacher-side preview (this folder) and the student-side
// VOD playback. Handles loading / buffering / error / fullscreen +
// orientation flips internally. The page enters portrait + restores the
// original orientation set on dispose so it plays nicely with the rest of
// the RTL Arabic-only app shell.

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/content_url.dart';

class HlsVideoPlayerScreen extends StatefulWidget {
  const HlsVideoPlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
  });

  /// HLS manifest URL (`.m3u8`). May be relative (will be resolved against
  /// content_url) or absolute (Bunny CDN URL passes through unchanged).
  final String url;
  final String title;
  final String? subtitle;
  final String? thumbnailUrl;

  @override
  State<HlsVideoPlayerScreen> createState() => _HlsVideoPlayerScreenState();
}

class _HlsVideoPlayerScreenState extends State<HlsVideoPlayerScreen> {
  BetterPlayerController? _controller;
  String _error = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void dispose() {
    try { _controller?.dispose() ; } catch (_) {}
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _build() {
    final resolved = resolveContentUrl(widget.url);
    if (resolved.isEmpty) {
      setState(() {
        _error = 'رابط الفيديو غير صالح';
        _loading = false;
      });
      return;
    }
    final ds = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      resolved,
      videoFormat: BetterPlayerVideoFormat.hls,
      cacheConfiguration: const BetterPlayerCacheConfiguration(useCache: false),
      notificationConfiguration: BetterPlayerNotificationConfiguration(
        showNotification: true,
        title: widget.title,
        author: widget.subtitle ?? 'مُلهِم IQ',
      ),
      placeholder: widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty
          ? Image.network(
              resolveContentUrl(widget.thumbnailUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : null,
    );
    final cfg = BetterPlayerConfiguration(
      autoPlay: true,
      autoDispose: false,
      fit: BoxFit.contain,
      aspectRatio: 16 / 9,
      handleLifecycle: true,
      allowedScreenSleep: false,
      showPlaceholderUntilPlay: true,
      placeholderOnTop: true,
      // Loading widget (replaces the default white circle on black
      // background which makes the player look broken before bytes start).
      placeholder: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      ),
      errorBuilder: (ctx, err) => _PlayerErrorOverlay(
        message: err ?? 'تعذّر تشغيل الفيديو',
        onRetry: _retry,
      ),
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        enableProgressText: true,
        enableProgressBar: true,
        enableSkips: true,
        enableFullscreen: true,
        enablePlayPause: true,
        enableMute: true,
        enableOverflowMenu: true,
        playerTheme: BetterPlayerTheme.material,
      ),
      eventListener: _onPlayerEvent,
    );

    final c = BetterPlayerController(cfg, betterPlayerDataSource: ds);
    if (!mounted) return;
    setState(() {
      _controller = c;
      _loading = false;
      _error = '';
    });
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      final msg = event.parameters?['exception']?.toString() ?? 'خطأ غير معروف';
      // Stay on the screen so the user can hit retry. Log to console.
      // ignore: avoid_print
      print('[BetterPlayer] exception: $msg');
      if (mounted) setState(() => _error = msg);
    }
  }

  void _retry() {
    setState(() {
      _error = '';
      _loading = true;
    });
    try { _controller?.dispose(); } catch (_) {}
    _controller = null;
    _build();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
              Text(widget.subtitle!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : _error.isNotEmpty && _controller == null
                  ? _PlayerErrorOverlay(message: _error, onRetry: _retry)
                  : AspectRatio(
                      aspectRatio: 16 / 9,
                      child: BetterPlayer(controller: _controller!),
                    ),
        ),
      ),
    );
  }
}

class _PlayerErrorOverlay extends StatelessWidget {
  const _PlayerErrorOverlay({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}
