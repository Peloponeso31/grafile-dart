import 'dart:typed_data';

/// A value returned by grafile: the result of a Cypher expression or a
/// property read.
///
/// Top-level column values are decoded by kind (see `GrafileStatement`), so
/// temporal values, points, nodes and edges arrive as their dedicated
/// subclasses. Inside lists and maps the JSON conventions apply: temporal
/// values are ISO 8601 strings, bytes are `"0x…"` strings and entities are
/// JSON objects.
sealed class GrafileValue {
  const GrafileValue();

  /// Converts this value to plain Dart data, recursively for containers.
  ///
  /// Entity, temporal and point values are already rich Dart objects and are
  /// returned as-is.
  Object? toDart() => this;

  /// Decodes a JSON value produced by grafile's serializers.
  static GrafileValue fromJson(Object? json) {
    switch (json) {
      case null:
        return const GrafileNull();
      case final bool value:
        return GrafileBool(value);
      case final int value:
        return GrafileInt(value);
      case final double value:
        return GrafileDouble(value);
      case final String value:
        return GrafileText(value);
      case final List<Object?> value:
        return GrafileList([for (final item in value) fromJson(item)]);
      case final Map<Object?, Object?> value:
        return GrafileMap({
          for (final entry in value.entries)
            entry.key.toString(): fromJson(entry.value),
        });
    }
    throw ArgumentError.value(json, 'json', 'not a JSON value');
  }
}

/// Cypher `null`.
final class GrafileNull extends GrafileValue {
  /// Creates the null value.
  const GrafileNull();

  @override
  Object? toDart() => null;

  @override
  bool operator ==(Object other) => other is GrafileNull;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'GrafileNull()';
}

/// Cypher integer.
final class GrafileInt extends GrafileValue {
  /// Creates an integer value.
  const GrafileInt(this.value);

  /// The integer value.
  final int value;

  @override
  Object? toDart() => value;

  @override
  bool operator ==(Object other) => other is GrafileInt && other.value == value;

  @override
  int get hashCode => Object.hash(GrafileInt, value);

  @override
  String toString() => 'GrafileInt($value)';
}

/// Cypher float.
final class GrafileDouble extends GrafileValue {
  /// Creates a floating-point value.
  const GrafileDouble(this.value);

  /// The floating-point value.
  final double value;

  @override
  Object? toDart() => value;

  @override
  bool operator ==(Object other) =>
      other is GrafileDouble && other.value == value;

  @override
  int get hashCode => Object.hash(GrafileDouble, value);

  @override
  String toString() => 'GrafileDouble($value)';
}

/// Cypher string.
final class GrafileText extends GrafileValue {
  /// Creates a string value.
  const GrafileText(this.value);

  /// The string value.
  final String value;

  @override
  Object? toDart() => value;

  @override
  bool operator ==(Object other) =>
      other is GrafileText && other.value == value;

  @override
  int get hashCode => Object.hash(GrafileText, value);

  @override
  String toString() => 'GrafileText($value)';
}

/// Cypher boolean.
final class GrafileBool extends GrafileValue {
  /// Creates a boolean value.
  const GrafileBool(this.value);

  /// The boolean value.
  final bool value;

  @override
  Object? toDart() => value;

  @override
  bool operator ==(Object other) =>
      other is GrafileBool && other.value == value;

  @override
  int get hashCode => Object.hash(GrafileBool, value);

  @override
  String toString() => 'GrafileBool($value)';
}

/// Cypher bytes. The native JSON serializers render bytes as `"0x…"`; the
/// driver decodes them back into raw bytes.
final class GrafileBlob extends GrafileValue {
  /// Creates a bytes value.
  const GrafileBlob(this.bytes);

  /// The raw bytes.
  final Uint8List bytes;

  @override
  Object? toDart() => bytes;

