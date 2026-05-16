# dirasiq-f — Flutter Student Mobile App Analysis

> Read-only audit. No source files were modified. See [../CLAUDE.md](../CLAUDE.md) for the cross-project index.

## At a glance

- **Package name:** `mulhimiq` (Pub) — branded "Mulhim IQ" on stores. Version `1.0.2+8`.
- **Flutter SDK:** `3.35.5` (pinned in `.fvmrc`). Dart SDK constraint: `^3.9.2`.
- **State management:** **GetX** (`get` 4.6.6) — `GetxController` + `Obx` + named routes + DI via `Get.lazyPut`/`Get.put` (with `InitialBindings`).
- **HTTP:** **Dio** 5.7 with a custom `AuthInterceptor` and `LogInterceptor`. Base URL `https://api.mulhimiq.com/api`.
- **Auth:** email/password + Google (`google_sign_in` 6.2) + Apple (`sign_in_with_apple` 6.1).
- **Push:** OneSignal Flutter 5.1. App ID `b136e33d-56f0-4fc4-ad08-8c8a534ca447` in source.
- **Storage:** `shared_preferences` 2.3 (⚠ plaintext — no `flutter_secure_storage` for tokens).
- **Maps/location:** `geolocator` 12.0; **no Mapbox/Leaflet** — only coordinate capture.
- **Camera/QR:** `mobile_scanner` 7.1.3 (attendance check-in).
- **Media:** `video_player` 2.9 + `better_player_plus` 1.1.2 + `image_picker` 1.1.2.
- **Charts:** `fl_chart` 0.68 (exam grade reports).
- **Calendar:** `table_calendar` 3.0.10.
- **i18n / RTL:** `intl` 0.20; `flutter_localizations` — **locale hard-coded to Arabic (`ar`) with `Directionality.rtl`**.
- **Fonts:** `google_fonts` 6.2 (no specific family selected in code).
- **Splash/icons:** `flutter_launcher_icons` 0.13, `flutter_native_splash` 2.4.
- **Lints:** `flutter_lints` 6.0 via `analysis_options.yaml`.

---

## Root files

### `pubspec.yaml`
- Defines app metadata, dependencies, and asset declarations (`assets/logo.png`, `assets/google_logo.png` — small footprint, no bundled data files).
- Pins major deps but leaves caret ranges open — `flutter pub upgrade` could pull breaking minors.

### `analysis_options.yaml`
- Includes `package:flutter_lints/flutter.yaml`. No custom rules.

### `.fvmrc`
- Pins Flutter 3.35.5 for FVM users.

### `.metadata`
- Flutter project metadata (channel: stable). Records migration history.

### `.gitignore`, `dirasiq.iml`, `README.md`
- Standard scaffolding. README is the default Flutter starter text — nothing project-specific.

### Android — `android/app/src/main/AndroidManifest.xml`
- Package `com.mulhimiq.app`. App label "Mulhim IQ".
- Permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `CAMERA`, `POST_NOTIFICATIONS`.
- OneSignal `app_id` `b136e33d-56f0-4fc4-ad08-8c8a534ca447`.
- MainActivity `singleTop`, hardware acceleration on, embedding v2.

### iOS — `ios/Runner/Info.plist`
- Bundle id matches Android. iOS marketing version 1.0.1, build 7.
- Portrait + Landscape on both iPhone and iPad.
- **Camera usage description (Arabic):** "نحتاج إلى استخدام الكاميرا لمسح رمز QR لتسجيل حضورك" — camera is for QR attendance.
- Photo library usage description is in English — translation gap.
- Both "When in Use" and Background location modes declared.
- Google Sign-In URL scheme + client IDs:
  - GID Client ID `765386230641-a2iko4308ouljpb9kk0ut0shpl9vvqm0.apps.googleusercontent.com`
  - Server client ID `765386230641-bl1vn9b2o3o5eghkj1b0jl31ri1b4gr2.apps.googleusercontent.com`
- OneSignal `BackgroundModes` includes `remote-notification`.
- App Tracking Transparency description present.
- `ITSAppUsesNonExemptEncryption = false`.

### Assets
- `assets/logo.png`, `assets/google_logo.png`. That's it.

---

## `lib/main.dart`

