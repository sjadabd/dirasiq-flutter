// Phase 7 — Unified video player.
//
// SINGLE entry point for ANY video playback in the app. Built on the
// `video_player` package (HLS-capable through ExoPlayer/AVPlayer) so we
// have full control over disposal — the legacy HlsVideoPlayerScreen built
// on better_player_plus had a bug where audio could survive after the
// screen popped because the internal lifecycle handler raced with route
// pop. That class is retained for reference but no code path links to it
// anymore.
//
// Invariants enforced here (these are the Phase 7 requirements):
//
//   1. NO background playback. `allowBackgroundPlayback: false` +
//      `mixWithOthers: false` at the platform layer, plus an explicit
//      pause on every non-resumed `AppLifecycleState`, plus a synchronous
//      pause + setVolume(0) + dispose chain in [dispose].
//
//   2. Resume from last position. Every play tick saves the position to
//      [PlaybackProgressStorage] under the caller-supplied `videoId`. On
//      open, the saved position seeks the controller before play() runs.
//      A video watched to within 5 seconds of the end clears its entry on
//      teardown so a re-open starts from zero.
//
//   3. Deterministic disposal. The State.dispose() implementation cancels
//      every timer, removes the controller listener, pauses, mutes, then
//      disposes — in that order — even if the controller is mid-buffer.
//      A WidgetsBindingObserver is registered + removed in pairs.
//
//   4. Orientation safety. Fullscreen flips to landscape + immersive UI
//      and the regular Scaffold body fills the rotated viewport. dispose()
//      always restores the system UI mode + all four orientation locks so
//      a back-from-fullscreen-via-back-button can't strand the app.
//
// Extensibility hooks left open (intentional NOT-YET-WIRED):
//   - speed control      (controller.setPlaybackSpeed)
//   - quality selector   (multiple manifest variants — needs backend list)
//   - subtitles          (VideoPlayerController.closedCaptionFile)
//   - download protection (HLS DRM headers via Dio)
//   - analytics          (heartbeat ping in _saveProgress)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'playback_progress_storage.dart';

class UnifiedVideoPlayer extends StatefulWidget {
  const UnifiedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.videoId,
    this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.autoPlay = true,
    this.startAt,
    this.aspectRatio = 16 / 9,
    this.onCompleted,
  });

  /// HLS `.m3u8` manifest URL or direct video URL. Signed URLs are fine —
  /// caller is responsible for minting a fresh one just before construct.
  final String videoUrl;

  /// Stable identifier for resume storage. Two different signed URLs that
  /// point at the same logical lesson MUST share the same videoId so the
  /// resume point survives URL rotation.
  final String videoId;

  final String? title;
  final String? subtitle;
  final String? thumbnailUrl;

  /// Whether to start playing as soon as the controller is initialized.
  final bool autoPlay;

  /// Optional explicit start position. When null, the widget loads the
  /// last saved position via [PlaybackProgressStorage] on init.
  final Duration? startAt;

  /// Used only as a fallback aspect ratio while the controller is loading
  /// or when the video reports a zero aspect ratio (some HLS variants).
  final double aspectRatio;

  /// Fires once when the position first reaches the duration. Useful for
  /// "next lesson" auto-advance in callers.
  final VoidCallback? onCompleted;

  @override
  State<UnifiedVideoPlayer> createState() => _UnifiedVideoPlayerState();
}

