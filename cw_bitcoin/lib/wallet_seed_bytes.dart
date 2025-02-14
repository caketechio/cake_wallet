import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/seedbyte_types.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_info.dart';

// TODO: pass a list instead of checking every wallet open
class WalletSeedData {
  final Map<SeedBytesType, Bip32Slip10Secp256k1> hdWallets;

  WalletSeedData({required this.hdWallets});

  static Future<WalletSeedData> fromMnemonic(
    WalletInfo walletInfo,
    String mnemonic,
    BasedUtxoNetwork network, [
    String? passphrase,
  ]) async {
    final Map<SeedBytesType, Bip32Slip10Secp256k1> hdWallets = {};

    try {
      final bip39SeedBytes = Bip39SeedGenerator.generateFromString(mnemonic, passphrase);

      hdWallets[SeedBytesType.bip39] = Bip32Slip10Secp256k1.fromSeed(
        bip39SeedBytes,
        BitcoinAddressUtils.getKeyNetVersion(network),
      );
    } catch (e) {
      printV("bip39 seed error: $e");
    }

    List<int>? electrumSeedBytes;

    try {
      electrumSeedBytes = ElectrumV2SeedGenerator.generateFromString(mnemonic, passphrase);
    } catch (e) {
      printV("electrum_v2 seed error: $e");

      try {
        electrumSeedBytes = ElectrumV1SeedGenerator(mnemonic).generate();
      } catch (e) {
        printV("electrum_v1 seed error: $e");

        try {
          electrumSeedBytes = await mnemonicToSeedBytes(mnemonic, passphrase: passphrase ?? "");
        } catch (e) {
          printV("mnemonicToSeedBytes electrum seed error: $e");
        }
      }
    }

    if (electrumSeedBytes != null) {
      hdWallets[SeedBytesType.electrum] = Bip32Slip10Secp256k1.fromSeed(
        electrumSeedBytes,
        BitcoinAddressUtils.getKeyNetVersion(network),
      );
    }

    if (network == BitcoinNetwork.mainnet) {
      if (hdWallets[SeedBytesType.bip39] != null) {
        hdWallets[SeedBytesType.old_bip39] = hdWallets[SeedBytesType.bip39]!;
      }

      if (hdWallets[SeedBytesType.electrum] != null) {
        hdWallets[SeedBytesType.old_electrum] = hdWallets[SeedBytesType.electrum]!;
      }
    }

    return WalletSeedData(hdWallets: hdWallets);
  }

  static WalletSeedData fromXpub(WalletInfo walletInfo, String xpub, BasedUtxoNetwork network) {
    final Map<SeedBytesType, Bip32Slip10Secp256k1> hdWallets = {};

    try {
      hdWallets[SeedBytesType.bip39] = Bip32Slip10Secp256k1.fromExtendedKey(
        xpub,
        BitcoinAddressUtils.getKeyNetVersion(network),
      );
    } catch (_) {}

    try {
      hdWallets[SeedBytesType.electrum] = Bip32Slip10Secp256k1.fromExtendedKey(
        xpub,
        BitcoinAddressUtils.getKeyNetVersion(network),
      );
    } catch (_) {}

    if (hdWallets[SeedBytesType.bip39] != null) {
      hdWallets[SeedBytesType.old_bip39] = hdWallets[SeedBytesType.bip39]!;
    }

    if (hdWallets[SeedBytesType.electrum] != null) {
      hdWallets[SeedBytesType.old_electrum] = hdWallets[SeedBytesType.electrum]!;
    }

    return WalletSeedData(hdWallets: hdWallets);
  }
}