- **Purpose:** app bootstrap, themes, routing table, WhatsApp support overlay.
- **Boot order:** `WidgetsFlutterBinding.ensureInitialized()` → `NotificationService.init()` (OneSignal + permission requests) → `runApp(MyApp())`.
- **`MyApp`:** `GetMaterialApp` with:
  - `initialRoute: '/splash'`
  - `localizationsDelegates` for material/widgets/cupertino; `supportedLocales: [Locale('ar'), Locale('en')]`; `locale: Locale('ar')`.
  - Builder wraps everything in `Directionality(textDirection: TextDirection.rtl, …)`.
  - Themes: Material 3 light/dark using `AppColors.lightColorScheme` / `darkColorScheme`.
  - `themeMode: ThemeController.to.themeMode.value` (reactive via Obx-style binding).
  - `initialBinding: InitialBindings()`.
  - `smartManagement: SmartManagement.onlyBuilder` (controllers disposed after route pop).
- **19 named routes** defined as `GetPage`s (see Routing section below).
- **`_WhatsAppSupportOverlay`:** draggable floating button to `https://wa.me/9647724275947`. Position persisted in `SharedPreferences` (`wa_pos`).
- **Issues:**
  - WhatsApp number hard-coded.
  - No deep-link URI scheme registered in the platform manifests despite a custom URI (`mulhimiq://`) used by the QR flow.
  - Some `GetPage` argument casts are unsafe (relies on `Get.arguments as Map<String, dynamic>` without null checks — see "Quality findings").
  - `ThemeMode.system` is the constructor default but no persistence layer keeps it across launches.

---

## `lib/core/`

### `lib/core/config/app_config.dart`
- Constants:
  - `serverBaseUrl = "https://api.mulhimiq.com"`
  - `apiBaseUrl = "$serverBaseUrl/api"`
  - `oneSignalAppId = "b136e33d-56f0-4fc4-ad08-8c8a534ca447"`
- **Issue:** No build flavor / `--dart-define` for env switching.

### `lib/core/config/initial_bindings.dart`
- `Bindings` subclass. Wires services and global controllers:
  - `Get.lazyPut<ApiService>` (fenix=true)
  - `Get.lazyPut<AuthService>` (fenix=true)
  - `Get.lazyPut<GoogleAuthService>` (fenix=true)
  - `Get.lazyPut<AppleAuthService>` (fenix=true)
  - `Get.put<AuthController>(permanent: true)`
  - `Get.put<GlobalController>(permanent: true)`
- Theme controller is registered via its own static `to` getter.

### `lib/core/services/api_service.dart`
- **Purpose:** HTTP client for all non-auth student endpoints.
- **Dio configuration:** base URL, 15 s connect/receive timeouts, JSON headers, `LogInterceptor`, custom `AuthInterceptor` that:
  - Reads token from `SharedPreferences` per request and sets `Authorization: Bearer …`.
  - On `401`: clears storage and `Get.offAllNamed('/login')`.
- **Method inventory (~30+ methods):**
  - **Dashboard:** `fetchDashboardOverview`, `fetchWeeklySchedule`, `fetchUnreadNotificationsCount`.
  - **Courses:** `fetchSuggestedCourses({maxDistance})`, `fetchCourseDetails`, `fetchSuggestedTeachers`, `fetchTeacherDetails`, `fetchTeacherIntroVideo`, `fetchTeacherSubjectsCourses`.
  - **Enrollments / attendance:** `fetchEnrollments`, `fetchCourseWeeklySchedule`, `fetchCourseAttendance`, `studentCheckInQr({teacherId})`.
  - **Assignments:** `fetchMyAssignments`, `fetchAssignmentDetails`, `fetchMyAssignmentSubmission`, `submitAssignment`.
  - **Exams:** `fetchMyExams({type})`, `fetchExamDetails`, `fetchMyExamGrade`, `fetchExamReportByType`.
  - **Evaluations:** `fetchMyEvaluations({from, to})`, `fetchEvaluationDetails`.
  - **Invoices:** `fetchMyInvoices({studyYear, courseId, status})`, `fetchInvoiceDetails`, `fetchInvoiceFull`, `fetchInstallments`, `fetchInvoiceEntries`, `fetchInstallmentFull`.
  - **Bookings:** `createBooking`, `fetchMyBookings`, `fetchBookingDetails`, `cancelBooking`, `reactivateBooking`, `fetchBookingStatsSummary`.
  - **Notifications:** `fetchMyNotifications`, `markNotificationRead`.
  - **Search:** `searchStudentUnified({maxDistance})`.
  - **News:** `fetchLatestNews()` (hard-codes `newsType=mobile`).
  - **Grades:** `fetchGradesAllStudent`, `fetchGradesAllTeacher`.
