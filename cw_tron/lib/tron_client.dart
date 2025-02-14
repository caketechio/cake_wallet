import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/node.dart';
import 'package:cw_tron/pending_tron_transaction.dart';
import 'package:cw_tron/tron_abi.dart';
import 'package:cw_tron/tron_balance.dart';
import 'package:cw_tron/tron_http_provider.dart';
import 'package:cw_tron/tron_token.dart';
import 'package:cw_tron/tron_transaction_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import '.secrets.g.dart' as secrets;
import 'package:on_chain/on_chain.dart';

class TronClient {
  final httpClient = Client();
  TronProvider? _provider;
  // This is an internal tracker, so we don't have to "refetch".
  int _nativeTxEstimatedFee = 0;

  int get chainId => 1000;

  Future<List<TronTransactionModel>> fetchTransactions(String address,
      {String? contractAddress}) async {
    try {
      final response = await httpClient.get(
        Uri.https(
          "api.trongrid.io",
          "/v1/accounts/$address/transactions",
          {
            "only_confirmed": "true",
            "limit": "200",
          },
        ),
        headers: {
          'Content-Type': 'application/json',
          'TRON-PRO-API-KEY': secrets.tronGridApiKey,
        },
      );
      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          jsonResponse['status'] != false) {
        return (jsonResponse['data'] as List).map((e) {
          return TronTransactionModel.fromJson(e as Map<String, dynamic>);
        }).toList();
      }

      return [];
    } catch (e, s) {
      log('Error getting tx: ${e.toString()}\n ${s.toString()}');
      return [];
    }
  }

  Future<List<TronTRC20TransactionModel>> fetchTrc20ExcludedTransactions(String address) async {
    try {
      final response = await httpClient.get(
        Uri.https(
          "api.trongrid.io",
          "/v1/accounts/$address/transactions/trc20",
          {
            "only_confirmed": "true",
            "limit": "200",
          },
        ),
        headers: {
          'Content-Type': 'application/json',
          'TRON-PRO-API-KEY': secrets.tronGridApiKey,
        },
      );
      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          jsonResponse['status'] != false) {
        return (jsonResponse['data'] as List).map((e) {
          return TronTRC20TransactionModel.fromJson(e as Map<String, dynamic>);
        }).toList();
      }

      return [];
    } catch (e, s) {
      log('Error getting trc20 tx: ${e.toString()}\n ${s.toString()}');
      return [];
    }
  }

  bool connect(Node node) {
    try {
      final formattedUrl = '${node.isSSL ? 'https' : 'http'}://${node.uriRaw}';
      _provider = TronProvider(TronHTTPProvider(url: formattedUrl));

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<BigInt> getBalance(TronAddress address) async {
    try {
      final accountDetails = await _provider!.request(TronRequestGetAccount(address: address));

      return accountDetails?.balance ?? BigInt.zero;
    } catch (_) {
      return BigInt.zero;
    }
  }

  Future<int> getFeeLimit(
    TransactionRaw rawTransaction,
    TronAddress address,
    TronAddress receiverAddress, {
    int energyUsed = 0,
    bool isEstimatedFeeFlow = false,
  }) async {
    try {
      // Get the tron chain parameters.
      final chainParams = await _provider!.request(TronRequestGetChainParameters());

      final bandWidthInSun = chainParams.getTransactionFee!;
      log('BandWidth In Sun: $bandWidthInSun');

      final energyInSun = chainParams.getEnergyFee!;
      log('Energy In Sun: $energyInSun');

      final fakeTransaction = Transaction(
        rawData: rawTransaction,
        signature: [Uint8List(65)],
      );

      // Calculate the total size of the fake transaction, considering the required network overhead.
      final transactionSize = fakeTransaction.length + 64;

      // Assign the calculated size to the variable representing the required bandwidth.
      int neededBandWidth = transactionSize;
      log('Initial Needed Bandwidth: $neededBandWidth');

      int neededEnergy = energyUsed;
      log('Initial Needed Energy: $neededEnergy');

      // Fetch account resources to assess the available bandwidth and energy
      final accountResource =
          await _provider!.request(TronRequestGetAccountResource(address: address));

      neededEnergy -= accountResource.howManyEnergy.toInt();
      log('Account resource energy: ${accountResource.howManyEnergy.toInt()}');
      log('Needed Energy after deducting from account resource energy: $neededEnergy');

      // Deduct the bandwidth from the account's available bandwidth.
      final BigInt accountBandWidth = accountResource.howManyBandwIth;
      log('Account resource bandwidth: ${accountResource.howManyBandwIth.toInt()}');

      if (accountBandWidth >= BigInt.from(neededBandWidth) && !isEstimatedFeeFlow) {
        log('Account has more bandwidth than required');
        neededBandWidth = 0;
      }

      if (neededEnergy < 0) {
        neededEnergy = 0;
      }

      final energyBurn = neededEnergy * energyInSun.toInt();
      log('Energy Burn: $energyBurn');

      final bandWidthBurn = neededBandWidth * bandWidthInSun;
      log('Bandwidth Burn: $bandWidthBurn');

      int totalBurn = energyBurn + bandWidthBurn;
      log('Total Burn: $totalBurn');

      /// If there is a note (memo), calculate the memo fee.
      if (rawTransaction.data != null) {
        totalBurn += chainParams.getMemoFee!;
      }

      log('Final total burn: $totalBurn');

      return totalBurn;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getEstimatedFee(TronAddress ownerAddress) async {
    const constantAmount = '1000';
    // Fetch the latest Tron block
    final block = await _provider!.request(TronRequestGetNowBlock());

    // Create the transfer contract
    final contract = TransferContract(
      amount: TronHelper.toSun(constantAmount),
      ownerAddress: ownerAddress,
      toAddress: ownerAddress,
    );

    // Prepare the contract parameter for the transaction.
    final parameter = Any(typeUrl: contract.typeURL, value: contract);

    // Create a TransactionContract object with the contract type and parameter.
    final transactionContract =
        TransactionContract(type: contract.contractType, parameter: parameter);

    // Set the transaction expiration time (maximum 24 hours)
    final expireTime = DateTime.now().add(const Duration(minutes: 30));

    // Create a raw transaction
    TransactionRaw rawTransaction = TransactionRaw(
      refBlockBytes: block.blockHeader.rawData.refBlockBytes,
      refBlockHash: block.blockHeader.rawData.refBlockHash,
      expiration: BigInt.from(expireTime.millisecondsSinceEpoch),
      contract: [transactionContract],
      timestamp: block.blockHeader.rawData.timestamp,
    );

    final estimatedFee = await getFeeLimit(
      rawTransaction,
      ownerAddress,
      ownerAddress,
      isEstimatedFeeFlow: true,
    );

    _nativeTxEstimatedFee = estimatedFee;

    return estimatedFee;
  }

  Future<int> getTRCEstimatedFee(TronAddress ownerAddress) async {
    String contractAddress = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
    String constantAmount =
        '0'; // We're using 0 as the base amount here as we get an error when balance is zero i.e for new wallets.
    final contract = ContractABI.fromJson(trc20Abi);

    final function = contract.functionFromName("transfer");

    /// address /// amount
    final transferparams = [
      ownerAddress,
      TronHelper.toSun(constantAmount),
    ];

    final contractAddr = TronAddress(contractAddress);

    final request = await _provider!.request(
      TronRequestTriggerConstantContract(
        ownerAddress: ownerAddress,
        contractAddress: contractAddr,
        data: function.encodeHex(transferparams),
      ),
    );

    if (!request.isSuccess) {
      log("Tron TRC20 error: ${request.error} \n ${request.respose}");
    }

    final feeLimit = await getFeeLimit(
      request.transactionRaw!,
      ownerAddress,
      ownerAddress,
      energyUsed: request.energyUsed ?? 0,
      isEstimatedFeeFlow: true,
    );
    return feeLimit;
  }

  Future<PendingTronTransaction> signTransaction({
    required TronPrivateKey ownerPrivKey,
    required String toAddress,
    required String amount,
    required CryptoCurrency currency,
    required BigInt tronBalance,
    required bool sendAll,
  }) async {
    // Get the owner tron address from the key
    final ownerAddress = ownerPrivKey.publicKey().toAddress();

    // Define the receiving Tron address for the transaction.
    final receiverAddress = TronAddress(toAddress);

    bool isNativeTransaction = currency == CryptoCurrency.trx;

    String totalAmount;
    TransactionRaw rawTransaction;
    if (isNativeTransaction) {
      if (sendAll) {
        final accountResource =
            await _provider!.request(TronRequestGetAccountResource(address: ownerAddress));

        final availableBandWidth = accountResource.howManyBandwIth.toInt();

        // 269 is the current middle ground for bandwidth per transaction
        if (availableBandWidth >= 269) {
          totalAmount = amount;
        } else {
          final amountInSun = TronHelper.toSun(amount).toInt();

          // 5000 added here is a buffer since we're working with "estimated" value of the fee.
          final result = amountInSun - (_nativeTxEstimatedFee + 5000);

          totalAmount = TronHelper.fromSun(BigInt.from(result));
        }
      } else {
        totalAmount = amount;
      }
      rawTransaction = await _signNativeTransaction(
        ownerAddress,
        receiverAddress,
        totalAmount,
        tronBalance,
        sendAll,
      );
    } else {
      final tokenAddress = (currency as TronToken).contractAddress;
      totalAmount = amount;
      rawTransaction = await _signTrcTokenTransaction(
        ownerAddress,
        receiverAddress,
        totalAmount,
        tokenAddress,
        tronBalance,
      );
    }

    final signature = ownerPrivKey.sign(rawTransaction.toBuffer());

    sendTx() async => await sendTransaction(
          rawTransaction: rawTransaction,
          signature: signature,
        );

    return PendingTronTransaction(
      signedTransaction: signature,
      amount: totalAmount,
      fee: TronHelper.fromSun(rawTransaction.feeLimit ?? BigInt.zero),
      sendTransaction: sendTx,
    );
  }

  Future<TransactionRaw> _signNativeTransaction(
    TronAddress ownerAddress,
    TronAddress receiverAddress,
    String amount,
    BigInt tronBalance,
    bool sendAll,
  ) async {
    // This is introduce to server as a limit in cases where feeLimit is 0
    // The transaction signing will fail if the feeLimit is explicitly 0.
    int defaultFeeLimit = 269000;

    final block = await _provider!.request(TronRequestGetNowBlock());
    // Create the transfer contract
    final contract = TransferContract(
      amount: TronHelper.toSun(amount),
      ownerAddress: ownerAddress,
      toAddress: receiverAddress,
    );

    // Prepare the contract parameter for the transaction.
    final parameter = Any(typeUrl: contract.typeURL, value: contract);

    // Create a TransactionContract object with the contract type and parameter.
    final transactionContract =
        TransactionContract(type: contract.contractType, parameter: parameter);

    // Set the transaction expiration time (maximum 24 hours)
    final expireTime = DateTime.now().add(const Duration(minutes: 30));

    // Create a raw transaction
    TransactionRaw rawTransaction = TransactionRaw(
      refBlockBytes: block.blockHeader.rawData.refBlockBytes,
      refBlockHash: block.blockHeader.rawData.refBlockHash,
      expiration: BigInt.from(expireTime.millisecondsSinceEpoch),
      contract: [transactionContract],
      timestamp: block.blockHeader.rawData.timestamp,
    );

    final feeLimit = await getFeeLimit(rawTransaction, ownerAddress, receiverAddress);
    final feeLimitToUse = feeLimit != 0 ? feeLimit : defaultFeeLimit;
    final tronBalanceInt = tronBalance.toInt();

    if (feeLimit > tronBalanceInt) {
      final feeInTrx = TronHelper.fromSun(BigInt.parse(feeLimit.toString()));
      throw Exception(
        'You don\'t have enough TRX to cover the transaction fee for this transaction. Please top up.\nTransaction fee: $feeInTrx TRX',
      );
    }

    rawTransaction = rawTransaction.copyWith(
      feeLimit: BigInt.from(feeLimitToUse),
    );

    return rawTransaction;
  }

  Future<TransactionRaw> _signTrcTokenTransaction(
    TronAddress ownerAddress,
    TronAddress receiverAddress,
    String amount,
    String contractAddress,
    BigInt tronBalance,
  ) async {
    final contract = ContractABI.fromJson(trc20Abi);

    final function = contract.functionFromName("transfer");

    /// address /// amount
    final transferparams = [
      receiverAddress,
      TronHelper.toSun(amount),
    ];

    final contractAddr = TronAddress(contractAddress);

    final request = await _provider!.request(
      TronRequestTriggerConstantContract(
        ownerAddress: ownerAddress,
        contractAddress: contractAddr,
        data: function.encodeHex(transferparams),
      ),
    );

    if (!request.isSuccess) {
      log("Tron TRC20 error: ${request.error} \n ${request.respose}");
      throw Exception(
        'An error occured while creating the transfer request. Please try again.',
      );
    }

    final feeLimit = await getFeeLimit(
      request.transactionRaw!,
      ownerAddress,
      receiverAddress,
      energyUsed: request.energyUsed ?? 0,
    );

    final tronBalanceInt = tronBalance.toInt();

    if (feeLimit > tronBalanceInt) {
      final feeInTrx = TronHelper.fromSun(BigInt.parse(feeLimit.toString()));
      throw Exception(
        'You don\'t have enough TRX to cover the transaction fee for this transaction. Please top up. Transaction fee: $feeInTrx TRX',
      );
    }

    final rawTransaction = request.transactionRaw!.copyWith(
      feeLimit: BigInt.from(feeLimit),
    );

    return rawTransaction;
  }

  Future<String> sendTransaction({
    required TransactionRaw rawTransaction,
    required List<int> signature,
  }) async {
    try {
      final transaction = Transaction(rawData: rawTransaction, signature: [signature]);

      final raw = BytesUtils.toHexString(transaction.toBuffer());

      final txBroadcastResult = await _provider!.request(TronRequestBroadcastHex(transaction: raw));

      if (txBroadcastResult.isSuccess) {
        return txBroadcastResult.txId!;
      } else {
        throw Exception(txBroadcastResult.error);
      }
    } catch (e) {
      log('Send block Exception: ${e.toString()}');
      throw Exception(e);
    }
  }

  Future<TronBalance> fetchTronTokenBalances(String userAddress, String contractAddress) async {
    try {
      final ownerAddress = TronAddress(userAddress);

      final tokenAddress = TronAddress(contractAddress);

      final contract = ContractABI.fromJson(trc20Abi);

      final function = contract.functionFromName("balanceOf");

      final request = await _provider!.request(
        TronRequestTriggerConstantContract.fromMethod(
          ownerAddress: ownerAddress,
          contractAddress: tokenAddress,
          function: function,
          params: [ownerAddress],
        ),
      );

      final outputResult = request.outputResult?.first ?? BigInt.zero;

      return TronBalance(outputResult);
    } catch (_) {
      return TronBalance(BigInt.zero);
    }
  }

  Future<TronToken?> getTronToken(String contractAddress, String userAddress) async {
    try {
      final tokenAddress = TronAddress(contractAddress);

      final ownerAddress = TronAddress(userAddress);

      final contract = ContractABI.fromJson(trc20Abi);

      final name =
          (await getTokenDetail(contract, "name", ownerAddress, tokenAddress) as String?) ?? '';

      final symbol =
          (await getTokenDetail(contract, "symbol", ownerAddress, tokenAddress) as String?) ?? '';

      final decimal =
          (await getTokenDetail(contract, "decimals", ownerAddress, tokenAddress) as BigInt?) ??
              BigInt.zero;

      return TronToken(
        name: name,
        symbol: symbol,
        contractAddress: contractAddress,
        decimal: decimal.toInt(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> getTokenDetail(
    ContractABI contract,
    String functionName,
    TronAddress ownerAddress,
    TronAddress tokenAddress,
  ) async {
    final function = contract.functionFromName(functionName);

    try {
      final request = await _provider!.request(
        TronRequestTriggerConstantContract.fromMethod(
          ownerAddress: ownerAddress,
          contractAddress: tokenAddress,
          function: function,
          params: [],
        ),
      );

      final outputResult = request.outputResult?.first;

      return outputResult;
    } catch (_) {
      log('Erorr fetching detail: ${_.toString()}');

      return null;
    }
  }
}
