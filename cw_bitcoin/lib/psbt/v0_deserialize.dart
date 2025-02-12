import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:ledger_bitcoin/psbt.dart';
import 'package:ledger_bitcoin/src/psbt/map_extension.dart';
import 'package:ledger_bitcoin/src/utils/buffer_reader.dart';
import 'package:ledger_bitcoin/src/utils/uint8list_extension.dart' as ext;

extension PsbtSigner on PsbtV2 {

  void deserializeV0(Uint8List psbt) {
    final bufferReader = BufferReader(psbt);
    if (!listEquals(bufferReader.readSlice(5), Uint8List.fromList([0x70, 0x73, 0x62, 0x74, 0xff]))) {
      throw Exception("Invalid magic bytes");
    }
    while (_readKeyPair(globalMap, bufferReader)) {}

    final tx = BtcTransaction.fromRaw(BytesUtils.toHexString(globalMap['00']!));

    setGlobalInputCount(tx.inputs.length);
    setGlobalOutputCount(tx.outputs.length);
    setGlobalTxVersion(Uint8List.fromList(tx.version).readUint32LE(0));

    for (var i = 0; i < getGlobalInputCount(); i++) {
      inputMaps.insert(i, <String, Uint8List>{});
      while (_readKeyPair(inputMaps[i], bufferReader)) {}
      final input = tx.inputs[i];
      setInputOutputIndex(i, input.txIndex);
      setInputPreviousTxId(i, Uint8List.fromList(BytesUtils.fromHexString(input.txId).reversed.toList()));
      setInputSequence(i, Uint8List.fromList(input.sequence).readUint32LE(0));
    }
    for (var i = 0; i < getGlobalOutputCount(); i++) {
      outputMaps.insert(i, <String, Uint8List>{});
      while (_readKeyPair(outputMaps[i], bufferReader)) {}
      final output = tx.outputs[i];
      setOutputAmount(i, output.amount.toInt());
      setOutputScript(i, Uint8List.fromList(output.scriptPubKey.toBytes()));
    }
  }

  bool _readKeyPair(Map<String, Uint8List> map, BufferReader bufferReader) {
    final keyLen = bufferReader.readVarInt();
    if (keyLen == 0) return false;

    final keyType = bufferReader.readUInt8();
    final keyData = bufferReader.readSlice(keyLen - 1);
    final value = bufferReader.readVarSlice();

    map.set(keyType, keyData, value);
    return true;
  }
}
