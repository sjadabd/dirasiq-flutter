// Phase 6 — shared shell for every Course Hub section.
//
// Every section card on the unified Hub uses this same outer chrome
// (icon + title + optional badge + body slot + optional CTA). Keeping
// the shell here ensures consistent spacing, theming, and ARIA-style
// semantics across all 8 sections. Section widgets focus on their
// content + lazy-load lifecycle, not layout.

import 'package:flutter/material.dart';

class CourseHubSectionShell extends StatelessWidget {
  const CourseHubSectionShell({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
    this.badge,
    this.action,
  });

  /// Header icon (e.g. ri-megaphone, calendar, ...).
  final IconData icon;

  /// Section title in Arabic (e.g. "الإعلانات", "الجدول الأسبوعي").
  final String title;

  /// Right-aligned chip (e.g. a count). Optional.
  final Widget? badge;

  /// Trailing action button in the header (e.g. "عرض الكل"). Optional.
  final Widget? action;

  /// Override the default primary color for the header icon. Optional.
  final Color? iconColor;

  /// Section body — whatever the section wants to render below the
  /// header. The shell adds vertical spacing automatically.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? cs.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: effectiveIconColor.withValues(alpha: 0.15),
                child: Icon(icon, color: effectiveIconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                badge!,
              ],
              if (action != null) ...[
                const SizedBox(width: 6),
                action!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Compact "row" used by several sections — leading icon + title +
/// optional trailing widget. Tappable.
class CourseHubRow extends StatelessWidget {
  const CourseHubRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Tiny pill used in section badges (e.g. "5 جديد"). Adapts to dark
/// mode via `surfaceContainerHighest` of the current ColorScheme.
class CourseHubBadge extends StatelessWidget {
  const CourseHubBadge({super.key, required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

/// Loading skeleton used when a section is fetching its first payload.
class CourseHubSectionLoading extends StatelessWidget {
  const CourseHubSectionLoading({super.key, this.height = 60});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Inline error banner used by every section's error state.
class CourseHubSectionError extends StatelessWidget {
  const CourseHubSectionError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.error, fontSize: 12),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
