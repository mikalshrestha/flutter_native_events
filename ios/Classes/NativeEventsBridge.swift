import Flutter
import Foundation

public struct NativeEvent {
  public let id: String
  public let name: String
  public let data: [String: Any]
  public let timestamp: Int
  public let source: String

  public init(id: String, name: String, data: [String: Any], timestamp: Int, source: String) {
    self.id = id
    self.name = name
    self.data = data
    self.timestamp = timestamp
    self.source = source
  }
}

public struct NativeEventRequest {
  public let requestId: String
  public let name: String
  public let data: [String: Any]
  public let timestamp: Int

  public init(requestId: String, name: String, data: [String: Any], timestamp: Int) {
    self.requestId = requestId
    self.name = name
    self.data = data
    self.timestamp = timestamp
  }
}

public final class NativeEventsBridge {
  public static let shared = NativeEventsBridge()

  private var eventSink: FlutterEventSink?
  private var enableLogging = false
  private var bufferNativeEvents = true
  private var nativeEventBufferSize = 64
  private var pendingFlutterEvents: [NativeEvent] = []
  private var listeners: [String: [(NativeEvent) -> Void]] = [:]
  private var requestHandlers: [String: (NativeEventRequest) -> Void] = [:]
  private var pendingResults: [String: FlutterResult] = [:]

  private init() {}

  func configure(_ config: [String: Any]?) {
    enableLogging = config?["enableLogging"] as? Bool ?? false
    bufferNativeEvents = config?["bufferNativeEvents"] as? Bool ?? true
    nativeEventBufferSize = max(config?["nativeEventBufferSize"] as? Int ?? 64, 0)
    if !bufferNativeEvents || nativeEventBufferSize == 0 {
      pendingFlutterEvents.removeAll()
    } else {
      trimPendingFlutterEvents()
    }
  }

  func attachSink(_ sink: FlutterEventSink?) {
    DispatchQueue.main.async {
      self.eventSink = sink
      if let sink = sink {
        self.flushPendingFlutterEvents(to: sink)
      }
    }
  }

  func dispose() {
    attachSink(nil)
    pendingResults.removeAll()
    pendingFlutterEvents.removeAll()
  }

  public func sendToFlutter(name: String, data: [String: Any] = [:]) {
    let event = NativeEvent(
      id: newId(prefix: "evt"),
      name: name,
      data: data,
      timestamp: Int(Date().timeIntervalSince1970 * 1000),
      source: "ios"
    )
    sendToFlutter(event)
  }

  public func sendToFlutter(_ event: NativeEvent) {
    DispatchQueue.main.async {
      guard let eventSink = self.eventSink else {
        self.bufferEvent(event)
        return
      }

      eventSink(self.eventMap(event))
      self.log("sent \(event.name)")
    }
  }

  public func on(_ name: String, handler: @escaping (NativeEvent) -> Void) {
    listeners[name, default: []].append(handler)
  }

  public func off(_ name: String) {
    listeners.removeValue(forKey: name)
  }

  public func onRequest(_ name: String, handler: @escaping (NativeEventRequest) -> Void) {
    requestHandlers[name] = handler
  }

  public func clearRequestHandler(_ name: String) {
    requestHandlers.removeValue(forKey: name)
  }

  public func replySuccess(requestId: String, data: [String: Any] = [:]) {
    completeRequest(
      requestId: requestId,
      response: [
        "requestId": requestId,
        "success": true,
        "data": data
      ]
    )
  }

  public func replyError(requestId: String, errorCode: String, errorMessage: String) {
    completeRequest(
      requestId: requestId,
      response: [
        "requestId": requestId,
        "success": false,
        "errorCode": errorCode,
        "errorMessage": errorMessage
      ]
    )
  }

  func handleFlutterEvent(_ arguments: [String: Any]) throws {
    guard let name = arguments["name"] as? String, !name.isEmpty else {
      throw NativeEventsBridgeError.invalidArguments("Event name is required.")
    }

    let event = NativeEvent(
      id: arguments["id"] as? String ?? newId(prefix: "evt"),
      name: name,
      data: arguments["data"] as? [String: Any] ?? [:],
      timestamp: parseTimestamp(arguments["timestamp"]),
      source: arguments["source"] as? String ?? "flutter"
    )

    listeners[name]?.forEach { handler in
      handler(event)
    }
    log("received \(event.name)")
  }

  func handleFlutterRequest(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard
      let requestId = arguments["requestId"] as? String, !requestId.isEmpty,
      let name = arguments["name"] as? String, !name.isEmpty
    else {
      result(FlutterError(code: "invalid_request", message: "Request id and name are required.", details: nil))
      return
    }

    let request = NativeEventRequest(
      requestId: requestId,
      name: name,
      data: arguments["data"] as? [String: Any] ?? [:],
      timestamp: parseTimestamp(arguments["timestamp"])
    )

    guard let handler = requestHandlers[name] else {
      result([
        "requestId": requestId,
        "success": false,
        "errorCode": "NO_HANDLER",
        "errorMessage": "No iOS request handler registered for \"\(name)\"."
      ])
      return
    }

    pendingResults[requestId] = result
    handler(request)
  }

  private func completeRequest(requestId: String, response: [String: Any]) {
    guard let result = pendingResults.removeValue(forKey: requestId) else {
      return
    }
    DispatchQueue.main.async {
      result(response)
      self.log("replied \(requestId)")
    }
  }

  private func bufferEvent(_ event: NativeEvent) {
    guard bufferNativeEvents, nativeEventBufferSize > 0 else {
      log("dropped \(event.name); no Flutter listener")
      return
    }

    pendingFlutterEvents.append(event)
    trimPendingFlutterEvents()
    log("buffered \(event.name)")
  }

  private func flushPendingFlutterEvents(to sink: FlutterEventSink) {
    pendingFlutterEvents.forEach { event in
      sink(eventMap(event))
      log("flushed \(event.name)")
    }
    pendingFlutterEvents.removeAll()
  }

  private func trimPendingFlutterEvents() {
    let overflowCount = pendingFlutterEvents.count - nativeEventBufferSize
    if overflowCount > 0 {
      pendingFlutterEvents.removeFirst(overflowCount)
    }
  }

  private func eventMap(_ event: NativeEvent) -> [String: Any] {
    [
      "id": event.id,
      "name": event.name,
      "data": event.data,
      "timestamp": event.timestamp,
      "source": event.source
    ]
  }

  private func parseTimestamp(_ value: Any?) -> Int {
    if let number = value as? NSNumber {
      return number.intValue
    }
    if let string = value as? String, let date = ISO8601DateFormatter().date(from: string) {
      return Int(date.timeIntervalSince1970 * 1000)
    }
    return Int(Date().timeIntervalSince1970 * 1000)
  }

  private func newId(prefix: String) -> String {
    "\(prefix)-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString)"
  }

  private func log(_ message: String) {
    if enableLogging {
      NSLog("[NativeEventsBridge] \(message)")
    }
  }
}

private enum NativeEventsBridgeError: LocalizedError {
  case invalidArguments(String)

  var errorDescription: String? {
    switch self {
    case .invalidArguments(let message):
      return message
    }
  }
}
