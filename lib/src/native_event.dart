import 'native_event_exception.dart';
import 'native_event_payload.dart';

enum NativeEventSource {
  flutter,
  android,
  ios,
  unknown;

  static NativeEventSource fromValue(Object? value) {
    if (value is! String) {
      return NativeEventSource.unknown;
    }
    return NativeEventSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => NativeEventSource.unknown,
    );
  }
}

class NativeEvent {
  const NativeEvent({
    required this.id,
    required this.name,
    required this.data,
    required this.timestamp,
    required this.source,
  });

  final String id;
  final String name;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final NativeEventSource source;

  factory NativeEvent.fromMap(Map<Object?, Object?> map) {
    final id = map['id'];
    final name = map['name'];
    final rawData = map['data'];
    final timestamp = map['timestamp'];
    final source = NativeEventSource.fromValue(map['source']);

    if (id is! String || id.isEmpty) {
      throw const NativeEventException(
        'Native event id must be a non-empty string.',
      );
    }
    if (name is! String || name.isEmpty) {
      throw const NativeEventException(
        'Native event name must be a non-empty string.',
      );
    }

    return NativeEvent(
      id: id,
      name: name,
      data: _stringMap(rawData),
      timestamp: _dateTime(timestamp),
      source: source,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'source': source.name,
  };

  static Map<String, dynamic> _stringMap(Object? value) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is! Map) {
      throw const NativeEventException('Native event data must be a map.');
    }

    return value.map<String, dynamic>((key, value) {
      if (key is! String) {
        throw const NativeEventException(
          'Native event data keys must be strings.',
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
    throw const NativeEventException('Native event timestamp is invalid.');
  }
}
