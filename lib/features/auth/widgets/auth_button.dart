// Shared auth button (MulhimIQ design system). Thin wrapper over MqButton so
// existing call sites (text / onPressed / isLoading / isSecondary) keep working.
// Requires its host screen to be wrapped in MqTheme (every auth screen is).

import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return MqButton(
      label: text,
      icon: icon,
      loading: isLoading,
      onPressed: isLoading ? null : onPressed,
      variant: isSecondary ? MqButtonVariant.secondary : MqButtonVariant.primary,
    );
  }
}
