import 'package:flutter/services.dart';
import 'package:flutter_native_events/flutter_native_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('flutter_native_events/methods');
  const eventChannel = EventChannel('flutter_native_events/events');

  setUp(() {
    NativeEvents.debugResetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      if (call.method == 'init' || call.method == 'dispose') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    NativeEvents.debugResetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  test('NativeEvent serializes and deserializes', () {
    final event = NativeEvent(
      id: 'evt-1',
      name: 'payment_success',
      data: <String, dynamic>{'transactionId': 'TXN123'},
      timestamp: DateTime.parse('2026-07-06T10:00:00.000Z'),
      source: NativeEventSource.android,
    );

    final parsed = NativeEvent.fromMap(event.toMap().cast<Object?, Object?>());

    expect(parsed.id, event.id);
    expect(parsed.name, event.name);
    expect(parsed.data, event.data);
    expect(parsed.source, NativeEventSource.android);
    expect(parsed.timestamp, event.timestamp);
  });

  test('NativeEventRequest serializes and deserializes', () {
    final request = NativeEventRequest(
      requestId: 'req-1',
      name: 'select_account',
      data: <String, dynamic>{'currency': 'USD'},
      timestamp: DateTime.parse('2026-07-06T10:00:00.000Z'),
    );

    final parsed = NativeEventRequest.fromMap(
      request.toMap().cast<Object?, Object?>(),
    );

    expect(parsed.requestId, request.requestId);
    expect(parsed.name, request.name);
    expect(parsed.data, request.data);
    expect(parsed.timestamp, request.timestamp);
  });

  test('NativeEventResponse serializes and deserializes', () {
    const response = NativeEventResponse(
      requestId: 'req-1',
      success: false,
      errorCode: 'ACCOUNT_NOT_SELECTED',
      errorMessage: 'User cancelled account selection',
    );

    final parsed = NativeEventResponse.fromMap(
      response.toMap().cast<Object?, Object?>(),
    );

    expect(parsed.requestId, response.requestId);
    expect(parsed.success, false);
    expect(parsed.errorCode, response.errorCode);
    expect(parsed.errorMessage, response.errorMessage);
  });

  test('payload validation accepts JSON-safe values', () async {
    await NativeEvents.init();

    await expectLater(
      NativeEvents.emit(
        'payment_success',
        data: <String, dynamic>{
          'string': 'value',
          'int': 1,
          'double': 1.5,
          'bool': true,
          'null': null,
          'list': <Object?>['a', 1, false],
          'map': <String, dynamic>{'nested': 'ok'},
        },
      ),
      completes,
    );
  });

  test('payload validation rejects unsupported values', () async {
    await NativeEvents.init();

    expect(
      () => NativeEvents.emit(
        'bad_payload',
        data: <String, dynamic>{'future': Future<void>.value()},
      ),
      throwsA(isA<NativeEventPayloadException>()),
    );
  });

  test('once completes once and then cancels', () async {
    await NativeEvents.init();
    final future = NativeEvents.once('payment_success');

    NativeEvents.debugAddEvent(_event('payment_success', id: 'evt-1'));
    NativeEvents.debugAddEvent(_event('payment_success', id: 'evt-2'));

    final event = await future;
    expect(event.id, 'evt-1');
  });

  test('event filtering only emits matching event names', () async {
    await NativeEvents.init();
    final events = <NativeEvent>[];
    final subscription = NativeEvents.on('logout').listen(events.add);

    NativeEvents.debugAddEvent(_event('payment_success'));
    NativeEvents.debugAddEvent(_event('logout'));

    await Future<void>.delayed(Duration.zero);
    expect(events.map((event) => event.name), <String>['logout']);
    await subscription.cancel();
  });

  test('replayLastEvent sends latest named event to late listener', () async {
    await NativeEvents.init(
      config: const NativeEventConfig(replayLastEvent: true),
    );
    NativeEvents.debugAddEvent(_event('session_timeout'));

    final event = await NativeEvents.once('session_timeout');
    expect(event.name, 'session_timeout');
  });

  test('request timeout throws NativeEventTimeoutException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      if (call.method == 'init' || call.method == 'dispose') {
        return null;
      }
      if (call.method == 'request') {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return null;
    });
    await NativeEvents.init(
      config:
          const NativeEventConfig(requestTimeout: Duration(milliseconds: 10)),
    );

    await expectLater(
      NativeEvents.request('select_account'),
      throwsA(isA<NativeEventTimeoutException>()),
    );
  });

  test('response parsing returns success response', () async {
    String? requestId;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      if (call.method == 'init' || call.method == 'dispose') {
        return null;
      }
      final arguments = call.arguments as Map<dynamic, dynamic>;
      requestId = arguments['requestId'] as String;
      return <String, Object?>{
        'requestId': requestId,
        'success': true,
        'data': <String, Object?>{'accountNumber': '1234567890'},
      };
    });
    await NativeEvents.init();

    final response = await NativeEvents.request('select_account');

    expect(response.requestId, requestId);
    expect(response.success, true);
    expect(response.data?['accountNumber'], '1234567890');
  });

  test('config defaults are stable', () {
    const config = NativeEventConfig();

    expect(config.enableLogging, false);
    expect(config.replayLastEvent, false);
    expect(config.requestTimeout, const Duration(seconds: 30));
    expect(config.toMap()['requestTimeoutMs'], 30000);
  });

  test('exception messages are meaningful', () {
    const error = NativeEventTimeoutException('Request timed out.');

    expect(error.toString(), contains('NativeEventTimeoutException'));
    expect(error.toString(), contains('Request timed out.'));
  });

  test('using event bus before init throws', () {
    expect(
      () => NativeEvents.all,
      throwsA(isA<NativeEventNotInitializedException>()),
    );
  });
}

NativeEvent _event(String name, {String id = 'evt'}) {
  return NativeEvent(
    id: id,
    name: name,
    data: <String, dynamic>{},
    timestamp: DateTime.now().toUtc(),
    source: NativeEventSource.android,
  );
}
