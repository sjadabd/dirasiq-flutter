/// Centralized application configuration
class AppConfig {
  // 🌐 Base server origin (use this for images/assets and non-API endpoints)
  static const String serverBaseUrl = "https://api.mulhimiq.com";

  // 📡 API base (compose from serverBaseUrl to keep them in sync)
  static const String apiBaseUrl = "$serverBaseUrl/api";

  // 🔔 OneSignal configuration (unchanged)
  static const String oneSignalAppId = "b136e33d-56f0-4fc4-ad08-8c8a534ca447";
}
