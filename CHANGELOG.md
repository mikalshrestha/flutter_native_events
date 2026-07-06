## 1.1.0

* Added buffered native events so Android/iOS events sent before Flutter starts listening can be delivered after `NativeEvents.init()`.
* Added `bufferNativeEvents` and `nativeEventBufferSize` to `NativeEventConfig`.
* Documented deep link, notification, payment redirect, and auth callback buffering behavior.

## 1.0.0

* Stable API and pub.dev-ready documentation.
* Added `NativeEvents.init()` and `NativeEvents.dispose()`.
* Added `NativeEventConfig` for logging, replay-last-event, and default request timeout.
* Added `NativeEventSource` enum and updated `NativeEvent.source`.
* Added explicit native request handlers with `replySuccess` and `replyError`.
* Added `NativeEventTimeoutException`, `NativeEventPayloadException`, and `NativeEventNotInitializedException`.
* Added replay-last-event support for late named listeners.
* Expanded example app, README, and tests for production SDK/module usage.

## Roadmap History

* `0.1.0` - Basic emit/on/all.
* `0.2.0` - Typed event model and payload validation.
* `0.3.0` - once(), replay, logging config.
* `0.5.0` - request-response and timeout.
* `0.8.0` - cleanup, lifecycle handling, tests.
* `1.0.0` - stable API and pub.dev-ready docs.
