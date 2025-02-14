import 'package:cw_core/enumerate.dart';
import 'package:bitcoin_base/bitcoin_base.dart' as btc_base;

class SeedBytesType implements Enumerate {
  static const old_electrum = SeedBytesType._('old_electrum');
  static const electrum = SeedBytesType._('electrum');
  static const old_bip39 = SeedBytesType._('old_bip39');
  static const bip39 = SeedBytesType._('bip39');
  static const mweb = SeedBytesType._('mweb');

  const SeedBytesType._(this.value);

  final String value;

  String toString() {
    return value;
  }

  static List<SeedBytesType> get values => [
        old_electrum,
        electrum,
        old_bip39,
        bip39,
        mweb,
      ];

  int get index => values.indexOf(this);

  bool get isElectrum => this == old_electrum || this == electrum;

  static SeedBytesType fromValue(String value) {
    switch (value) {
      case 'old_electrum':
        return SeedBytesType.old_electrum;
      case 'electrum':
        return SeedBytesType.electrum;
      case 'old_bip39':
        return SeedBytesType.old_bip39;
      case 'bip39':
        return SeedBytesType.bip39;
      case 'mweb':
        return SeedBytesType.mweb;
      default:
        throw Exception('Unknown derivation type');
    }
  }

  btc_base.BitcoinDerivationType toBitcoinDerivationType() {
    switch (this) {
      case SeedBytesType.old_electrum:
      case SeedBytesType.electrum:
        return btc_base.BitcoinDerivationType.electrum;
      case SeedBytesType.old_bip39:
      case SeedBytesType.bip39:
        return btc_base.BitcoinDerivationType.bip39;
      case SeedBytesType.mweb:
      default:
        throw Exception('Unknown derivation type');
    }
  }
}
