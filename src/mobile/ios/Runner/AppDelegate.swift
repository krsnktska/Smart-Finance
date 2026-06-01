import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var initialLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let controller = window?.rootViewController as? FlutterViewController {
      deepLinkChannel = FlutterMethodChannel(name: "smartfinance/deep_link", binaryMessenger: controller.binaryMessenger)
      deepLinkChannel?.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        if call.method == "getInitialLink" {
          result(self.initialLink)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    initialLink = url.absoluteString
    deepLinkChannel?.invokeMethod("linkChanged", arguments: url.absoluteString)
    return super.application(app, open: url, options: options)
  }
}
