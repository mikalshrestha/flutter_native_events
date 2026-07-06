class NativeEventException implements Exception {
  const NativeEventException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() {
    final codeText = code == null ? '' : ' ($code)';
    return 'NativeEventException$codeText: $message';
  }
}

class NativeEventTimeoutException extends NativeEventException {
  const NativeEventTimeoutException(super.message,
      {super.code = 'request_timeout', super.details});

  @override
  String toString() => 'NativeEventTimeoutException ($code): $message';
}

class NativeEventPayloadException extends NativeEventException {
  const NativeEventPayloadException(super.message,
      {super.code = 'invalid_payload', super.details});

  @override
  String toString() => 'NativeEventPayloadException ($code): $message';
}

class NativeEventNotInitializedException extends NativeEventException {
  const NativeEventNotInitializedException([
    super.message =
        'NativeEvents.init() must be called before using the event bus.',
  ]) : super(code: 'not_initialized');

  @override
  String toString() => 'NativeEventNotInitializedException ($code): $message';
}
