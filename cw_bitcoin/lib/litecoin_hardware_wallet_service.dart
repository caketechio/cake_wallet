import 'dart:async';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_core/hardware/hardware_account_data.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:ledger_litecoin/ledger_litecoin.dart';

class LitecoinHardwareWalletService {
  LitecoinHardwareWalletService(this.ledgerConnection);

  final LedgerConnection ledgerConnection;

  Future<List<HardwareAccountData>> getAvailableAccounts({int account = 0, int limit = 5}) async {
    final litecoinLedgerApp = LitecoinLedgerApp(ledgerConnection);

    await litecoinLedgerApp.getVersion();

    final accounts = <HardwareAccountData>[];
    final accountRange = List.generate(limit, (i) => i + account);
    final xpubVersion = Bip44Conf.litecoinMainNet.altKeyNetVer;

    for (final i in accountRange) {
      final derivationPath = "m/84'/2'/$i'";
      final xpub = await litecoinLedgerApp.getXPubKey(
          accountsDerivationPath: derivationPath,
          xPubVersion: int.parse(hex.encode(xpubVersion.public), radix: 16));
      final changeKey = Bip32KeyIndex(0);
      final indexKey = Bip32KeyIndex(0);
      final hd = Bip32Slip10Secp256k1.fromExtendedKey(xpub, xpubVersion)
          .childKey(changeKey)
          .childKey(indexKey);

      final address = hd.toECPublic().toP2wpkhAddress();

      accounts.add(HardwareAccountData(
        address: address.toAddress(LitecoinNetwork.mainnet),
        accountIndex: i,
        derivationPath: derivationPath,
        xpub: xpub,
      ));
    }

    return accounts;
  }
}
