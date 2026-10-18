import 'dart:async';
import 'dart:io';

import 'package:grafile_dart/grafile_dart.dart';
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
    'async grafile integration',
    () {
      late Directory directory;
      late String dbPath;
      late AsyncGrafileDb db;

      setUp(() async {
        directory = Directory.systemTemp.createTempSync(
          'grafile_dart_async_test',
        );
        dbPath = '${directory.path}${Platform.pathSeparator}test.grafile';
        db = await AsyncGrafile.open(dbPath);
        addTearDown(db.dispose);
        addTearDown(() {
          try {
            directory.deleteSync(recursive: true);
          } catch (_) {
            // Best-effort cleanup; the OS reclaims the temp directory anyway.
          }
        });
      });

      test('exec and queryJson round trip', () async {
        await db.exec("CREATE (:Person {name: 'alice', age: 30})");
        await db.exec("CREATE (:Person {name: 'bob', age: 25})");

        final rows = await db.queryJson(
          'MATCH (p:Person) RETURN p.name AS name, p.age AS age ORDER BY age',
        );
        expect(rows, [
          {'name': 'bob', 'age': 25},
          {'name': 'alice', 'age': 30},
        ]);
      });

      test('typed query decodes values and binds parameters', () async {
        await db.exec(
          "CREATE (:Person {name: \$name, age: \$age})",
          params: {'name': 'carol', 'age': 41},
        );

        final rows = await db.query(
          'MATCH (p:Person) WHERE p.age > \$min RETURN p.name AS name, p.age AS age',
          params: {'min': 40},
        );
        expect(rows, hasLength(1));
        expect(rows.single['name'], const GrafileText('carol'));
        expect(rows.single['age'], const GrafileInt(41));
      });

      test(
        'entities, temporals and points survive the isolate boundary',
        () async {
          await db.exec(
            "CREATE (a:Person {name: 'alice'})"
            "-[:KNOWS {since: 2020}]->(b:Person {name: 'bob'})",
          );

          final rows = await db.query(
            'MATCH (a)-[r:KNOWS]->(b) '
            "RETURN a AS a, r AS r, b AS b, date('2026-10-17') AS d, "
            'point({x: 1.5, y: 2.5}) AS p, [1, \'two\'] AS xs',
          );
          final row = rows.single;

          final a = row['a']! as GrafileNode;
          expect(a.labels, ['Person']);
          expect(a.properties['name'], const GrafileText('alice'));

          final r = row['r']! as GrafileEdge;
          expect(r.type, 'KNOWS');
          expect(r.start, a.id);
          expect(r.properties['since'], const GrafileInt(2020));

          expect(row['d'], isA<GrafileDate>());
          final point = row['p']! as GrafilePoint;
          expect(point.x, 1.5);
          expect(point.y, 2.5);
          expect(
            row['xs'],
            const GrafileList([GrafileInt(1), GrafileText('two')]),
          );
        },
      );

      test('transactions commit and roll back', () async {
        await db.exec("CREATE (:Person {name: 'alice'})");

        await db.begin();
        await db.exec("CREATE (:Person {name: 'bob'})");
        await db.commit();

        await db.begin();
        await db.exec("CREATE (:Person {name: 'carol'})");
        await db.rollback();

        final rows = await db.queryJson(
          'MATCH (p:Person) RETURN p.name AS name ORDER BY name',
        );
        expect(rows.map((row) => row['name']), ['alice', 'bob']);
      });

      test(
        'transaction helper commits on success and rolls back on failure',
        () async {
          await db.transaction(
            () => db.exec("CREATE (:Person {name: 'dave'})"),
          );

          await expectLater(
            db.transaction(() async {
              await db.exec("CREATE (:Person {name: 'eve'})");
              throw StateError('stop');
            }),
            throwsStateError,
          );

          final rows = await db.queryJson(
            'MATCH (p:Person) RETURN p.name AS name',
          );
          expect(rows.map((row) => row['name']), ['dave']);
        },
      );

      test('syntax errors propagate as typed grafile exceptions', () async {
        await expectLater(
          db.query('MATCH (n RETURN n'),
          throwsA(
            isA<GrafileException>()
                .having((error) => error.code, 'code', isNot(GrafileResult.ok))
                .having((error) => error.message, 'message', isNotEmpty),
          ),
        );

        final rows = await db.query('RETURN 1 AS v');
        expect(rows.single['v'], const GrafileInt(1));
      });

      test('concurrent calls stay correlated', () async {
        await Future.wait([
          for (var i = 0; i < 20; i++)
            db.exec('CREATE (:N {i: \$i})', params: {'i': i}),
        ]);

        final results = await Future.wait([
          for (var i = 0; i < 10; i++)
            db.query(
              'MATCH (n:N) WHERE n.i = \$i RETURN n.i AS i',
              params: {'i': i},
            ),
        ]);
        for (var i = 0; i < 10; i++) {
          expect(results[i].single['i'], GrafileInt(i));
        }
      });

      test('a second writer gets busy while a transaction is open', () async {
        final other = await AsyncGrafile.open(dbPath);
        addTearDown(other.dispose);

        await db.begin();
        try {
          await expectLater(
            other.begin(),
            throwsA(
              anyOf(isA<GrafileBusyException>(), isA<GrafileLockedException>()),
            ),
          );
        } finally {
          await db.rollback();
        }
      });

      test(
        'sync and async handles on one file share the writer slot',
        () async {
          final sync = Grafile.open(dbPath);
          addTearDown(sync.dispose);

          await db.begin();
          try {
            expect(
              () => sync.begin(),
              throwsA(
                anyOf(
                  isA<GrafileBusyException>(),
                  isA<GrafileLockedException>(),
                ),
              ),
            );
          } finally {
            await db.rollback();
          }
        },
      );

      test('meta returns the header', () async {
        expect(await db.meta(), isNotEmpty);
        expect(await db.meta(raw: true), isNotEmpty);
      });

      test('dispose stops the worker and later calls fail', () async {
        final local = await AsyncGrafile.open(dbPath);
        await local.dispose();
        expect(local.isDisposed, isTrue);
        await expectLater(local.exec('RETURN 1'), throwsStateError);
        await local.dispose();
      });

      test('open failures propagate to the caller', () async {
        final missing =
            '${directory.path}${Platform.pathSeparator}missing.grafile';
        await expectLater(
          AsyncGrafile.openReadOnly(missing),
          throwsA(isA<GrafileException>()),
        );
      });

      test('parameter encoding failures surface locally', () async {
        await expectLater(
          db.exec('RETURN \$d AS d', params: {'d': Duration(days: 1)}),
          throwsArgumentError,
        );

        final rows = await db.query('RETURN 1 AS v');
        expect(rows.single['v'], const GrafileInt(1));
      });

      test(
        'abandoned futures and late replies do not break the handle',
        () async {
          final late = db.query('RETURN 1 AS v');
          final timeout = Completer<void>();
          final raced = Future.any<Object?>([late, timeout.future]);
          timeout.completeError(TimeoutException('synthetic'));
          await expectLater(raced, throwsA(isA<TimeoutException>()));

          final rows = await db.query('RETURN 2 AS v');
          expect(rows.single['v'], const GrafileInt(2));
        },
      );
    },
    skip: available
        ? false
        : 'libgrafile not found; set GRAFILE_LIBRARY to run integration tests',
  );
}
