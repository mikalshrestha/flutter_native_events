import Flutter
import flutter_native_events
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    NativeEventsBridge.shared.on("logout") { event in
      NSLog("Flutter logout: \(event.data)")
      NativeEventsBridge.shared.sendToFlutter(
        name: "payment_success",
        data: ["transactionId": "IOS-TXN-123"]
      )
    }

    NativeEventsBridge.shared.onRequest("select_account") { request in
      NativeEventsBridge.shared.replySuccess(
        requestId: request.requestId,
        data: [
          "accountNumber": "1234567890",
          "source": "ios"
        ]
      )
    }

    NativeEventsBridge.shared.onRequest("select_account_error") { request in
      NativeEventsBridge.shared.replyError(
        requestId: request.requestId,
        errorCode: "ACCOUNT_NOT_SELECTED",
        errorMessage: "User cancelled account selection"
      )
    }

    NativeEventsBridge.shared.sendToFlutter(
      name: "native_navigation",
      data: ["route": "ios/home"]
    )
  }
}
