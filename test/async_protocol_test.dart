import 'package:grafile/grafile.dart';
import 'package:grafile/src/async/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('describeFailure', () {
    test('describes grafile exceptions with code and message', () {
      final record = describeFailure(
        const GrafileBusyException(GrafileResult.busy, 'locked'),
        StackTrace.current,
      );
      expect(record.$1, 'grafile');
      expect(record.$2, GrafileResult.busy);
      expect(record.$3, 'locked');
      expect(record.$4, isNotEmpty);
    });

    test('describes state, argument, library and unknown failures', () {
      expect(
        describeFailure(StateError('bad state'), StackTrace.empty).$1,
        'state',
      );
      expect(
        describeFailure(ArgumentError('bad arg'), StackTrace.empty).$1,
        'argument',
      );
      expect(
        describeFailure(
          const GrafileLibraryException('missing'),
          StackTrace.empty,
        ).$1,
        'library',
      );
      expect(
        describeFailure(
          const GrafileLibraryNotFoundException(['path']),
          StackTrace.empty,
        ).$1,
        'library',
      );
      expect(describeFailure(Object(), StackTrace.empty).$1, 'unknown');
    });
  });

  group('remoteFailure', () {
    test('rebuilds typed grafile exceptions with the stack trace', () {
      final (error, stack) = remoteFailure((
        'grafile',
        GrafileResult.busy,
        'locked',
        StackTrace.empty.toString(),
      ));
      expect(error, isA<GrafileBusyException>());
      expect((error as GrafileException).code, GrafileResult.busy);
      expect(error.message, 'locked');
      expect(stack, isA<StackTrace>());
    });

    test('rebuilds state, argument, library and unknown failures', () {
      expect(remoteFailure(('state', 0, 'bad', '')).$1, isA<StateError>());
      expect(
        remoteFailure(('argument', 0, 'bad', '')).$1,
        isA<ArgumentError>(),
      );
      expect(
        remoteFailure(('library', 0, 'bad', '')).$1,
        isA<GrafileLibraryException>(),
      );
      expect(
        remoteFailure(('custom', 0, 'bad', '')).$1,
        isA<GrafileRemoteException>(),
      );
    });

    test('reports malformed payloads as state errors', () {
      expect(remoteFailure(null).$1, isA<StateError>());
      expect(remoteFailure(('partial',)).$1, isA<StateError>());
      expect(remoteFailure(1).$1, isA<StateError>());
    });
  });
}