- **Error handling:** try/catch wraps each call; `DioException` is unwrapped to extract `response.data['message']`. Generic `Exception` is rethrown.
- **Issues:**
  - No certificate pinning; vulnerable to MITM on hostile networks.
  - No retry / exponential backoff.
  - `fetchUnreadNotificationsCount` falls back across many possible field names — a sign of unstable API response shape.
  - No caching layer (every screen refetches on open).
  - No request signing.
  - Base URL hard-coded.

### `lib/core/services/auth_service.dart`
- **Purpose:** auth-flow API + local persistence.
- **Methods:** `registerStudent`, `login`, `verifyEmail`, `resendVerification`, `requestPasswordReset`, `resetPassword`, `updateProfile`, `completeProfile`, `isLoggedIn`, `getUser`, `isProfileComplete`, `logout`, `deleteAccount`.
- Sends OneSignal player ID alongside register/login.
- Stores token + user JSON in `SharedPreferences`.
- **Bugs:**
  - **`deleteAccount` posts to `/api/student/account`** — but the Dio base URL already ends in `/api`, so it 404s.
  - **`SharedPreferences` is not secure** — tokens and user data are accessible to other apps on a rooted device. Move to `flutter_secure_storage`.
  - No refresh-token flow — token expiry forces full re-login.
  - No model class for user — everything is `Map<String, dynamic>`.

### `lib/core/services/google_auth_service.dart`
- Scopes: `email`, `profile`. iOS client ID + server client ID hard-coded.
- Flow: sign out previous session → `signIn()` → get `idToken` → `POST /auth/google-auth` with `userType='student'` → store token + user → `NotificationService.loginUser(...)`.
- Caches `_lastEmail` for the subsequent email-verification screen.
- **Issues:** static state (`_lastEmail`) is not safe under concurrent attempts; DioException loses stack trace; no differentiation between `EMAIL_VERIFICATION_REQUIRED` and a generic auth failure beyond a string check.

### `lib/core/services/apple_auth_service.dart`
- For Android, uses `webAuthenticationOptions` with `clientId: 'com.mulhimiq.auth'` and `redirectUri: 'https://api.mulhimiq.com/api/auth/apple-redirect'`.
- Posts `identityToken`, `authorizationCode`, optional `givenName`/`familyName`, plus `userType='student'`.
- **Issues:** `clientId` mismatches iOS bundle id; response decoded via `ResponseType.bytes` + manual UTF-8 (Dio handles encoding by default — unnecessary).

### `lib/core/services/notification_service.dart`
- Singleton (`NotificationService.instance`).
- `init()`: `OneSignal.initialize(appId)`, requests permission (iOS prompt + Android 13+), wires foreground display, click listener, and a push-subscription observer that stores `playerId` in `SharedPreferences`.
- `loginUser(userId)` / `logoutUser()` / `rebindExternalUserId()` bind/unbind OneSignal external user ID.
- Click handler routes via `data['route']` and emits to `NotificationEvents` streams.
- **Issues:**
  - External user ID is sometimes `user._id`, sometimes `user.id` — same naming inconsistency the backend exposes.
  - Click handler dereferences `data['route']` without null check.
  - No deep-link parsing (relies on the route string + raw arguments).

### `lib/core/services/notification_events.dart`
- App-wide event bus: two broadcast `StreamController`s (`onNewNotification`, `onNotificationPayload`).
- **Issue:** streams are never closed (no top-level dispose).

### `lib/core/services/permission_service.dart`
- Static helpers: `requestCameraPermission`, `requestNotificationPermission`, `requestLocationWhenInUsePermission`. Each requests permission and offers to open settings if permanently denied.
- **Gap:** no rationale UI; doesn't distinguish iOS "restricted" from "denied".

---

## `lib/shared/`

