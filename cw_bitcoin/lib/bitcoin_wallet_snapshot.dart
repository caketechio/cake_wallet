import 'dart:convert';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';

class BitcoinWalletSnapshot extends ElectrumWalletSnapshot {
  BitcoinWalletSnapshot({
    required super.name,
    required super.type,
    required super.password,
    required super.mnemonic,
    required super.xpub,
    required super.balance,
    required this.alwaysScan,
    required super.unspentCoins,
    required super.walletAddressesSnapshot,
    super.passphrase,
    super.derivationType,
    super.derivationPath,
  }) : super();

  bool alwaysScan;

  static Future<BitcoinWalletSnapshot> load(
    EncryptionFileUtils encryptionFileUtils,
    String name,
    WalletInfo walletInfo,
    String password,
    BasedUtxoNetwork network,
  ) async {
    final type = walletInfo.type;
    final path = await pathForWallet(name: name, type: type);
    final jsonSource = await encryptionFileUtils.read(path: path, password: password);
    final data = json.decode(jsonSource) as Map;

    final ElectrumWalletSnapshot electrumWalletSnapshot = await ElectrumWalletSnapshot.load(
      encryptionFileUtils,
      name,
      walletInfo,
      password,
      network,
    );

    final alwaysScan = data['alwaysScan'] as bool? ?? false;

    final walletAddressesSnapshot = data['walletAddresses'] as Map<String, dynamic>? ??
        BitcoinWalletAddressesBase.fromSnapshot(data);

    return BitcoinWalletSnapshot(
      name: name,
      type: type,
      password: password,
      passphrase: electrumWalletSnapshot.passphrase,
      mnemonic: electrumWalletSnapshot.mnemonic,
      xpub: electrumWalletSnapshot.xpub,
      balance: electrumWalletSnapshot.balance,
      derivationType: electrumWalletSnapshot.derivationType,
      derivationPath: electrumWalletSnapshot.derivationPath,
      unspentCoins: electrumWalletSnapshot.unspentCoins,
      alwaysScan: alwaysScan,
      walletAddressesSnapshot: walletAddressesSnapshot,
    );
  }
}
