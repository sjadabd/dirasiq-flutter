/// Centralized application configuration.
///
/// Single switch for "where does the app connect to?". Flip [useLocal] and
/// every Dio + Socket.IO call follows. Mirrors the dashboard's
/// `src/utils/api-mode.js` so both clients have the same operator-friendly
/// toggle.
///
///   useLocal = true   → localhost (Android emulator uses 10.0.2.2 for the
///                       host loopback).
///   useLocal = false  → production domains (api.mulhimiq.com +
///                       chat.mulhimiq.com).
class AppConfig {
  // ↓↓↓ FLIP this one line to switch the whole app ↓↓↓
  static const bool useLocal = false;

  // -------- LOCAL (Android emulator → host loopback via 10.0.2.2) ----------
  static const String _localServer = 'http://10.0.2.2:3000';
  static const String _localChat = 'http://10.0.2.2:3001';

  // -------- PUBLIC (production) -------------------------------------------
  static const String _publicServer = 'https://api.mulhimiq.com';
  static const String _publicChat = 'https://chat.mulhimiq.com';

  // -------- Resolved (read these everywhere in the app) -------------------

  /// Origin (no `/api` suffix). Use for absolute asset paths (uploaded images,
  /// intro-video HLS manifests, etc.).
  static const String serverBaseUrl = useLocal ? _localServer : _publicServer;

  /// REST API root (includes `/api`).
  static const String apiBaseUrl = '$serverBaseUrl/api';

  /// Account deletion request page (serves `public/delete-account.html` on the API).
  static const String deleteAccountPageUrl = '$serverBaseUrl/delete-account';

  /// Chat service root (REST + Socket.IO share this host). No `/api`.
  static const String chatBaseUrl = useLocal ? _localChat : _publicChat;

  /// OneSignal — public app id, identifies the project (not auth).
  static const String oneSignalAppId = 'b136e33d-56f0-4fc4-ad08-8c8a534ca447';

  // -------- Feature flags --------------------------------------------------
  //
  // Phase 6 of the National Video Marketplace introduces a unified
  // "Course Hub" screen that replaces the legacy EnrollmentActionsScreen
  // grid for taps from "My Courses" and "My Teachers". The legacy screen
  // and route stay in place; this flag picks which one navigation runs
  // at the entry points.
  //
  // Now the SHIPPING DEFAULT: true. The Course Hub is the unified
  // course-detail surface — every "tap a course" path from My Courses,
  // My Teachers (single-course), and the teacher-courses picker lands
  // here. The legacy `/enrollment-actions` route still resolves so
  // deep-links from old notifications keep working, but no UI navigates
  // to it anymore.
  //
  // To roll back: set this back to false and the legacy 8-action grid
  // returns immediately on next cold start. No other code changes
  // needed — every navigation site already branches on this flag.
  static const bool useNewCourseHub = true;
}
