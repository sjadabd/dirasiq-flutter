import UIKit
import Flutter
import OneSignalFramework

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    OneSignal.initialize("b136e33d-56f0-4fc4-ad08-8c8a534ca447", withLaunchOptions: launchOptions)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
