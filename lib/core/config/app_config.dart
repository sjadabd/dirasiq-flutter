/// Centralized application configuration
class AppConfig {
  // Change this in one place to affect the whole app
  // Base server origin (use this for images/assets and non-API endpoints)
  static const String serverBaseUrl = "http://192.168.68.103:3000";

  // API base (compose from serverBaseUrl to keep them in sync)
  static const String apiBaseUrl = "$serverBaseUrl/api";

  // OneSignal configuration
  static const String oneSignalAppId = "69b01adf-8a70-41fe-b47c-270f12f9662c";
}
