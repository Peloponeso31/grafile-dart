import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'constants.dart';
import 'database.dart';
import 'decoding.dart';
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
      default:
        return decodeColumnValue(kind, getJson(index));
    }
  }

  /// Reads the current value at [index] as its JSON-decoded form.
  ///
  /// This is the raw transport used by the async worker; prefer [getValue]
  /// for typed access.
  Object? getJson(int index) {
    _checkLive();
    return _jsonRaw(index);
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

  String _temporalText(int index) => temporalText(_jsonRaw(index));

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
}

/// Wraps a native statement handle; called by `GrafileDb.prepare`.
GrafileStatement createGrafileStatement(
  GrafileDb db,
  GrafileBindings bindings,
  Pointer<Void> handle,
) => GrafileStatement._(db, bindings, handle);
