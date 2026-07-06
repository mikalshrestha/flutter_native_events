import 'native_event_exception.dart';

Map<String, dynamic> jsonSafePayload(Map<String, dynamic>? data) {
  final payload =
      data == null ? <String, dynamic>{} : Map<String, dynamic>.from(data);
  validateJsonSafeValue(payload);
  return payload;
}

dynamic jsonSafeValue(Object? value) {
  validateJsonSafeValue(value);
  if (value is List) {
    return value.map<dynamic>(jsonSafeValue).toList(growable: false);
  }
  if (value is Map) {
    return value.map<String, dynamic>((key, value) {
      if (key is! String) {
        throw const NativeEventPayloadException(
            'Payload map keys must be strings.');
      }
      return MapEntry<String, dynamic>(key, jsonSafeValue(value));
    });
  }
  return value;
}

void validateJsonSafeValue(Object? value, {String path = 'payload'}) {
  if (value == null || value is bool || value is String) {
    return;
  }
  if (value is int) {
    return;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw NativeEventPayloadException('$path contains a non-finite double.');
    }
    return;
  }
  if (value is List) {
    for (var index = 0; index < value.length; index += 1) {
      validateJsonSafeValue(value[index], path: '$path[$index]');
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw NativeEventPayloadException(
            '$path contains a non-string map key.');
      }
      validateJsonSafeValue(entry.value, path: '$path.${entry.key}');
    }
    return;
  }
  throw NativeEventPayloadException(
    '$path contains unsupported value type ${value.runtimeType}. '
    'Convert it to String, int, double, bool, null, List, or Map<String, dynamic>.',
  );
}
