import 'package:grafile/grafile.dart';
import 'package:test/test.dart';

void main() {
  group('GrafileException.forCode', () {
    test('maps result codes to specific exceptions', () {
      expect(
        GrafileException.forCode(GrafileResult.error, 'x'),
        isA<GrafileError>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.internal, 'x'),
        isA<GrafileInternalException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.busy, 'x'),
        isA<GrafileBusyException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.locked, 'x'),
        isA<GrafileLockedException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.readOnly, 'x'),
        isA<GrafileReadOnlyException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.ioError, 'x'),
        isA<GrafileIoException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.corrupt, 'x'),
        isA<GrafileCorruptException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.notFound, 'x'),
        isA<GrafileNotFoundException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.tooBig, 'x'),
        isA<GrafileTooBigException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.constraint, 'x'),
        isA<GrafileConstraintException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.mismatch, 'x'),
        isA<GrafileMismatchException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.misuse, 'x'),
        isA<GrafileMisuseException>(),
      );
      expect(
        GrafileException.forCode(GrafileResult.notADatabase, 'x'),
        isA<GrafileNotADatabaseException>(),
      );
    });

    test('falls back to the base class for unknown codes', () {
      final exception = GrafileException.forCode(999, 'unknown');
      expect(exception.runtimeType, GrafileException);
      expect(exception.code, 999);
    });

    test('toString carries the code and message', () {
      expect(
        const GrafileBusyException(
          GrafileResult.busy,
          'database is locked',
        ).toString(),
        'GrafileBusyException(5): database is locked',
      );
    });
  });

  group('GrafileLibraryNotFoundException', () {
    test('message includes install instructions and searched paths', () {
      const exception = GrafileLibraryNotFoundException(['a', 'b']);
      expect(exception.message, contains('install.sh'));
      expect(exception.message, contains('GRAFILE_LIBRARY'));
      expect(exception.message, contains('- a'));
      expect(exception.message, contains('- b'));
    });

    test('truncates very long search lists', () {
      final exception = GrafileLibraryNotFoundException([
        for (var i = 0; i < 20; i++) 'p$i',
      ]);
      expect(exception.message, contains('- ...'));
    });
  });
}
