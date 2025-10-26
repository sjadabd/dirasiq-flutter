import UIKit
import Flutter
import OneSignalFramework
import GoogleSignIn   // 👈 أضف هذا السطر

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // تسجيل الـ plugins (Firebase / Google / OneSignal)
    GeneratedPluginRegistrant.register(with: self)

    // ✅ تهيئة OneSignal
    OneSignal.initialize("b136e33d-56f0-4fc4-ad08-8c8a534ca447", withLaunchOptions: launchOptions)

    // ✅ نرجع النتيجة الافتراضية
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 👇 أضف هذه الدالة لتفعيل Google Sign-In
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // إذا الرابط خاص بـ Google Sign-In → يتم معالجته هنا
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
