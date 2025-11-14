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

    // تسجيل Frameworks
    GeneratedPluginRegistrant.register(with: self)

    // تهيئة OneSignal
    OneSignal.initialize("b136e33d-56f0-4fc4-ad08-8c8a534ca447", withLaunchOptions: launchOptions)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {

    // دعم تسجيل الدخول عبر Google
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }

    return super.application(app, open: url, options: options)
  }
}
