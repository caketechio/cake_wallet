import 'dart:convert';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';

class LitecoinWalletSnapshot extends ElectrumWalletSnapshot {
  LitecoinWalletSnapshot({
    required super.name,
    required super.type,
    required super.password,
    required super.mnemonic,
    required super.xpub,
    required super.balance,
    required this.mwebAddresses,
    required this.alwaysScan,
    required super.unspentCoins,
    required super.walletAddressesSnapshot,
    super.passphrase,
    super.derivationType,
    super.derivationPath,
  }) : super();

  List<LitecoinMWEBAddressRecord> mwebAddresses;
  bool alwaysScan;

  static Future<LitecoinWalletSnapshot> load(
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

    final mwebAddressTmp = data['mweb_addresses'] as List? ?? <Object>[];
    final mwebAddresses = mwebAddressTmp
        .whereType<String>()
        .map((addr) => LitecoinMWEBAddressRecord.fromJSON(addr))
        .toList();
    final alwaysScan = data['alwaysScan'] as bool? ?? false;

    return LitecoinWalletSnapshot(
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
      mwebAddresses: mwebAddresses,
      alwaysScan: alwaysScan,
      walletAddressesSnapshot: electrumWalletSnapshot.walletAddressesSnapshot,
    );
  }
}
