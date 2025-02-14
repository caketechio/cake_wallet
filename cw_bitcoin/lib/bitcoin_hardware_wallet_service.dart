import 'dart:async';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_core/hardware/hardware_account_data.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

class BitcoinHardwareWalletService {
  BitcoinHardwareWalletService(this.ledgerConnection);

  final LedgerConnection ledgerConnection;

  Future<List<HardwareAccountData>> getAvailableAccounts({int account = 0, int limit = 5}) async {
    final bitcoinLedgerApp = BitcoinLedgerApp(ledgerConnection);

    final masterFp = await bitcoinLedgerApp.getMasterFingerprint();

    final accounts = <HardwareAccountData>[];
    final accountRange = List.generate(limit, (i) => i + account);

    for (final i in accountRange) {
      final derivationPath = "m/84'/0'/$i'";
      final xpub = await bitcoinLedgerApp.getXPubKey(derivationPath: derivationPath);
      final changeKey = Bip32KeyIndex(0);
      final indexKey = Bip32KeyIndex(0);
      final hd = Bip32Slip10Secp256k1.fromExtendedKey(xpub).childKey(changeKey).childKey(indexKey);

      final address = hd.toECPublic().toP2wpkhAddress();

      accounts.add(HardwareAccountData(
        address: address.toAddress(BitcoinNetwork.mainnet),
        accountIndex: i,
        derivationPath: derivationPath,
        masterFingerprint: masterFp,
        xpub: xpub,
      ));
    }

    return accounts;
  }
}
