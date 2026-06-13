import 'dart:io';

import 'package:flutter/services.dart';

class VideoSecurityService {
  VideoSecurityService._();

  static const MethodChannel _channel = MethodChannel(
    'mulhimiq/video_security',
  );

  static Future<void> enable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await _channel.invokeMethod<void>('enableProtection');
    } on PlatformException {
      // Protection is best-effort and must never prevent video playback.
    } on MissingPluginException {
      // Keeps tests and unsupported runner configurations from failing.
    }
  }

  static Future<void> disable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await _channel.invokeMethod<void>('disableProtection');
    } on PlatformException {
      // Protection teardown must not interfere with player disposal.
    } on MissingPluginException {
      // Keeps tests and unsupported runner configurations from failing.
    }
  }
}
