import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/node.dart';
import 'package:cw_evm/evm_chain_transaction_model.dart';
import 'package:cw_evm/evm_chain_transaction_priority.dart';
import 'package:cw_evm/evm_erc20_balance.dart';
import 'package:cw_evm/pending_evm_chain_transaction.dart';
import 'package:cw_evm/.secrets.g.dart' as secrets;
import 'package:flutter/services.dart';
import 'package:hex/hex.dart' as hex;
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

import 'contract/erc20.dart';

abstract class EVMChainClient {
  final httpClient = Client();
  Web3Client? _client;

  //! To be overridden by all child classes

  int get chainId;

  Future<List<EVMChainTransactionModel>> fetchTransactions(String address,
      {String? contractAddress});

  Future<List<EVMChainTransactionModel>> fetchInternalTransactions(String address);

  Uint8List prepareSignedTransactionForSending(Uint8List signedTransaction);

  //! Common methods across all child classes

  bool connect(Node node) {
    try {
      _client = Web3Client(node.uri.toString(), httpClient);

      return true;
    } catch (e) {
      return false;
    }
  }

  void setListeners(EthereumAddress userAddress, Function() onNewTransaction) async {
    // _client?.pendingTransactions().listen((transactionHash) async {
    //   final transaction = await _client!.getTransactionByHash(transactionHash);
    //
    //   if (transaction.from.hex == userAddress || transaction.to?.hex == userAddress) {
    //     onNewTransaction();
    //   }
    // });
  }

  Future<EtherAmount> getBalance(EthereumAddress address) async {
    try {
      return await _client!.getBalance(address);
    } catch (_) {
      return EtherAmount.zero();
    }
  }

  Future<int> getGasUnitPrice() async {
    try {
      final gasPrice = await _client!.getGasPrice();
    
      return gasPrice.getInWei.toInt();
    } catch (_) {
      return 0;
    }
  }

  Future<int?> getGasBaseFee() async {
    try {
      final blockInfo = await _client!.getBlockInformation(isContainFullObj: false);
      final baseFee = blockInfo.baseFeePerGas;

      return baseFee?.getInWei.toInt();
    } catch (_) {
      return 0;
    }
  }

  Future<int> getEstimatedGas({
    String? contractAddress,
    required EthereumAddress toAddress,
    required EthereumAddress senderAddress,
    required EtherAmount value,
    EtherAmount? gasPrice,
    // EtherAmount? maxFeePerGas,
    // EtherAmount? maxPriorityFeePerGas,
  }) async {
    try {
      if (contractAddress == null) {
        final estimatedGas = await _client!.estimateGas(
          sender: senderAddress,
          gasPrice: gasPrice,
          to: toAddress,
          value: value,
          // maxPriorityFeePerGas: maxPriorityFeePerGas,
          // maxFeePerGas: maxFeePerGas,
        );

        return estimatedGas.toInt();
      } else {
        final contract = DeployedContract(
          ethereumContractAbi,
          EthereumAddress.fromHex(contractAddress),
        );

        final transfer = contract.function('transfer');

        // Estimate gas units
        final gasEstimate = await _client!.estimateGas(
          sender: senderAddress,
          to: EthereumAddress.fromHex(contractAddress),
          data: transfer.encodeCall([
            toAddress,
            value.getInWei,
          ]),
        );

        return gasEstimate.toInt();
      }
    } catch (_) {
      return 0;
    }
  }

