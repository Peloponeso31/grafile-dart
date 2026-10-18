import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'constants.dart';
import 'exceptions.dart';
import 'ffi_util.dart';
import 'library.dart';
import 'params.dart';
import 'statement.dart';
import 'values.dart';

/// Entry point for the grafile Dart driver.
///
/// ```dart
/// final db = Grafile.open('graph.grafile');
/// db.exec("CREATE (:Person {name: 'alice'})");
/// final rows = db.query('MATCH (p:Person) RETURN p.name AS name');
/// print(rows.first['name']); // GrafileText(alice)
/// db.dispose();
/// ```
final class Grafile {
  Grafile._();

  static GrafileBindings? _defaultBindings;

  /// The bindings for the default-discovered `libgrafile`.
  static GrafileBindings get bindings =>
      _defaultBindings ??= loadGrafileBindings();

  /// Version of the loaded `libgrafile`, e.g. `0.2.0`.
  static String get version => bindings.versionString().toDartString();

  /// Version of the loaded `libgrafile` as an integer
  /// (major * 1000000 + minor * 1000 + patch).
  static int get versionNumber => bindings.libversion();

  /// Opens (or creates) the database at [path].
  ///
  /// With [readOnly] the file is opened for reading only; with [create]
  /// (default) it is created when missing. [libraryPath] overrides native
  /// library discovery for this handle.
  static GrafileDb open(
    String path, {
    bool readOnly = false,
    bool create = true,
    String? libraryPath,
  }) {
    final bindings = libraryPath == null
        ? Grafile.bindings
        : loadGrafileBindings(libraryPath: libraryPath);
    var flags = readOnly
        ? GrafileOpenFlags.readOnly
        : GrafileOpenFlags.readWrite;
    if (!readOnly && create) flags |= GrafileOpenFlags.create;
    return _open(bindings, path, flags);
  }

  /// Opens an existing database for reading only.
  static GrafileDb openReadOnly(String path, {String? libraryPath}) =>
      open(path, readOnly: true, create: false, libraryPath: libraryPath);

  static GrafileDb _open(GrafileBindings bindings, String path, int flags) {
    final outDb = calloc<Pointer<Void>>();
    final outErr = calloc<Pointer<Utf8>>();
    try {
      final rc = withUtf8(
        path,
        (pointer) => bindings.openV2(pointer, flags, outDb, outErr),
      );
      if (rc != GrafileResult.ok) {
        final message =
            consumeAllocatedString(bindings, outErr) ??
            'failed to open $path (code $rc)';
        throw GrafileException.forCode(rc, message);
      }
      final handle = outDb.value;
      if (handle == nullptr) {
        throw const GrafileException(
          GrafileResult.internal,
          'grafile_open_v2 returned OK without a handle',
        );
      }
      return GrafileDb._(bindings, handle, path);
    } finally {
      calloc.free(outDb);
      calloc.free(outErr);
    }
  }
}

/// A connection to one grafile database.
///
/// Calls are synchronous and serialized by the native handle. Dispose the
/// connection when done; leaked connections are released by a finalizer.
final class GrafileDb {
  GrafileDb._(this._bindings, this._handle, this.path) {
    _finalizer.attach(this, _handle, detach: this);
  }

  final GrafileBindings _bindings;
  final Pointer<Void> _handle;

  /// Path this database was opened from.
  final String path;

  late final Finalizer<Pointer<Void>> _finalizer = Finalizer(
    (pointer) => _bindings.close(pointer),
  );
  bool _disposed = false;

  /// Whether [dispose] has run.
  bool get isDisposed => _disposed;

  /// Executes [cypher], discarding any rows.
  void exec(String cypher, {Map<String, Object?>? params}) {
    _checkLive();
    final paramsJson = encodeParams(params);
    final rc = withUtf8(
      cypher,
      (cypherPointer) => withUtf8Nullable(
        paramsJson,
        (paramsPointer) =>
            _bindings.exec(_handle, cypherPointer, paramsPointer),
      ),
    );
    _check(rc);
  }

