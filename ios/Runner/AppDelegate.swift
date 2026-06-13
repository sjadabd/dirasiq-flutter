import UIKit
import Flutter
import OneSignalFramework
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let videoSecurityChannel = "mulhimiq/video_security"

  private var videoProtectionEnabled = false
  private var isAppObscured = false
  private var privacyOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureVideoSecurityChannel()

    OneSignal.initialize(
      "b136e33d-56f0-4fc4-ad08-8c8a534ca447",
      withLaunchOptions: launchOptions
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }

    return super.application(app, open: url, options: options)
  }

  private func configureVideoSecurityChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: Self.videoSecurityChannel,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "VIDEO_SECURITY_UNAVAILABLE",
            message: "Video security handler is unavailable.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "enableProtection":
        self.enableVideoProtection()
        result(nil)
      case "disableProtection":
        self.disableVideoProtection()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func enableVideoProtection() {
    guard !videoProtectionEnabled else {
      updatePrivacyOverlay()
      return
    }

    videoProtectionEnabled = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    updatePrivacyOverlay()
  }

  private func disableVideoProtection() {
    videoProtectionEnabled = false
    isAppObscured = false
    NotificationCenter.default.removeObserver(
      self,
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    removePrivacyOverlay()
  }

  @objc private func screenCaptureDidChange() {
    updatePrivacyOverlay()
  }

  @objc private func applicationWillResignActive() {
    isAppObscured = true
    updatePrivacyOverlay()
  }

  @objc private func applicationDidBecomeActive() {
    isAppObscured = false
    updatePrivacyOverlay()
  }

  private func updatePrivacyOverlay() {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { [weak self] in
        self?.updatePrivacyOverlay()
      }
      return
    }

    guard videoProtectionEnabled else {
      removePrivacyOverlay()
      return
    }

    if UIScreen.main.isCaptured {
      showPrivacyOverlay(isCaptureActive: true)
    } else if isAppObscured {
      showPrivacyOverlay(isCaptureActive: false)
    } else {
      removePrivacyOverlay()
    }
  }

  private func showPrivacyOverlay(isCaptureActive: Bool) {
    guard let window else {
      return
    }

    removePrivacyOverlay()

    let overlay: UIView
    if isCaptureActive {
      overlay = UIView()
      overlay.backgroundColor = .black
    } else {
      let blur = UIBlurEffect(style: .systemMaterialDark)
      overlay = UIVisualEffectView(effect: blur)
      overlay.backgroundColor = UIColor.black.withAlphaComponent(0.65)
    }

    overlay.translatesAutoresizingMaskIntoConstraints = false
    overlay.isUserInteractionEnabled = false
    window.addSubview(overlay)
    NSLayoutConstraint.activate([
      overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor),
      overlay.topAnchor.constraint(equalTo: window.topAnchor),
      overlay.bottomAnchor.constraint(equalTo: window.bottomAnchor),
    ])
    window.bringSubviewToFront(overlay)
    privacyOverlay = overlay
  }

  private func removePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