### `lib/shared/controllers/theme_controller.dart`
- `GetxController` with `Rx<ThemeMode>`.
- Methods: `setThemeMode`, `toggleDarkLight`; static `to` getter.
- **Issue:** no persistence (resets on every launch). Read `SharedPreferences` on `onInit`.

### `lib/shared/controllers/global_controller.dart`
- Holds `user` (`Rxn<Map>`), `unreadCount` (`Rx<int>`).
- On init: `loadUser()` from `SharedPreferences`, subscribes to `NotificationEvents`, refreshes unread count.
- Updates the home-screen badge via `AppBadgePlus.updateBadge(count)`.
- `logout()` clears user/count and delegates to `AuthService`.
- **Issues:** errors silently swallowed; badge call can fail without UI feedback.

### `lib/shared/themes/app_colors.dart`
- Full Material 3 palettes for light and dark.
- Light: primary `#1E3A8A`, secondary `#4ADE80`, tertiary `#0EA5E9`, accent `#F59E0B`, surface `#FFFFFF`, background `#F9FAFB`, error `#EF4444`, text `#111827`.
- Dark: primary `#60A5FA`, secondary `#34D399`, surface `#1F2937`, background `#0F172A`, text `#F9FAFB`.
- Subject gradients (Math/Science/Language/Art) and motivational color helpers.

### `lib/shared/widgets/global_app_bar.dart`
- Reusable app bar with user menu (profile / logout), search field (read-only, navigates to `StudentUnifiedSearchScreen`), theme toggle, notifications icon with unread badge.
- Avatar resolution tries: base64 keys (7 variants) → URL keys (8 variants) → nested paths → initials fallback. This defensiveness is a smell — the backend should return one consistent field.
- **Issues:** no caching layer (`NetworkImage` direct); no `SafeArea` padding (notch overlap on some devices); search uses a `TextField` styled read-only instead of an `InkWell` + label.

---

## `lib/features/` — feature modules

Each feature follows the same shape: `controllers/`, `screens/`, sometimes `widgets/`. Screens are `StatefulWidget` with manual `ScrollController` + pagination logic.

### Auth (`lib/features/auth/`)
- **`auth_controller.dart`** — bridges screens to `AuthService`; on login success routes by profile completeness.
- **`login_screen.dart`** — email + password fields, Google button, Apple button (platform-gated). Routes to `EmailVerificationScreen` when backend signals `EMAIL_VERIFICATION_REQUIRED`. `TextEditingController`s **not disposed**.
- **`register_screen.dart`** — name/email/password/student-phone/parent-phone/school + gender + grade (fetched from API) + birth date picker + optional geolocation. No email format / phone format validation client-side.
- **`email_verification_screen.dart`** — OTP entry + resend. No countdown for resend cooldown.
- **`reset_password_screen.dart`** — email/code/new-password; minimum length 8. No strength meter.
- **`forgot_password_screen.dart`** — sends reset code email, routes to reset screen.
- **`auth_text_field.dart`** — reusable styled `TextFormField`. No input formatters for phone.
- **`auth_button.dart`** — gradient primary / outlined secondary with loading state.
- **`profile_completion_guard.dart`** — checks completion in `didChangeDependencies`; shows an 8 s snackbar with "Complete Now". Runs only once per mount.

### Splash & onboarding (`lib/features/splash/`, `lib/features/onboarding/`)
- **`splash_screen.dart`** — 1.5 s splash; reads `has_seen_onboarding_2025_v1` flag and routes to `/onboarding`, `/login`, `/home`, or `/complete-profile`.
- **`onboarding_screen.dart`** — 4-page carousel with fade + slide transitions; sets the onboarding flag on completion.

### Home (`lib/features/home/`)
- **`home_screen.dart`** — student dashboard. Sections: global app bar, dashboard overview (progress %, attendance %), `student_calendar.dart`, `news_carousel.dart`, next-session/exam cards with countdown, suggested teachers list. Uses `WidgetsBindingObserver` for resume refresh but **does not remove the observer in `dispose`** — leak.
- **`news_carousel.dart`** — auto-rotating `PageView` (5 s), 0.78 viewport fraction. Timer never cancelled on dispose — leak.
- **`student_calendar.dart`** — `TableCalendar` keyed by weekday (1–7); bottom-sheet day details.

