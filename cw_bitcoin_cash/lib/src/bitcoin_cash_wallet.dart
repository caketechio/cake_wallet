import 'dart:convert';

import 'package:bitbox/bitbox.dart' as bitbox;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_transaction_priority.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

import 'bitcoin_cash_base.dart';

part 'bitcoin_cash_wallet.g.dart';

class BitcoinCashWallet = BitcoinCashWalletBase with _$BitcoinCashWallet;

abstract class BitcoinCashWalletBase extends ElectrumWallet with Store {
  BitcoinCashWalletBase({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required Uint8List seedBytes,
    required EncryptionFileUtils encryptionFileUtils,
    BitcoinAddressType? addressPageType,
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
  }) : super(
            mnemonic: mnemonic,
            password: password,
            walletInfo: walletInfo,
            unspentCoinsInfo: unspentCoinsInfo,
            networkType: bitcoin.bitcoin,
            initialAddresses: initialAddresses,
            initialBalance: initialBalance,
            seedBytes: seedBytes,
            currency: CryptoCurrency.bch,
            encryptionFileUtils: encryptionFileUtils) {
    walletAddresses = BitcoinCashWalletAddresses(
      walletInfo,
      electrumClient: electrumClient,
      initialAddresses: initialAddresses,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      mainHd: hd,
      sideHd: bitcoin.HDWallet.fromSeed(seedBytes).derivePath("m/44'/145'/0'/1"),
      network: network,
      initialAddressPageType: addressPageType,
    );
    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
    });
  }

  static Future<BitcoinCashWallet> create(
      {required String mnemonic,
      required String password,
      required WalletInfo walletInfo,
      required Box<UnspentCoinsInfo> unspentCoinsInfo,
      required EncryptionFileUtils encryptionFileUtils,
      String? addressPageType,
      List<BitcoinAddressRecord>? initialAddresses,
      ElectrumBalance? initialBalance,
      Map<String, int>? initialRegularAddressIndex,
      Map<String, int>? initialChangeAddressIndex}) async {
    return BitcoinCashWallet(
      mnemonic: mnemonic,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: initialAddresses,
      initialBalance: initialBalance,
      seedBytes: await Mnemonic.toSeed(mnemonic),
      encryptionFileUtils: encryptionFileUtils,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      addressPageType: P2pkhAddressType.p2pkh,
    );
  }

  static Future<BitcoinCashWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final snp = await ElectrumWalletSnapshot.load(
        encryptionFileUtils, name, walletInfo.type, password, BitcoinCashNetwork.mainnet);
    return BitcoinCashWallet(
      mnemonic: snp.mnemonic,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: snp.addresses.map((addr) {
        try {
          BitcoinCashAddress(addr.address);
          return BitcoinAddressRecord(
            addr.address,
            index: addr.index,
            isHidden: addr.isHidden,
            type: P2pkhAddressType.p2pkh,
            network: BitcoinCashNetwork.mainnet,
          );
        } catch (_) {
          return BitcoinAddressRecord(
            AddressUtils.getCashAddrFormat(addr.address),
            index: addr.index,
            isHidden: addr.isHidden,
            type: P2pkhAddressType.p2pkh,
            network: BitcoinCashNetwork.mainnet,
          );
        }
      }).toList(),
      initialBalance: snp.balance,
      seedBytes: await Mnemonic.toSeed(snp.mnemonic),
      encryptionFileUtils: encryptionFileUtils,
      initialRegularAddressIndex: snp.regularAddressIndex,
      initialChangeAddressIndex: snp.changeAddressIndex,
      addressPageType: P2pkhAddressType.p2pkh,
    );
  }

  bitbox.ECPair generateKeyPair({required bitcoin.HDWallet hd, required int index}) =>
      bitbox.ECPair.fromWIF(hd.derive(index).wif!);

  int calculateEstimatedFeeWithFeeRate(int feeRate, int? amount, {int? outputsCount, int? size}) {
    int inputsCount = 0;
    int totalValue = 0;

    for (final input in unspentCoins) {
      if (input.isSending) {
        inputsCount++;
        totalValue += input.value;
      }
      if (amount != null && totalValue >= amount) {
        break;
      }
    }

    if (amount != null && totalValue < amount) return 0;

    final _outputsCount = outputsCount ?? (amount != null ? 2 : 1);

    return feeAmountWithFeeRate(feeRate, inputsCount, _outputsCount);
  }

  @override
  int feeRate(TransactionPriority priority) {
    if (priority is BitcoinCashTransactionPriority) {
      switch (priority) {
        case BitcoinCashTransactionPriority.slow:
          return 1;
        case BitcoinCashTransactionPriority.medium:
          return 5;
        case BitcoinCashTransactionPriority.fast:
          return 10;
      }
    }

    return 0;
  }

  @override
  String signMessage(String message, {String? address = null}) {
    final index = address != null
        ? walletAddresses.allAddresses
            .firstWhere((element) => element.address == AddressUtils.toLegacyAddress(address))
            .index
        : null;
    final HD = index == null ? hd : hd.derive(index);
    return base64Encode(HD.signMessage(message));
  }
}
