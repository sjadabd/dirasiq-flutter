import UIKit
import Flutter
import OneSignalFramework
import GoogleSignIn

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

  // 👇 معالجة URLs لـ Google Sign-In (iOS 9+)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // معالجة Google Sign-In URLs
    let handled = GIDSignIn.sharedInstance.handle(url)
    if handled {
      return true
    }
    
    // تمرير باقي URLs للـ Flutter
    return super.application(app, open: url, options: options)
  }
}