### Root shell (`lib/features/root/`)
- **`root_shell.dart`** — five-tab bottom navigation: Home, Courses, Enrollments, Invoices, Bookings. Implemented with a `KeyedSubtree` that's rebuilt by bumping a version counter — easier than `IndexedStack` but loses per-tab state. Back-button on non-home tab navigates to home; on home, an exit-confirmation dialog appears.

### Courses (`lib/features/courses/`)
- **`suggested_courses_screen.dart`** — paginated infinite-scroll list. `maxDistance` hard-coded to 10 km.
- **`course_details_screen.dart`** — fetches one course; shows image, description, schedule; enroll/booking-status button.
- **`suggested_courses_widget.dart`** — compact 3-item carousel; duplicates list logic from the full screen.

### Enrollments (`lib/features/enrollments/`)
- **`enrollments_screen.dart`** — enrolled courses list. URL normalization checks four key variants — backend response inconsistency.
- **`course_weekly_schedule_screen.dart`** — fetches and sorts by weekday + start time.
- **`course_attendance_screen.dart`** — present/absent/leave filter (UI-side only; no API filter param).
- **`enrollment_actions_screen.dart`** — hub of 8 actions for an enrolled course: QR check-in, weekly schedule, assignments, attendance, daily exams, monthly exams, evaluations, exam grades.

### Assignments (`lib/features/assignments/`)
- **`student_assignments_screen.dart`** — paginated list; status colors hard-coded.
- **`assignment_details_screen.dart`** — details + my-submission + grade. There's an `_enableAutoRefresh = false` flag and an unused 10 s polling timer — dead code.

### Exams (`lib/features/exams/`)
- **`student_exams_screen.dart`** — list filtered by `fixedType` (daily/monthly) passed in by the calling route.
- **`student_exam_grades_screen.dart`** — `fl_chart` bar chart of grades; report type hard-coded to `monthly`.

### Evaluations (`lib/features/evaluations/`)
- **`student_evaluations_screen.dart`** — paginated list with date range filter (UI present but `from`/`to` not yet passed to API). Maps rating keys (`excellent`, `very_good`, `good`, `fair`, `weak`) to Arabic strings + colors.

### Invoices (`lib/features/invoices/`)
- **`student_invoices_screen.dart`** — filter by study year + course + status (`pending`/`partial`/`paid`/`overdue`); pie chart of payment distribution. `limit=100` hard-coded; current academic year computed client-side (September–August).
- **`invoice_details_screen.dart`** — invoice + entries + payment pie chart.
- **`installment_details_screen.dart`** — installment plan view (assumes installments exist).

### Bookings (`lib/features/bookings/`)
- **`bookings_list_screen.dart`** — list with status filter and animation. Optional `onNavigateToTab` callback for the root shell.
- **`booking_details_screen.dart`** — show details, cancel with reason, reactivate. Resolves booking id from three sources (widget arg, `Get.arguments`, route args) — redundant.

### Notifications (`lib/features/notifications/`)
- **`notifications_screen.dart`** — 9 filter buttons (mix of snake_case and UPPER_CASE keys — backend inconsistency). Infinite scroll, mark-as-read, real-time append via `NotificationEvents`. Tap routes by payload (`assignment_id`/`exam_id`/`booking_id`/etc.).

### QR (`lib/features/qr/`)
- **`qr_scan_screen.dart`** — `mobile_scanner` camera. Expects QR payload `mulhimiq://attend?teacher=<id>`; validates scheme + host; pops with `teacherId`. Camera flip + torch buttons.

### Search (`lib/features/search/`)
- **`student_unified_search_screen.dart`** — single API hit returning teachers + courses + subjects sections. No debounce — fires per keystroke. `maxDistance` hard-coded to 8.

### Teachers (`lib/features/teachers/`)
- **`suggested_teachers_screen.dart`** — paginated list; client-side search filter.
- **`teacher_details_screen.dart`** — teacher profile + subjects + courses + intro video (HLS via `video_player`/`better_player_plus`). Controller disposal not fully shown — verify.

### Profile (`lib/features/profile/`)
- **`complete_profile_screen.dart`** — required-field collector after signup (phone, parent phone, school, gender, grade, birth date, optional address + location). Study year hard-coded to `2025-2026`.
- **`student_profile_screen.dart`** — view/edit + base64 profile image. "Delete account" with confirmation. Controllers not disposed; base64 in memory is wasteful for larger images.

