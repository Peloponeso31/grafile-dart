import 'dart:typed_data';

import 'constants.dart';
import 'exceptions.dart';
import 'values.dart';

/// Decodes a native column value from its [kind] and the JSON produced by
/// `grafile_column_json`.
///
/// Shared by the synchronous statement accessors and the async worker
/// transport, so both paths produce identical [GrafileValue] graphs.
GrafileValue decodeColumnValue(int kind, Object? json) {
  switch (kind) {
    case GrafileColumnKind.nullValue:
      return const GrafileNull();
    case GrafileColumnKind.integer:
      if (json is! num) return _unexpected('integer', json);
      return GrafileInt(json.toInt());
    case GrafileColumnKind.float:
      if (json is! num) return _unexpected('float', json);
      return GrafileDouble(json.toDouble());
    case GrafileColumnKind.text:
      if (json is! String) return _unexpected('text', json);
      return GrafileText(json);
    case GrafileColumnKind.blob:
      if (json is! String) return _unexpected('blob', json);
      return GrafileBlob(decodeHexBlob(json));
    case GrafileColumnKind.boolean:
      if (json is! bool) return _unexpected('boolean', json);
      return GrafileBool(json);
    case GrafileColumnKind.list:
    case GrafileColumnKind.map:
      return GrafileValue.fromJson(json);
    case GrafileColumnKind.node:
      return nodeFromJson(json);
    case GrafileColumnKind.edge:
      return edgeFromJson(json);
    case GrafileColumnKind.date:
      return GrafileDate(temporalText(json));
    case GrafileColumnKind.localTime:
      return GrafileLocalTime(temporalText(json));
    case GrafileColumnKind.time:
      return GrafileTime(temporalText(json));
    case GrafileColumnKind.localDateTime:
      return GrafileLocalDateTime(temporalText(json));
    case GrafileColumnKind.dateTime:
      return GrafileDateTime(temporalText(json));
    case GrafileColumnKind.duration:
      return GrafileDuration(temporalText(json));
    case GrafileColumnKind.point:
      return pointFromJson(json);
    default:
      return GrafileValue.fromJson(json);
  }
}

/// Decodes a node object: `{"id", "labels", "properties"}`.
GrafileNode nodeFromJson(Object? raw) {
  if (raw is! Map) return _unexpected('node', raw);
  return GrafileNode(
    id: raw['id'] as int,
    labels: [for (final label in raw['labels'] as List) label as String],
    properties: propertiesFromJson(raw['properties']),
  );
}

/// Decodes an edge object: `{"id", "type", "start", "end", "properties"}`.
GrafileEdge edgeFromJson(Object? raw) {
  if (raw is! Map) return _unexpected('edge', raw);
  return GrafileEdge(
    id: raw['id'] as int,
    type: raw['type'] as String?,
    start: raw['start'] as int?,
    end: raw['end'] as int?,
    properties: propertiesFromJson(raw['properties']),
  );
}

/// Decodes a point object: `{"srid", "x", "y"[, "z"]}`.
GrafilePoint pointFromJson(Object? raw) {
  if (raw is! Map) return _unexpected('point', raw);
  return GrafilePoint(
    srid: raw['srid'] as int,
    x: (raw['x'] as num).toDouble(),
    y: (raw['y'] as num).toDouble(),
    z: raw['z'] == null ? null : (raw['z'] as num).toDouble(),
  );
}

/// Decodes a property map into typed values.
Map<String, GrafileValue> propertiesFromJson(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      entry.key.toString(): GrafileValue.fromJson(entry.value),
  };
}

/// Reads the ISO 8601 rendering of a temporal value.
String temporalText(Object? json) {
  if (json is! String) return _unexpected('temporal', json);
  return json;
}

/// Decodes the `"0x…"` hex rendering of bytes.
Uint8List decodeHexBlob(String value) {
  final hex = value.startsWith('0x') ? value.substring(2) : value;
  if (hex.length.isOdd) {
    throw const GrafileException(
      GrafileResult.mismatch,
      'blob hex string has odd length',
    );
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

Never _unexpected(String what, Object? json) {
  throw GrafileException(
    GrafileResult.mismatch,
    '$what column did not serialize to the expected JSON shape '
    '(got ${json.runtimeType})',
  );
}
