import 'dart:io';

import 'package:grafile_dart/grafile_dart.dart';

void main() {
  final directory = Directory.systemTemp.createTempSync('grafile_dart_example');
  final path = '${directory.path}${Platform.pathSeparator}example.grafile';
  final db = Grafile.open(path);

  try {
    print('grafile driver on libgrafile ${Grafile.version}');

    db.exec("CREATE (:Person {name: 'alice', age: 30})");
    db.exec("CREATE (:Person {name: 'bob', age: 25})");
    db.exec(
      "MATCH (a:Person {name: 'alice'}), (b:Person {name: 'bob'}) "
      'CREATE (a)-[:KNOWS {since: 2020}]->(b)',
    );

    final people = db.query(
      'MATCH (p:Person) WHERE p.age > \$min '
      'RETURN p.name AS name, p.age AS age ORDER BY age',
      params: {'min': 24},
    );
    for (final person in people) {
      print('${person['name']!.toDart()} is ${person['age']!.toDart()}');
    }

    final row = db
        .query('MATCH (a)-[r:KNOWS]->(b) RETURN a AS a, r AS r, b AS b')
        .single;
    final a = row['a']! as GrafileNode;
    final relationship = row['r']! as GrafileEdge;
    final b = row['b']! as GrafileNode;
    print(
      '${a.properties['name']!.toDart()} '
      '-[${relationship.type} since ${relationship.properties['since']!.toDart()}]-> '
      '${b.properties['name']!.toDart()}',
    );

    db.transaction(() => db.exec("CREATE (:Person {name: 'carol', age: 27})"));
    print(
      'names: ${db.queryJson('MATCH (p:Person) RETURN p.name AS name ORDER BY name')}',
    );

    final meta = db.meta();
    print('header keys: ${meta.keys.join(', ')}');
  } finally {
    db.dispose();
    try {
      directory.deleteSync(recursive: true);
    } catch (_) {
      // Best-effort cleanup of the temp directory.
    }
  }
}