  @override
  bool operator ==(Object other) {
    if (other is! GrafileBlob || other.bytes.length != bytes.length) {
      return false;
    }
    for (var i = 0; i < bytes.length; i++) {
      if (other.bytes[i] != bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => 'GrafileBlob(${bytes.length} bytes)';
}

/// Cypher list.
final class GrafileList extends GrafileValue {
  /// Creates a list value.
  const GrafileList(this.items);

  /// The list elements.
  final List<GrafileValue> items;

  @override
  Object? toDart() => [for (final item in items) item.toDart()];

  @override
  bool operator ==(Object other) {
    if (other is! GrafileList || other.items.length != items.length) {
      return false;
    }
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);

  @override
  String toString() => 'GrafileList($items)';
}

/// Cypher map.
final class GrafileMap extends GrafileValue {
  /// Creates a map value.
  const GrafileMap(this.entries);

  /// The map entries.
  final Map<String, GrafileValue> entries;

  @override
  Object? toDart() => {
    for (final entry in entries.entries) entry.key: entry.value.toDart(),
  };

  @override
  bool operator ==(Object other) {
    if (other is! GrafileMap || other.entries.length != entries.length) {
      return false;
    }
    for (final entry in entries.entries) {
      if (other.entries[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    for (final entry in entries.entries) Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'GrafileMap($entries)';
}

/// A node: identity, labels and properties.
final class GrafileNode extends GrafileValue {
  /// Creates a node value.
  const GrafileNode({
    required this.id,
    required this.labels,
    required this.properties,
  });

  /// Node id.
  final int id;

  /// Node labels.
  final List<String> labels;

  /// Node properties.
  final Map<String, GrafileValue> properties;

  @override
  bool operator ==(Object other) {
    if (other is! GrafileNode) return false;
    if (other.id != id || other.labels.length != labels.length) return false;
    if (other.properties.length != properties.length) return false;
    for (var i = 0; i < labels.length; i++) {
      if (other.labels[i] != labels[i]) return false;
    }
    for (final entry in properties.entries) {
      if (other.properties[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAll(labels),
    Object.hashAll(properties.entries),
  );

  @override
  String toString() =>
      'GrafileNode(id: $id, labels: $labels, properties: $properties)';
}

/// A relationship: identity, type, endpoint node ids and properties.
final class GrafileEdge extends GrafileValue {
  /// Creates an edge value.
  const GrafileEdge({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.properties,
  });

  /// Edge id.
  final int id;

  /// Relationship type, when known.
  final String? type;

  /// Id of the start node.
  final int? start;

  /// Id of the end node.
  final int? end;

  /// Edge properties.
  final Map<String, GrafileValue> properties;

  @override
  bool operator ==(Object other) {
    if (other is! GrafileEdge) return false;
    if (other.id != id ||
        other.type != type ||
        other.start != start ||
        other.end != end ||
        other.properties.length != properties.length) {
      return false;
    }
    for (final entry in properties.entries) {
      if (other.properties[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(id, type, start, end, Object.hashAll(properties.entries));

  @override
  String toString() =>
      'GrafileEdge(id: $id, type: $type, start: $start, end: $end, '
      'properties: $properties)';
}

/// A point in space, as `{"srid", "x", "y"[, "z"]}` on the wire.
final class GrafilePoint extends GrafileValue {
  /// Creates a point value.
  const GrafilePoint({
    required this.srid,
    required this.x,
    required this.y,
    this.z,
  });

  /// Spatial reference system id.
  final int srid;

  /// X coordinate.
  final double x;

  /// Y coordinate.
  final double y;

  /// Z coordinate, for 3D points.
  final double? z;

  @override
  bool operator ==(Object other) =>
      other is GrafilePoint &&
      other.srid == srid &&
      other.x == x &&
      other.y == y &&
      other.z == z;

  @override
  int get hashCode => Object.hash(srid, x, y, z);

  @override
  String toString() =>
      'GrafilePoint(srid: $srid, x: $x, y: $y${z == null ? '' : ', z: $z'})';
}

/// Base class for the temporal values; [iso] is the ISO 8601 rendering used
/// by the native serializers.
sealed class GrafileTemporal extends GrafileValue {
  /// Creates a temporal value from its ISO 8601 [iso] text.
  const GrafileTemporal(this.iso);

  /// The ISO 8601 rendering of the value.
  final String iso;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType && (other as GrafileTemporal).iso == iso;

  @override
  int get hashCode => Object.hash(runtimeType, iso);

  @override
  String toString() => '$runtimeType($iso)';
}

/// Cypher `DATE`, e.g. `2026-10-17`.
final class GrafileDate extends GrafileTemporal {
  /// Creates a date value from its ISO 8601 [iso] text.
  const GrafileDate(super.iso);

  /// The date parsed from [iso], when it is a valid calendar date.
  DateTime? get dateTime => DateTime.tryParse(iso);
}

/// Cypher `LOCAL TIME`, e.g. `12:30:00.5`.
final class GrafileLocalTime extends GrafileTemporal {
  /// Creates a local time value from its ISO 8601 [iso] text.
  const GrafileLocalTime(super.iso);
}

/// Cypher `TIME`, an instant time with a UTC offset, e.g. `12:30:00+02:00`.
final class GrafileTime extends GrafileTemporal {
  /// Creates a time value from its ISO 8601 [iso] text.
  const GrafileTime(super.iso);
}

/// Cypher `LOCAL DATETIME`, e.g. `2026-10-17T12:30:00`.
final class GrafileLocalDateTime extends GrafileTemporal {
  /// Creates a local date and time value from its ISO 8601 [iso] text.
  const GrafileLocalDateTime(super.iso);

  /// The value parsed from [iso], when it is a valid date and time.
  DateTime? get dateTime => DateTime.tryParse(iso);
}

/// Cypher `DATETIME`, e.g. `2026-10-17T12:30:00Z`.
final class GrafileDateTime extends GrafileTemporal {
  /// Creates a date and time value from its ISO 8601 [iso] text.
  const GrafileDateTime(super.iso);

  /// The value parsed from [iso], when it is a valid date and time.
  DateTime? get dateTime => DateTime.tryParse(iso);
}

/// Cypher `DURATION`, e.g. `P1DT2H`.
final class GrafileDuration extends GrafileTemporal {
  /// Creates a duration value from its ISO 8601 [iso] text.
  const GrafileDuration(super.iso);
}
