import 'dart:typed_data';

import 'package:grafile/grafile.dart';
import 'package:grafile/src/decoding.dart';
import 'package:test/test.dart';

void main() {
  group('decodeColumnValue', () {
    test('decodes scalar kinds', () {
      expect(
        decodeColumnValue(GrafileColumnKind.nullValue, null),
        const GrafileNull(),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.integer, 7),
        const GrafileInt(7),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.float, 2.5),
        const GrafileDouble(2.5),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.float, 2),
        const GrafileDouble(2),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.text, 'x'),
        const GrafileText('x'),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.boolean, true),
        const GrafileBool(true),
      );
    });

    test('decodes blobs from hex', () {
      expect(
        decodeColumnValue(GrafileColumnKind.blob, '0x0102ff'),
        GrafileBlob(Uint8List.fromList([1, 2, 255])),
      );
    });

    test('decodes lists and maps', () {
      expect(
        decodeColumnValue(GrafileColumnKind.list, [1, 'two']),
        const GrafileList([GrafileInt(1), GrafileText('two')]),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.map, {'a': 1}),
        const GrafileMap({'a': GrafileInt(1)}),
      );
    });

    test('decodes nodes, edges and points', () {
      expect(
        decodeColumnValue(GrafileColumnKind.node, {
          'id': 1,
          'labels': ['A'],
          'properties': {'k': 2},
        }),
        const GrafileNode(
          id: 1,
          labels: ['A'],
          properties: {'k': GrafileInt(2)},
        ),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.edge, {
          'id': 3,
          'type': 'T',
          'start': 1,
          'end': 2,
          'properties': {},
        }),
        const GrafileEdge(id: 3, type: 'T', start: 1, end: 2, properties: {}),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.point, {
          'srid': 7203,
          'x': 1,
          'y': 2,
        }),
        const GrafilePoint(srid: 7203, x: 1, y: 2),
      );
    });

    test('decodes temporal kinds from ISO text', () {
      expect(
        decodeColumnValue(GrafileColumnKind.date, '2026-10-17'),
        const GrafileDate('2026-10-17'),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.localTime, '12:30:00'),
        const GrafileLocalTime('12:30:00'),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.time, '12:30:00+02:00'),
        const GrafileTime('12:30:00+02:00'),
      );
      expect(
        decodeColumnValue(
          GrafileColumnKind.localDateTime,
          '2026-10-17T12:30:00',
        ),
        const GrafileLocalDateTime('2026-10-17T12:30:00'),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.dateTime, '2026-10-17T12:30:00Z'),
        const GrafileDateTime('2026-10-17T12:30:00Z'),
      );
      expect(
        decodeColumnValue(GrafileColumnKind.duration, 'P1DT2H'),
        const GrafileDuration('P1DT2H'),
      );
    });

    test('rejects mismatched JSON shapes', () {
      expect(
        () => decodeColumnValue(GrafileColumnKind.integer, 'x'),
        throwsA(isA<GrafileException>()),
      );
      expect(
        () => decodeColumnValue(GrafileColumnKind.blob, '0xabc'),
        throwsA(isA<GrafileException>()),
      );
      expect(
        () => decodeColumnValue(GrafileColumnKind.date, 5),
        throwsA(isA<GrafileException>()),
      );
      expect(
        () => decodeColumnValue(GrafileColumnKind.point, 5),
        throwsA(isA<GrafileException>()),
      );
    });

    test('unknown kinds fall back to generic JSON decoding', () {
      expect(
        decodeColumnValue(999, {'a': 1}),
        const GrafileMap({'a': GrafileInt(1)}),
      );
    });
  });
}
