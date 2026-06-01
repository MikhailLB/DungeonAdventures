import FirebaseMessaging
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins eagerly so Firebase Messaging installs its
    // UNUserNotificationCenterDelegate swizzle before any push tap arrives.
    GeneratedPluginRegistrant.register(with: self)

    // Explicit APNs registration on every launch — ensures the FCM→APNs
    // token mapping is refreshed even when permission was granted in a
    // previous install.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
