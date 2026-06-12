// Phase 7 — Thin Scaffold wrapper around [UnifiedVideoPlayer].
//
// Most playback entry points navigate to a dedicated route for the lesson, so
// they want a full screen with a back button + black background + no app bar
// (the player draws its own top overlay). This wrapper provides exactly that.
//
// CRITICAL: the playback engine lives inside [UnifiedVideoPlayer] (Bunny/HLS,
// progress tracking, resume, deterministic dispose, watermark) and is NOT
// touched here. This wrapper only adds chrome AROUND the player: the back
// button and an OPTIONAL lesson-navigation bar (previous / next / lesson list
// / "الدرس X من Y"). Lesson switching is delegated to the caller via
// [onSelectLesson]; the caller re-mints the signed URL and replaces this
// route with a fresh player instance — so every lesson is a brand-new
// controller exactly like opening a lesson normally. No playback logic is
// re-entered here.

import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';
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
    this.ownerLabel,
    this.lessonTitles,
    this.lessonIndex,
    this.onSelectLesson,
  });

  final String videoUrl;
  final String videoId;
  final String? title;
  final String? subtitle;
  final String? thumbnailUrl;
  final Duration? startAt;
  final VoidCallback? onCompleted;
  final String? ownerLabel;

  /// Optional playlist context. When [lessonTitles] + [lessonIndex] +
  /// [onSelectLesson] are all provided, the wrapper shows prev/next + a lesson
  /// list. The caller owns minting + route replacement.
  final List<String>? lessonTitles;
  final int? lessonIndex;
  final void Function(int index)? onSelectLesson;

  bool get _hasPlaylist =>
      lessonTitles != null && lessonTitles!.isNotEmpty && lessonIndex != null && onSelectLesson != null;

  void _openLessonList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Theme(
        data: dsTheme,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (ctx) {
              final m = ctx.mq;
              return Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                decoration: BoxDecoration(
                  color: m.card,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: m.line, borderRadius: MqRadius.brPill),
                      ),
                    ),
                    MqSpacing.gapMd,
                    Text('قائمة الدروس', style: ctx.text.titleMedium),
                    MqSpacing.gapSm,
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: lessonTitles!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.xs),
                        itemBuilder: (_, i) {
                          final current = i == lessonIndex;
                          return MqCard(
                            padding: const EdgeInsets.all(MqSpacing.sm),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              if (!current) onSelectLesson!(i);
                            },
                            child: Row(children: [
                              Container(
                                width: 28, height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: current ? m.accent : m.accentSoft,
                                  borderRadius: MqRadius.brSm,
                                ),
                                child: current
                                    ? Icon(Icons.play_arrow_rounded, size: 18, color: m.onAccent)
                                    : Text('${i + 1}',
                                        style: ctx.text.labelSmall?.copyWith(color: m.accent, fontWeight: FontWeight.w700)),
                              ),
                              MqSpacing.gapSm,
                              Expanded(
                                child: Text(lessonTitles![i],
                                    style: current
                                        ? ctx.text.titleSmall?.copyWith(color: m.accent)
                                        : ctx.text.bodyMedium,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              if (current) MqBadge(label: 'الآن', tone: MqBadgeTone.accent),
                            ]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

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
                ownerLabel: ownerLabel,
              ),
            ),
            // Top chrome — back + (optional) lesson navigation. RTL: back is
            // the forward arrow on the right; lesson controls on the left.
            Positioned(
              top: 8, left: 8, right: 8,
              child: Row(
                children: [
                  _circleBtn(
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    tooltip: 'رجوع',
                  ),
                  const Spacer(),
                  if (_hasPlaylist) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text('الدرس ${lessonIndex! + 1} من ${lessonTitles!.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    _circleBtn(
                      icon: Icons.skip_previous_rounded,
                      enabled: lessonIndex! > 0,
                      onTap: () => onSelectLesson!(lessonIndex! - 1),
                      tooltip: 'الدرس السابق',
                    ),
                    const SizedBox(width: 6),
                    _circleBtn(
                      icon: Icons.skip_next_rounded,
                      enabled: lessonIndex! < lessonTitles!.length - 1,
                      onTap: () => onSelectLesson!(lessonIndex! + 1),
                      tooltip: 'الدرس التالي',
                    ),
                    const SizedBox(width: 6),
                    _circleBtn(
                      icon: Icons.playlist_play_rounded,
                      onTap: () => _openLessonList(context),
                      tooltip: 'قائمة الدروس',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap, String? tooltip, bool enabled = true}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 20),
        onPressed: enabled ? onTap : null,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
