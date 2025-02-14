import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_core/receive_page_option.dart';

class BitcoinReceivePageOption implements ReceivePageOption {
  static const p2wpkh = BitcoinReceivePageOption._('Segwit (P2WPKH) (Default)');
  static const p2sh = BitcoinReceivePageOption._('Segwit-Compatible (P2SH)');
  static const p2tr = BitcoinReceivePageOption._('Taproot (P2TR)');
  static const p2wsh = BitcoinReceivePageOption._('Segwit-Script (P2WSH)');
  static const p2pkh = BitcoinReceivePageOption._('Legacy (P2PKH)');
  static const mweb = BitcoinReceivePageOption._('MWEB');

  static const silent_payments = BitcoinReceivePageOption._('Silent Payments');

  const BitcoinReceivePageOption._(this.value);

  final String value;

  String toString() {
    return value;
  }

  static const all = [
    BitcoinReceivePageOption.silent_payments,
    BitcoinReceivePageOption.p2wpkh,
    BitcoinReceivePageOption.p2tr,
    BitcoinReceivePageOption.p2wsh,
    BitcoinReceivePageOption.p2sh,
    BitcoinReceivePageOption.p2pkh
  ];

  static const allLitecoin = [
    BitcoinReceivePageOption.p2wpkh,
    BitcoinReceivePageOption.mweb,
  ];

  BitcoinAddressType toType() {
    switch (this) {
      case BitcoinReceivePageOption.p2tr:
        return SegwitAddressType.p2tr;
      case BitcoinReceivePageOption.p2wsh:
        return SegwitAddressType.p2wsh;
      case BitcoinReceivePageOption.p2pkh:
        return P2pkhAddressType.p2pkh;
      case BitcoinReceivePageOption.p2sh:
        return P2shAddressType.p2wpkhInP2sh;
      case BitcoinReceivePageOption.silent_payments:
        return SilentPaymentsAddresType.p2sp;
      case BitcoinReceivePageOption.mweb:
        return SegwitAddressType.mweb;
      case BitcoinReceivePageOption.p2wpkh:
      default:
        return SegwitAddressType.p2wpkh;
    }
  }

  factory BitcoinReceivePageOption.fromType(BitcoinAddressType type) {
    switch (type) {
      case SegwitAddressType.p2tr:
        return BitcoinReceivePageOption.p2tr;
      case SegwitAddressType.p2wsh:
        return BitcoinReceivePageOption.p2wsh;
      case SegwitAddressType.mweb:
        return BitcoinReceivePageOption.mweb;
      case P2pkhAddressType.p2pkh:
        return BitcoinReceivePageOption.p2pkh;
      case P2shAddressType.p2wpkhInP2sh:
        return BitcoinReceivePageOption.p2sh;
      case SilentPaymentsAddresType.p2sp:
        return BitcoinReceivePageOption.silent_payments;
      case SegwitAddressType.p2wpkh:
      default:
        return BitcoinReceivePageOption.p2wpkh;
    }
  }
}
