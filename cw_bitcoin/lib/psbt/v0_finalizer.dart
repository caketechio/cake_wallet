import "dart:typed_data";

import "package:ledger_bitcoin/src/psbt/constants.dart";
import "package:ledger_bitcoin/src/psbt/psbtv2.dart";
import "package:ledger_bitcoin/src/utils/buffer_writer.dart";

/// This roughly implements the "input finalizer" role of BIP370 (PSBTv2
/// https://github.com/bitcoin/bips/blob/master/bip-0370.mediawiki). However
/// the role is documented in BIP174 (PSBTv0
/// https://github.com/bitcoin/bips/blob/master/bip-0174.mediawiki).
///
/// Verify that all inputs have a signature, and set inputFinalScriptwitness
/// and/or inputFinalScriptSig depending on the type of the spent outputs. Clean
/// fields that aren't useful anymore, partial signatures, redeem script and
/// derivation paths.
///
/// @param psbt The psbt with all signatures added as partial sigs, either
/// through PSBT_IN_PARTIAL_SIG or PSBT_IN_TAP_KEY_SIG
extension InputFinalizer on PsbtV2 {
  void finalizeV0() {

    // First check that each input has a signature
    for (var i = 0; i < getGlobalInputCount(); i++) {
      if (_isFinalized(i)) continue;

      final legacyPubkeys = getInputKeyDatas(i, PSBTIn.partialSig);
      final taprootSig = getInputTapKeySig(i);
      if (legacyPubkeys.isEmpty && taprootSig == null) {
        continue;
        // throw Exception('No signature for input $i present');
      }
      if (legacyPubkeys.isNotEmpty) {
        if (legacyPubkeys.length > 1) {
          throw Exception(
              'Expected exactly one signature, got ${legacyPubkeys.length}');
        }
        if (taprootSig != null) {
          throw Exception('Both taproot and non-taproot signatures present.');
        }

        final isSegwitV0 = getInputWitnessUtxo(i) != null;
        final redeemScript = getInputRedeemScript(i);
        final isWrappedSegwit = redeemScript != null;
        final signature = getInputPartialSig(i, legacyPubkeys[0]);
        if (signature == null) {
          throw Exception('Expected partial signature for input $i');
        }
        if (isSegwitV0) {
          final witnessBuf = BufferWriter()
            ..writeVarInt(2)
            ..writeVarInt(signature.length)
            ..writeSlice(signature)
            ..writeVarInt(legacyPubkeys[0].length)
            ..writeSlice(legacyPubkeys[0]);
          setInputFinalScriptwitness(i, witnessBuf.buffer());
          if (isWrappedSegwit) {
            if (redeemScript.isEmpty) {
              throw Exception(
                  "Expected non-empty redeemscript. Can't finalize intput $i");
            }
            final scriptSigBuf = BufferWriter()
              ..writeUInt8(redeemScript.length) // Push redeemScript length
              ..writeSlice(redeemScript);
            setInputFinalScriptsig(i, scriptSigBuf.buffer());
          }
        } else {
          // Legacy input
          final scriptSig = BufferWriter();
          _writePush(scriptSig, signature);
          _writePush(scriptSig, legacyPubkeys[0]);
          setInputFinalScriptsig(i, scriptSig.buffer());
        }
      } else {
        // Taproot input
        final signature = getInputTapKeySig(i);
        if (signature == null) {
          throw Exception("No taproot signature found");
        }
        if (signature.length != 64 && signature.length != 65) {
          throw Exception("Unexpected length of schnorr signature.");
        }
        final witnessBuf = BufferWriter()
          ..writeVarInt(1)
          ..writeVarSlice(signature);
        setInputFinalScriptwitness(i, witnessBuf.buffer());
      }
      clearFinalizedInput(i);
    }
  }

  /// Deletes fields that are no longer neccesary from the psbt.
  ///
  /// Note, the spec doesn't say anything about removing ouput fields
  /// like PSBT_OUT_BIP32_DERIVATION_PATH and others, so we keep them
  /// without actually knowing why. I think we should remove them too.
  void clearFinalizedInput(int inputIndex) {
    final keyTypes = [
      PSBTIn.bip32Derivation,
      PSBTIn.partialSig,
      PSBTIn.tapBip32Derivation,
      PSBTIn.tapKeySig,
    ];
    final witnessUtxoAvailable = getInputWitnessUtxo(inputIndex) != null;
    final nonWitnessUtxoAvailable = getInputNonWitnessUtxo(inputIndex) != null;
    if (witnessUtxoAvailable && nonWitnessUtxoAvailable) {
      // Remove NON_WITNESS_UTXO for segwit v0 as it's only needed while signing.
      // Segwit v1 doesn't have NON_WITNESS_UTXO set.
      // See https://github.com/bitcoin/bips/blob/master/bip-0174.mediawiki#cite_note-7
      keyTypes.add(PSBTIn.nonWitnessUTXO);
    }
    deleteInputEntries(inputIndex, keyTypes);
  }

  /// Writes a script push operation to buf, which looks different
  /// depending on the size of the data. See
  /// https://en.bitcoin.it/wiki/Script#finalants
  ///
  /// [buf] the BufferWriter to write to
  /// [data] the Buffer to be pushed.
  void _writePush(BufferWriter buf, Uint8List data) {
    if (data.length <= 75) {
      buf.writeUInt8(data.length);
    } else if (data.length <= 256) {
      buf.writeUInt8(76);
      buf.writeUInt8(data.length);
    } else if (data.length <= 256 * 256) {
      buf.writeUInt8(77);
      final b = ByteData(2)..setUint16(0, data.length, Endian.little);
      buf.writeSlice(b.buffer.asUint8List());
    }
    buf.writeSlice(data);
  }

  bool _isFinalized(int i) {
    if (getInputFinalScriptsig(i) != null) return true;
    try {
      getInputFinalScriptwitness(i);
      return true;
    } catch (_) {
      return false;
    }
  }
}
