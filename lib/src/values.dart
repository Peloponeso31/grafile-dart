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
  const GrafileInt(this.value);

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
  const GrafileDouble(this.value);

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
  const GrafileText(this.value);

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
  const GrafileBool(this.value);

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
  const GrafileBlob(this.bytes);

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
  const GrafileList(this.items);

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
  const GrafileMap(this.entries);

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
  const GrafileNode({
    required this.id,
    required this.labels,
    required this.properties,
  });

  final int id;
  final List<String> labels;
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
  const GrafileEdge({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.properties,
  });

  final int id;
  final String? type;
  final int? start;
  final int? end;
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
  const GrafilePoint({
    required this.srid,
    required this.x,
    required this.y,
    this.z,
  });

  final int srid;
  final double x;
  final double y;
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
  const GrafileTemporal(this.iso);

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
  const GrafileDate(super.iso);

  /// The date parsed from [iso], when it is a valid calendar date.
  DateTime? get dateTime => DateTime.tryParse(iso);
}

/// Cypher `LOCAL TIME`, e.g. `12:30:00.5`.
final class GrafileLocalTime extends GrafileTemporal {
  const GrafileLocalTime(super.iso);
}

/// Cypher `TIME`, an instant time with a UTC offset, e.g. `12:30:00+02:00`.
final class GrafileTime extends GrafileTemporal {
  const GrafileTime(super.iso);
}

/// Cypher `LOCAL DATETIME`, e.g. `2026-10-17T12:30:00`.
final class GrafileLocalDateTime extends GrafileTemporal {
  const GrafileLocalDateTime(super.iso);

  /// The value parsed from [iso], when it is a valid date and time.
  DateTime? get dateTime => DateTime.tryParse(iso);
}

/// Cypher `DATETIME`, e.g. `2026-10-17T12:30:00Z`.
final class GrafileDateTime extends GrafileTemporal {
  const GrafileDateTime(super.iso);

  /// The value parsed from [iso], when it is a valid date and time.
  DateTime? get dateTime => DateTime.tryParse(iso);
}

/// Cypher `DURATION`, e.g. `P1DT2H`.
final class GrafileDuration extends GrafileTemporal {
  const GrafileDuration(super.iso);
}
