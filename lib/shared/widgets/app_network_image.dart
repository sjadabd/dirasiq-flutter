// AppNetworkImage — a defensive wrapper around Image.network that handles
// the three failure modes that produce "black frame" UX bugs:
//
//   1. No URL at all → light fallback, never a dark Container.
//   2. URL loading   → light tinted placeholder (NOT theme-derived, so it
//                      can't pick up a dark scheme.surfaceContainerHighest
//                      and render as a black box).
//   3. URL failed    → light fallback with an icon, no decoration error
//                      bleeding to a dark parent.
//
// Always specify a fit + an explicit non-dark background. The previous
// implementation used `scheme.surfaceContainerHighest` for the fallback,
// which produced a near-black frame under the dark theme variant. This
// widget pins the background to a fixed light shade so the user sees a
// consistent placeholder regardless of theme + load state.

import 'package:flutter/material.dart';

import '../../core/utils/content_url.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackBackground = const Color(0xFFEEF2FB),
    this.fallbackIconColor = const Color(0xFF94A3B8),
    this.borderRadius,
  });

  /// Raw URL (relative or absolute). Empty / null → fallback.
  final String url;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color fallbackBackground;
  final Color fallbackIconColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveContentUrl(url);
    Widget body;
    if (resolved.isEmpty) {
      body = _fallback();
    } else {
      body = Image.network(
        resolved,
        fit: fit,
        gaplessPlayback: true,
        // Frame builder gives us a fade-in once the bytes decode.
        frameBuilder: (ctx, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return child;
          return AnimatedOpacity(
            opacity: frame != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return _loadingPlaceholder(progress);
        },
        errorBuilder: (ctx, err, stack) => _fallback(),
      );
    }
    if (borderRadius != null) {
      body = ClipRRect(borderRadius: borderRadius!, child: body);
    }
    return body;
  }

  Widget _loadingPlaceholder(ImageChunkEvent progress) {
    final total = progress.expectedTotalBytes;
    final loaded = progress.cumulativeBytesLoaded;
    final value = (total != null && total > 0) ? (loaded / total).clamp(0.0, 1.0) : null;
    return Container(
      color: fallbackBackground,
      alignment: Alignment.center,
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: value,
          // Soft greyed-out spinner — doesn't compete with the eventual image.
          valueColor: AlwaysStoppedAnimation(fallbackIconColor),
          backgroundColor: fallbackIconColor.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: fallbackBackground,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: fallbackIconColor, size: 32),
    );
  }
}
