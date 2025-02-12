import 'dart:typed_data';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:collection/collection.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/bitcoin_wallet.dart';
import 'package:cw_bitcoin/utils.dart';
import 'package:ledger_bitcoin/psbt.dart';
import 'package:ledger_bitcoin/src/utils/buffer_writer.dart';

extension PsbtSigner on PsbtV2 {

  Uint8List extractUnsignedTX({bool getSegwit = true}) {
    final tx = BufferWriter()..writeUInt32(getGlobalTxVersion());

    final isSegwit = getInputWitnessUtxo(0) != null;
    if (isSegwit && getSegwit) {
      tx.writeSlice(Uint8List.fromList([0, 1]));
    }

    final inputCount = getGlobalInputCount();
    tx.writeVarInt(inputCount);

    for (var i = 0; i < inputCount; i++) {
      tx
        ..writeSlice(getInputPreviousTxid(i))
        ..writeUInt32(getInputOutputIndex(i))
        ..writeVarSlice(Uint8List(0))
        ..writeUInt32(getInputSequence(i));
    }

    final outputCount = getGlobalOutputCount();
    tx.writeVarInt(outputCount);
    for (var i = 0; i < outputCount; i++) {
      tx.writeUInt64(getOutputAmount(i));
      tx.writeVarSlice(getOutputScript(i));
    }
    tx.writeUInt32(getGlobalFallbackLocktime() ?? 0);
    return tx.buffer();
  }

  Future<void> signWithUTXO(List<UtxoWithPrivateKey> utxos, UTXOSignerCallBack signer, [UTXOGetterCallBack? getTaprootPair]) async {
    final raw = BytesUtils.toHexString(extractUnsignedTX(getSegwit: false));
    final tx = BtcTransaction.fromRaw(raw);

    /// when the transaction is taproot and we must use getTaproot transaction
    /// digest we need all of inputs amounts and owner script pub keys
    List<BigInt> taprootAmounts = [];
    List<Script> taprootScripts = [];

    if (utxos.any((e) => e.utxo.isP2tr())) {
      for (final input in tx.inputs) {
        final utxo = utxos.firstWhereOrNull(
            (u) => u.utxo.txHash == input.txId && u.utxo.vout == input.txIndex);

        if (utxo == null) {
          final trPair = await getTaprootPair!.call(input.txId, input.txIndex);
          taprootAmounts.add(trPair.value);
          taprootScripts.add(trPair.script);
          continue;
        }
        taprootAmounts.add(utxo.utxo.value);
        taprootScripts.add(_findLockingScript(utxo, true));
      }
    }

    for (var i = 0; i < tx.inputs.length; i++) {
      final utxo = utxos.firstWhereOrNull((e) => e.utxo.txHash == tx.inputs[i].txId && e.utxo.vout == tx.inputs[i].txIndex); // ToDo: More robust verify
      if (utxo == null) continue;
      /// We receive the owner's ScriptPubKey
      final script = _findLockingScript(utxo, false);

      final int sighash = utxo.utxo.isP2tr()
          ? BitcoinOpCodeConst.TAPROOT_SIGHASH_ALL
          : BitcoinOpCodeConst.SIGHASH_ALL;

      /// We generate transaction digest for current input
      final digest = _generateTransactionDigest(
          script, i, utxo.utxo, tx, taprootAmounts, taprootScripts);

      /// now we need sign the transaction digest
      final sig = signer(digest, utxo, utxo.privateKey, sighash);

      if (utxo.utxo.isP2tr()) {
        setInputTapKeySig(i, Uint8List.fromList(BytesUtils.fromHexString(sig)));
      } else {
        setInputPartialSig(i, Uint8List.fromList(BytesUtils.fromHexString(utxo.public().toHex())), Uint8List.fromList(BytesUtils.fromHexString(sig)));
      }
    }
  }

  List<int> _generateTransactionDigest(
      Script scriptPubKeys,
      int input,
      BitcoinUtxo utxo,
      BtcTransaction transaction,
      List<BigInt> taprootAmounts,
      List<Script> tapRootPubKeys) {
    if (utxo.isSegwit()) {
      if (utxo.isP2tr()) {
        return transaction.getTransactionTaprootDigset(
          txIndex: input,
          scriptPubKeys: tapRootPubKeys,
          amounts: taprootAmounts,
        );
      }
      return transaction.getTransactionSegwitDigit(
          txInIndex: input, script: scriptPubKeys, amount: utxo.value);
    }
    return transaction.getTransactionDigest(
        txInIndex: input, script: scriptPubKeys);
  }

