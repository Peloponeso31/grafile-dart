import 'dart:io';

import 'package:grafile/grafile.dart';

Future<void> main() async {
  final directory = Directory.systemTemp.createTempSync('grafile_async');
  final path = '${directory.path}${Platform.pathSeparator}example.grafile';

  stdout.writeln('opening $path in a worker isolate...');
  final db = await AsyncGrafile.open(path);
  try {
    await db.exec("CREATE (:Person {name: 'alice', age: 30})");
    await db.exec("CREATE (:Person {name: 'bob', age: 25})");
    await db.exec(
      "MATCH (a:Person {name: 'alice'}), (b:Person {name: 'bob'}) "
      'CREATE (a)-[:KNOWS {since: 2020}]->(b)',
    );

    final people = await db.query(
      'MATCH (p:Person) WHERE p.age > \$min '
      'RETURN p.name AS name, p.age AS age ORDER BY age',
      params: {'min': 24},
    );
    for (final person in people) {
      print('${person['name']!.toDart()} is ${person['age']!.toDart()}');
    }

    final row = (await db.query(
      'MATCH (a)-[r:KNOWS]->(b) RETURN a AS a, r AS r, b AS b',
    )).single;
    final a = row['a']! as GrafileNode;
    final relationship = row['r']! as GrafileEdge;
    final b = row['b']! as GrafileNode;
    print(
      '${a.properties['name']!.toDart()} '
      '-[${relationship.type} since ${relationship.properties['since']!.toDart()}]-> '
      '${b.properties['name']!.toDart()}',
    );

    await db.transaction(() async {
      await db.exec("CREATE (:Person {name: 'carol', age: 27})");
    });
    final names = await db.queryJson(
      'MATCH (p:Person) RETURN p.name AS name ORDER BY name',
    );
    print('names: $names');

    final meta = await db.meta();
    print('header keys: ${meta.keys.join(', ')}');
  } finally {
    await db.dispose();
    try {
      directory.deleteSync(recursive: true);
    } catch (_) {
      // Best-effort cleanup of the temp directory.
    }
  }
}
