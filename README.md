# flutter_native_events

Stable native to Flutter event bus for Flutter modules, SDKs, and hybrid apps.

## What is flutter_native_events?

`flutter_native_events` is a lightweight event bus over Flutter platform channels. It lets Dart, Android Kotlin, and iOS Swift exchange typed events, listen to filtered streams, receive one-time callbacks, and make request-response calls with correlated `requestId` values and timeouts.

It is designed for embedded Flutter modules, SDK-style integrations, payment callbacks, login/session events, native navigation, and native account picker flows.

## Why not use MethodChannel directly?

Use `MethodChannel` directly when you have one or two simple calls.

Use `flutter_native_events` when the contract starts to look like an SDK: repeated event names, native callbacks into Flutter, one-time listeners, request-response flows, timeout handling, payload validation, lifecycle cleanup, and readable host-app examples.

## Installation

```yaml
dependencies:
  flutter_native_events: ^1.0.0
```

```bash
flutter pub get
```

## Quick Start

```dart
await NativeEvents.init(
  config: const NativeEventConfig(
    enableLogging: true,
    replayLastEvent: true,
    bufferNativeEvents: true,
    nativeEventBufferSize: 64,
    requestTimeout: Duration(seconds: 30),
  ),
);

final subscription = NativeEvents.on('payment_success').listen((event) {
  print(event.data);
});

await NativeEvents.emit('logout', data: {'reason': 'manual'});

final once = await NativeEvents.once('payment_success');
print(once.data);

await subscription.cancel();
await NativeEvents.dispose();
```

## Flutter to Native Events

```dart
await NativeEvents.emit(
  'payment_failed',
  data: {
    'code': 'card_declined',
    'message': 'The payment was declined.',
  },
);
```

Android:

```kotlin
NativeEventsBridge.on("payment_failed") { event ->
    val code = event.data["code"]
}
```

iOS:

```swift
NativeEventsBridge.shared.on("payment_failed") { event in
    let code = event.data["code"]
}
```

## Native to Flutter Events

Android:

```kotlin
NativeEventsBridge.sendToFlutter(
    "payment_success",
    mapOf("transactionId" to "TXN123")
)
```

iOS:

```swift
NativeEventsBridge.shared.sendToFlutter(
    name: "payment_success",
    data: ["transactionId": "TXN123"]
)
```

Flutter:

```dart
NativeEvents.all.listen((event) {
  print('${event.name}: ${event.data}');
});
```

## Request-Response

Flutter:

```dart
try {
  final response = await NativeEvents.request(
    'select_account',
    data: {'currency': 'USD'},
  );
  print(response.data?['accountNumber']);
} on NativeEventTimeoutException catch (error) {
  print(error);
} on NativeEventException catch (error) {
  print(error);
}
```

Android:

```kotlin
NativeEventsBridge.onRequest("select_account") { request ->
    NativeEventsBridge.replySuccess(
        requestId = request.requestId,
        data = mapOf("accountNumber" to "1234567890")
    )
}

NativeEventsBridge.onRequest("select_account_error") { request ->
    NativeEventsBridge.replyError(
        requestId = request.requestId,
        errorCode = "ACCOUNT_NOT_SELECTED",
        errorMessage = "User cancelled account selection"
    )
}
```

iOS:

```swift
NativeEventsBridge.shared.onRequest("select_account") { request in
    NativeEventsBridge.shared.replySuccess(
        requestId: request.requestId,
        data: ["accountNumber": "1234567890"]
    )
}

NativeEventsBridge.shared.onRequest("select_account_error") { request in
    NativeEventsBridge.shared.replyError(
        requestId: request.requestId,
        errorCode: "ACCOUNT_NOT_SELECTED",
        errorMessage: "User cancelled account selection"
    )
}
```

Every request and response contains the same `requestId`. Dart validates the correlation before returning a response.

## Buffered Native Events

Native events sent before Flutter starts listening are buffered by default. This is useful for deep links, push notification taps, payment redirects, auth callbacks, and other native events that can happen before Dart calls `NativeEvents.init()`.

