import 'native_event_exception.dart';
import 'native_event_payload.dart';

class NativeEventResponse {
  const NativeEventResponse({
    required this.requestId,
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  final String requestId;
  final bool success;
  final Map<String, dynamic>? data;
  final String? errorCode;
  final String? errorMessage;

  factory NativeEventResponse.fromMap(Map<Object?, Object?> map) {
    final requestId = map['requestId'];
    final success = map['success'];
    final rawData = map['data'];
    final errorCode = map['errorCode'];
    final errorMessage = map['errorMessage'];

    if (requestId is! String || requestId.isEmpty) {
      throw const NativeEventException(
          'Response requestId must be a non-empty string.');
    }
    if (success is! bool) {
      throw const NativeEventException('Response success must be a boolean.');
    }
    if (errorCode != null && errorCode is! String) {
      throw const NativeEventException('Response errorCode must be a string.');
    }
    if (errorMessage != null && errorMessage is! String) {
      throw const NativeEventException(
          'Response errorMessage must be a string.');
    }

    return NativeEventResponse(
      requestId: requestId,
      success: success,
      data: rawData == null ? null : _stringMap(rawData),
      errorCode: errorCode as String?,
      errorMessage: errorMessage as String?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'requestId': requestId,
        'success': success,
        if (data != null) 'data': data,
        if (errorCode != null) 'errorCode': errorCode,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };

  static Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map) {
      throw const NativeEventException('Response data must be a map.');
    }
    return value.map<String, dynamic>((key, value) {
      if (key is! String) {
        throw const NativeEventException('Response data keys must be strings.');
      }
      return MapEntry<String, dynamic>(key, jsonSafeValue(value));
    });
  }
}
