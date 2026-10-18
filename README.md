# grafile_dart

Dart driver for [grafile](https://github.com/Peloponeso31/grafile), the
single-file graph database, over its C ABI (`libgrafile`). Works in Dart CLI
apps, servers and Flutter apps.

```dart
import 'package:grafile_dart/grafile_dart.dart';

void main() {
  final db = Grafile.open('graph.grafile');
  db.exec("CREATE (:Person {name: 'alice', age: 30})");

  final rows = db.query(
    'MATCH (p:Person) WHERE p.age > \$min RETURN p.name AS name, p.age AS age',
    params: {'min': 20},
  );
  print(rows.first['name']); // GrafileText(alice)

  db.dispose();
}
```

## Install the native library

The driver needs `libgrafile` (shared library) on the machine. Install grafile
with its installer:

```console
$ curl -LsSf https://github.com/Peloponeso31/grafile/releases/latest/download/install.sh | sh
```

That places the library under `~/.local/lib` (override with `GRAFILE_PREFIX`).
When building grafile from source, `cargo build -p grafile-ffi` produces
`target/{debug,release}/libgrafile.dylib|so` (or `grafile.dll` on Windows).

## Library discovery

`Grafile.open` finds the library in this order:

1. `libraryPath:` given to `Grafile.open`;
2. the `GRAFILE_LIBRARY` environment variable;
3. the platform loader search path (`DYLD_LIBRARY_PATH`, `LD_LIBRARY_PATH`,
   Windows `PATH`);
4. common install locations: `$GRAFILE_PREFIX/lib` (default `~/.local/lib`),
   `/usr/local/lib`, `/opt/homebrew/lib`, `/usr/lib`, and `lib/` directories
   next to every entry of `PATH`.

When nothing loads, a `GrafileLibraryNotFoundException` lists every location
that was tried. If no library is available at all, integration tests and
queries fail at the first call, so you can probe with:

```dart
print(Grafile.version); // e.g. 0.2.0
```

## Usage

### Queries

```dart
final db = Grafile.open('graph.grafile');

// Rows as plain JSON-shaped maps.
final rows = db.queryJson('MATCH (p:Person) RETURN p.name AS name');

// Rows as typed values (GrafileNode, GrafileEdge, GrafileInt, ...).
final typed = db.query('MATCH (p:Person) RETURN p AS person, p.age AS age');

// Parameters ($name) are bound from a JSON-encodable map.
db.exec('CREATE (:Person {name: \$name})', params: {'name': 'bob'});
```

### Statements

```dart
final statement = db.prepare('MATCH (p:Person) WHERE p.age > \$min RETURN p.name');
statement.bindParams({'min': 30});
while (statement.step()) {
  print(statement.getText(0));
}
statement.dispose();
```

Parsing and planning happen on the first `step()`, so syntax errors surface
there as `GrafileException`.

### Transactions

```dart
db.begin();
db.exec("CREATE (:Person {name: 'carol'})");
db.commit(); // or db.rollback()

// Or with automatic rollback on failure:
db.transaction(() => db.exec("CREATE (:Person {name: 'dave'})"));
```

Concurrency follows grafile: one writer at a time across processes and within
a process (a second writer gets `GrafileBusyException`); readers run
concurrently and always observe committed state.

### Async usage

Every synchronous call blocks the calling isolate. `AsyncGrafile` moves the
native handle into a dedicated worker isolate, so Flutter frames and event
loops stay responsive:

```dart
final db = await AsyncGrafile.open('graph.grafile');

await db.exec("CREATE (:Person {name: 'alice'})");
final rows = await db.query('MATCH (p:Person) RETURN p.name AS name');
await db.transaction(() async {
  await db.exec("CREATE (:Person {name: 'bob'})");
});
await db.dispose();
```

`AsyncGrafileDb` mirrors the sync surface: `exec`, `query`, `queryJson`,
`meta`, `begin`/`commit`/`rollback`, `transaction`. Prepared statements are
not exposed asynchronously; use `query`/`queryJson`.

Semantics:

- One worker isolate per `AsyncGrafileDb`; commands on one handle are
  processed in order, so no two native calls ever overlap.
- While a transaction is open, every subsequent command on that handle
  belongs to it. Use one handle per concurrent writer.
- Errors are rebuilt on the caller side with their original type, code,
  message and stack trace.
- `dispose()` shuts the worker down; a finalizer sends a best-effort close if
  a handle is garbage-collected.

### Values

`GrafileValue` is a sealed hierarchy: `GrafileNull`, `GrafileInt`,
`GrafileDouble`, `GrafileText`, `GrafileBool`, `GrafileBlob`, `GrafileList`,
`GrafileMap`, `GrafileNode`, `GrafileEdge`, `GrafilePoint` and the temporal
values `GrafileDate`, `GrafileLocalTime`, `GrafileTime`, `GrafileLocalDateTime`,
`GrafileDateTime`, `GrafileDuration`. `toDart()` converts to plain Dart data.

Temporal values expose their ISO 8601 rendering via `iso`. Inside lists and
maps the JSON conventions apply (ISO strings, `"0x…"` bytes, entities as
objects); top-level columns are fully typed by their native column kind.

### Errors

Failures raise `GrafileException` (or a typed subclass such as
`GrafileBusyException`, `GrafileConstraintException`, `GrafileMismatchException`)
carrying the native `code` (`GrafileResult`) and the library's `message`.

### Resource handling

`GrafileDb.dispose()` and `GrafileStatement.dispose()` release native handles
and are idempotent; leaked objects are reclaimed by finalizers. Statements
stay usable after their connection is disposed, matching the C ABI.

## Platform notes

- Linux tarballs ship glibc-linked libraries; musl distros (Alpine) need
  grafile built from source for FFI use.
- Windows: the installer is `winget install Peloponeso31.Grafile`; point
  `GRAFILE_LIBRARY` at `grafile.dll` if it is not on `PATH`.
- Flutter apps can use this package directly on desktop. For mobile bundles,
  ship `libgrafile` with the app and pass `libraryPath:`.

## Limitations

- All native calls are synchronous and block the calling isolate; use the
  `AsyncGrafile` worker API to keep event loops responsive.
- Result rows are materialized by grafile before the first `step`, so very
  large results use memory proportional to their size (both APIs).
- The JSON parameter channel cannot carry typed durations or points; build
  them in Cypher (`duration($text)`, `point({x: $x, y: $y})`).
- `grafile_column_json` is the value transport; it must be present in the
  linked library (grafile 0.1+).

## Development

```console
$ dart pub get
$ dart analyze
$ dart test                              # integration tests use grafile's
                                         # discovery; set GRAFILE_LIBRARY to
                                         # point at a specific build
$ dart run example/grafile_dart_example.dart
$ dart run example/grafile_dart_async_example.dart
```

## License

MIT
