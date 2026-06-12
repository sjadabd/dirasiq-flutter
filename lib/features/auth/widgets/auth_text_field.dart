// Shared auth text field (MulhimIQ design system). Presentation only — the
// controller / validator / keyboard contract is unchanged. Requires its host
// screen to be wrapped in MqTheme (every auth screen is).

import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final IconData? prefixIcon;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final m = context.mq;
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: c, width: w));

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      enabled: enabled,
      cursorColor: m.accent,
      style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.text.bodySmall,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: MqSize.iconSm, color: m.ink3) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: m.fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: MqSpacing.md, vertical: MqSpacing.sm),
        isDense: true,
        border: border(m.line),
        enabledBorder: border(m.line),
        focusedBorder: border(m.accent, 1.6),
        errorBorder: border(m.error),
        focusedErrorBorder: border(m.error, 1.6),
      ),
    );
  }
}