### Students / teachers / etc. listings
- Stub feature folders (`features/students/`, `features/teachers/controllers/`) — present in the folder structure but largely used by teacher-side flows that don't exist in this app (this is the student app). Likely scaffolding from an earlier shared codebase.

---

## Architecture overview

### State management
- GetX everywhere: `GetxController` + `Obx`/`GetX` widgets + reactive `Rx*` primitives.
- DI through `Get.lazyPut`/`Get.put`. Services are singletons (`fenix: true`); `AuthController` and `GlobalController` are permanent.
- `SmartManagement.onlyBuilder` disposes per-route controllers automatically.

### Navigation
- All routes declared as `GetPage` in `main.dart`. No `auto_route` / `go_router`. Arguments passed via `Get.toNamed(route, arguments: …)` and read via `Get.arguments`.

### Repository pattern
- Not used. Services call Dio directly and return `Map<String, dynamic>` / `List<dynamic>`. There are no model classes — every screen handles its own JSON unpacking.

### Theming & i18n
- Material 3 light/dark schemes in `AppColors`. Locale forced to Arabic with RTL `Directionality` wrapper. No translation layer — Arabic strings inlined.

---

## API surface used by the app

Endpoints called (all under `https://api.mulhimiq.com/api`):

- **Auth:** `POST /auth/register/student`, `POST /auth/login`, `POST /auth/verify-email`, `POST /auth/resend-verification`, `POST /auth/request-password-reset`, `POST /auth/reset-password`, `POST /auth/update-profile`, `POST /auth/complete-profile`, `POST /auth/google-auth`, `POST /auth/apple-auth`, `DELETE /student/account` (buggy in `AuthService.deleteAccount`).
- **Dashboard:** `GET /student/dashboard/overview`, `GET /student/dashboard/weekly-schedule`.
- **Courses:** `GET /student/courses/suggested?maxDistance=…`, `GET /student/courses/{id}`.
- **Teachers:** `GET /student/teachers/suggested`, `GET /student/teachers/{id}/intro-video`, `GET /student/teachers/{id}/subjects-courses`.
- **Enrollments:** `GET /student/enrollments`, `GET /student/enrollments/schedule/weekly/by-course/{id}`, `GET /student/attendance/by-course/{id}`.
- **Assignments:** `GET /student/assignments`, `GET /student/assignments/{id}`, `GET /student/assignments/{id}/submission`, `POST /student/assignments/{id}/submit`.
- **Exams:** `GET /student/exams?type=daily|monthly`, `GET /student/exams/{id}`, `GET /student/exams/{id}/my-grade`, `GET /student/exams/report/by-type`.
- **Evaluations:** `GET /student/evaluations`, `GET /student/evaluations/{id}`.
- **Invoices:** `GET /student/invoices`, `GET /student/invoices/{id}`, `GET /student/invoices/{id}/full`, `GET /student/invoices/{id}/installments`, `GET /student/invoices/{id}/entries`, `GET /student/invoices/{id}/installments/{installmentId}/full`.
- **Bookings:** `POST /student/bookings`, `GET /student/bookings`, `GET /student/bookings/{id}`, `PATCH /student/bookings/{id}/cancel`, `PATCH /student/bookings/{id}/reactivate`, `GET /student/bookings/stats/summary`.
- **Attendance:** `POST /student/attendance/check-in?teacherId=…`.
- **Notifications:** `GET /notifications/user/my-notifications`, `PUT /notifications/{id}/read`.
- **Search:** `GET /student/search/unified?maxDistance=…`.
- **News:** `GET /news?newsType=mobile`.
- **Grades:** `GET /grades/all-student`, `GET /grades/all-teacher`.

---

## Auth flow (concrete)

