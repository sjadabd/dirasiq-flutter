// Phase 7 — Thin Scaffold wrapper around [UnifiedVideoPlayer].
//
// Most playback entry points in the app navigate to a dedicated route for
// the lesson, so they want a full screen with a back button + black
// background + no app bar (the player draws its own top overlay). This
// wrapper provides exactly that. Callers that need to embed the player
// inline (e.g. a course preview card) use [UnifiedVideoPlayer] directly.
//
// CRITICAL: this is a StatelessWidget on purpose — the State lives inside
// UnifiedVideoPlayer where the dispose chain runs. Popping this route
// disposes the player widget which guarantees pause + volume(0) + dispose
// on the underlying controller.

import 'package:flutter/material.dart';

import 'unified_video_player.dart';

class UnifiedVideoPlayerScreen extends StatelessWidget {
  const UnifiedVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoId,
    this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.startAt,
    this.onCompleted,
  });

  final String videoUrl;
  final String videoId;
  final String? title;
  final String? subtitle;
  final String? thumbnailUrl;
  final Duration? startAt;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: UnifiedVideoPlayer(
                videoUrl: videoUrl,
                videoId: videoId,
                title: title,
                subtitle: subtitle,
                thumbnailUrl: thumbnailUrl,
                startAt: startAt,
                onCompleted: onCompleted,
              ),
            ),
            // Back button — sits over the player's own top gradient.
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'رجوع',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
