import Flutter
import XCTest

@testable import flutter_native_events

class RunnerTests: XCTestCase {
  func testEmitDispatchesToBridgeListener() {
    let plugin = FlutterNativeEventsPlugin()
    let resultExpectation = expectation(description: "result block must be called.")
    var receivedReason: String?

    NativeEventsBridge.shared.on("logout") { event in
      receivedReason = event.data["reason"] as? String
    }

    let call = FlutterMethodCall(
      methodName: "emit",
      arguments: [
        "name": "logout",
        "data": ["reason": "manual"]
      ]
    )

    plugin.handle(call) { result in
      XCTAssertNil(result)
      XCTAssertEqual(receivedReason, "manual")
      resultExpectation.fulfill()
    }

    waitForExpectations(timeout: 1)
    NativeEventsBridge.shared.off("logout")
  }
}
