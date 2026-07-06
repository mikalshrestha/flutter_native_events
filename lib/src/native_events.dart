import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_event.dart';
import 'native_event_config.dart';
import 'native_event_exception.dart';
import 'native_event_payload.dart';
import 'native_event_request.dart';
import 'native_event_response.dart';

class NativeEvents {
  NativeEvents._();

  static const MethodChannel _methodChannel = MethodChannel(
    'flutter_native_events/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'flutter_native_events/events',
  );

  static final Random _random = Random.secure();
  static int _counter = 0;

  static NativeEventConfig _config = const NativeEventConfig();
  static StreamController<NativeEvent>? _controller;
  static StreamSubscription<dynamic>? _nativeSubscription;
  static final Map<String, NativeEvent> _lastEventsByName =
      <String, NativeEvent>{};
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static NativeEventConfig get config => _config;

  static Future<void> init({
    NativeEventConfig config = const NativeEventConfig(),
  }) async {
    if (config.requestTimeout <= Duration.zero) {
      throw const NativeEventException(
        'Config requestTimeout must be greater than zero.',
      );
    }
    if (config.nativeEventBufferSize < 0) {
      throw const NativeEventException(
        'Config nativeEventBufferSize cannot be negative.',
      );
    }

    if (_initialized) {
      await dispose();
    }

    _config = config;
    _controller = StreamController<NativeEvent>.broadcast();
    _lastEventsByName.clear();

    try {
      await _methodChannel.invokeMethod<void>('init', config.toMap());
    } on PlatformException catch (error) {
      await dispose();
      throw NativeEventException(
        error.message ?? 'Failed to initialize native events.',
        code: error.code,
        details: error.details,
      );
    }

    _nativeSubscription = _eventChannel.receiveBroadcastStream().listen((
      rawEvent,
    ) {
      final event = _parseEvent(rawEvent);
      _recordAndDispatch(event);
    }, onError: _controller?.addError);

    _initialized = true;
    _log('initialized');
  }

  static Future<void> dispose() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    await _controller?.close();
    _controller = null;
    _lastEventsByName.clear();
    _initialized = false;

    try {
      await _methodChannel.invokeMethod<void>('dispose');
    } on PlatformException catch (error) {
      throw NativeEventException(
        error.message ?? 'Failed to dispose native events.',
        code: error.code,
        details: error.details,
      );
    }
  }

  static Stream<NativeEvent> get all {
    _ensureInitialized();
    return _controller!.stream;
  }

  static Stream<NativeEvent> on(String name) {
    _ensureInitialized();
    _validateName(name);

    late StreamController<NativeEvent> filteredController;
    StreamSubscription<NativeEvent>? subscription;

    filteredController = StreamController<NativeEvent>.broadcast(
      onListen: () {
        if (_config.replayLastEvent) {
          final lastEvent = _lastEventsByName[name];
          if (lastEvent != null && !filteredController.isClosed) {
            filteredController.add(lastEvent);
          }
        }
        subscription = all
            .where((event) => event.name == name)
            .listen(
              filteredController.add,
              onError: filteredController.addError,
              onDone: filteredController.close,
            );
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );

    return filteredController.stream;
  }

  static Future<NativeEvent> once(String name) {
    return on(name).first;
  }

  static Future<void> emit(String name, {Map<String, dynamic>? data}) async {
    _ensureInitialized();
    _validateName(name);

    final event = NativeEvent(
      id: _nextId(),
      name: name,
      data: jsonSafePayload(data),
      timestamp: DateTime.now().toUtc(),
      source: NativeEventSource.flutter,
    );

    try {
      await _methodChannel.invokeMethod<void>('emit', event.toMap());
      _log('emitted ${event.name}');
    } on PlatformException catch (error) {
      throw NativeEventException(
        error.message ?? 'Failed to emit native event.',
        code: error.code,
        details: error.details,
      );
    }
  }

  static Future<NativeEventResponse> request(
    String name, {
    Map<String, dynamic>? data,
    Duration? timeout,
  }) async {
    _ensureInitialized();
    _validateName(name);

    final effectiveTimeout = timeout ?? _config.requestTimeout;
    if (effectiveTimeout <= Duration.zero) {
      throw const NativeEventException(
        'Request timeout must be greater than zero.',
      );
    }

    final request = NativeEventRequest(
      requestId: _nextId(prefix: 'req'),
      name: name,
      data: jsonSafePayload(data),
      timestamp: DateTime.now().toUtc(),
    );

    try {
      final rawResponse = await _methodChannel
          .invokeMethod<Object?>('request', request.toMap())
          .timeout(effectiveTimeout);

      if (rawResponse is! Map) {
        throw const NativeEventException(
          'Native request response must be a map.',
        );
      }

      final response = NativeEventResponse.fromMap(
        rawResponse.cast<Object?, Object?>(),
      );
      if (response.requestId != request.requestId) {
        throw NativeEventException(
          'Native response requestId "${response.requestId}" does not match request "${request.requestId}".',
          code: 'request_id_mismatch',
        );
      }

      if (!response.success) {
        throw NativeEventException(
          response.errorMessage ?? 'Native request failed.',
          code: response.errorCode ?? 'request_failed',
        );
      }

      _log('request ${request.name} completed');
      return response;
    } on TimeoutException catch (_) {
      throw NativeEventTimeoutException(
        'Request "$name" timed out after ${effectiveTimeout.inMilliseconds}ms.',
      );
    } on PlatformException catch (error) {
      throw NativeEventException(
        error.message ?? 'Native request failed.',
        code: error.code,
        details: error.details,
      );
    }
  }

  @visibleForTesting
  static void debugAddEvent(NativeEvent event) {
    _ensureInitialized();
    _recordAndDispatch(event);
  }

  @visibleForTesting
  static void debugResetForTesting() {
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
    _controller?.close();
    _controller = null;
    _lastEventsByName.clear();
    _config = const NativeEventConfig();
    _initialized = false;
  }

  static NativeEvent _parseEvent(Object? rawEvent) {
    if (rawEvent is! Map) {
      throw const NativeEventException('Native event payload must be a map.');
    }
    return NativeEvent.fromMap(rawEvent.cast<Object?, Object?>());
  }

  static void _recordAndDispatch(NativeEvent event) {
    _lastEventsByName[event.name] = event;
    _controller?.add(event);
    _log('received ${event.name}');
  }

  static void _validateName(String name) {
    if (name.trim().isEmpty) {
      throw const NativeEventException(
        'Event name must be a non-empty string.',
      );
    }
  }

  static void _ensureInitialized() {
    if (!_initialized || _controller == null) {
      throw const NativeEventNotInitializedException();
    }
  }

  static String _nextId({String prefix = 'evt'}) {
    _counter = (_counter + 1) & 0x3fffffff;
    final randomPart = _random.nextInt(0x7fffffff).toRadixString(36);
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_counter-$randomPart';
  }

  static void _log(String message) {
    if (_config.enableLogging) {
      debugPrint('[flutter_native_events] $message');
    }
  }
}