1. **Signup (email/password):** `RegisterScreen` → `AuthService.registerStudent()` → `POST /auth/register/student` (with OneSignal player ID). On success: store token+user in `SharedPreferences`, navigate `/home`. If backend requires email verification → `EmailVerificationScreen`.
2. **Email verification:** `POST /auth/verify-email` with email + code. On success → `/login`.
3. **Login (email/password):** `POST /auth/login`. On success check `isProfileComplete()` (looks for `phone`, `gender`, `birthDate`). Complete → `/home`. Incomplete → `/complete-profile`. `EMAIL_VERIFICATION_REQUIRED` → `EmailVerificationScreen`.
4. **Google Sign-In:** `GoogleAuthService.signInWithGoogle('student')` → `POST /auth/google-auth` with id token → same post-login flow.
5. **Apple Sign-In (iOS/macOS only):** `AppleAuthService.signInWithApple('student')` → `POST /auth/apple-auth` → same post-login flow.
6. **Profile completion:** `CompleteProfileScreen` posts to `POST /auth/complete-profile` and replaces `user` in storage.
7. **Password reset:** `ForgotPasswordScreen` → `POST /auth/request-password-reset` → `ResetPasswordScreen` → `POST /auth/reset-password` → `/login`.
8. **Logout:** clear token + user in `SharedPreferences`, `OneSignal.logout()`, navigate `/login`.

Token expiry: no refresh flow. The Dio `AuthInterceptor` catches `401` and force-logs-out.

---

## Routing table (from `main.dart`)

| Path | Screen | Notes |
|---|---|---|
| `/splash` | `SplashScreen` | Initial route. |
| `/onboarding` | `OnboardingScreen` | First-run only. |
| `/login` | `LoginScreen` | Email + Google + Apple. |
| `/home` | `RootShell` | Bottom-tab shell. |
| `/complete-profile` | `CompleteProfileScreen` | Required after signup. |
| `/student-profile` | `StudentProfileScreen` | View / edit profile. |
| `/notifications` | `NotificationsScreen` | Filterable list. |
| `/enrollments` | `EnrollmentsScreen` | Tab content (also a standalone route). |
| `/enrollment-actions` | `EnrollmentActionsScreen` | Per-course hub. Args: `courseId`, `courseName`, `teacherId`. |
| `/qr-scan` | `QrScanScreen` | Returns `teacherId` via pop. |
| `/course-weekly-schedule` | `CourseWeeklyScheduleScreen` | Args: `courseId`, `courseName`. |
| `/course-attendance` | `CourseAttendanceScreen` | Args: `courseId`, `courseName`. |
| `/invoices` | `StudentInvoicesScreen` | Tab content. |
| `/invoice-details` | `InvoiceDetailsScreen` | Arg: `invoiceId`. |
| `/installment-details` | `InstallmentDetailsScreen` | Args: `invoiceId`, `installmentId`. |
| `/suggested-courses` | `SuggestedCoursesScreen` | Tab content. |
| `/course-details` | `CourseDetailsScreen` | Arg: `courseId`. |
| `/suggested-teachers` | `SuggestedTeachersScreen` | Browse teachers. |
| `/teacher-details` | `TeacherDetailsScreen` | Arg: `teacherId`. |
| `/bookings` | `BookingsListScreen` | Tab content. |
| `/booking-details` | `BookingDetailsScreen` | Arg: `bookingId` (nullable). |

No URL scheme registered (`mulhimiq://` is only used internally by the QR scanner). To enable real deep linking from push notifications or web, register the scheme in `AndroidManifest.xml` (intent filter) and `Info.plist` (`CFBundleURLTypes`).

---

## Push notifications

- **OneSignal init** in `main.dart` before `runApp` — `NotificationService.init()`.
- **Permissions:** iOS prompt at init; Android 13+ requires `POST_NOTIFICATIONS` (declared in manifest).
- **External user ID** bound on login, unbound on logout, re-bound on profile update. The ID source toggles between `user._id` and `user.id` — pick one.
- **Player ID** stored in `SharedPreferences` for inclusion in the next register/login API call.
- **Foreground display:** OneSignal default display is triggered (notification shows in-app).
- **Click handling:** parses `data['route']` and emits to `NotificationEvents`. The notifications screen and detail screens are listeners.
- **Categories observed:** `assignment_due`, `class_reminder`, `grade_update`, `COURSE_UPDATE`, `PAYMENT_REMINDER`, `teacher_message`, `SYSTEM_ANNOUNCEMENT`, `booking_status`. Case inconsistency is a backend issue.

---

## Quality findings (prioritized)

