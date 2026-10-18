import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'exceptions.dart';

typedef _IntNative = Int32 Function();
typedef _IntDart = int Function();

typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);

typedef _OpenV2Native =
    Int32 Function(
      Pointer<Utf8>,
      Int32,
      Pointer<Pointer<Void>>,
      Pointer<Pointer<Utf8>>,
    );
typedef _OpenV2Dart =
    int Function(
      Pointer<Utf8>,
      int,
      Pointer<Pointer<Void>>,
      Pointer<Pointer<Utf8>>,
    );

typedef _HandleCallNative = Int32 Function(Pointer<Void>);
typedef _HandleCallDart = int Function(Pointer<Void>);

typedef _ErrmsgNative = Pointer<Utf8> Function(Pointer<Void>);
typedef _ErrmsgDart = Pointer<Utf8> Function(Pointer<Void>);

typedef _ExecNative =
    Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _ExecDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef _QueryJsonNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );
typedef _QueryJsonDart =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
    );

typedef _MetaJsonNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<Pointer<Utf8>>);
typedef _MetaJsonDart =
    int Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>);

typedef _PrepareNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Pointer<Void>>,
      Pointer<Pointer<Utf8>>,
    );
typedef _PrepareDart =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Pointer<Void>>,
      Pointer<Pointer<Utf8>>,
    );

typedef _BindNative = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef _BindDart = int Function(Pointer<Void>, Pointer<Utf8>);

typedef _FinalizeNative = Void Function(Pointer<Void>);
typedef _FinalizeDart = void Function(Pointer<Void>);

typedef _ColumnNameNative = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef _ColumnNameDart = Pointer<Utf8> Function(Pointer<Void>, int);

typedef _ColumnKindNative = Int32 Function(Pointer<Void>, Int32);
typedef _ColumnKindDart = int Function(Pointer<Void>, int);

typedef _ColumnJsonNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<Pointer<Utf8>>);
typedef _ColumnJsonDart =
    int Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>);

typedef _ColumnIntNative = Int32 Function(Pointer<Void>, Int32, Pointer<Int64>);
typedef _ColumnIntDart = int Function(Pointer<Void>, int, Pointer<Int64>);

typedef _ColumnDoubleNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<Double>);
typedef _ColumnDoubleDart = int Function(Pointer<Void>, int, Pointer<Double>);

typedef _ColumnTextNative = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef _ColumnTextDart = Pointer<Utf8> Function(Pointer<Void>, int);

