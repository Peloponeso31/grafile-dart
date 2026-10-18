import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

/// Runs [body] with a temporary UTF-8 C string allocated for [value].
T withUtf8<T>(String value, T Function(Pointer<Utf8>) body) {
  final pointer = value.toNativeUtf8();
  try {
    return body(pointer);
  } finally {
    calloc.free(pointer);
  }
}

/// Like [withUtf8] but passes `nullptr` when [value] is null.
T withUtf8Nullable<T>(String? value, T Function(Pointer<Utf8>) body) {
  if (value == null) return body(nullptr);
  return withUtf8(value, body);
}

/// Reads a borrowed C string; `nullptr` becomes `null`.
String? borrowUtf8(Pointer<Utf8> pointer) =>
    pointer == nullptr ? null : pointer.toDartString();

/// Copies the library-allocated string in [out] and releases it with
/// `grafile_free`. Returns `null` when the pointer is `nullptr`.
String? consumeAllocatedString(
  GrafileBindings bindings,
  Pointer<Pointer<Utf8>> out,
) {
  final pointer = out.value;
  if (pointer == nullptr) return null;
  out.value = nullptr;
  try {
    return pointer.toDartString();
  } finally {
    bindings.free(pointer.cast<Void>());
  }
}
