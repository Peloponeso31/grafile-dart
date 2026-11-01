## 0.2.2

Tracks grafile 0.2.2. The C ABI is unchanged, so this release only moves the
reference version; the driver API is identical to 0.2.1.

grafile 0.2.2 brings, through the same library:

* A fix for relationship expansion on node ids divisible by 256, which could
  return relationships belonging to neighbouring nodes.
* Correlated `CALL {}` subqueries and batched `CALL {} IN TRANSACTIONS`
  commits.
* Procedure arguments and comment-aware multi-statement scripts.

## 0.2.1

First pub.dev release of the Dart driver for grafile, tracking grafile 0.2.1.

* `Grafile.open` / `GrafileDb` with `exec`, typed `query`, `queryJson`,
  `meta`, `prepare` and `begin` / `commit` / `rollback` / `transaction`.
* `GrafileStatement` with parameter binding, stepping, column metadata and
  kind-driven value decoding.
* `GrafileValue` model: null, int, float, text, blob, bool, list, map, node,
  edge, temporal values and points.
* Result-code-mapped exception hierarchy (`GrafileBusyException`, ...).
* Native library discovery via `libraryPath`, `GRAFILE_LIBRARY`,
  `GRAFILE_PREFIX` and common install prefixes.
* Async API: `AsyncGrafile.open` / `AsyncGrafileDb` run every native call in a
  dedicated worker isolate (`exec`, `query`, `queryJson`, `meta`,
  transactions) so calling isolates never block; errors round-trip with their
  type, code, message and stack trace.
