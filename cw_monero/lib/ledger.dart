import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:ffi/ffi.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus_dart.dart';
import 'package:monero/monero.dart' as monero;

LedgerConnection? gLedger;

Timer? _ledgerExchangeTimer;
Timer? _ledgerKeepAlive;

void enableLedgerExchange(monero.wallet ptr, LedgerConnection connection) {
  _ledgerExchangeTimer?.cancel();
  _ledgerExchangeTimer = Timer.periodic(Duration(milliseconds: 1), (_) async {
    final ledgerRequestLength = monero.Wallet_getSendToDeviceLength(ptr);
    final ledgerRequest = monero.Wallet_getSendToDevice(ptr)
        .cast<Uint8>()
        .asTypedList(ledgerRequestLength);
    if (ledgerRequestLength > 0) {
      _ledgerKeepAlive?.cancel();

      final Pointer<Uint8> emptyPointer = malloc<Uint8>(0);
      monero.Wallet_setDeviceSendData(
          ptr, emptyPointer.cast<UnsignedChar>(), 0);
      malloc.free(emptyPointer);

      _logLedgerCommand(ledgerRequest, false);
      final response = await exchange(connection, ledgerRequest);
      _logLedgerCommand(response, true);

      if (ListEquality().equals(response, [0x55, 0x15])) {
        await connection.disconnect();
        //   // TODO: Show POPUP pls unlock your device
        // await Future.delayed(Duration(seconds: 15));
      //   response = await exchange(connection, ledgerRequest);
      }

      final Pointer<Uint8> result = malloc<Uint8>(response.length);
      for (var i = 0; i < response.length; i++) {
        result.asTypedList(response.length)[i] = response[i];
      }

      monero.Wallet_setDeviceReceivedData(
          ptr, result.cast<UnsignedChar>(), response.length);
      malloc.free(result);
      keepAlive(connection);
    }
  });
}

void keepAlive(LedgerConnection connection) {
  if (connection.connectionType == ConnectionType.ble) {
    _ledgerKeepAlive = Timer.periodic(Duration(seconds: 10), (_) async {
      UniversalBle.setNotifiable(
        connection.device.id,
        connection.device.deviceInfo.serviceId,
        connection.device.deviceInfo.notifyCharacteristicKey,
        BleInputProperty.notification,
      ).onError((_, __) async {});
    });
  }
}

void disableLedgerExchange() {
  _ledgerExchangeTimer?.cancel();
  _ledgerKeepAlive?.cancel();
  gLedger?.disconnect();
  gLedger = null;
}

Future<Uint8List> exchange(LedgerConnection connection, Uint8List data) async =>
    connection.sendOperation<Uint8List>(ExchangeOperation(data));

class ExchangeOperation extends LedgerRawOperation<Uint8List> {
  final Uint8List inputData;

  ExchangeOperation(this.inputData);

  @override
  Future<Uint8List> read(ByteDataReader reader) async =>
      reader.read(reader.remainingLength);

  @override
  Future<List<Uint8List>> write(ByteDataWriter writer) async => [inputData];
}

const _ledgerMoneroCommands = {
  0x00: "INS_NONE",
  0x02: "INS_RESET",
  0x20: "INS_GET_KEY",
  0x21: "INS_DISPLAY_ADDRESS",
  0x22: "INS_PUT_KEY",
  0x24: "INS_GET_CHACHA8_PREKEY",
  0x26: "INS_VERIFY_KEY",
  0x28: "INS_MANAGE_SEEDWORDS",
  0x30: "INS_SECRET_KEY_TO_PUBLIC_KEY",
  0x32: "INS_GEN_KEY_DERIVATION",
  0x34: "INS_DERIVATION_TO_SCALAR",
  0x36: "INS_DERIVE_PUBLIC_KEY",
  0x38: "INS_DERIVE_SECRET_KEY",
  0x3A: "INS_GEN_KEY_IMAGE",
  0x3B: "INS_DERIVE_VIEW_TAG",
  0x3C: "INS_SECRET_KEY_ADD",
  0x3E: "INS_SECRET_KEY_SUB",
  0x40: "INS_GENERATE_KEYPAIR",
  0x42: "INS_SECRET_SCAL_MUL_KEY",
  0x44: "INS_SECRET_SCAL_MUL_BASE",
  0x46: "INS_DERIVE_SUBADDRESS_PUBLIC_KEY",
  0x48: "INS_GET_SUBADDRESS",
  0x4A: "INS_GET_SUBADDRESS_SPEND_PUBLIC_KEY",
  0x4C: "INS_GET_SUBADDRESS_SECRET_KEY",
  0x70: "INS_OPEN_TX",
  0x72: "INS_SET_SIGNATURE_MODE",
  0x74: "INS_GET_ADDITIONAL_KEY",
  0x76: "INS_STEALTH",
  0x77: "INS_GEN_COMMITMENT_MASK",
  0x78: "INS_BLIND",
  0x7A: "INS_UNBLIND",
  0x7B: "INS_GEN_TXOUT_KEYS",
  0x7D: "INS_PREFIX_HASH",
  0x7C: "INS_VALIDATE",
  0x7E: "INS_MLSAG",
  0x7F: "INS_CLSAG",
  0x80: "INS_CLOSE_TX",
  0xA0: "INS_GET_TX_PROOF",
  0xC0: "INS_GET_RESPONSE"
};

void _logLedgerCommand(Uint8List command, [bool isResponse = true]) {
  String toHexString(Uint8List data) =>
      data.map((e) => e.toRadixString(16).padLeft(2, '0')).join();



  if (isResponse) {
    printV("< ${toHexString(command)}");
  } else {
    printV(
        "> ${_ledgerMoneroCommands[command[1]]} ${toHexString(command.sublist(2))}");
  }
}
