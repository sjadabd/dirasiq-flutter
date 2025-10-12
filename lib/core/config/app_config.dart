/// Centralized application configuration
class AppConfig {
  // Change this in one place to affect the whole app
  // Base server origin (use this for images/assets and non-API endpoints)
  static const String serverBaseUrl = "http://192.168.68.104:3000";

  // API base (compose from serverBaseUrl to keep them in sync)
  static const String apiBaseUrl = "$serverBaseUrl/api";

  // OneSignal configuration
  static const String oneSignalAppId = "b136e33d-56f0-4fc4-ad08-8c8a534ca447";
}
