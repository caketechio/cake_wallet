/// bindings for `libldk_ffi`

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart' as ffi;

// ignore_for_file: unused_import, camel_case_types, non_constant_identifier_names
final DynamicLibrary _dl = _open();
/// Reference to the Dynamic Library, it should be only used for low-level access
final DynamicLibrary dl = _dl;
DynamicLibrary _open() {
  if (Platform.isAndroid) return DynamicLibrary.open('libldk_ffi.so');
  if (Platform.isIOS) return DynamicLibrary.executable();
  throw UnsupportedError('This platform is not supported.');
}

/// C function `error_message_utf8`.
int error_message_utf8(
  Pointer<ffi.Utf8> buf,
  int length,
) {
  return _error_message_utf8(buf, length);
}
final _error_message_utf8_Dart _error_message_utf8 = _dl.lookupFunction<_error_message_utf8_C, _error_message_utf8_Dart>('error_message_utf8');
typedef _error_message_utf8_C = Int32 Function(
  Pointer<ffi.Utf8> buf,
  Int32 length,
);
typedef _error_message_utf8_Dart = int Function(
  Pointer<ffi.Utf8> buf,
  int length,
);

/// <p class="para-brief"> dummy function to call in ios to avoid tree shacking.</p>
void hello_world() {
  _hello_world();
}
final _hello_world_Dart _hello_world = _dl.lookupFunction<_hello_world_C, _hello_world_Dart>('hello_world');
typedef _hello_world_C = Void Function();
typedef _hello_world_Dart = void Function();

/// C function `last_error_length`.
int last_error_length() {
  return _last_error_length();
}
final _last_error_length_Dart _last_error_length = _dl.lookupFunction<_last_error_length_C, _last_error_length_Dart>('last_error_length');
typedef _last_error_length_C = Int32 Function();
typedef _last_error_length_Dart = int Function();

/// C function `send_message`.
int send_message(
  Pointer<ffi.Utf8> msg,
  int isolate_port,
) {
  return _send_message(msg, isolate_port);
}
final _send_message_Dart _send_message = _dl.lookupFunction<_send_message_C, _send_message_Dart>('send_message');
typedef _send_message_C = Int32 Function(
  Pointer<ffi.Utf8> msg,
  Int64 isolate_port,
);
typedef _send_message_Dart = int Function(
  Pointer<ffi.Utf8> msg,
  int isolate_port,
);

/// <p class="para-brief"> ffi interface for starting the LDK.</p>
void start_ldk(
  Pointer<ffi.Utf8> rpc_info,
  Pointer<ffi.Utf8> ldk_storage_path,
  int port,
  Pointer<ffi.Utf8> network,
  Pointer<ffi.Utf8> node_name,
  Pointer<ffi.Utf8> address,
  Pointer<ffi.Utf8> mnemonic_key_phrase,
  Pointer<NativeFunction<Void Function(Pointer<ffi.Utf8>)>> func,
) {
  _start_ldk(rpc_info, ldk_storage_path, port, network, node_name, address, mnemonic_key_phrase, func);
}
final _start_ldk_Dart _start_ldk = _dl.lookupFunction<_start_ldk_C, _start_ldk_Dart>('start_ldk');
typedef _start_ldk_C = Void Function(
  Pointer<ffi.Utf8> rpc_info,
  Pointer<ffi.Utf8> ldk_storage_path,
  Uint16 port,
  Pointer<ffi.Utf8> network,
  Pointer<ffi.Utf8> node_name,
  Pointer<ffi.Utf8> address,
  Pointer<ffi.Utf8> mnemonic_key_phrase,
  Pointer<NativeFunction<Void Function(Pointer<ffi.Utf8>)>> func,
);
typedef _start_ldk_Dart = void Function(
  Pointer<ffi.Utf8> rpc_info,
  Pointer<ffi.Utf8> ldk_storage_path,
  int port,
  Pointer<ffi.Utf8> network,
  Pointer<ffi.Utf8> node_name,
  Pointer<ffi.Utf8> address,
  Pointer<ffi.Utf8> mnemonic_key_phrase,
  Pointer<NativeFunction<Void Function(Pointer<ffi.Utf8>)>> func,
);

/// Binding to `allo-isolate` crate
void store_dart_post_cobject(
  Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>> ptr,
) {
  _store_dart_post_cobject(ptr);
}
final _store_dart_post_cobject_Dart _store_dart_post_cobject = _dl.lookupFunction<_store_dart_post_cobject_C, _store_dart_post_cobject_Dart>('store_dart_post_cobject');
typedef _store_dart_post_cobject_C = Void Function(
  Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>> ptr,
);
typedef _store_dart_post_cobject_Dart = void Function(
  Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>> ptr,
);
