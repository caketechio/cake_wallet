import 'package:bitcoin_base/bitcoin_base.dart';

String addressFromOutputScript(Script script, BasedUtxoNetwork network) {
  try {
    return addressFromScript(script, network).toAddress(network);
  } catch (_) {}

  return '';
}

BitcoinBaseAddress addressFromScript(Script script, [BasedUtxoNetwork network = BitcoinNetwork.mainnet]) {
  final addressType = script.getAddressType();
  if (addressType == null) {
    throw ArgumentError("Invalid script");
  }

  switch (addressType) {
    case P2pkhAddressType.p2pkh:
      return P2pkhAddress.fromScriptPubkey(
          script: script, network: BitcoinNetwork.mainnet);
    case P2shAddressType.p2pkhInP2sh:
      return P2shAddress.fromScriptPubkey(
          script: script, network: BitcoinNetwork.mainnet);
    case SegwitAddresType.p2wpkh:
      return P2wpkhAddress.fromScriptPubkey(
          script: script, network: BitcoinNetwork.mainnet);
    case SegwitAddresType.p2wsh:
      return P2wshAddress.fromScriptPubkey(
          script: script, network: BitcoinNetwork.mainnet);
    case SegwitAddresType.p2tr:
      return P2trAddress.fromScriptPubkey(
          script: script, network: BitcoinNetwork.mainnet);
  }

  throw ArgumentError("Invalid script");
}
