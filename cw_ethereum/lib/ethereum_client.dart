import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cw_evm/evm_chain_client.dart';
import 'package:cw_evm/.secrets.g.dart' as secrets;
import 'package:cw_evm/evm_chain_transaction_model.dart';
import 'package:web3dart/web3dart.dart';

class EthereumClient extends EVMChainClient {
  @override
  int get chainId => 1;

  @override
  Uint8List prepareSignedTransactionForSending(Uint8List signedTransaction) =>
      prependTransactionType(0x02, signedTransaction);

  @override
  Future<List<EVMChainTransactionModel>> fetchTransactions(String address,
      {String? contractAddress}) async {
    try {
      final response = await client.get(Uri.https("api.etherscan.io", "/api", {
        "module": "account",
        "action": contractAddress != null ? "tokentx" : "txlist",
        if (contractAddress != null) "contractaddress": contractAddress,
        "address": address,
        "apikey": secrets.etherScanApiKey,
      }));

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      if (jsonResponse['result'] is String) {
        log(jsonResponse['result']);
        return [];
      }

      if (response.statusCode >= 200 && response.statusCode < 300 && jsonResponse['status'] != 0) {
        return (jsonResponse['result'] as List)
            .map((e) => EVMChainTransactionModel.fromJson(e as Map<String, dynamic>, 'ETH'))
            .toList();
      }

      return [];
    } catch (e) {
      log(e.toString());
      return [];
    }
  }

  @override
  Future<List<EVMChainTransactionModel>> fetchInternalTransactions(String address) async {
    try {
      final response = await client.get(Uri.https("api.etherscan.io", "/api", {
        "module": "account",
        "action": "txlistinternal",
        "address": address,
        "apikey": secrets.etherScanApiKey,
      }));

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300 && jsonResponse['status'] != 0) {
        return (jsonResponse['result'] as List)
            .map((e) => EVMChainTransactionModel.fromJson(e as Map<String, dynamic>, 'ETH'))
            .toList();
      }

      return [];
    } catch (e) {
      log(e.toString());
      return [];
    }
  }
}