  Future<PendingEVMChainTransaction> signTransaction({
    required Credentials privateKey,
    required String toAddress,
    required BigInt amount,
    required BigInt gas,
    required EVMChainTransactionPriority priority,
    required CryptoCurrency currency,
    required int exponent,
    String? contractAddress,
    String? memo,
    String? router,
    String? data,
  }) async {
    assert(currency == CryptoCurrency.eth ||
        currency == CryptoCurrency.maticpoly ||
        contractAddress != null);

    bool isNativeToken = currency == CryptoCurrency.eth || currency == CryptoCurrency.maticpoly;

    final gasPrice = await _client!.getGasPrice();
    final adjustedGasPrice = gasPrice.getInWei * BigInt.from(15) ~/ BigInt.from(10);

    if (!isNativeToken && router != null) {
      await _approveTokensIfNeeded(
        privateKey: privateKey,
        contractAddress: contractAddress!,
        amount: amount,
        router: router,
      );
    }

    final estimatedGasLimit = await _client!.estimateGas(
      sender: privateKey.address,
      to: EthereumAddress.fromHex(toAddress),
      value: isNativeToken ? EtherAmount.inWei(amount) : EtherAmount.zero(),
      data: data != null ? hexToBytes(data) : null,
    );

    final int gasLimit = estimatedGasLimit.toInt() < 80000 ? 80000 : estimatedGasLimit.toInt();

    final Transaction transaction = createTransaction(
      from: privateKey.address,
      to: EthereumAddress.fromHex(toAddress),
      maxPriorityFeePerGas: EtherAmount.fromInt(EtherUnit.gwei, priority.tip),
      amount: isNativeToken ? EtherAmount.inWei(amount) : EtherAmount.zero(),
      data: data != null ? hexToBytes(data) : null,
      maxGas: router != null && memo != null && isNativeToken ? gasLimit : null,
      gasPrice: router != null && memo != null && isNativeToken ? EtherAmount.inWei(adjustedGasPrice) : null,
    );

    Uint8List signedTransaction;

    if (isNativeToken) {
      signedTransaction = await _client!.signTransaction(privateKey, transaction, chainId: chainId);
    } else {
      final erc20 = ERC20(
        client: _client!,
        address: EthereumAddress.fromHex(contractAddress!),
        chainId: chainId,
      );

      signedTransaction = await erc20.transfer(
        EthereumAddress.fromHex(toAddress),
        amount,
        credentials: privateKey,
        transaction: transaction,
      );
    }

    final Function sendTransactionCallback;

    if (router != null && memo != null && !isNativeToken) {
      sendTransactionCallback = () async {
        await sendThorChainERC20TransactionCallback(
          privateKey: privateKey,
          contractAddress: contractAddress!,
          toAddress: toAddress,
          amount: amount,
          router: router,
          memo: memo,
        );
      };
    } else {
      sendTransactionCallback = () async => await sendTransaction(signedTransaction);
    }

    return PendingEVMChainTransaction(
      signedTransaction: signedTransaction,
      amount: amount.toString(),
      fee: gas,
      sendTransaction: sendTransactionCallback,
      exponent: exponent,
    );
  }

  Transaction createTransaction({
    required EthereumAddress from,
    required EthereumAddress to,
    required EtherAmount amount,
    EtherAmount? maxPriorityFeePerGas,
    Uint8List? data,
    int? maxGas,
    EtherAmount? gasPrice,
  }) {
    return Transaction(
      from: from,
      to: to,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      value: amount,
      data: data,
      maxGas: maxGas,
      gasPrice: gasPrice,
    );
  }

  Future<String> sendTransaction(Uint8List signedTransaction) async {
    return await _client!.sendRawTransaction(prepareSignedTransactionForSending(signedTransaction));
  }

