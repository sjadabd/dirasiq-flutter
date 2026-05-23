// resolveContentUrl — Flutter mirror of the dashboard utility.
//
// Most backend controllers return relative paths like
//   /public/uploads/video-courses/<id>/<file>.png
// alongside the canonical envelope's `content_url` field. The mobile app
// needs to display them as fully-qualified URLs.
//
// Bunny CDN URLs (https://vz-...b-cdn.net/...) are already absolute and
// pass through unchanged.

import 'package:mulhimiq/core/config/app_config.dart';

String resolveContentUrl(String? input) {
  if (input == null) return '';
  final s = input.trim();
  if (s.isEmpty) return '';

  if (s.startsWith('http://') ||
      s.startsWith('https://') ||
      s.startsWith('//') ||
      s.startsWith('data:') ||
      s.startsWith('blob:')) {
    return s;
  }

  // Derive the host by stripping the `/api` suffix from AppConfig.apiBaseUrl.
  String host = AppConfig.apiBaseUrl;
  if (host.endsWith('/api')) {
    host = host.substring(0, host.length - 4);
  } else if (host.endsWith('/api/')) {
    host = host.substring(0, host.length - 5);
  }
  if (host.endsWith('/')) host = host.substring(0, host.length - 1);

  if (s.startsWith('/')) return '$host$s';
  return '$host/$s';
}
