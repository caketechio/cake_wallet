import 'dart:convert';

import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/currency_for_wallet_type.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_evm/evm_chain_transaction_history.dart';
import 'package:cw_evm/evm_chain_transaction_info.dart';
import 'package:cw_evm/evm_chain_transaction_model.dart';
import 'package:cw_evm/evm_chain_wallet.dart';
import 'package:cw_evm/evm_erc20_balance.dart';
import 'package:cw_evm/file.dart';
import 'package:cw_polygon/default_polygon_erc20_tokens.dart';
import 'package:cw_polygon/polygon_client.dart';
import 'package:cw_polygon/polygon_transaction_history.dart';

class PolygonWallet extends EVMChainWallet {
  PolygonWallet({
    required super.walletInfo,
    required super.password,
    super.mnemonic,
    super.initialBalance,
    super.privateKey,
    super.nativeCurrency = CryptoCurrency.maticpoly,
    required super.client,
  });

  @override
  Future<void> initErc20TokensBox() async {
    evmChainErc20TokensBox = await CakeHive.openBox<Erc20Token>(
      "${walletInfo.name.replaceAll(" ", "_")}_${Erc20Token.polygonBoxName}",
    );
  }

  @override
  void addInitialTokens() {
    final initialErc20Tokens = DefaultPolygonErc20Tokens().initialPolygonErc20Tokens;

    for (var token in initialErc20Tokens) {
      evmChainErc20TokensBox.put(token.contractAddress, token);
    }
  }

  @override
  Future<bool> checkIfScanProviderIsEnabled() async {
    bool isPolygonScanEnabled = (await sharedPrefs.future).getBool("use_polygonscan") ?? true;
    return isPolygonScanEnabled;
  }

  @override
  String getTransactionHistoryFileName() => 'polygon_transactions.json';

  @override
  Erc20Token createNewErc20TokenObject(Erc20Token token, String? iconPath) {
    return Erc20Token(
      name: token.name,
      symbol: token.symbol,
      contractAddress: token.contractAddress,
      decimal: token.decimal,
      enabled: token.enabled,
      tag: token.tag ?? "MATIC",
      iconPath: iconPath,
    );
  }

  @override
  EVMChainTransactionInfo getTransactionInfo(
      EVMChainTransactionModel transactionModel, String address) {
    final model = EVMChainTransactionInfo(
      id: transactionModel.hash,
      height: transactionModel.blockNumber,
      ethAmount: transactionModel.amount,
      direction: transactionModel.from == address
          ? TransactionDirection.outgoing
          : TransactionDirection.incoming,
      isPending: false,
      date: transactionModel.date,
      confirmations: transactionModel.confirmations,
      ethFee: BigInt.from(transactionModel.gasUsed) * transactionModel.gasPrice,
      exponent: transactionModel.tokenDecimal ?? 18,
      tokenSymbol: transactionModel.tokenSymbol ?? "MATIC",
      to: transactionModel.to,
    );
    return model;
  }

  @override
  EVMChainTransactionHistory setUpTransactionHistory(WalletInfo walletInfo, String password) {
    return PolygonTransactionHistory(walletInfo: walletInfo, password: password);
  }

  static Future<PolygonWallet> open(
      {required String name, required String password, required WalletInfo walletInfo}) async {
    final path = await pathForWallet(name: name, type: walletInfo.type);
    final jsonSource = await read(path: path, password: password);
    final data = json.decode(jsonSource) as Map;
    final mnemonic = data['mnemonic'] as String?;
    final privateKey = data['private_key'] as String?;
    final balance = EVMChainERC20Balance.fromJSON(data['balance'] as String) ??
        EVMChainERC20Balance(BigInt.zero);

    final nativeCurrency = currencyForWalletType(walletInfo.type);

    return PolygonWallet(
      walletInfo: walletInfo,
      password: password,
      mnemonic: mnemonic,
      privateKey: privateKey,
      initialBalance: balance,
      nativeCurrency: nativeCurrency,
      client: PolygonClient(),
    );
  }
}
