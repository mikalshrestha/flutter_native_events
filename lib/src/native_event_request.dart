import 'native_event_exception.dart';
import 'native_event_payload.dart';

class NativeEventRequest {
  const NativeEventRequest({
    required this.requestId,
    required this.name,
    required this.data,
    required this.timestamp,
  });

  final String requestId;
  final String name;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  factory NativeEventRequest.fromMap(Map<Object?, Object?> map) {
    final requestId = map['requestId'];
    final name = map['name'];
    final rawData = map['data'];
    final timestamp = map['timestamp'];

    if (requestId is! String || requestId.isEmpty) {
      throw const NativeEventException(
        'Request requestId must be a non-empty string.',
      );
    }
    if (name is! String || name.isEmpty) {
      throw const NativeEventException(
        'Request name must be a non-empty string.',
      );
    }

    return NativeEventRequest(
      requestId: requestId,
      name: name,
      data: jsonSafePayload(rawData == null ? null : _stringMap(rawData)),
      timestamp: _dateTime(timestamp),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'requestId': requestId,
    'name': name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  static Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map) {
      throw const NativeEventPayloadException('Request data must be a map.');
    }
    return value.map<String, dynamic>((key, value) {
      if (key is! String) {
        throw const NativeEventPayloadException(
          'Request data keys must be strings.',
        );
      }
      return MapEntry<String, dynamic>(key, jsonSafeValue(value));
    });
  }

  static DateTime _dateTime(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw const NativeEventException('Request timestamp is invalid.');
  }
}