  /// Executes [cypher] and returns all rows as JSON-shaped maps (nodes and
  /// edges expand to `{"id", "labels", "properties"}` /
  /// `{"id", "type", "start", "end", "properties"}`).
  List<Map<String, dynamic>> queryJson(
    String cypher, {
    Map<String, Object?>? params,
  }) {
    _checkLive();
    final out = calloc<Pointer<Utf8>>();
    try {
      final paramsJson = encodeParams(params);
      final rc = withUtf8(
        cypher,
        (cypherPointer) => withUtf8Nullable(
          paramsJson,
          (paramsPointer) =>
              _bindings.queryJson(_handle, cypherPointer, paramsPointer, out),
        ),
      );
      if (rc != GrafileResult.ok) throw _failure(rc);
      final text = consumeAllocatedString(_bindings, out);
      final decoded = text == null || text.isEmpty ? null : jsonDecode(text);
      if (decoded is! List) {
        throw const GrafileException(
          GrafileResult.internal,
          'grafile_query_json did not return a JSON array',
        );
      }
      return [for (final row in decoded) Map<String, dynamic>.from(row as Map)];
    } finally {
      calloc.free(out);
    }
  }

  /// Executes [cypher] and returns typed rows keyed by column name.
  List<Map<String, GrafileValue>> query(
    String cypher, {
    Map<String, Object?>? params,
  }) {
    final statement = prepare(cypher);
    try {
      if (params != null) statement.bindParams(params);
      final rows = statement.readRows();
      final names = statement.columnNames;
      return [
        for (final row in rows)
          {for (var i = 0; i < row.length; i++) names[i]: row[i]},
      ];
    } finally {
      statement.dispose();
    }
  }

  /// Returns the database header as JSON-shaped data. With [raw] the exact
  /// stored values are emitted.
  Map<String, dynamic> meta({bool raw = false}) {
    _checkLive();
    final out = calloc<Pointer<Utf8>>();
    try {
      final rc = _bindings.metaJson(_handle, raw ? 1 : 0, out);
      if (rc != GrafileResult.ok) throw _failure(rc);
      final text = consumeAllocatedString(_bindings, out);
      final decoded = text == null || text.isEmpty ? null : jsonDecode(text);
      if (decoded is! Map) {
        throw const GrafileException(
          GrafileResult.internal,
          'grafile_meta_json did not return a JSON object',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } finally {
      calloc.free(out);
    }
  }

  /// Compiles [cypher] into a statement. Parameters can be bound afterwards
  /// with `GrafileStatement.bindParams`.
  GrafileStatement prepare(String cypher) {
    _checkLive();
    final outStmt = calloc<Pointer<Void>>();
    final outErr = calloc<Pointer<Utf8>>();
    try {
      final rc = withUtf8(
        cypher,
        (pointer) => _bindings.prepare(_handle, pointer, outStmt, outErr),
      );
      if (rc != GrafileResult.ok) {
        final message =
            consumeAllocatedString(_bindings, outErr) ?? describeError(rc);
        throw GrafileException.forCode(rc, message);
      }
      final handle = outStmt.value;
      if (handle == nullptr) {
        throw const GrafileException(
          GrafileResult.internal,
          'grafile_prepare returned OK without a statement',
        );
      }
      return createGrafileStatement(this, _bindings, handle);
    } finally {
      calloc.free(outStmt);
      calloc.free(outErr);
    }
  }

  /// Begins a write transaction, acquiring the exclusive writer slot.
  void begin() {
    _checkLive();
    _check(_bindings.begin(_handle));
  }

  /// Commits the active write transaction.
  void commit() {
    _checkLive();
    _check(_bindings.commit(_handle));
  }

  /// Rolls back the active write transaction.
  void rollback() {
    _checkLive();
    _check(_bindings.rollback(_handle));
  }

  /// Runs [body] inside a write transaction, committing on success and
  /// rolling back on failure.
  T transaction<T>(T Function() body) {
    begin();
    var committed = false;
    try {
      final result = body();
      commit();
      committed = true;
      return result;
    } finally {
      if (!committed) {
        try {
          rollback();
        } catch (_) {
          // The original failure is more useful than a failed rollback.
        }
      }
    }
  }

  /// Releases the native handle. Outstanding statements stay usable.
  /// Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    _bindings.close(_handle);
  }

  /// The library's message for the last error [code] on this handle.
  String describeError(int code) {
    if (_disposed) return 'grafile error (code $code)';
    final message = borrowUtf8(_bindings.errorMessage(_handle));
    return message == null || message.isEmpty
        ? 'grafile error (code $code)'
        : message;
  }

  void _checkLive() {
    if (_disposed) {
      throw StateError('GrafileDb has been disposed');
    }
  }

  void _check(int rc) {
    if (rc != GrafileResult.ok) throw _failure(rc);
  }

  GrafileException _failure(int rc) =>
      GrafileException.forCode(rc, describeError(rc));
}
