import 'dart:convert';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';

class ElectrumWalletSnapshot {
  ElectrumWalletSnapshot({
    required this.name,
    required this.type,
    required this.password,
    required this.mnemonic,
    required this.xpub,
    required this.balance,
    required this.unspentCoins,
    required this.walletAddressesSnapshot,
    this.passphrase,
    this.derivationType,
    this.derivationPath,
    this.didInitialSync,
  });

  final String name;
  final String password;
  final WalletType type;
  List<BitcoinUnspent> unspentCoins;

  @deprecated
  String? mnemonic;

  @deprecated
  String? xpub;

  @deprecated
  String? passphrase;

  ElectrumBalance balance;
  DerivationType? derivationType;
  String? derivationPath;
  bool? didInitialSync;

  Map<String, dynamic>? walletAddressesSnapshot;

  static Future<ElectrumWalletSnapshot> load(
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
    final mnemonic = data['mnemonic'] as String?;
    final xpub = data['xpub'] as String?;
    final passphrase = data['passphrase'] as String? ?? '';

    final balance = ElectrumBalance.fromJSON(data['balance'] as String?) ??
        ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);

    final derivationType = DerivationType
        .values[(data['derivationTypeIndex'] as int?) ?? DerivationType.electrum.index];
    // TODO: defaulting to electrum
    final derivationPath = data['derivationPath'] as String? ?? ELECTRUM_PATH;

    final walletAddressesSnapshot = data['walletAddresses'] as Map<String, dynamic>? ??
        ElectrumWalletAddressesBase.fromSnapshot(data);

    return ElectrumWalletSnapshot(
      name: name,
      type: type,
      password: password,
      passphrase: passphrase,
      mnemonic: mnemonic,
      xpub: xpub,
      balance: balance,
      derivationType: derivationType,
      derivationPath: derivationPath,
      unspentCoins: (data['unspent_coins'] as List?)
              ?.map((e) => BitcoinUnspent.fromJSON(
                    null,
                    e as Map<String, dynamic>,
                    walletInfo.derivationInfo!,
                    network,
                  ))
              .toList() ??
          [],
      didInitialSync: data['didInitialSync'] as bool?,
      walletAddressesSnapshot: walletAddressesSnapshot,
    );
  }
}
