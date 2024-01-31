import 'dart:convert';

import 'package:bitbox/bitbox.dart' as bitbox;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/bitcoin_transaction_no_inputs_exception.dart';
import 'package:cw_bitcoin/bitcoin_transaction_priority.dart';
import 'package:cw_bitcoin/bitcoin_transaction_wrong_balance_exception.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_bitcoin_cash/src/pending_bitcoin_cash_transaction.dart';
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
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumBalance? initialBalance,
    int initialRegularAddressIndex = 0,
    int initialChangeAddressIndex = 0,
    required super.isFlatpak,
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
    walletAddresses = BitcoinCashWalletAddresses(walletInfo,
        electrumClient: electrumClient,
        initialAddresses: initialAddresses,
        initialRegularAddressIndex: initialRegularAddressIndex,
        initialChangeAddressIndex: initialChangeAddressIndex,
        mainHd: hd,
        sideHd: bitcoin.HDWallet.fromSeed(seedBytes).derivePath("m/44'/145'/0'/1"),
        networkType: networkType);
    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
    });
  }

  static Future<BitcoinCashWallet> create({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required EncryptionFileUtils encryptionFileUtils,
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumBalance? initialBalance,
    int initialRegularAddressIndex = 0,
    int initialChangeAddressIndex = 0,
    required bool isFlatpak,
  }) async {
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
      isFlatpak: isFlatpak,
    );
  }

  static Future<BitcoinCashWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
    required bool isFlatpak,
  }) async {
    final snp = await ElectrumWallletSnapshot.load(
        encryptionFileUtils, name, walletInfo.type, password, isFlatpak);
    return BitcoinCashWallet(
      mnemonic: snp.mnemonic,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: snp.addresses,
      initialBalance: snp.balance,
      seedBytes: await Mnemonic.toSeed(snp.mnemonic),
      encryptionFileUtils: encryptionFileUtils,
      initialRegularAddressIndex: snp.regularAddressIndex,
      initialChangeAddressIndex: snp.changeAddressIndex,
      isFlatpak: isFlatpak,
    );
  }

  @override
  Future<PendingBitcoinCashTransaction> createTransaction(Object credentials) async {
    const minAmount = 546;
    final transactionCredentials = credentials as BitcoinTransactionCredentials;
    final inputs = <BitcoinUnspent>[];
    final outputs = transactionCredentials.outputs;
    final hasMultiDestination = outputs.length > 1;

    var allInputsAmount = 0;

    if (unspentCoins.isEmpty) await updateUnspent();

    for (final utx in unspentCoins) {
      if (utx.isSending) {
        allInputsAmount += utx.value;
        inputs.add(utx);
      }
    }

    if (inputs.isEmpty) throw BitcoinTransactionNoInputsException();

    final allAmountFee = transactionCredentials.feeRate != null
        ? feeAmountWithFeeRate(transactionCredentials.feeRate!, inputs.length, outputs.length)
        : feeAmountForPriority(transactionCredentials.priority!, inputs.length, outputs.length);

    final allAmount = allInputsAmount - allAmountFee;

    var credentialsAmount = 0;
    var amount = 0;
    var fee = 0;

    if (hasMultiDestination) {
      if (outputs.any((item) => item.sendAll || item.formattedCryptoAmount! <= 0)) {
        throw BitcoinTransactionWrongBalanceException(currency);
      }

      credentialsAmount = outputs.fold(0, (acc, value) => acc + value.formattedCryptoAmount!);

      if (allAmount - credentialsAmount < minAmount) {
        throw BitcoinTransactionWrongBalanceException(currency);
      }

      amount = credentialsAmount;

      if (transactionCredentials.feeRate != null) {
        fee = calculateEstimatedFeeWithFeeRate(transactionCredentials.feeRate!, amount,
            outputsCount: outputs.length + 1);
      } else {
        fee = calculateEstimatedFee(transactionCredentials.priority, amount,
            outputsCount: outputs.length + 1);
      }
    } else {
      final output = outputs.first;
      credentialsAmount = !output.sendAll ? output.formattedCryptoAmount! : 0;

      if (credentialsAmount > allAmount) {
        throw BitcoinTransactionWrongBalanceException(currency);
      }

      amount = output.sendAll || allAmount - credentialsAmount < minAmount
          ? allAmount
          : credentialsAmount;

      if (output.sendAll || amount == allAmount) {
        fee = allAmountFee;
      } else if (transactionCredentials.feeRate != null) {
        fee = calculateEstimatedFeeWithFeeRate(transactionCredentials.feeRate!, amount);
      } else {
        fee = calculateEstimatedFee(transactionCredentials.priority, amount);
      }
    }

    if (fee == 0) {
      throw BitcoinTransactionWrongBalanceException(currency);
    }

    final totalAmount = amount + fee;

    if (totalAmount > balance[currency]!.confirmed || totalAmount > allInputsAmount) {
      throw BitcoinTransactionWrongBalanceException(currency);
    }
    final txb = bitbox.Bitbox.transactionBuilder(testnet: false);

    final changeAddress = await walletAddresses.getChangeAddress();
    var leftAmount = totalAmount;
    var totalInputAmount = 0;

    inputs.clear();

    for (final utx in unspentCoins) {
      if (utx.isSending) {
        leftAmount = leftAmount - utx.value;
        totalInputAmount += utx.value;
        inputs.add(utx);

        if (leftAmount <= 0) {
          break;
        }
      }
    }

    if (inputs.isEmpty) throw BitcoinTransactionNoInputsException();

    if (amount <= 0 || totalInputAmount < totalAmount) {
      throw BitcoinTransactionWrongBalanceException(currency);
    }

    inputs.forEach((input) {
      txb.addInput(input.hash, input.vout);
    });

    final String bchPrefix = "bitcoincash:";

    outputs.forEach((item) {
      final outputAmount = hasMultiDestination ? item.formattedCryptoAmount : amount;
      String outputAddress = item.isParsedAddress ? item.extractedAddress! : item.address;

      if (!outputAddress.startsWith(bchPrefix)) {
        outputAddress = "$bchPrefix$outputAddress";
      }

      bool isP2sh = outputAddress.startsWith("p", bchPrefix.length);

      if (isP2sh) {
        final p2sh = P2shAddress.fromAddress(
          address: outputAddress,
          network: BitcoinCashNetwork.mainnet,
        );

        txb.addOutput(Uint8List.fromList(p2sh.toScriptPubKey().toBytes()), outputAmount!);
        return;
      }

      txb.addOutput(outputAddress, outputAmount!);
    });

    final estimatedSize = bitbox.BitcoinCash.getByteCount(inputs.length, outputs.length + 1);

    var feeAmount = 0;

    if (transactionCredentials.feeRate != null) {
      feeAmount = transactionCredentials.feeRate! * estimatedSize;
    } else {
      feeAmount = feeRate(transactionCredentials.priority!) * estimatedSize;
    }

    final changeValue = totalInputAmount - amount - feeAmount;

    if (changeValue > minAmount) {
      txb.addOutput(changeAddress, changeValue);
    }

    for (var i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      final keyPair = generateKeyPair(
          hd: input.bitcoinAddressRecord.isHidden ? walletAddresses.sideHd : walletAddresses.mainHd,
          index: input.bitcoinAddressRecord.index);
      txb.sign(i, keyPair, input.value);
    }

    // Build the transaction
    final tx = txb.build();

    return PendingBitcoinCashTransaction(tx, type,
        electrumClient: electrumClient, amount: amount, fee: fee);
  }

  bitbox.ECPair generateKeyPair({required bitcoin.HDWallet hd, required int index}) =>
      bitbox.ECPair.fromWIF(hd.derive(index).wif!);

  @override
  int feeAmountForPriority(
          BitcoinTransactionPriority priority, int inputsCount, int outputsCount) =>
      feeRate(priority) * bitbox.BitcoinCash.getByteCount(inputsCount, outputsCount);

  int feeAmountWithFeeRate(int feeRate, int inputsCount, int outputsCount) =>
      feeRate * bitbox.BitcoinCash.getByteCount(inputsCount, outputsCount);

  int calculateEstimatedFeeWithFeeRate(int feeRate, int? amount, {int? outputsCount}) {
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
        ? walletAddresses.addresses
            .firstWhere((element) => element.address == AddressUtils.toLegacyAddress(address))
            .index
        : null;
    final HD = index == null ? hd : hd.derive(index);
    return base64Encode(HD.signMessage(message));
  }
}
