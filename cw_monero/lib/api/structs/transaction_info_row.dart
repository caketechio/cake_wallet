import 'dart:ffi';
import 'package:ffi/ffi.dart';

class TransactionInfoRow extends Struct {
  @Uint64()
  external int amount;

  @Uint64()
  external int fee;

  @Uint64()
  external int blockHeight;

  @Uint64()
  external int confirmations;

  @Uint64()
  external int unlockTime;

  @Uint32()
  external int subaddrAccount;

  @Int8()
  external int direction;

  @Int8()
  external int isPending;

  @Uint32()
  external int subaddrIndex;

  external Pointer<Utf8> hash;

  external Pointer<Utf8> paymentId;

  @Int64()
  external int datetime;

  int getDatetime() => datetime;
  int getAmount() => amount >= 0 ? amount : amount * -1;
  bool getIsPending() => isPending != 0;
  String getHash() => hash.toDartString();
  String getPaymentId() => paymentId.toDartString();
  int getUnlockTime() => unlockTime >> 32;
}