  Future getTransactionDetails(String transactionHash) async {
    // Wait for the transaction receipt to become available
    TransactionReceipt? receipt;
    while (receipt == null) {
      receipt = await _client!.getTransactionReceipt(transactionHash);
      await Future.delayed(const Duration(seconds: 1));
    }

    // Print the receipt information
    log('Transaction Hash: ${receipt.transactionHash}');
    log('Block Hash: ${receipt.blockHash}');
    log('Block Number: ${receipt.blockNumber}');
    log('Gas Used: ${receipt.gasUsed}');

    /*
      Transaction Hash: [112, 244, 4, 238, 89, 199, 171, 191, 210, 236, 110, 42, 185, 202, 220, 21, 27, 132, 123, 221, 137, 90, 77, 13, 23, 43, 12, 230, 93, 63, 221, 116]
      I/flutter ( 4474): Block Hash: [149, 44, 250, 119, 111, 104, 82, 98, 17, 89, 30, 190, 25, 44, 218, 118, 127, 189, 241, 35, 213, 106, 25, 95, 195, 37, 55, 131, 185, 180, 246, 200]
      I/flutter ( 4474): Block Number: 17120242
      I/flutter ( 4474): Gas Used: 21000
    */

    // Wait for the transaction receipt to become available
    TransactionInformation? transactionInformation;
    while (transactionInformation == null) {
      log("********************************");
      transactionInformation = await _client!.getTransactionByHash(transactionHash);
      await Future.delayed(const Duration(seconds: 1));
    }
    // Print the receipt information
    log('Transaction Hash: ${transactionInformation.hash}');
    log('Block Hash: ${transactionInformation.blockHash}');
    log('Block Number: ${transactionInformation.blockNumber}');
    log('Gas Used: ${transactionInformation.gas}');

    /*
      Transaction Hash: 0x70f404ee59c7abbfd2ec6e2ab9cadc151b847bdd895a4d0d172b0ce65d3fdd74
      I/flutter ( 4474): Block Hash: 0x952cfa776f68526211591ebe192cda767fbdf123d56a195fc3253783b9b4f6c8
      I/flutter ( 4474): Block Number: 17120242
      I/flutter ( 4474): Gas Used: 53000
    */
  }

  Future<EVMChainERC20Balance> fetchERC20Balances(
      EthereumAddress userAddress, String contractAddress) async {
    final erc20 = ERC20(address: EthereumAddress.fromHex(contractAddress), client: _client!);
    final balance = await erc20.balanceOf(userAddress);

    int exponent = (await erc20.decimals()).toInt();

    return EVMChainERC20Balance(balance, exponent: exponent);
  }

  Future<Erc20Token?> getErc20Token(String contractAddress, String chainName) async {
    try {
      final uri = Uri.https(
        'deep-index.moralis.io',
        '/api/v2.2/erc20/metadata',
        {
          "chain": chainName,
          "addresses": contractAddress,
        },
      );

      final response = await httpClient.get(
        uri,
        headers: {
          "Accept": "application/json",
          "X-API-Key": secrets.moralisApiKey,
        },
      );

      final decodedResponse = jsonDecode(response.body)[0] as Map<String, dynamic>;

      final symbol = (decodedResponse['symbol'] ?? '') as String;
      String filteredSymbol = symbol.replaceFirst(RegExp('^\\\$'), '');

      final name = decodedResponse['name'] ?? '';
      final decimal = decodedResponse['decimals'] ?? '0';
      final iconPath = decodedResponse['logo'] ?? '';

      return Erc20Token(
        name: name,
        symbol: filteredSymbol,
        contractAddress: contractAddress,
        decimal: int.tryParse(decimal) ?? 0,
        iconPath: iconPath,
      );
    } catch (e) {
      try {
        final erc20 = ERC20(address: EthereumAddress.fromHex(contractAddress), client: _client!);
        final name = await erc20.name();
        final symbol = await erc20.symbol();
        final decimal = await erc20.decimals();

        return Erc20Token(
          name: name,
          symbol: symbol,
          contractAddress: contractAddress,
          decimal: decimal.toInt(),
        );
      } catch (_) {}

      return null;
    }
  }

  Uint8List hexToBytes(String hexString) {
    return Uint8List.fromList(
        hex.HEX.decode(hexString.startsWith('0x') ? hexString.substring(2) : hexString));
  }

  void stop() {
    _client?.dispose();
  }

  Web3Client? getWeb3Client() {
    return _client;
  }

