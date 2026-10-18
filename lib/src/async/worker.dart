import 'dart:convert';
import 'dart:isolate';

import '../database.dart';
import 'protocol.dart';

/// Entry point of the isolate that owns the native database handle.
///
/// Receives the main isolate's reply [SendPort] and the open arguments,
/// opens the database and then answers commands until `close` arrives.
void grafileWorkerEntry(GrafileWorkerMessage message) {
  final (mainPort, (path, readOnly, create, libraryPath)) = message;

  GrafileDb? db;
  try {
    db = Grafile.open(
      path,
      readOnly: readOnly,
      create: create,
      libraryPath: libraryPath,
    );
  } catch (error, stack) {
    mainPort.send((0, false, describeFailure(error, stack)));
    return;
  }

  final commands = ReceivePort();
  mainPort.send((0, true, commands.sendPort));
  commands.listen((message) {
    final (id, op, args) = message as GrafileRequest;
    final database = db;
    if (database == null) {
      mainPort.send((
        id,
        false,
        describeFailure(
          StateError('grafile worker is closed'),
          StackTrace.current,
        ),
      ));
      return;
    }
    Object? payload;
    try {
      payload = _execute(database, op, args);
    } catch (error, stack) {
      mainPort.send((id, false, describeFailure(error, stack)));
      return;
    }
    mainPort.send((id, true, payload));
    if (op == GrafileOp.close) {
      database.dispose();
      db = null;
      commands.close();
    }
  });
}

Object? _execute(GrafileDb db, String op, Object? args) {
  switch (op) {
    case GrafileOp.exec:
      final (cypher, paramsJson) = args as (String, String?);
      db.exec(cypher, params: _params(paramsJson));
      return null;
    case GrafileOp.query:
      final (cypher, paramsJson) = args as (String, String?);
      return _query(db, cypher, _params(paramsJson));
    case GrafileOp.queryJson:
      final (cypher, paramsJson) = args as (String, String?);
      return db.queryJson(cypher, params: _params(paramsJson));
    case GrafileOp.meta:
      return db.meta(raw: args! as bool);
    case GrafileOp.begin:
      db.begin();
      return null;
    case GrafileOp.commit:
      db.commit();
      return null;
    case GrafileOp.rollback:
      db.rollback();
      return null;
    case GrafileOp.close:
      return null;
  }
  throw ArgumentError.value(op, 'op', 'unknown grafile worker command');
}

GrafileQueryResult _query(
  GrafileDb db,
  String cypher,
  Map<String, Object?>? params,
) {
  final statement = db.prepare(cypher);
  try {
    if (params != null) statement.bindParams(params);
    var hasRow = statement.step();
    final count = statement.columnCount;
    final columns = statement.columnNames;
    final rows = <List<GrafileCell>>[];
    while (hasRow) {
      rows.add([
        for (var index = 0; index < count; index++)
          (statement.columnKind(index), statement.getJson(index)),
      ]);
      hasRow = statement.step();
    }
    return (columns, rows);
  } finally {
    statement.dispose();
  }
}

Map<String, Object?>? _params(String? paramsJson) {
  if (paramsJson == null) return null;
  return Map<String, Object?>.from(jsonDecode(paramsJson) as Map);
}