  Script _findLockingScript(UtxoWithAddress utxo, bool isTaproot) {
    if (utxo.isMultiSig()) {
      throw Exception("MultiSig is not supported yet");
    }

    final senderPub = utxo.public();
    switch (utxo.utxo.scriptType) {
      case PubKeyAddressType.p2pk:
        return senderPub.toRedeemScript();
      case SegwitAddresType.p2wsh:
        if (isTaproot) {
          return senderPub.toP2wshAddress().toScriptPubKey();
        }
        return senderPub.toP2wshRedeemScript();
      case P2pkhAddressType.p2pkh:
        return senderPub.toP2pkhAddress().toScriptPubKey();
      case SegwitAddresType.p2wpkh:
        if (isTaproot) {
          return senderPub.toP2wpkhAddress().toScriptPubKey();
        }
        return senderPub.toP2pkhAddress().toScriptPubKey();
      case SegwitAddresType.p2tr:
        return senderPub
            .toTaprootAddress(tweak: utxo.utxo.isSilentPayment != true)
            .toScriptPubKey();
      case SegwitAddresType.mweb:
        return Script(script: []);
      case P2shAddressType.p2pkhInP2sh:
        if (isTaproot) {
          return senderPub.toP2pkhInP2sh().toScriptPubKey();
        }
        return senderPub.toP2pkhAddress().toScriptPubKey();
      case P2shAddressType.p2wpkhInP2sh:
        if (isTaproot) {
          return senderPub.toP2wpkhInP2sh().toScriptPubKey();
        }
        return senderPub.toP2pkhAddress().toScriptPubKey();
      case P2shAddressType.p2wshInP2sh:
        if (isTaproot) {
          return senderPub.toP2wshInP2sh().toScriptPubKey();
        }
        return senderPub.toP2wshRedeemScript();
      case P2shAddressType.p2pkInP2sh:
        if (isTaproot) {
          return senderPub.toP2pkInP2sh().toScriptPubKey();
        }
        return senderPub.toRedeemScript();
    }
    throw Exception("invalid bitcoin address type");
  }
}

typedef UTXOSignerCallBack = String Function(
    List<int> trDigest, UtxoWithAddress utxo, ECPrivate privateKey, int sighash);

typedef UTXOGetterCallBack = Future<
    TaprootAmountScriptPair> Function(String txId, int vout);

class TaprootAmountScriptPair {
  final BigInt value;
  final Script script;

  const TaprootAmountScriptPair(this.value, this.script);
}

class UtxoWithPrivateKey extends UtxoWithAddress {
  final ECPrivate privateKey;

  UtxoWithPrivateKey({
    required super.utxo,
    required super.ownerDetails,
    required this.privateKey,
  });

  static UtxoWithPrivateKey fromUtxo(UtxoWithAddress input, List<ECPrivateInfo> inputPrivateKeyInfos) {

    ECPrivateInfo? key;

    if (inputPrivateKeyInfos.isEmpty) {
      throw Exception("No private keys generated.");
    } else {
      key = inputPrivateKeyInfos.firstWhereOrNull((element) {
        final elemPubkey = element.privkey.getPublic().toHex();
        if (elemPubkey == input.public().toHex()) {
          return true;
        } else {
          return false;
        }
      });
    }

    if (key == null) {
      throw Exception("${input.utxo.txHash} No Key found");
    }

    return UtxoWithPrivateKey(
      utxo: input.utxo,
      ownerDetails: input.ownerDetails,
      privateKey: key.privkey
    );
  }

  static UtxoWithPrivateKey fromUnspent(BitcoinUnspent input, BitcoinWalletBase wallet) {
    final address = RegexUtils.addressTypeFromStr(
        input.address, BitcoinNetwork.mainnet);

    final newHd = input.bitcoinAddressRecord.isHidden
        ? wallet.sideHd
        : wallet.hd;

    ECPrivate privkey;
    if (input.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) {
      final unspentAddress = input
          .bitcoinAddressRecord as BitcoinSilentPaymentAddressRecord;
      privkey = wallet.walletAddresses.silentAddress!.b_spend.tweakAdd(
        BigintUtils.fromBytes(
          BytesUtils.fromHexString(unspentAddress.silentPaymentTweak!),
        ),
      );
    } else {
      privkey =
          generateECPrivate(hd: newHd,
              index: input.bitcoinAddressRecord.index,
              network: BitcoinNetwork.mainnet);
    }

    return UtxoWithPrivateKey(
          utxo: BitcoinUtxo(
            txHash: input.hash,
            value: BigInt.from(input.value),
            vout: input.vout,
            scriptType: input.bitcoinAddressRecord.type,
            isSilentPayment: input
                .bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord,
          ),
          ownerDetails: UtxoAddressDetails(
            publicKey: privkey.getPublic().toHex(),
            address: address,
          ),
          privateKey: privkey
      );
  }
}
