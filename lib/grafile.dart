/// Dart driver for grafile, the single-file graph database, over its C FFI.
///
/// The driver loads `libgrafile` (see `loadGrafileBindings` for the search
/// order), opens databases and runs Cypher queries:
///
/// ```dart
/// import 'package:grafile/grafile.dart';
///
/// void main() {
///   final db = Grafile.open('graph.grafile');
///   db.exec("CREATE (:Person {name: 'alice', age: 30})");
///   final rows = db.query(
///     'MATCH (p:Person) WHERE p.age > \$min RETURN p.name AS name',
///     params: {'min': 20},
///   );
///   print(rows.first['name']);
///   db.dispose();
/// }
/// ```
library;

export 'src/async/async_database.dart' show AsyncGrafile, AsyncGrafileDb;
export 'src/bindings.dart' show GrafileBindings;
export 'src/constants.dart'
    show GrafileColumnKind, GrafileOpenFlags, GrafileResult;
export 'src/database.dart' show Grafile, GrafileDb;
export 'src/exceptions.dart';
export 'src/library.dart' show loadGrafileBindings, nativeLibraryFileName;
export 'src/statement.dart' show GrafileStatement;
export 'src/values.dart';