```dart
await NativeEvents.init(
  config: const NativeEventConfig(
    bufferNativeEvents: true,
    nativeEventBufferSize: 64,
  ),
);
```

Android:

```kotlin
NativeEventsBridge.sendToFlutter(
    "deep_link_opened",
    mapOf("url" to url)
)
```

iOS:

```swift
NativeEventsBridge.shared.sendToFlutter(
    name: "deep_link_opened",
    data: ["url": url.absoluteString]
)
```

The native bridge keeps the newest buffered events up to `nativeEventBufferSize` and flushes them to Flutter in order when the event stream attaches. Set `bufferNativeEvents` to `false` or `nativeEventBufferSize` to `0` if you prefer to drop events until Flutter is ready.

## Android Host Integration

```kotlin
import com.flutter_native_events.NativeEventsBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        NativeEventsBridge.on("logout") { event ->
            // Clear native session.
        }

        NativeEventsBridge.sendToFlutter(
            "native_navigation",
            mapOf("route" to "settings")
        )
    }
}
```

## iOS Host Integration

```swift
import Flutter
import flutter_native_events
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    NativeEventsBridge.shared.on("logout") { event in
      // Clear native session.
    }

    NativeEventsBridge.shared.sendToFlutter(
      name: "session_timeout",
      data: ["reason": "idle"]
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## Flutter Module / SDK Integration

For a Flutter SDK embedded inside an Android or iOS app, initialize the bus at SDK startup and dispose it at SDK shutdown.

```dart
class PaymentSdk {
  Future<void> start() {
    return NativeEvents.init(
      config: const NativeEventConfig(replayLastEvent: true),
    );
  }

  Future<void> stop() => NativeEvents.dispose();
}
```

Register native handlers once per Flutter engine lifecycle. Avoid registering inside frequently repeated UI callbacks.

## Payment SDK Example

```dart
NativeEvents.on('payment_success').listen((event) {
  final transactionId = event.data['transactionId'];
});

await NativeEvents.emit('payment_started', data: {'amount': 1200});
```

## Session Timeout Example

Native can notify Flutter:

```kotlin
NativeEventsBridge.sendToFlutter(
    "session_timeout",
    mapOf("reason" to "idle")
)
```

Flutter can notify native:

```dart
await NativeEvents.emit('logout', data: {'reason': 'session_timeout'});
```

## Native Account Picker Request

```dart
final response = await NativeEvents.request('select_account');
final accountNumber = response.data?['accountNumber'];
```

## Best Practices

Use stable lower snake case names such as `payment_success`, `logout`, `native_navigation`, and `session_timeout`.

Keep payloads small and JSON-safe. Convert `DateTime`, files, controllers, widgets, streams, futures, and functions into IDs, strings, or primitive maps before sending.

Use `request` when Flutter needs an acknowledgement. Use `emit` for fire-and-forget events.

Cancel subscriptions when screens, SDK sessions, or modules are disposed:

```dart
final subscription = NativeEvents.on('payment_success').listen((event) {
  print(event.data);
});

await subscription.cancel();
```

## Limitations

Payloads must contain only `String`, `int`, `double`, `bool`, `null`, `List`, and `Map<String, dynamic>`.

Native events are process-local and engine-local. The plugin does not provide durable queues, background delivery, cross-process messaging, or event persistence across app restarts.

Replay stores only the latest event per event name in Dart memory while initialized.

## Troubleshooting

If `NativeEventNotInitializedException` is thrown, call `NativeEvents.init()` before using `emit`, `on`, `once`, `all`, or `request`.

If `NativeEventTimeoutException` is thrown, confirm native registered `onRequest(name)` and calls `replySuccess` or `replyError` with the same `requestId`.

If payload validation fails, remove unsupported values such as `BuildContext`, `Widget`, `File`, controllers, functions, streams, futures, or raw `DateTime`.

If Flutter does not receive native events, make sure Dart has initialized and subscribed before native sends the event, or enable `replayLastEvent` for the latest event per name.

See `example/` for a complete Flutter, Android, and iOS sample.
