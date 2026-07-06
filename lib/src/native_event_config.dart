class NativeEventConfig {
  const NativeEventConfig({
    this.enableLogging = false,
    this.replayLastEvent = false,
    this.bufferNativeEvents = true,
    this.nativeEventBufferSize = 64,
    this.requestTimeout = const Duration(seconds: 30),
  });

  final bool enableLogging;
  final bool replayLastEvent;
  final bool bufferNativeEvents;
  final int nativeEventBufferSize;
  final Duration requestTimeout;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'enableLogging': enableLogging,
    'replayLastEvent': replayLastEvent,
    'bufferNativeEvents': bufferNativeEvents,
    'nativeEventBufferSize': nativeEventBufferSize,
    'requestTimeoutMs': requestTimeout.inMilliseconds,
  };
}
