import UIKit
import Flutter
import OneSignalFramework
import GoogleSignIn
import FirebaseCore
import FirebaseAuth   // ← مهم جداً لمنع الكراش

@main
@objc class AppDelegate: FlutterAppDelegate {
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // تهيئة Firebase
    FirebaseApp.configure()

    // تسجيل الـ Plugins
    GeneratedPluginRegistrant.register(with: self)

    // تهيئة OneSignal
    OneSignal.initialize("b136e33d-56f0-4fc4-ad08-8c8a534ca447", withLaunchOptions: launchOptions)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // معالجة الروابط الخاصة بتسجيل دخول Google
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {

    // 1️⃣ الدخول عبر Google
    if GIDSignIn.sharedInstance.handle(url) {
        return true
    }

    // 2️⃣ دعم Firebase Auth للروابط
    if Auth.auth().canHandle(url) {
        return true
    }

    // 3️⃣ تمرير الباقي للـ Flutter
    return super.application(app, open: url, options: options)
  }
}
