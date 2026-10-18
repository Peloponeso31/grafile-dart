## 0.1.0

* Initial release: a pure Dart driver for grafile over its C ABI (`libgrafile`).
* `Grafile.open` / `GrafileDb` with `exec`, typed `query`, `queryJson`, `meta`,
  `prepare` and `begin` / `commit` / `rollback` / `transaction`.
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
