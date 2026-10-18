import 'package:grafile_dart/src/params.dart';
import 'package:test/test.dart';

void main() {
  group('encodeParams', () {
    test('returns null without params', () {
      expect(encodeParams(null), isNull);
    });

    test('encodes primitives, lists and maps', () {
      expect(encodeParams(const {}), '{}');
      expect(
        encodeParams(const {
          'int': 1,
          'double': 2.5,
          'text': 'x',
          'bool': true,
          'null': null,
          'list': [1, 'two'],
          'map': {'nested': 3},
        }),
        '{"int":1,"double":2.5,"text":"x","bool":true,"null":null,'
        '"list":[1,"two"],"map":{"nested":3}}',
      );
    });

    test('encodes DateTime as ISO 8601 text', () {
      expect(
        encodeParams({'d': DateTime.utc(2026, 10, 17, 12, 30)}),
        '{"d":"2026-10-17T12:30:00.000Z"}',
      );
    });

    test('rejects values the JSON parameter channel cannot carry', () {
      expect(
        () => encodeParams({'duration': Duration(days: 1)}),
        throwsArgumentError,
      );
    });
  });
}
