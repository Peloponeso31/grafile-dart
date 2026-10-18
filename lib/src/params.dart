import 'dart:convert';

/// Encodes [params] into the JSON object accepted by the C ABI, or `null`
/// when there are no parameters.
///
/// Values must be JSON-encodable: `null`, `bool`, `num`, `String`, `List`,
/// `Map` with `String` keys, or [DateTime] (encoded as ISO 8601 text).
/// Typed values such as durations and points cannot travel through the JSON
/// parameter channel; build them in Cypher, e.g. `duration($text)` or
/// `point({x: $x, y: $y})`.
String? encodeParams(Map<String, Object?>? params) {
  if (params == null) return null;
  try {
    return const JsonEncoder(_toEncodable).convert(params);
  } on JsonUnsupportedObjectError catch (error) {
    throw ArgumentError.value(
      error.unsupportedObject,
      'params',
      'grafile parameters must be null, bool, num, String, DateTime, List or Map; '
          'build typed values in Cypher (duration(\$text), point({x: \$x, y: \$y}))',
    );
  }
}

Object? _toEncodable(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  throw JsonUnsupportedObjectError(value);
}
