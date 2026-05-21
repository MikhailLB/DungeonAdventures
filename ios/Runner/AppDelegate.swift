import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// Orientation mask controlled by Flutter via "app/orientation" MethodChannel.
  /// Starts unlocked so the loading screen can rotate freely.
  static var orientationLock: UIInterfaceOrientationMask = .allButUpsideDown

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "OrientationLock")?.messenger else { return }
    let channel = FlutterMethodChannel(name: "app/orientation", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "lock":
        AppDelegate.orientationLock = .portrait
        result(nil)
      case "unlock":
        AppDelegate.orientationLock = .allButUpsideDown
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// This override is the only reliable way to restrict rotation on iPad.
  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }
}
