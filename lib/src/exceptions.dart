import 'constants.dart';

/// Base class for every error reported by `libgrafile`.
///
/// [code] is one of the [GrafileResult] constants; [message] is the library's
/// own description of the failure.
class GrafileException implements Exception {
  /// Creates an exception with the native result [code] and [message].
  const GrafileException(this.code, this.message);

  /// Creates the most specific exception for [code].
  factory GrafileException.forCode(int code, String message) {
    return switch (code) {
      GrafileResult.error => GrafileError(code, message),
      GrafileResult.internal => GrafileInternalException(code, message),
      GrafileResult.busy => GrafileBusyException(code, message),
      GrafileResult.locked => GrafileLockedException(code, message),
      GrafileResult.readOnly => GrafileReadOnlyException(code, message),
      GrafileResult.ioError => GrafileIoException(code, message),
      GrafileResult.corrupt => GrafileCorruptException(code, message),
      GrafileResult.notFound => GrafileNotFoundException(code, message),
      GrafileResult.tooBig => GrafileTooBigException(code, message),
      GrafileResult.constraint => GrafileConstraintException(code, message),
      GrafileResult.mismatch => GrafileMismatchException(code, message),
      GrafileResult.misuse => GrafileMisuseException(code, message),
      GrafileResult.notADatabase => GrafileNotADatabaseException(code, message),
      _ => GrafileException(code, message),
    };
  }

  /// The native result code; compare against [GrafileResult].
  final int code;

  /// Human-readable description produced by the library.
  final String message;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// Generic failure: syntax errors and unsupported features
/// ([GrafileResult.error]).
final class GrafileError extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileError(super.code, super.message);
}

/// Internal invariant failure or panic ([GrafileResult.internal]).
final class GrafileInternalException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileInternalException(super.code, super.message);
}

/// The database is locked by another writer ([GrafileResult.busy]).
final class GrafileBusyException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileBusyException(super.code, super.message);
}

/// A lock request conflicts with locks held elsewhere
/// ([GrafileResult.locked]).
final class GrafileLockedException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileLockedException(super.code, super.message);
}

/// A write was attempted on a read-only database
/// ([GrafileResult.readOnly]).
final class GrafileReadOnlyException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileReadOnlyException(super.code, super.message);
}

/// Operating-system I/O failure ([GrafileResult.ioError]).
final class GrafileIoException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileIoException(super.code, super.message);
}

/// On-disk structure failed validation ([GrafileResult.corrupt]).
final class GrafileCorruptException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileCorruptException(super.code, super.message);
}

/// A referenced entity does not exist ([GrafileResult.notFound]).
final class GrafileNotFoundException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileNotFoundException(super.code, super.message);
}

/// A value is out of range ([GrafileResult.tooBig]).
final class GrafileTooBigException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileTooBigException(super.code, super.message);
}

/// A uniqueness constraint was violated ([GrafileResult.constraint]).
final class GrafileConstraintException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileConstraintException(super.code, super.message);
}

/// A value has the wrong type for the requested accessor
/// ([GrafileResult.mismatch]).
final class GrafileMismatchException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileMismatchException(super.code, super.message);
}

/// The API was misused (null pointers, wrong state)
/// ([GrafileResult.misuse]).
final class GrafileMisuseException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileMisuseException(super.code, super.message);
}

/// The file is not a grafile database ([GrafileResult.notADatabase]).
final class GrafileNotADatabaseException extends GrafileException {
  /// Creates an exception with the native result [code] and [message].
  const GrafileNotADatabaseException(super.code, super.message);
}

/// `libgrafile` could not be loaded or is missing required symbols.
final class GrafileLibraryException implements Exception {
  /// Creates a library failure with [message].
  const GrafileLibraryException(this.message);

  /// The failure description.
  final String message;

  @override
  String toString() => 'GrafileLibraryException: $message';
}

/// An error crossed the async worker boundary without a known Dart type.
final class GrafileRemoteException implements Exception {
  /// Creates a remote failure with [message].
  const GrafileRemoteException(this.message);

  /// The failure description.
  final String message;

  @override
  String toString() => 'GrafileRemoteException: $message';
}

/// No `libgrafile` was found in any of the searched locations.
final class GrafileLibraryNotFoundException implements Exception {
  /// Creates a failure carrying the [tried] locations.
  const GrafileLibraryNotFoundException(this.tried);

  /// Locations that were tried, in order.
  final List<String> tried;

  /// A message with instructions to install grafile or point the driver at
  /// an existing library.
  String get message {
    final shown = tried.take(12).map((entry) => '  - $entry').join('\n');
    final ellipsis = tried.length > 12 ? '\n  - ...' : '';
    return 'Could not load libgrafile.\n'
        'Install it with:\n'
        '  curl -LsSf '
        'https://github.com/Peloponeso31/grafile/releases/latest/download/install.sh | sh\n'
        'or set GRAFILE_LIBRARY (or Grafile.open(libraryPath: ...)) to the '
        'library file.\n'
        'Searched:\n$shown$ellipsis';
  }

  @override
  String toString() => 'GrafileLibraryNotFoundException: $message';
}