  Future<void> _approveTokensIfNeeded({
    required Credentials privateKey,
    required String contractAddress,
    required BigInt amount,
    required String router,
  }) async {
    final erc20 = ERC20(
      client: _client!,
      address: EthereumAddress.fromHex(contractAddress),
      chainId: chainId,
    );

    final currentAllowance =
        await erc20.allowance(privateKey.address, EthereumAddress.fromHex(router));
    log('Current Allowance: $currentAllowance');

    if (currentAllowance < amount) {
      log('Approving more tokens...');

      final approvalTransaction = await erc20.approve(
        EthereumAddress.fromHex(router),
        amount,
        credentials: privateKey,
      );

      final txHash = await _client!.sendRawTransaction(approvalTransaction);

      var receipt = await getTransactionReceiptWithTimeout(txHash);

      if (receipt == null || receipt.status == false) {
        log('Approval transaction failed');
        throw Exception('Approval transaction failed');
      }
    }
  }

  Future<void> sendThorChainERC20TransactionCallback({
    required Credentials privateKey,
    required String contractAddress,
    required String toAddress,
    required BigInt amount,
    required String router,
    required String memo,
  }) async {
    return await _depositWithExpiry(
      privateKey: privateKey,
      contractAddress: router,
      inboundAddress: toAddress,
      amount: amount,
      memo: memo,
      assetContractAddress: contractAddress,
    );
  }

  Future<void> _depositWithExpiry({
    required Credentials privateKey,
    required String contractAddress,
    required String inboundAddress,
    String? assetContractAddress,
    required BigInt amount,
    required String memo,
  }) async {
    final contract = await _getContract(
      contractAbiPath: "assets/smart_contracts/thorchain_erc20_contract.json",
      contractName: "THORChain_Router",
      contractAddress: contractAddress,
    );
    final depositWithExpiryFunction = contract.function('depositWithExpiry');
    final inboundEthAddress = EthereumAddress.fromHex(inboundAddress);
    final assetEthAddress = EthereumAddress.fromHex(assetContractAddress!);
    final contractEthAddress = EthereumAddress.fromHex(contractAddress);
    final formattedDate =
        BigInt.from(DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000);

    try {
      final gasPrice = await _client!.getGasPrice();
      final feeHistory = await _client!.getFeeHistory(
        1,
        rewardPercentiles: [],
      );

      final baseFeePerGas = feeHistory['baseFeePerGas'].first as BigInt;

      final effectiveGasPrice = gasPrice.getInWei > baseFeePerGas
          ? gasPrice
          : EtherAmount.inWei(baseFeePerGas * BigInt.from(2));

      final gasLimit = await _client!.estimateGas(
        sender: privateKey.address,
        to: contractEthAddress,
        value: EtherAmount.zero(),
        data: depositWithExpiryFunction.encodeCall([
          inboundEthAddress,
          assetEthAddress,
          amount,
          memo,
          formattedDate,
        ]),
      );

      await _client!.sendTransaction(
        privateKey,
        Transaction.callContract(
          contract: contract,
          function: depositWithExpiryFunction,
          parameters: [
            inboundEthAddress,
            assetEthAddress,
            amount,
            memo,
            formattedDate,
          ],
          gasPrice: effectiveGasPrice,
          maxGas: gasLimit.toInt(),
        ),
        chainId: chainId,
      );
    } catch (e) {
      log("Error during depositWithExpiry: $e");
    }
  }

  Future<DeployedContract> _getContract({
    required String contractAbiPath,
    required String contractName,
    required String contractAddress,
  }) async {
    final String abi = await rootBundle.loadString(contractAbiPath);
    final contractAbi = ContractAbi.fromJson(abi, contractName);

    return DeployedContract(
      contractAbi,
      EthereumAddress.fromHex(contractAddress),
    );
  }

  Future<TransactionReceipt?> getTransactionReceiptWithTimeout(String txHash, {int timeoutSeconds = 60}) async {
    TransactionReceipt? receipt;
    final endTime = DateTime.now().add(Duration(seconds: timeoutSeconds));

    while (receipt == null && DateTime.now().isBefore(endTime)) {
      receipt = await _client!.getTransactionReceipt(txHash);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (receipt == null) {
      throw TimeoutException("Transaction receipt not found");
    }

    return receipt;
  }
}
