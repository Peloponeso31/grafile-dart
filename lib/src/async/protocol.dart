import 'dart:isolate';

import '../exceptions.dart';

/// Operations understood by the async worker.
abstract final class GrafileOp {
  static const String exec = 'exec';
  static const String query = 'query';
  static const String queryJson = 'queryJson';
  static const String meta = 'meta';
  static const String begin = 'begin';
  static const String commit = 'commit';
  static const String rollback = 'rollback';
  static const String close = 'close';
}

/// Isolation handshake sent from the worker to the client on `requestId` 0:
/// the worker's command [SendPort] on success, an error record on failure.
typedef GrafileOpenArgs = (
  String path,
  bool readOnly,
  bool create,
  String? libraryPath,
);
typedef GrafileWorkerMessage = (SendPort mainPort, GrafileOpenArgs args);

/// A command: `(requestId, op, args)`.
typedef GrafileRequest = (int id, String op, Object? args);

/// A reply: `(requestId, ok, payload)`. On failure the payload is a
/// [GrafileErrorRecord].
typedef GrafileResponse = (int id, bool ok, Object? payload);

/// A transported failure: `(kind, code, message, stackTrace)`.
typedef GrafileErrorRecord = (
  String kind,
  int code,
  String message,
  String stackTrace,
);

/// One column value on the wire: `(nativeKind, columnJson)`.
typedef GrafileCell = (int kind, Object? json);

/// The result of a typed query: `(columnNames, rows)`.
typedef GrafileQueryResult = (
  List<String> columns,
  List<List<GrafileCell>> rows,
);

const String _kindGrafile = 'grafile';
const String _kindLibrary = 'library';
const String _kindState = 'state';
const String _kindArgument = 'argument';
const String _kindUnknown = 'unknown';

/// Converts a thrown [error] into a sendable record.
GrafileErrorRecord describeFailure(Object error, StackTrace stack) {
  final text = stack.toString();
  return switch (error) {
    GrafileException() => (_kindGrafile, error.code, error.message, text),
    GrafileLibraryException() => (_kindLibrary, 0, error.message, text),
    GrafileLibraryNotFoundException() => (_kindLibrary, 0, error.message, text),
    StateError() => (_kindState, 0, error.message, text),
    ArgumentError() => (_kindArgument, 0, '$error', text),
    _ => (_kindUnknown, 0, '$error', text),
  };
}

/// Rebuilds an error and stack trace received from the other isolate.
(Object, StackTrace) remoteFailure(Object? payload) {
  if (payload is! GrafileErrorRecord) {
    return (
      StateError('grafile worker reported a malformed error: $payload'),
      StackTrace.current,
    );
  }
  final (kind, code, message, stackText) = payload;
  final stack = stackText.isEmpty
      ? StackTrace.empty
      : StackTrace.fromString(stackText);
  final Object error = switch (kind) {
    _kindGrafile => GrafileException.forCode(code, message),
    _kindLibrary => GrafileLibraryException(message),
    _kindState => StateError(message),
    _kindArgument => ArgumentError(message),
    _ => GrafileRemoteException(message),
  };
  return (error, stack);
}