class _UnifiedVideoPlayerState extends State<UnifiedVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _progressSaver;
  Timer? _controlsHider;

  bool _initialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupController();
  }

  Future<void> _setupController() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      _setError('رابط الفيديو غير صالح');
      return;
    }

    final isHls = url.toLowerCase().contains('.m3u8');
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: isHls ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
        mixWithOthers: false,
      ),
    );
    _controller = controller;

    try {
      await controller.initialize();
    } catch (_) {
      _setError('تعذّر تحميل الفيديو');
      return;
    }

    if (!mounted) {
      // The widget was torn down while initialize() was in flight. Drop
      // the controller right away — leaving it alive is exactly how the
      // legacy player leaked audio.
      await controller.dispose();
      _controller = null;
      return;
    }

    final resumeFrom =
        widget.startAt ?? await PlaybackProgressStorage.read(widget.videoId);
    if (resumeFrom != null &&
        resumeFrom < controller.value.duration &&
        resumeFrom > Duration.zero) {
      try {
        await controller.seekTo(resumeFrom);
      } catch (_) {/* non-fatal; fall through with position 0 */}
    }

    controller.addListener(_onControllerTick);

    if (widget.autoPlay) {
      try {
        await controller.play();
      } catch (_) {/* user can hit play manually */}
    }

    if (!mounted) {
      await controller.dispose();
      _controller = null;
      return;
    }

    setState(() {
      _initialized = true;
      _hasError = false;
      _errorMessage = '';
    });

    _startProgressSaver();
    _scheduleControlsHide();
  }

  void _onControllerTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;

    if (v.hasError && !_hasError) {
      _setError('انقطع البث. حاول مرة أخرى.');
      return;
    }

    if (!_completedFired &&
        v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration) {
      _completedFired = true;
      // Clear so the next open starts from zero, not the saved late spot.
      unawaited(PlaybackProgressStorage.clear(widget.videoId));
      widget.onCompleted?.call();
    }

    if (mounted) setState(() {});
  }

  void _startProgressSaver() {
    _progressSaver?.cancel();
    _progressSaver = Timer.periodic(const Duration(seconds: 5), (_) {
      final c = _controller;
      if (c == null || !c.value.isInitialized || !c.value.isPlaying) return;
      final pos = c.value.position;
      final dur = c.value.duration;
      // Within last 5 seconds → treat as effectively-completed, don't save.
      if (dur > Duration.zero && (dur - pos).inSeconds <= 5) return;
      unawaited(PlaybackProgressStorage.save(widget.videoId, pos));
    });
  }

  void _scheduleControlsHide() {
    _controlsHider?.cancel();
    _controlsHider = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      // Don't hide controls while paused — keeps "tap to play" discoverable.
      final c = _controller;
      if (c != null && c.value.isInitialized && !c.value.isPlaying) return;
      setState(() => _showControls = false);
    });
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = msg;
      _initialized = false;
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleControlsHide();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      _controlsHider?.cancel();
      setState(() => _showControls = true);
    } else {
      if (c.value.duration > Duration.zero &&
          c.value.position >= c.value.duration) {
        // Replay from start when the user hits play after completion.
        c.seekTo(Duration.zero);
        _completedFired = false;
      }
      c.play();
      _scheduleControlsHide();
    }
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    if (next) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _initialized = false;
    });
    final old = _controller;
    _controller = null;
    if (old != null) {
      try { await old.pause(); } catch (_) {}
      try { await old.setVolume(0); } catch (_) {}
      try { await old.dispose(); } catch (_) {}
    }
    if (!mounted) return;
    await _setupController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      // Defensive: pause on inactive / paused / detached / hidden. The
      // platform option `allowBackgroundPlayback: false` is the primary
      // guard; this is a belt-and-braces second line.
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    // Order matters. Each step is wrapped in try/catch because we never
    // want a dispose failure to throw above the Element layer.
    _progressSaver?.cancel();
    _progressSaver = null;
    _controlsHider?.cancel();
    _controlsHider = null;

    final c = _controller;
    if (c != null) {
      if (c.value.isInitialized) {
        final pos = c.value.position;
        final dur = c.value.duration;
        final within5OfEnd =
            dur > Duration.zero && (dur - pos).inSeconds <= 5;
        if (within5OfEnd) {
          unawaited(PlaybackProgressStorage.clear(widget.videoId));
        } else {
          unawaited(PlaybackProgressStorage.save(widget.videoId, pos));
        }
      }
      try { c.removeListener(_onControllerTick); } catch (_) {}
      try { c.pause(); } catch (_) {}
      try { c.setVolume(0); } catch (_) {}
      try { c.dispose(); } catch (_) {}
    }
    _controller = null;

    if (_isFullscreen) {
      unawaited(_restoreSystemUi());
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_initialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio == 0
                    ? widget.aspectRatio
                    : _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (widget.thumbnailUrl != null &&
              widget.thumbnailUrl!.isNotEmpty &&
              !_hasError)
            Image.network(
              widget.thumbnailUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),
          if (_initialized && _showControls) _buildControlsOverlay(),
          if (!_initialized && !_hasError) _buildLoadingOverlay(),
          if (_hasError) _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return const Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          Text(
            _errorMessage.isEmpty ? 'تعذّر تشغيل الفيديو' : _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('إعادة المحاولة',
                style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final c = _controller!;
    final v = c.value;
    final position = v.position;
    final duration = v.duration;
    final hasDuration = duration > Duration.zero;
    final isPlaying = v.isPlaying;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top bar — title + subtitle, no app bar so it sits over the
          // video edge-to-edge.
          if (widget.title != null && widget.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty)
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          // Centered play/pause button
          IconButton(
            iconSize: 64,
            color: Colors.white,
            icon: Icon(isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled),
            onPressed: _togglePlayPause,
          ),
          const Spacer(),
          // Seek + duration + fullscreen
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(_fmt(position),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11)),
                Expanded(
                  child: SliderTheme(
                    data: const SliderThemeData(
                      trackHeight: 3,
                      overlayShape:
                          RoundSliderOverlayShape(overlayRadius: 12),
                      thumbShape:
                          RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      activeColor: Colors.redAccent,
                      inactiveColor: Colors.white24,
                      value: hasDuration
                          ? position.inMilliseconds
                              .clamp(0, duration.inMilliseconds)
                              .toDouble()
                          : 0,
                      min: 0,
                      max: hasDuration
                          ? duration.inMilliseconds.toDouble()
                          : 1,
                      onChanged: hasDuration
                          ? (val) => c.seekTo(
                                Duration(milliseconds: val.toInt()),
                              )
                          : null,
                      onChangeStart: (_) => _controlsHider?.cancel(),
                      onChangeEnd: (_) => _scheduleControlsHide(),
                    ),
                  ),
                ),
                Text(_fmt(duration),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  color: Colors.white,
                  icon: Icon(_isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
