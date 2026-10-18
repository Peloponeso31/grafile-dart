import 'dart:async';
import 'dart:isolate';

import '../decoding.dart';
import '../params.dart';
import '../values.dart';
import 'protocol.dart';
import 'worker.dart';

/// Asynchronous front end for grafile.
///
/// Every [AsyncGrafileDb] owns a worker isolate that owns the native handle,
/// so no FFI call ever blocks the calling isolate. Commands sent to one
/// handle are processed in order, which keeps transactions coherent.
///
/// ```dart
/// final db = await AsyncGrafile.open('graph.grafile');
/// await db.exec("CREATE (:Person {name: 'alice'})");
/// final rows = await db.query('MATCH (p:Person) RETURN p.name AS name');
/// await db.dispose();
/// ```
final class AsyncGrafile {
  AsyncGrafile._();

  /// Opens (or creates) the database at [path] in a dedicated worker isolate.
  ///
  /// [readOnly], [create] and [libraryPath] behave like `Grafile.open`.
  static Future<AsyncGrafileDb> open(
    String path, {
    bool readOnly = false,
    bool create = true,
    String? libraryPath,
  }) async {
    final reply = ReceivePort();
    Isolate isolate;
    try {
      isolate = await Isolate.spawn<GrafileWorkerMessage>(grafileWorkerEntry, (
        reply.sendPort,
        (path, readOnly, create, libraryPath),
      ), debugName: 'grafile: $path');
    } catch (_) {
      reply.close();
      rethrow;
    }

    final db = AsyncGrafileDb._(isolate, reply, path);
    try {
      await db._ready.future;
    } catch (_) {
      db._shutdown();
      rethrow;
    }
    return db;
  }

  /// Opens an existing database for reading only, in a worker isolate.
  static Future<AsyncGrafileDb> openReadOnly(
    String path, {
    String? libraryPath,
  }) => open(path, readOnly: true, create: false, libraryPath: libraryPath);
}

/// A connection to one grafile database served by a worker isolate.
///
/// Methods mirror `GrafileDb` but return [Future]s. A thrown
/// `GrafileException` on the worker side is rebuilt here with the same type,
/// code, message and stack trace.
///
/// While a transaction is open, every subsequent command on this handle
/// belongs to it (the worker processes commands in order). Use one handle per
/// concurrent writer.
final class AsyncGrafileDb {
  AsyncGrafileDb._(this._isolate, this._reply, this.path) {
    _finalizer.attach(this, null, detach: this);
    _reply.listen(_onMessage);
    _exitPort.listen(_onExit);
    _isolate.addOnExitListener(_exitPort.sendPort);
    _isolate.addErrorListener(_errorPort.sendPort);
  }

  final Isolate _isolate;
  final ReceivePort _reply;

  /// Path this database was opened from.
  final String path;

  final Completer<void> _ready = Completer<void>();
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;
  SendPort? _commands;
  bool _disposed = false;

  late final Finalizer<Object?> _finalizer = Finalizer<Object?>(
    (_) => _closeForFinalizer(),
  );
  late final ReceivePort _exitPort = ReceivePort();
  late final ReceivePort _errorPort = ReceivePort();

  /// Whether [dispose] has run or the worker isolate exited.
  bool get isDisposed => _disposed;

  /// Executes [cypher], discarding any rows.
  Future<void> exec(String cypher, {Map<String, Object?>? params}) async {
    final paramsJson = encodeParams(params);
    await _send(GrafileOp.exec, (cypher, paramsJson));
  }

  /// Executes [cypher] and returns all rows as JSON-shaped maps.
  Future<List<Map<String, dynamic>>> queryJson(
    String cypher, {
    Map<String, Object?>? params,
  }) async {
    final paramsJson = encodeParams(params);
    final payload = await _send(GrafileOp.queryJson, (cypher, paramsJson));
    return [
      for (final row in payload as List) Map<String, dynamic>.from(row as Map),
    ];
  }

  /// Executes [cypher] and returns typed rows keyed by column name.
  Future<List<Map<String, GrafileValue>>> query(
    String cypher, {
    Map<String, Object?>? params,
  }) async {
    final paramsJson = encodeParams(params);
    final payload = await _send(GrafileOp.query, (cypher, paramsJson));
    final result = payload as GrafileQueryResult;
    final columns = result.$1;
    return [
      for (final row in result.$2)
        {
          for (var index = 0; index < row.length; index++)
            columns[index]: decodeColumnValue(row[index].$1, row[index].$2),
        },
    ];
  }

  /// Returns the database header as JSON-shaped data.
  Future<Map<String, dynamic>> meta({bool raw = false}) async {
    final payload = await _send(GrafileOp.meta, raw);
    return Map<String, dynamic>.from(payload as Map);
  }

  /// Begins a write transaction on the worker handle.
  Future<void> begin() async {
    await _send(GrafileOp.begin);
  }

  /// Commits the active write transaction.
  Future<void> commit() async {
    await _send(GrafileOp.commit);
  }

  /// Rolls back the active write transaction.
  Future<void> rollback() async {
    await _send(GrafileOp.rollback);
  }

  /// Runs [body] inside a write transaction, committing on success and
  /// rolling back on failure.
  Future<T> transaction<T>(Future<T> Function() body) async {
    await begin();
    var committed = false;
    try {
      final result = await body();
      await commit();
      committed = true;
      return result;
    } finally {
      if (!committed) {
        try {
          await rollback();
        } catch (_) {
          // The original failure is more useful than a failed rollback.
        }
      }
    }
  }

  /// Asks the worker to close the database, then releases the isolate.
  /// Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await _sendRaw(GrafileOp.close);
    } catch (_) {
      // The worker may already be gone; resources are released below.
    }
    _shutdown();
  }

  Future<Object?> _send(String op, [Object? args]) {
    if (_disposed) {
      return Future.error(StateError('AsyncGrafileDb has been disposed'));
    }
    return _sendRaw(op, args);
  }

  Future<Object?> _sendRaw(String op, [Object? args]) {
    final commands = _commands;
    if (commands == null) {
      return Future.error(StateError('grafile worker is not ready'));
    }
    final id = ++_nextId;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    commands.send((id, op, args));
    return completer.future;
  }

  void _onMessage(Object? message) {
    if (message is! GrafileResponse) return;
    final (id, ok, payload) = message;
    if (id == 0) {
      if (_ready.isCompleted) return;
      if (ok) {
        _commands = payload as SendPort;
        _ready.complete();
      } else {
        final (error, stack) = remoteFailure(payload);
        _ready.completeError(error, stack);
      }
      return;
    }
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    if (ok) {
      completer.complete(payload);
    } else {
      final (error, stack) = remoteFailure(payload);
      completer.completeError(error, stack);
    }
  }

  void _onExit(Object? _) {
    if (_disposed) return;
    _disposed = true;
    _ready.completeErrorIfPending(StateError('grafile worker isolate exited'));
    _failPending(StateError('grafile worker isolate exited'));
  }

  void _failPending(Object error) {
    final pending = List.of(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  void _closeForFinalizer() {
    if (_disposed) return;
    _disposed = true;
    _commands?.send((++_nextId, GrafileOp.close, null));
    _reply.close();
    _exitPort.close();
    _errorPort.close();
  }

  void _shutdown() {
    _disposed = true;
    _finalizer.detach(this);
    _reply.close();
    _exitPort.close();
    _errorPort.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

extension on Completer<void> {
  void completeErrorIfPending(Object error) {
    if (!isCompleted) completeError(error);
  }
}