### Critical security
1. **Tokens in `SharedPreferences`** — migrate to `flutter_secure_storage`.
2. **No HTTPS certificate pinning** on Dio — vulnerable to MITM with a malicious root CA.
3. **OAuth client IDs and OneSignal app ID hard-coded** in source — visible after APK/IPA unpack. Acceptable per OAuth threat model but limits rotation.
4. **No code obfuscation** declared (`flutter build --obfuscate --split-debug-info=…`). Add for release builds.
5. **Plaintext user JSON in `SharedPreferences`** — exposes email, phone, school on a compromised device.

### High-severity bugs
6. **`AuthService.deleteAccount`** uses path `/api/student/account` — 404s because base URL already has `/api`. Fix to `/student/account`.
7. **Unsafe `Get.arguments as Map<String, dynamic>`** in several routes — crashes when arguments are missing or wrong type. Add null-safe extraction.
8. **`HomeScreen` doesn't remove `WidgetsBindingObserver`** in `dispose` — leaks across hot reloads and after sign-out.
9. **`NewsCarousel` auto-slide timer** is never cancelled — leaks and may fire on disposed widget.
10. **Many screens don't dispose `TextEditingController`s** (`LoginScreen`, `RegisterScreen`, `StudentProfileScreen`).
11. **`AssignmentDetailsScreen` has a dead 10 s polling timer** behind `_enableAutoRefresh = false` — remove.
12. **`unread count` field unpacking is multi-fallback** — backend should normalize.

### Performance
13. **No image caching** — replace `NetworkImage` with `cached_network_image`.
14. **`RootShell` rebuilds tab subtree on every switch** — use `IndexedStack` with `AutomaticKeepAliveClientMixin` so list scroll positions and form state survive.
15. **Per-keystroke search** in `student_unified_search_screen.dart` — add a debounce (e.g., 250 ms).
16. **`limit=100` invoices** at once — paginate.

### Maintainability
17. **No model classes** for any API resource — adopt `freezed` + `json_serializable`.
18. **Magic strings** for routes, statuses, weekday keys, filter values — centralize in `lib/core/constants/`.
19. **Duplicate widgets:** `SuggestedCoursesScreen` and `suggested_courses_widget.dart` reimplement the same list logic.
20. **Avatar URL/base64 resolution** is repeated in many places — extract `AvatarImage` widget.
21. **No tests** — add `widget_test.dart`s for at least login, splash, and booking flow.
22. **`student_evaluations_screen.dart` filter UI** doesn't pass `from`/`to` to the API — wire it up.
23. **Mixed naming:** `_id` vs `id`, snake_case vs camelCase vs UPPER_CASE for the same notification categories.

### UX / accessibility
24. No semantic labels on icons; consider `tooltip` / `Semantics(label: …)`.
25. Color-only status indicators on exam/evaluation cards — add an icon or text label.
26. Splash spinner doesn't appear after the initial 1.5 s delay if routing hangs.
27. Hard-coded WhatsApp number and Apple Sign-In availability check use `defaultTargetPlatform` — works but consider `Platform.isIOS` for clarity.

---

## Tech debt / inconsistencies summary

- **State + persistence**: GetX reactive vars + raw `SharedPreferences` mix; theme not persisted; user profile in three places (storage, `GlobalController.user`, individual screens).
- **API response shape**: defensive multi-key lookups everywhere imply the backend response envelope drifts (`data.courses`, `data.items`, top-level array, etc.). Standardize on a `ApiResponse<T>` envelope on the server.
- **Routing**: no centralized constants for route names — `Get.toNamed('/booking-details', …)` strings are scattered.
- **OneSignal app ID + OAuth client IDs**: should at least be `--dart-define`d so test/staging builds don't share prod IDs.
- **No env switching**: single `app_config.dart` for all flavors. Use Flutter flavors + `--dart-define`.
- **`flutter_lints`** is on but no project-specific lint additions (e.g., `unawaited_futures`, `cancel_subscriptions`) — both would catch the leaks listed above.
- **Dead/stub features**: `lib/features/students/`, `lib/features/teachers/controllers/` look leftover from a shared monorepo phase.
- **Generated artifacts** (`.flutter-plugins-dependencies`, `pubspec.lock`) are tracked — `.lock` is intentional, the rest are generated.
