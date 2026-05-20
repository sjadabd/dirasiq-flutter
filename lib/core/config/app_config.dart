/// Centralized application configuration
class AppConfig {
  // 🌐 Base server origin (use this for images/assets and non-API endpoints)
  // Production: "https://api.mulhimiq.com"
  // Local dev — Android emulator uses 10.0.2.2 to reach the host loopback:
  static const String serverBaseUrl = "http://10.0.2.2:3000";

  // 📡 API base (compose from serverBaseUrl to keep them in sync)
  static const String apiBaseUrl = "$serverBaseUrl/api";

  // 💬 Chat service (separate Node process on a different port; same JWT).
  // Production: "https://chat.mulhimiq.com" (or wherever the chat host lands).
  static const String chatBaseUrl = "http://10.0.2.2:3001";

  // 🔔 OneSignal configuration (unchanged)
  static const String oneSignalAppId = "b136e33d-56f0-4fc4-ad08-8c8a534ca447";
}
