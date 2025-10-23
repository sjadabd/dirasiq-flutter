import UIKit
import Flutter
import OneSignalFramework

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    OneSignal.Debug.setLogLevel(.LL_VERBOSE)
    OneSignal.initialize("b136e33d-56f0-4fc4-ad08-8c8a534ca447")
    OneSignal.Notifications.requestPermission({ accepted in
        print("User accepted notifications: \(accepted)")
    }, fallbackToSettings: true)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
