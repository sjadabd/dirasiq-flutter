import UIKit
import Flutter
import OneSignalFramework
import GoogleSignIn
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Initialize Firebase
    FirebaseApp.configure()

    // تسجيل الـ plugins
    GeneratedPluginRegistrant.register(with: self)

    // تهيئة OneSignal
    OneSignal.initialize("b136e33d-56f0-4fc4-ad08-8c8a534ca447", withLaunchOptions: launchOptions)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // معالجة الروابط الخاصة بـ Google Sign-In
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {

    // 1️⃣ ضروري لـ Google Sign-In
    if GIDSignIn.sharedInstance.handle(url) {
        return true
    }

    // 2️⃣ ضروري لـ Firebase Authentication (يربط Google Sign-In مع Firebase)
    if Auth.auth().canHandle(url) {
        return true
    }

    // 3️⃣ تمرير الباقي للـ Flutter
    return super.application(app, open: url, options: options)
  }
}
