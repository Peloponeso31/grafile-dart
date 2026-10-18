import 'dart:ffi';
import 'dart:io';

import 'bindings.dart';
import 'exceptions.dart';

/// The native library file name for the current platform.
String get nativeLibraryFileName {
  if (Platform.isMacOS || Platform.isIOS) return 'libgrafile.dylib';
  if (Platform.isWindows) return 'grafile.dll';
  return 'libgrafile.so';
}

/// Loads `libgrafile` and looks up its symbols.
///
/// Resolution order:
/// 1. [libraryPath], when given (a file path or a library name);
/// 2. the `GRAFILE_LIBRARY` environment variable;
/// 3. the platform loader search path (`DYLD_LIBRARY_PATH`, `LD_LIBRARY_PATH`,
///    `PATH` on Windows);
/// 4. common install locations: `$GRAFILE_PREFIX/lib` (default `~/.local/lib`),
///    `/usr/local/lib`, `/opt/homebrew/lib`, `/usr/lib` and every `lib/`
///    directory next to an entry of `PATH`.
///
/// Throws [GrafileLibraryNotFoundException] when nothing loads and
/// [GrafileLibraryException] when the library loads but lacks required
/// symbols.
GrafileBindings loadGrafileBindings({String? libraryPath}) {
  final fileName = nativeLibraryFileName;

  if (libraryPath != null) {
    final bindings = _tryOpen(libraryPath);
    if (bindings != null) return bindings;
    throw GrafileLibraryNotFoundException([libraryPath]);
  }

  final fromEnvironment = Platform.environment['GRAFILE_LIBRARY'];
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    final bindings = _tryOpen(fromEnvironment);
    if (bindings != null) return bindings;
    throw GrafileLibraryNotFoundException([fromEnvironment]);
  }

  final byLoaderPath = _tryOpen(fileName);
  if (byLoaderPath != null) return byLoaderPath;

  final tried = <String>[fileName, ..._candidates(fileName)];
  for (final candidate in tried.skip(1)) {
    final bindings = _tryOpen(candidate);
    if (bindings != null) return bindings;
  }
  throw GrafileLibraryNotFoundException(tried);
}

GrafileBindings? _tryOpen(String path) {
  try {
    return GrafileBindings(DynamicLibrary.open(path));
  } on GrafileLibraryException {
    rethrow;
  } catch (_) {
    return null;
  }
}

Iterable<String> _candidates(String fileName) {
  final directories = <String>{};

  void addDirectory(String? directory) {
    if (directory != null && directory.isNotEmpty) directories.add(directory);
  }

  final prefix = Platform.environment['GRAFILE_PREFIX'];
  if (prefix != null && prefix.isNotEmpty) addDirectory(_join(prefix, 'lib'));

  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && home.isNotEmpty) {
    addDirectory(_join(home, '.local', 'lib'));
  }

  if (Platform.isMacOS || Platform.isLinux) {
    addDirectory('/usr/local/lib');
  }
  if (Platform.isMacOS) {
    addDirectory('/opt/homebrew/lib');
  }
  if (Platform.isLinux) {
    addDirectory('/usr/lib');
    addDirectory('/home/linuxbrew/.linuxbrew/lib');
  }
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      addDirectory(_join(localAppData, 'grafile', 'lib'));
    }
  }

  final pathVariable = Platform.environment['PATH'] ?? '';
  for (final entry in pathVariable.split(Platform.isWindows ? ';' : ':')) {
    if (entry.isEmpty) continue;
    addDirectory(entry);
    addDirectory(_join(entry, '..', 'lib'));
  }

  return [for (final directory in directories) _join(directory, fileName)];
}

String _join(String base, String first, [String? second]) {
  final separator = Platform.pathSeparator;
  var result = base.endsWith(separator)
      ? '$base$first'
      : '$base$separator$first';
  if (second != null) {
    result = result.endsWith(separator)
        ? '$result$second'
        : '$result$separator$second';
  }
  return result;
}
