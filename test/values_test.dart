import 'dart:typed_data';

import 'package:grafile/grafile.dart';
import 'package:test/test.dart';

void main() {
  group('GrafileValue.fromJson', () {
    test('decodes scalars', () {
      expect(GrafileValue.fromJson(null), const GrafileNull());
      expect(GrafileValue.fromJson(true), const GrafileBool(true));
      expect(GrafileValue.fromJson(7), const GrafileInt(7));
      expect(GrafileValue.fromJson(3.5), const GrafileDouble(3.5));
      expect(GrafileValue.fromJson('hi'), const GrafileText('hi'));
    });

    test('decodes nested lists and maps', () {
      final value = GrafileValue.fromJson({
        'list': [1, 'two', null],
        'map': {'nested': false},
      });
      expect(
        value,
        const GrafileMap({
          'list': GrafileList([
            GrafileInt(1),
            GrafileText('two'),
            GrafileNull(),
          ]),
          'map': GrafileMap({'nested': GrafileBool(false)}),
        }),
      );
    });

    test('rejects non-JSON values', () {
      expect(() => GrafileValue.fromJson(Object()), throwsArgumentError);
    });
  });

  group('toDart', () {
    test('converts containers recursively', () {
      final value = GrafileValue.fromJson({
        'a': [1, 2],
        'b': 'text',
      });
      expect(value.toDart(), {
        'a': [1, 2],
        'b': 'text',
      });
    });

    test('returns scalars as plain Dart', () {
      expect(const GrafileNull().toDart(), isNull);
      expect(const GrafileInt(1).toDart(), 1);
      expect(const GrafileDouble(2.5).toDart(), 2.5);
      expect(const GrafileText('x').toDart(), 'x');
      expect(const GrafileBool(true).toDart(), true);
      final bytes = Uint8List.fromList([1, 2]);
      expect(GrafileBlob(Uint8List.fromList([1, 2])).toDart(), bytes);
    });
  });

  group('equality', () {
    test('node, edge, point and temporal values compare by content', () {
      expect(
        const GrafileNode(
          id: 1,
          labels: ['A'],
          properties: {'k': GrafileInt(1)},
        ),
        const GrafileNode(
          id: 1,
          labels: ['A'],
          properties: {'k': GrafileInt(1)},
        ),
      );
      expect(
        const GrafileEdge(id: 1, type: 'T', start: 1, end: 2, properties: {}),
        const GrafileEdge(id: 1, type: 'T', start: 1, end: 2, properties: {}),
      );
      expect(
        const GrafilePoint(srid: 7203, x: 1, y: 2, z: 3),
        const GrafilePoint(srid: 7203, x: 1, y: 2, z: 3),
      );
      expect(const GrafileDate('2026-10-17'), const GrafileDate('2026-10-17'));
      expect(const GrafileDuration('P1D'), isNot(const GrafileDate('P1D')));
    });

    test('blobs compare byte-wise', () {
      expect(
        GrafileBlob(Uint8List.fromList([1, 2, 3])),
        GrafileBlob(Uint8List.fromList([1, 2, 3])),
      );
      expect(
        GrafileBlob(Uint8List.fromList([1, 2, 3])),
        isNot(GrafileBlob(Uint8List.fromList([1, 2, 4]))),
      );
    });
  });

  group('temporal helpers', () {
    test('parses ISO text where possible', () {
      expect(const GrafileDate('2026-10-17').dateTime, DateTime(2026, 10, 17));
      expect(
        const GrafileDateTime('2026-10-17T12:30:00Z').dateTime?.toUtc(),
        DateTime.utc(2026, 10, 17, 12, 30),
      );
      expect(const GrafileLocalTime('12:30:00').iso, '12:30:00');
    });
  });
}
