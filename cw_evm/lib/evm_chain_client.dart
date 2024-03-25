import 'dart:async';
import 'dart:developer';

import 'package:cw_core/node.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/crypto_currency.dart';

import 'package:cw_evm/evm_erc20_balance.dart';
import 'package:cw_evm/evm_chain_transaction_model.dart';
import 'package:cw_evm/pending_evm_chain_transaction.dart';
import 'package:cw_evm/evm_chain_transaction_priority.dart';
import 'package:flutter/services.dart';

import 'package:http/http.dart';
import 'package:erc20/erc20.dart';
import 'package:web3dart/web3dart.dart';

abstract class EVMChainClient {
  Client httpClient = Client();
  Web3Client? _client;

  //! To be overridden by all child classes

  int get chainId;

  Future<List<EVMChainTransactionModel>> fetchTransactions(String address,
      {String? contractAddress});

  Uint8List prepareSignedTransactionForSending(Uint8List signedTransaction);

  //! Common methods across all child classes

  bool connect(Node node) {
    try {
      // re-initialize the client so any proxy wrapper settings take effect:
      httpClient = Client();
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

  Future<int> getEstimatedGas() async {
    try {
      final estimatedGas = await _client!.estimateGas();
      return estimatedGas.toInt();
    } catch (_) {
      return 0;
    }
  }

  Future<PendingEVMChainTransaction> signTransaction({
    required EthPrivateKey privateKey,
    required String toAddress,
    required String amount,
    required int gas,
    required EVMChainTransactionPriority priority,
    required CryptoCurrency currency,
    required int exponent,
    String? contractAddress,
  }) async {
    assert(currency == CryptoCurrency.eth ||
        currency == CryptoCurrency.maticpoly ||
        contractAddress != null);

    bool isEVMCompatibleChain =
        currency == CryptoCurrency.eth || currency == CryptoCurrency.maticpoly;

    final price = _client!.getGasPrice();

    final Transaction transaction = createTransaction(
      from: privateKey.address,
      to: EthereumAddress.fromHex(toAddress),
      maxPriorityFeePerGas: EtherAmount.fromInt(EtherUnit.gwei, priority.tip),
      amount: isEVMCompatibleChain ? EtherAmount.inWei(BigInt.parse(amount)) : EtherAmount.zero(),
    );

    final signedTransaction =
        await _client!.signTransaction(privateKey, transaction, chainId: chainId);

    final Function _sendTransaction;

    if (isEVMCompatibleChain) {
      _sendTransaction = () async => await sendTransaction(signedTransaction);
    } else {
      final erc20 = ERC20(
        client: _client!,
        address: EthereumAddress.fromHex(contractAddress!),
        chainId: chainId,
      );

      _sendTransaction = () async {
        await erc20.transfer(
          EthereumAddress.fromHex(toAddress),
          BigInt.parse(amount),
          credentials: privateKey,
          transaction: transaction,
        );
      };
    }

    return PendingEVMChainTransaction(
      signedTransaction: signedTransaction,
      amount: amount,
      fee: BigInt.from(gas) * (await price).getInWei,
      sendTransaction: _sendTransaction,
      exponent: exponent,
    );
  }

  Transaction createTransaction({
    required EthereumAddress from,
    required EthereumAddress to,
    required EtherAmount amount,
    EtherAmount? maxPriorityFeePerGas,
  }) {
    return Transaction(
      from: from,
      to: to,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      value: amount,
    );
  }

  Future<String> sendTransaction(Uint8List signedTransaction) async =>
      await _client!.sendRawTransaction(prepareSignedTransactionForSending(signedTransaction));

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

  Future<Erc20Token?> getErc20Token(String contractAddress) async {
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
    } catch (e) {
      return null;
    }
  }

  void stop() {
    _client?.dispose();
  }

  Web3Client? getWeb3Client() {
    return _client;
  }

// Future<int> _getDecimalPlacesForContract(DeployedContract contract) async {
//     final String abi = await rootBundle.loadString("assets/abi_json/erc20_abi.json");
//     final contractAbi = ContractAbi.fromJson(abi, "ERC20");
//
//     final contract = DeployedContract(
//       contractAbi,
//       EthereumAddress.fromHex(_erc20Currencies[erc20Currency]!),
//     );
//     final decimalsFunction = contract.function('decimals');
//     final decimals = await _client!.call(
//       contract: contract,
//       function: decimalsFunction,
//       params: [],
//     );
//
//     int exponent = int.parse(decimals.first.toString());
//     return exponent;
//   }
}