/// Thin, typed handles to every function exported by `libgrafile`.
///
/// One instance is created per loaded dynamic library; all higher-level
/// objects share it.
final class GrafileBindings {
  /// Looks up every `libgrafile` symbol in [library].
  GrafileBindings(this.library) {
    try {
      libversion = library.lookupFunction<_IntNative, _IntDart>(
        'grafile_libversion',
      );
      versionString = library.lookupFunction<_VersionNative, _VersionDart>(
        'grafile_version',
      );
      free = library.lookupFunction<_FreeNative, _FreeDart>('grafile_free');
      openV2 = library.lookupFunction<_OpenV2Native, _OpenV2Dart>(
        'grafile_open_v2',
      );
      close = library.lookupFunction<_FreeNative, _FreeDart>('grafile_close');
      errorCode = library.lookupFunction<_HandleCallNative, _HandleCallDart>(
        'grafile_errcode',
      );
      errorMessage = library.lookupFunction<_ErrmsgNative, _ErrmsgDart>(
        'grafile_errmsg',
      );
      exec = library.lookupFunction<_ExecNative, _ExecDart>('grafile_exec');
      queryJson = library.lookupFunction<_QueryJsonNative, _QueryJsonDart>(
        'grafile_query_json',
      );
      metaJson = library.lookupFunction<_MetaJsonNative, _MetaJsonDart>(
        'grafile_meta_json',
      );
      begin = library.lookupFunction<_HandleCallNative, _HandleCallDart>(
        'grafile_begin',
      );
      commit = library.lookupFunction<_HandleCallNative, _HandleCallDart>(
        'grafile_commit',
      );
      rollback = library.lookupFunction<_HandleCallNative, _HandleCallDart>(
        'grafile_rollback',
      );
      prepare = library.lookupFunction<_PrepareNative, _PrepareDart>(
        'grafile_prepare',
      );
      bindParamsJson = library.lookupFunction<_BindNative, _BindDart>(
        'grafile_bind_params_json',
      );
      step = library.lookupFunction<_HandleCallNative, _HandleCallDart>(
        'grafile_step',
      );
      reset = library.lookupFunction<_HandleCallNative, _HandleCallDart>(
        'grafile_reset',
      );
      finalizeStatement = library
          .lookupFunction<_FinalizeNative, _FinalizeDart>('grafile_finalize');
      columnCount = library.lookupFunction<_HandleCallNative, _HandleCallDart>(
        'grafile_column_count',
      );
      columnName = library.lookupFunction<_ColumnNameNative, _ColumnNameDart>(
        'grafile_column_name',
      );
      columnKind = library.lookupFunction<_ColumnKindNative, _ColumnKindDart>(
        'grafile_column_kind',
      );
      columnJson = library.lookupFunction<_ColumnJsonNative, _ColumnJsonDart>(
        'grafile_column_json',
      );
      columnInt64 = library.lookupFunction<_ColumnIntNative, _ColumnIntDart>(
        'grafile_column_int64',
      );
      columnDouble = library
          .lookupFunction<_ColumnDoubleNative, _ColumnDoubleDart>(
            'grafile_column_double',
          );
      columnText = library.lookupFunction<_ColumnTextNative, _ColumnTextDart>(
        'grafile_column_text',
      );
    } on ArgumentError catch (error) {
      throw GrafileLibraryException(
        'libgrafile is missing a required symbol: ${error.message}',
      );
    }
  }

  /// The underlying dynamic library.
  final DynamicLibrary library;

  /// `grafile_libversion`.
  late final int Function() libversion;

  /// `grafile_version`.
  late final Pointer<Utf8> Function() versionString;

  /// `grafile_free`.
  late final void Function(Pointer<Void>) free;

  /// `grafile_open_v2`.
  late final int Function(
    Pointer<Utf8>,
    int,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Utf8>>,
  )
  openV2;

  /// `grafile_close`.
  late final void Function(Pointer<Void>) close;

  /// `grafile_errcode`.
  late final int Function(Pointer<Void>) errorCode;

  /// `grafile_errmsg`.
  late final Pointer<Utf8> Function(Pointer<Void>) errorMessage;

  /// `grafile_exec`.
  late final int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>) exec;

  /// `grafile_query_json`.
  late final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Pointer<Utf8>>,
  )
  queryJson;

  /// `grafile_meta_json`.
  late final int Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>) metaJson;

  /// `grafile_begin`.
  late final int Function(Pointer<Void>) begin;

  /// `grafile_commit`.
  late final int Function(Pointer<Void>) commit;

  /// `grafile_rollback`.
  late final int Function(Pointer<Void>) rollback;

  /// `grafile_prepare`.
  late final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Utf8>>,
  )
  prepare;

  /// `grafile_bind_params_json`.
  late final int Function(Pointer<Void>, Pointer<Utf8>) bindParamsJson;

  /// `grafile_step`.
  late final int Function(Pointer<Void>) step;

  /// `grafile_reset`.
  late final int Function(Pointer<Void>) reset;

  /// `grafile_finalize`.
  late final void Function(Pointer<Void>) finalizeStatement;

  /// `grafile_column_count`.
  late final int Function(Pointer<Void>) columnCount;

  /// `grafile_column_name`.
  late final Pointer<Utf8> Function(Pointer<Void>, int) columnName;

  /// `grafile_column_kind`.
  late final int Function(Pointer<Void>, int) columnKind;

  /// `grafile_column_json`.
  late final int Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>)
  columnJson;

  /// `grafile_column_int64`.
  late final int Function(Pointer<Void>, int, Pointer<Int64>) columnInt64;

  /// `grafile_column_double`.
  late final int Function(Pointer<Void>, int, Pointer<Double>) columnDouble;

  /// `grafile_column_text`.
  late final Pointer<Utf8> Function(Pointer<Void>, int) columnText;
}
