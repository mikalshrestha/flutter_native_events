class NativeEventConfig {
  const NativeEventConfig({
    this.enableLogging = false,
    this.replayLastEvent = false,
    this.requestTimeout = const Duration(seconds: 30),
  });

  final bool enableLogging;
  final bool replayLastEvent;
  final Duration requestTimeout;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'enableLogging': enableLogging,
        'replayLastEvent': replayLastEvent,
        'requestTimeoutMs': requestTimeout.inMilliseconds,
      };
}
