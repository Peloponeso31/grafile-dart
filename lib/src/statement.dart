import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'constants.dart';
import 'database.dart';
import 'exceptions.dart';
import 'ffi_util.dart';
import 'params.dart';
import 'values.dart';

/// A compiled Cypher statement.
///
/// Native statements keep their connection alive, so a statement stays usable
/// after `GrafileDb.dispose`. Statements are single-threaded. Calling
/// [dispose] is recommended; a finalizer releases leaked statements when the
/// Dart object is collected.
final class GrafileStatement {
  GrafileStatement._(this._db, this._bindings, this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  final GrafileDb _db;
  final GrafileBindings _bindings;
  final Pointer<Void> _handle;
  late final Finalizer<Pointer<Void>> _finalizer = Finalizer(
    (pointer) => _bindings.finalizeStatement(pointer),
  );
  bool _disposed = false;

  /// Whether [dispose] has run.
  bool get isDisposed => _disposed;

  /// Binds `$name` parameters. Resets the materialized result, so the next
  /// [step] re-executes the query.
  void bindParams(Map<String, Object?> params) {
    _checkLive();
    final json = encodeParams(params);
    if (json == null) return;
    final rc = withUtf8(
      json,
      (pointer) => _bindings.bindParamsJson(_handle, pointer),
    );
    _check(rc);
  }

  /// Advances the statement: `true` when a row is available, `false` at the
  /// end of the result. Throws [GrafileException] on failure.
  ///
  /// Parsing and planning happen here on the first call, so syntax errors and
  /// unknown parameters surface from [step].
  bool step() {
    _checkLive();
    final rc = _bindings.step(_handle);
    return switch (rc) {
      GrafileResult.row => true,
      GrafileResult.done => false,
      _ => throw _failure(rc),
    };
  }

  /// Rewinds to the start of the already-materialized result.
  void reset() {
    _checkLive();
    _check(_bindings.reset(_handle));
  }

  /// Number of output columns; 0 until the first [step] materializes the
  /// result.
  int get columnCount {
    _checkLive();
    return _bindings.columnCount(_handle);
  }

  /// Output column names; empty until the first [step] materializes the
  /// result.
  List<String> get columnNames =>
      List.generate(columnCount, (index) => columnName(index) ?? '');

  /// Name of the column at [index], or `null` when out of range.
  String? columnName(int index) {
    _checkLive();
    return borrowUtf8(_bindings.columnName(_handle, index));
  }

  /// Kind of the value in the current row at [index]; one of
  /// [GrafileColumnKind].
  int columnKind(int index) {
    _checkLive();
    return _bindings.columnKind(_handle, index);
  }

  /// Reads the current value at [index] as a typed [GrafileValue].
  GrafileValue getValue(int index) {
    _checkLive();
    final kind = _bindings.columnKind(_handle, index);
    switch (kind) {
      case GrafileColumnKind.nullValue:
        return const GrafileNull();
      case GrafileColumnKind.integer:
        final out = calloc<Int64>();
        try {
          _check(_bindings.columnInt64(_handle, index, out));
          return GrafileInt(out.value);
        } finally {
          calloc.free(out);
        }
      case GrafileColumnKind.float:
        final out = calloc<Double>();
        try {
          _check(_bindings.columnDouble(_handle, index, out));
          return GrafileDouble(out.value);
        } finally {
          calloc.free(out);
        }
      case GrafileColumnKind.text:
        return GrafileText(_text(index) ?? '');
      case GrafileColumnKind.blob:
        final raw = _jsonRaw(index);
        if (raw is! String) {
          throw const GrafileException(
            GrafileResult.mismatch,
            'blob column did not serialize to a string',
          );
        }
        return GrafileBlob(_decodeHex(raw));
      case GrafileColumnKind.boolean:
        final raw = _jsonRaw(index);
        if (raw is! bool) {
          throw const GrafileException(
            GrafileResult.mismatch,
            'boolean column did not serialize to a bool',
          );
        }
        return GrafileBool(raw);
      case GrafileColumnKind.list:
      case GrafileColumnKind.map:
        return GrafileValue.fromJson(_jsonRaw(index));
      case GrafileColumnKind.node:
        return _nodeFromJson(_jsonRaw(index));
      case GrafileColumnKind.edge:
        return _edgeFromJson(_jsonRaw(index));
      case GrafileColumnKind.date:
        return GrafileDate(_temporalText(index));
      case GrafileColumnKind.localTime:
        return GrafileLocalTime(_temporalText(index));
      case GrafileColumnKind.time:
        return GrafileTime(_temporalText(index));
      case GrafileColumnKind.localDateTime:
        return GrafileLocalDateTime(_temporalText(index));
      case GrafileColumnKind.dateTime:
        return GrafileDateTime(_temporalText(index));
      case GrafileColumnKind.duration:
        return GrafileDuration(_temporalText(index));
      case GrafileColumnKind.point:
        return _pointFromJson(_jsonRaw(index));
      default:
        return GrafileValue.fromJson(_jsonRaw(index));
    }
  }

  /// Reads the current value at [index] as an integer.
  ///
  /// `null` yields 0 and non-numeric values raise [GrafileMismatchException].
  int getInt(int index) {
    _checkLive();
    final out = calloc<Int64>();
    try {
      _check(_bindings.columnInt64(_handle, index, out));
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  /// Reads the current value at [index] as a double.
  ///
  /// `null` yields 0.0 and non-numeric values raise [GrafileMismatchException].
  double getDouble(int index) {
    _checkLive();
    final out = calloc<Double>();
    try {
      _check(_bindings.columnDouble(_handle, index, out));
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  /// Reads the current value at [index] as text.
  ///
  /// Temporal kinds return their ISO 8601 rendering; a `null` value or a
  /// non-text kind raises [GrafileMismatchException].
  String getText(int index) {
    _checkLive();
    final kind = _bindings.columnKind(_handle, index);
    if (kind == GrafileColumnKind.text) {
      final text = _text(index);
      if (text != null) return text;
    } else if (_isTemporal(kind)) {
      return _temporalText(index);
    }
    throw GrafileException(GrafileResult.mismatch, 'column $index is not text');
  }

  /// Reads the remaining rows from the current position, materializing the
  /// result if needed.
  List<List<GrafileValue>> readRows() {
    _checkLive();
    final rows = <List<GrafileValue>>[];
    var hasRow = step();
    final count = columnCount;
    while (hasRow) {
      rows.add(
        List.generate(count, (index) => getValue(index), growable: false),
      );
      hasRow = step();
    }
    return rows;
  }

  /// Releases the native statement. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    _bindings.finalizeStatement(_handle);
  }

  void _checkLive() {
    if (_disposed) {
      throw StateError('GrafileStatement has been disposed');
    }
  }

  void _check(int rc) {
    if (rc != GrafileResult.ok) throw _failure(rc);
  }

  GrafileException _failure(int rc) =>
      GrafileException.forCode(rc, _db.describeError(rc));

  static bool _isTemporal(int kind) =>
      kind >= GrafileColumnKind.date && kind <= GrafileColumnKind.duration;

  String? _text(int index) => borrowUtf8(_bindings.columnText(_handle, index));

  String _temporalText(int index) {
    final raw = _jsonRaw(index);
    if (raw is! String) {
      throw const GrafileException(
        GrafileResult.mismatch,
        'temporal column did not serialize to a string',
      );
    }
    return raw;
  }

  Object? _jsonRaw(int index) {
    final out = calloc<Pointer<Utf8>>();
    try {
      _check(_bindings.columnJson(_handle, index, out));
      final text = consumeAllocatedString(_bindings, out);
      return text == null ? null : jsonDecode(text);
    } finally {
      calloc.free(out);
    }
  }

  GrafileNode _nodeFromJson(Object? raw) {
    if (raw is! Map) {
      throw const GrafileException(
        GrafileResult.mismatch,
        'node column did not serialize to an object',
      );
    }
    return GrafileNode(
      id: raw['id'] as int,
      labels: [for (final label in raw['labels'] as List) label as String],
      properties: _properties(raw['properties']),
    );
  }

  GrafileEdge _edgeFromJson(Object? raw) {
    if (raw is! Map) {
      throw const GrafileException(
        GrafileResult.mismatch,
        'edge column did not serialize to an object',
      );
    }
    return GrafileEdge(
      id: raw['id'] as int,
      type: raw['type'] as String?,
      start: raw['start'] as int?,
      end: raw['end'] as int?,
      properties: _properties(raw['properties']),
    );
  }

  GrafilePoint _pointFromJson(Object? raw) {
    if (raw is! Map) {
      throw const GrafileException(
        GrafileResult.mismatch,
        'point column did not serialize to an object',
      );
    }
    return GrafilePoint(
      srid: raw['srid'] as int,
      x: (raw['x'] as num).toDouble(),
      y: (raw['y'] as num).toDouble(),
      z: raw['z'] == null ? null : (raw['z'] as num).toDouble(),
    );
  }

  static Map<String, GrafileValue> _properties(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): GrafileValue.fromJson(entry.value),
    };
  }

  static Uint8List _decodeHex(String value) {
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
}

/// Wraps a native statement handle; called by `GrafileDb.prepare`.
GrafileStatement createGrafileStatement(
  GrafileDb db,
  GrafileBindings bindings,
  Pointer<Void> handle,
) => GrafileStatement._(db, bindings, handle);
