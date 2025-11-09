import 'package:flutter/material.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 52,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSecondary
              ? null
              : LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          border: isSecondary
              ? Border.all(
                  color: scheme.outline.withValues(alpha: 0.4),
                  width: 1,
                )
              : null,
          boxShadow: isSecondary
              ? null
              : [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: isSecondary ? scheme.onSurface : scheme.onPrimary,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSecondary ? scheme.primary : scheme.onPrimary,
                    ),
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSecondary ? scheme.onSurface : scheme.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
