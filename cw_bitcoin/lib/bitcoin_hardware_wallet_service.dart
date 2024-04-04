import 'dart:async';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:cw_bitcoin/utils.dart';
import 'package:cw_core/hardware/hardware_account_data.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:ledger_flutter/ledger_flutter.dart';

class BitcoinHardwareWalletService {
  BitcoinHardwareWalletService(this.ledger, this.device);

  final Ledger ledger;
  final LedgerDevice device;

  Future<List<HardwareAccountData>> getAvailableAccounts({int index = 0, int limit = 5}) async {
    final bitcoinLedgerApp = BitcoinLedgerApp(ledger);

    final masterFp = await bitcoinLedgerApp.getMasterFingerprint(device);
    print(masterFp);

    final accounts = <HardwareAccountData>[];
    final indexRange = List.generate(limit, (i) => i + index);

    for (final i in indexRange) {
      final derivationPath = "m/84'/0'/$i'";
      final xpub = await bitcoinLedgerApp.getXPubKey(device, derivationPath: derivationPath);
      HDWallet hd = HDWallet.fromBase58(xpub).derive(0);
      HDWallet hd1 = HDWallet.fromBase58(xpub).derivePath("0");
      HDWallet hd2 = HDWallet.fromBase58(xpub).derive(1);

      print(xpub);
      print(hd.base58);
      print(hd1.base58);
      print(hd2.base58);
      print(generateP2WPKHAddress(hd: hd2, index: 0, network: BitcoinNetwork.mainnet)); //bc1qkq9jrlq9clx4n3h0l877ks46x33jlh36xdfh0p

      final address = generateP2WPKHAddress(hd: hd, index: 0, network: BitcoinNetwork.mainnet);

      final account = HardwareAccountData(
          address: address, accountIndex: i, masterFingerprint: masterFp, xpub: xpub);
      accounts.add(account);
    }

    return accounts;
  }
}
