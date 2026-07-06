import Flutter
import UIKit

public class FlutterNativeEventsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "flutter_native_events/methods",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "flutter_native_events/events",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlutterNativeEventsPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      NativeEventsBridge.shared.configure(call.arguments as? [String: Any])
      result(nil)
    case "dispose":
      NativeEventsBridge.shared.dispose()
      result(nil)
    case "emit":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_arguments", message: "Arguments must be a map.", details: nil))
        return
      }
      do {
        try NativeEventsBridge.shared.handleFlutterEvent(arguments)
        result(nil)
      } catch {
        result(FlutterError(code: "emit_failed", message: error.localizedDescription, details: nil))
      }
    case "request":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_arguments", message: "Arguments must be a map.", details: nil))
        return
      }
      NativeEventsBridge.shared.handleFlutterRequest(arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    NativeEventsBridge.shared.attachSink(events)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NativeEventsBridge.shared.attachSink(nil)
    return nil
  }
}
