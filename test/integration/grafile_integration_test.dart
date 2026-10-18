import 'dart:io';

import 'package:grafile/grafile.dart';
import 'package:test/test.dart';

bool _libraryAvailable() {
  try {
    Grafile.version;
    return true;
  } on Exception {
    return false;
  }
}

void main() {
  final available = _libraryAvailable();

  group(
    'grafile integration',
    () {
      late Directory directory;
      late String dbPath;
      late GrafileDb db;

      setUp(() {
        directory = Directory.systemTemp.createTempSync('grafile_test');
        dbPath = '${directory.path}${Platform.pathSeparator}test.grafile';
        db = Grafile.open(dbPath);
        addTearDown(db.dispose);
        addTearDown(() {
          try {
            directory.deleteSync(recursive: true);
          } catch (_) {
            // Best-effort cleanup; the OS reclaims the temp directory anyway.
          }
        });
      });

      test('reports the native library version', () {
        expect(Grafile.version, isNotEmpty);
        expect(Grafile.versionNumber, greaterThanOrEqualTo(1000));
      });

      test('exec and queryJson round trip', () {
        db.exec("CREATE (:Person {name: 'alice', age: 30})");
        db.exec("CREATE (:Person {name: 'bob', age: 25})");

        final rows = db.queryJson(
          'MATCH (p:Person) RETURN p.name AS name, p.age AS age ORDER BY age',
        );
        expect(rows, [
          {'name': 'bob', 'age': 25},
          {'name': 'alice', 'age': 30},
        ]);
      });

      test('typed query decodes scalars and binds parameters', () {
        db.exec(
          "CREATE (:Person {name: \$name, age: \$age})",
          params: {'name': 'carol', 'age': 41},
        );

        final rows = db.query(
          'MATCH (p:Person) WHERE p.age > \$min RETURN p.name AS name, p.age AS age',
          params: {'min': 40},
        );
        expect(rows, hasLength(1));
        expect(rows.single['name'], const GrafileText('carol'));
        expect(rows.single['age'], const GrafileInt(41));
      });

      test('nodes and edges decode with labels, type and properties', () {
        db.exec(
          "CREATE (a:Person {name: 'alice'})"
          "-[:KNOWS {since: 2020}]->(b:Person {name: 'bob'})",
        );

        final rows = db.query(
          'MATCH (a)-[r:KNOWS]->(b) RETURN a AS a, r AS r, b AS b',
        );
        final row = rows.single;

        final a = row['a']! as GrafileNode;
        expect(a.labels, ['Person']);
        expect(a.properties['name'], const GrafileText('alice'));

        final b = row['b']! as GrafileNode;
        expect(b.labels, ['Person']);
        expect(b.properties['name'], const GrafileText('bob'));

        final r = row['r']! as GrafileEdge;
        expect(r.type, 'KNOWS');
        expect(r.start, a.id);
        expect(r.end, b.id);
        expect(r.properties['since'], const GrafileInt(2020));
      });

      test('lists and maps decode', () {
        final rows = db.query(
          "RETURN [1, 'two', 3.5, true, null] AS xs, {a: 1, b: 'two'} AS m",
        );
        final row = rows.single;

        expect(
          row['xs'],
          const GrafileList([
            GrafileInt(1),
            GrafileText('two'),
            GrafileDouble(3.5),
            GrafileBool(true),
            GrafileNull(),
          ]),
        );
        expect(
          row['m'],
          const GrafileMap({'a': GrafileInt(1), 'b': GrafileText('two')}),
        );
      });

      test('temporal values and points decode', () {
        final rows = db.query(
          "RETURN date('2026-10-17') AS d, "
          "localtime('12:30:00') AS lt, "
          "datetime('2026-10-17T12:30:00Z') AS dt, "
          "localdatetime('2026-10-17T12:30:00') AS ldt, "
          "duration('P1DT2H') AS dur, "
          'point({x: 1.5, y: 2.5}) AS p',
        );
        final row = rows.single;

        expect(row['d'], isA<GrafileDate>());
        expect((row['d']! as GrafileDate).iso, startsWith('2026-10-17'));
        expect(row['lt'], isA<GrafileLocalTime>());
        expect(row['dt'], isA<GrafileDateTime>());
        expect(row['ldt'], isA<GrafileLocalDateTime>());
        expect(row['dur'], isA<GrafileDuration>());

        final point = row['p']! as GrafilePoint;
        expect(point.x, 1.5);
        expect(point.y, 2.5);
      });

      test('getText reads text and temporal columns', () {
        final statement = db.prepare(
          "RETURN date('2026-10-17') AS d, 'plain' AS s",
        );
        addTearDown(statement.dispose);

        expect(statement.step(), isTrue);
        expect(statement.columnNames, ['d', 's']);
        expect(statement.getText(0), startsWith('2026-10-17'));
        expect(statement.getText(1), 'plain');
        expect(statement.step(), isFalse);
      });

      test('transactions commit and roll back', () {
        db.exec("CREATE (:Person {name: 'alice'})");

        db.begin();
        db.exec("CREATE (:Person {name: 'bob'})");
        db.commit();

        db.begin();
        db.exec("CREATE (:Person {name: 'carol'})");
        db.rollback();

        final rows = db.queryJson(
          'MATCH (p:Person) RETURN p.name AS name ORDER BY name',
        );
        expect(rows.map((row) => row['name']), ['alice', 'bob']);
      });

      test(
        'transaction helper commits on success and rolls back on failure',
        () {
          db.transaction(() => db.exec("CREATE (:Person {name: 'dave'})"));

          expect(
            () => db.transaction(() {
              db.exec("CREATE (:Person {name: 'eve'})");
              throw StateError('stop');
            }),
            throwsStateError,
          );

          final rows = db.queryJson('MATCH (p:Person) RETURN p.name AS name');
          expect(rows.map((row) => row['name']), ['dave']);
        },
      );

      test('syntax errors raise GrafileException with a message', () {
        expect(
          () => db.query('MATCH (n RETURN n'),
          throwsA(
            isA<GrafileException>()
                .having((error) => error.code, 'code', isNot(GrafileResult.ok))
                .having((error) => error.message, 'message', isNotEmpty),
          ),
        );
      });

      test('a second writer gets busy while a transaction is open', () {
        final other = Grafile.open(dbPath);
        addTearDown(other.dispose);

        db.begin();
        try {
          expect(
            () => other.begin(),
            throwsA(
              anyOf(isA<GrafileBusyException>(), isA<GrafileLockedException>()),
            ),
          );
        } finally {
          db.rollback();
        }
      });

      test('prepared statements rebind and reset', () {
        final statement = db.prepare('RETURN \$value AS v');
        addTearDown(statement.dispose);

        statement.bindParams({'value': 1});
        expect(statement.step(), isTrue);
        expect(statement.columnKind(0), GrafileColumnKind.integer);
        expect(statement.getInt(0), 1);
        expect(statement.getJson(0), 1);
        expect(statement.step(), isFalse);

        statement.reset();
        expect(statement.step(), isTrue);
        expect(statement.getInt(0), 1);

        statement.bindParams({'value': 2});
        expect(statement.step(), isTrue);
        expect(statement.getInt(0), 2);
      });

      test('meta returns the database header', () {
        final meta = db.meta();
        expect(meta, isNotEmpty);
        expect(db.meta(raw: true), isNotEmpty);
      });

      test('disposed handles throw StateError and dispose is idempotent', () {
        final local = Grafile.open(dbPath);
        local.dispose();
        expect(local.isDisposed, isTrue);
        expect(() => local.exec('RETURN 1'), throwsStateError);
        local.dispose();
      });

      test('read-only open of a missing file fails', () {
        final missing =
            '${directory.path}${Platform.pathSeparator}missing.grafile';
        expect(
          () => Grafile.openReadOnly(missing),
          throwsA(isA<GrafileException>()),
        );
      });
    },
    skip: available
        ? false
        : 'libgrafile not found; set GRAFILE_LIBRARY to run integration tests',
  );
}
