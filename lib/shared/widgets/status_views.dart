import 'package:flutter/material.dart';

/// Shared loading / empty / error views for student screens.
///
/// Pick one of three constructors per scenario, drop into any layout. Keeps
/// the visual language consistent so parents see the same Arabic copy across
/// every list (invoices, exams, evaluations, etc.).
class StatusView extends StatelessWidget {
  const StatusView.loading({super.key, this.message})
      : _kind = _Kind.loading,
        icon = null,
        actionLabel = null,
        onAction = null;

  const StatusView.empty({
    super.key,
    required String this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : _kind = _Kind.empty;

  const StatusView.error({
    super.key,
    required String this.message,
    this.actionLabel = 'إعادة المحاولة',
    this.onAction,
  })  : _kind = _Kind.error,
        icon = Icons.wifi_off_rounded;

  final _Kind _kind;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_kind == _Kind.loading) ...[
            SizedBox(
              width: 36, height: 36,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
            ),
            const SizedBox(height: 14),
            Text(
              message ?? 'جارٍ التحميل…',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ] else ...[
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: (_kind == _Kind.error ? cs.error : cs.primary).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 30,
                color: _kind == _Kind.error ? cs.error : cs.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

enum _Kind { loading, empty, error }
