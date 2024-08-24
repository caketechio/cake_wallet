import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_evm/evm_chain_client.dart';
import 'package:cw_evm/evm_chain_exceptions.dart';
import 'package:cw_evm/evm_chain_formatter.dart';
import 'package:cw_evm/evm_chain_transaction_credentials.dart';
import 'package:cw_evm/evm_chain_transaction_history.dart';
import 'package:cw_evm/evm_chain_transaction_model.dart';
import 'package:cw_evm/evm_chain_transaction_priority.dart';
import 'package:cw_evm/evm_chain_wallet_addresses.dart';
import 'package:cw_evm/evm_ledger_credentials.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:eth_sig_util/eth_sig_util.dart';

import 'evm_chain_transaction_info.dart';
import 'evm_erc20_balance.dart';

part 'evm_chain_wallet.g.dart';

const Map<String, String> methodSignatureToType = {
  '0x095ea7b3': 'approval',
  '0xa9059cbb': 'transfer',
  '0x23b872dd': 'transferFrom',
  '0x574da717': 'transferOut',
  '0x2e1a7d4d': 'withdraw',
  '0x7ff36ab5': 'swapExactETHForTokens',
  '0x40c10f19': 'mint',
  '0x44bc937b': 'depositWithExpiry',
  '0xd0e30db0': 'deposit',
  '0xe8e33700': 'addLiquidity',
  '0xd505accf': 'permit',
};

abstract class EVMChainWallet = EVMChainWalletBase with _$EVMChainWallet;

abstract class EVMChainWalletBase
    extends WalletBase<EVMChainERC20Balance, EVMChainTransactionHistory, EVMChainTransactionInfo>
    with Store, WalletKeysFile {
  EVMChainWalletBase({
    required WalletInfo walletInfo,
    required EVMChainClient client,
    required CryptoCurrency nativeCurrency,
    String? mnemonic,
    String? privateKey,
    required String password,
    EVMChainERC20Balance? initialBalance,
    required this.encryptionFileUtils,
  })  : syncStatus = const NotConnectedSyncStatus(),
        _password = password,
        _mnemonic = mnemonic,
        _hexPrivateKey = privateKey,
        _isTransactionUpdating = false,
        _client = client,
        walletAddresses = EVMChainWalletAddresses(walletInfo),
        balance = ObservableMap<CryptoCurrency, EVMChainERC20Balance>.of(
          {
            // Not sure of this yet, will it work? will it not?
            nativeCurrency: initialBalance ?? EVMChainERC20Balance(BigInt.zero),
          },
        ),
        super(walletInfo) {
    this.walletInfo = walletInfo;
    transactionHistory = setUpTransactionHistory(walletInfo, password, encryptionFileUtils);

    if (!CakeHive.isAdapterRegistered(Erc20Token.typeId)) {
      CakeHive.registerAdapter(Erc20TokenAdapter());
    }

    sharedPrefs.complete(SharedPreferences.getInstance());
  }

  final String? _mnemonic;
  final String? _hexPrivateKey;
  final String _password;
  final EncryptionFileUtils encryptionFileUtils;

  late final Box<Erc20Token> erc20TokensBox;

  late final Box<Erc20Token> evmChainErc20TokensBox;

  late final Credentials _evmChainPrivateKey;

  Credentials get evmChainPrivateKey => _evmChainPrivateKey;

  late final EVMChainClient _client;

  int gasPrice = 0;
  int? gasBaseFee = 0;
  int estimatedGasUnits = 0;

  Timer? _updateFeesTimer;

  bool _isTransactionUpdating;

  // TODO: remove after integrating our own node and having eth_newPendingTransactionFilter
  Timer? _transactionsUpdateTimer;

  @override
  WalletAddresses walletAddresses;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  late ObservableMap<CryptoCurrency, EVMChainERC20Balance> balance;

  Completer<SharedPreferences> sharedPrefs = Completer();

  //! Methods to be overridden by every child

  void addInitialTokens();

  // Future<EVMChainWallet> open({
  //   required String name,
  //   required String password,
  //   required WalletInfo walletInfo,
  // });

  Future<void> initErc20TokensBox();

  String getTransactionHistoryFileName();

  Future<bool> checkIfScanProviderIsEnabled();

  EVMChainTransactionInfo getTransactionInfo(
      EVMChainTransactionModel transactionModel, String address);

  Erc20Token createNewErc20TokenObject(Erc20Token token, String? iconPath);

  EVMChainTransactionHistory setUpTransactionHistory(
    WalletInfo walletInfo,
    String password,
    EncryptionFileUtils encryptionFileUtils,
  );

  //! Common Methods across child classes

  String idFor(String name, WalletType type) => '${walletTypeToString(type).toLowerCase()}_$name';

  Future<void> init() async {
    await initErc20TokensBox();

    await walletAddresses.init();
    await transactionHistory.init();

    if (walletInfo.isHardwareWallet) {
      _evmChainPrivateKey = EvmLedgerCredentials(walletInfo.address);
      walletAddresses.address = walletInfo.address;
    } else {
      _evmChainPrivateKey = await getPrivateKey(
        mnemonic: _mnemonic,
        privateKey: _hexPrivateKey,
        password: _password,
      );
      walletAddresses.address = _evmChainPrivateKey.address.hexEip55;
    }
    await save();
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int? amount) {
    {
      try {
        if (priority is EVMChainTransactionPriority) {
          final priorityFee = EtherAmount.fromInt(EtherUnit.gwei, priority.tip).getInWei.toInt();

          int maxFeePerGas;
          if (gasBaseFee != null) {
            // MaxFeePerGas with EIP1559;
            maxFeePerGas = gasBaseFee! + priorityFee;
          } else {
            // MaxFeePerGas with gasPrice;
            maxFeePerGas = gasPrice;
            debugPrint('MaxFeePerGas with gasPrice: $maxFeePerGas');
          }

          final totalGasFee = estimatedGasUnits * maxFeePerGas;
          return totalGasFee;
        }

        return 0;
      } catch (e) {
        return 0;
      }
    }
  }

  /// Allows more customization to the fetch estimatedFees flow.
  ///
  /// We are able to pass in:
  /// - The exact amount the user wants to send,
  /// - The addressHex for the receiving wallet,
  /// - A contract address which would be essential in determining if to calcualate the estimate for ERC20 or native ETH
  Future<int> calculateActualEstimatedFeeForCreateTransaction({
    required amount,
    required String? contractAddress,
    required String receivingAddressHex,
    required TransactionPriority priority,
  }) async {
    try {
      if (priority is EVMChainTransactionPriority) {
        final priorityFee = EtherAmount.fromInt(EtherUnit.gwei, priority.tip).getInWei.toInt();

        int maxFeePerGas;
        if (gasBaseFee != null) {
          // MaxFeePerGas with EIP1559;
          maxFeePerGas = gasBaseFee! + priorityFee;
        } else {
          // MaxFeePerGas with gasPrice
          maxFeePerGas = gasPrice;
        }

        final estimatedGas = await _client.getEstimatedGas(
          contractAddress: contractAddress,
          senderAddress: _evmChainPrivateKey.address,
          value: EtherAmount.fromBigInt(EtherUnit.wei, amount!),
          gasPrice: EtherAmount.fromInt(EtherUnit.wei, gasPrice),
          toAddress: EthereumAddress.fromHex(receivingAddressHex),
          // maxFeePerGas: EtherAmount.fromInt(EtherUnit.wei, maxFeePerGas),
          // maxPriorityFeePerGas: EtherAmount.fromInt(EtherUnit.gwei, priority.tip),
        );

        final totalGasFee = estimatedGas * maxFeePerGas;
        return totalGasFee;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> changePassword(String password) {
    throw UnimplementedError("changePassword");
  }

  @override
  void close({bool? switchingToSameWalletType}) {
    _client.stop();
    _transactionsUpdateTimer?.cancel();
    _updateFeesTimer?.cancel();
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    try {
      syncStatus = ConnectingSyncStatus();

      final isConnected = _client.connect(node);

      if (!isConnected) {
        throw Exception("${walletInfo.type.name.toUpperCase()} Node connection failed");
      }

      _client.setListeners(_evmChainPrivateKey.address, _onNewTransaction);

      _setTransactionUpdateTimer();

      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  @action
  @override
  Future<void> startSync() async {
    try {
      syncStatus = AttemptingSyncStatus();
      await _updateBalance();
      await _updateTransactions();

      await _updateEstimatedGasFeeParams();

      _updateFeesTimer ??= Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _updateEstimatedGasFeeParams();
      });

      syncStatus = SyncedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  Future<void> _updateEstimatedGasFeeParams() async {
    gasBaseFee = await _client.getGasBaseFee();

    gasPrice = await _client.getGasUnitPrice();

    estimatedGasUnits = await _client.getEstimatedGas(
      senderAddress: _evmChainPrivateKey.address,
      toAddress: _evmChainPrivateKey.address,
      gasPrice: EtherAmount.fromInt(EtherUnit.wei, gasPrice),
      value: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.one),
    );
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    final _credentials = credentials as EVMChainTransactionCredentials;
    final outputs = _credentials.outputs;
    final hasMultiDestination = outputs.length > 1;

    final String? opReturnMemo = outputs.first.memo;

    String? hexOpReturnMemo;
    if (opReturnMemo != null) {
      hexOpReturnMemo =
          '0x${opReturnMemo.codeUnits.map((char) => char.toRadixString(16).padLeft(2, '0')).join()}';
    }

    final CryptoCurrency transactionCurrency =
        balance.keys.firstWhere((element) => element.title == _credentials.currency.title);

    final erc20Balance = balance[transactionCurrency]!;
    BigInt totalAmount = BigInt.zero;
    BigInt estimatedFeesForTransaction = BigInt.zero;
    int exponent = transactionCurrency is Erc20Token ? transactionCurrency.decimal : 18;
    num amountToEVMChainMultiplier = pow(10, exponent);
    String? contractAddress;
    String toAddress = _credentials.outputs.first.isParsedAddress
        ? _credentials.outputs.first.extractedAddress!
        : _credentials.outputs.first.address;

    if (transactionCurrency is Erc20Token) {
      contractAddress = transactionCurrency.contractAddress;
    }

    // so far this can not be made with Ethereum as Ethereum does not support multiple recipients
    if (hasMultiDestination) {
      if (outputs.any((item) => item.sendAll || (item.formattedCryptoAmount ?? 0) <= 0)) {
        throw EVMChainTransactionCreationException(transactionCurrency);
      }

      final totalOriginalAmount = EVMChainFormatter.parseEVMChainAmountToDouble(
          outputs.fold(0, (acc, value) => acc + (value.formattedCryptoAmount ?? 0)));
      totalAmount = BigInt.from(totalOriginalAmount * amountToEVMChainMultiplier);

      final estimateFees = await calculateActualEstimatedFeeForCreateTransaction(
        amount: totalAmount,
        receivingAddressHex: toAddress,
        priority: _credentials.priority!,
        contractAddress: contractAddress,
      );

      estimatedFeesForTransaction = BigInt.from(estimateFees);

      if (erc20Balance.balance < totalAmount) {
        throw EVMChainTransactionCreationException(transactionCurrency);
      }
    } else {
      final output = outputs.first;
      if (!output.sendAll) {
        final totalOriginalAmount =
            EVMChainFormatter.parseEVMChainAmountToDouble(output.formattedCryptoAmount ?? 0);

        totalAmount = BigInt.from(totalOriginalAmount * amountToEVMChainMultiplier);
      }

      if (output.sendAll && transactionCurrency is Erc20Token) {
        totalAmount = erc20Balance.balance;
      }

      final estimateFees = await calculateActualEstimatedFeeForCreateTransaction(
        amount: totalAmount,
        receivingAddressHex: toAddress,
        priority: _credentials.priority!,
        contractAddress: contractAddress,
      );

      estimatedFeesForTransaction = BigInt.from(estimateFees);

      if (output.sendAll && transactionCurrency is! Erc20Token) {
        totalAmount = (erc20Balance.balance - estimatedFeesForTransaction);

        if (estimatedFeesForTransaction > erc20Balance.balance) {
          throw EVMChainTransactionFeesException();
        }
      }

      if (erc20Balance.balance < totalAmount) {
        throw EVMChainTransactionCreationException(transactionCurrency);
      }
    }

    if (transactionCurrency is Erc20Token && isHardwareWallet) {
      await (_evmChainPrivateKey as EvmLedgerCredentials)
          .provideERC20Info(transactionCurrency.contractAddress, _client.chainId);
    }

    final pendingEVMChainTransaction = await _client.signTransaction(
      privateKey: _evmChainPrivateKey,
      toAddress: toAddress,
      amount: totalAmount,
      gas: estimatedFeesForTransaction,
      priority: _credentials.priority!,
      currency: transactionCurrency,
      exponent: exponent,
      contractAddress:
          transactionCurrency is Erc20Token ? transactionCurrency.contractAddress : null,
      data: hexOpReturnMemo,
    );

    return pendingEVMChainTransaction;
  }

  Future<void> _updateTransactions() async {
    try {
      if (_isTransactionUpdating) {
        return;
      }

      final isProviderEnabled = await checkIfScanProviderIsEnabled();

      if (!isProviderEnabled) {
        return;
      }

      _isTransactionUpdating = true;
      final transactions = await fetchTransactions();
      transactionHistory.addMany(transactions);
      await transactionHistory.save();
      _isTransactionUpdating = false;
    } catch (_) {
      _isTransactionUpdating = false;
    }
  }

  @override
  Future<Map<String, EVMChainTransactionInfo>> fetchTransactions() async {
    final List<EVMChainTransactionModel> transactions = [];
    final List<Future<List<EVMChainTransactionModel>>> erc20TokensTransactions = [];

    final address = _evmChainPrivateKey.address.hex;
    final externalTransactions = await _client.fetchTransactions(address);
    final internalTransactions = await _client.fetchInternalTransactions(address);

    for (var transaction in externalTransactions) {
      final evmSignatureName = analyzeTransaction(transaction.input);

      if (evmSignatureName != 'depositWithExpiry' && evmSignatureName != 'transfer') {
        transaction.evmSignatureName = evmSignatureName;
        transactions.add(transaction);
      }
    }

    for (var token in balance.keys) {
      if (token is Erc20Token) {
        erc20TokensTransactions.add(_client.fetchTransactions(
          address,
          contractAddress: token.contractAddress,
        ));
      }
    }

    final tokensTransaction = await Future.wait(erc20TokensTransactions);
    transactions.addAll(tokensTransaction.expand((element) => element));
    transactions.addAll(internalTransactions);

    final Map<String, EVMChainTransactionInfo> result = {};

    for (var transactionModel in transactions) {
      if (transactionModel.isError) {
        continue;
      }

      result[transactionModel.hash] = getTransactionInfo(transactionModel, address);
    }

    return result;
  }

  String? analyzeTransaction(String? transactionInput) {
    if (transactionInput == '0x' || transactionInput == null || transactionInput.isEmpty) {
      return 'simpleTransfer';
    }

    final methodSignature =
        transactionInput.length >= 10 ? transactionInput.substring(0, 10) : null;

    return methodSignatureToType[methodSignature];
  }

  @override
  Object get keys => throw UnimplementedError("keys");

  @override
  Future<void> rescan({required int height}) {
    throw UnimplementedError("rescan");
  }

  @override
  Future<void> save() async {
    if (!(await WalletKeysFile.hasKeysFile(walletInfo.name, walletInfo.type))) {
      await saveKeysFile(_password, encryptionFileUtils);
      saveKeysFile(_password, encryptionFileUtils, true);
    }

    await walletAddresses.updateAddressesInBox();
    final path = await makePath();
    await encryptionFileUtils.write(path: path, password: _password, data: toJSON());
    await transactionHistory.save();
  }

  @override
  String? get seed => _mnemonic;

  @override
  String? get privateKey => evmChainPrivateKey is EthPrivateKey
      ? HEX.encode((evmChainPrivateKey as EthPrivateKey).privateKey)
      : null;

  @override
  WalletKeysData get walletKeysData => WalletKeysData(mnemonic: _mnemonic, privateKey: privateKey);

  String toJSON() => json.encode({
        'mnemonic': _mnemonic,
        'private_key': privateKey,
        'balance': balance[currency]!.toJSON(),
      });

  Future<void> _updateBalance() async {
    balance[currency] = await _fetchEVMChainBalance();

    await _fetchErc20Balances();
    await save();
  }

  Future<EVMChainERC20Balance> _fetchEVMChainBalance() async {
    final balance = await _client.getBalance(_evmChainPrivateKey.address);
    return EVMChainERC20Balance(balance.getInWei);
  }

  Future<void> _fetchErc20Balances() async {
    for (var token in evmChainErc20TokensBox.values) {
      try {
        if (token.enabled) {
          balance[token] = await _client.fetchERC20Balances(
            _evmChainPrivateKey.address,
            token.contractAddress,
          );
        } else {
          balance.remove(token);
        }
      } catch (_) {}
    }
  }

  Future<EthPrivateKey> getPrivateKey(
      {String? mnemonic, String? privateKey, required String password}) async {
    assert(mnemonic != null || privateKey != null);

    if (privateKey != null) {
      return EthPrivateKey.fromHex(privateKey);
    }

    final seed = bip39.mnemonicToSeed(mnemonic!);

    final root = bip32.BIP32.fromSeed(seed);

    const hdPathEVMChain = "m/44'/60'/0'/0";
    const index = 0;
    final addressAtIndex = root.derivePath("$hdPathEVMChain/$index");

    return EthPrivateKey.fromHex(HEX.encode(addressAtIndex.privateKey as List<int>));
  }

  @override
  Future<void>? updateBalance() async => await _updateBalance();

  List<Erc20Token> get erc20Currencies => evmChainErc20TokensBox.values.toList();

  Future<void> addErc20Token(Erc20Token token) async {
    String? iconPath;

    if (token.iconPath == null || token.iconPath!.isEmpty) {
      try {
        iconPath = CryptoCurrency.all
            .firstWhere((element) => element.title.toUpperCase() == token.symbol.toUpperCase())
            .iconPath;
      } catch (_) {}
    } else {
      iconPath = token.iconPath;
    }

    final newToken = createNewErc20TokenObject(token, iconPath);

    await evmChainErc20TokensBox.put(newToken.contractAddress, newToken);

    if (newToken.enabled) {
      balance[newToken] = await _client.fetchERC20Balances(
        _evmChainPrivateKey.address,
        newToken.contractAddress,
      );
    } else {
      balance.remove(newToken);
    }
  }

  Future<void> deleteErc20Token(Erc20Token token) async {
    await token.delete();

    balance.remove(token);
    await removeTokenTransactionsInHistory(token);
    _updateBalance();
  }

  Future<void> removeTokenTransactionsInHistory(Erc20Token token) async {
    transactionHistory.transactions.removeWhere((key, value) => value.tokenSymbol == token.title);
    await transactionHistory.save();
  }

  Future<Erc20Token?> getErc20Token(String contractAddress, String chainName) async =>
      await _client.getErc20Token(contractAddress, chainName);

  void _onNewTransaction() {
    _updateBalance();
    _updateTransactions();
  }

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    final transactionHistoryFileNameForWallet = getTransactionHistoryFileName();

    final currentWalletPath = await pathForWallet(name: walletInfo.name, type: type);
    final currentWalletFile = File(currentWalletPath);

    final currentDirPath = await pathForWalletDir(name: walletInfo.name, type: type);
    final currentTransactionsFile = File('$currentDirPath/$transactionHistoryFileNameForWallet');

    // Copies current wallet files into new wallet name's dir and files
    if (currentWalletFile.existsSync()) {
      final newWalletPath = await pathForWallet(name: newWalletName, type: type);
      await currentWalletFile.copy(newWalletPath);
    }
    if (currentTransactionsFile.existsSync()) {
      final newDirPath = await pathForWalletDir(name: newWalletName, type: type);
      await currentTransactionsFile.copy('$newDirPath/$transactionHistoryFileNameForWallet');
    }

    // Delete old name's dir and files
    await Directory(currentDirPath).delete(recursive: true);
  }

  void _setTransactionUpdateTimer() {
    if (_transactionsUpdateTimer?.isActive ?? false) {
      _transactionsUpdateTimer!.cancel();
    }

    _transactionsUpdateTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _updateTransactions();
      _updateBalance();
    });
  }

  /// Scan Providers:
  ///
  /// EtherScan for Ethereum.
  ///
  /// PolygonScan for Polygon.
  void updateScanProviderUsageState(bool isEnabled) {
    if (isEnabled) {
      _updateTransactions();
      _setTransactionUpdateTimer();
    } else {
      _transactionsUpdateTimer?.cancel();
    }
  }

  @override
  Future<String> signMessage(String message, {String? address}) async {
    return bytesToHex(await _evmChainPrivateKey.signPersonalMessage(ascii.encode(message)));
  }

  @override
  Future<bool> verifyMessage(String message, String signature, {String? address}) async {
    if (address == null) {
      return false;
    }
    final recoveredAddress = EthSigUtil.recoverPersonalSignature(
      message: ascii.encode(message),
      signature: signature,
    );
    return recoveredAddress.toUpperCase() == address.toUpperCase();
  }

  Web3Client? getWeb3Client() => _client.getWeb3Client();

  @override
  String get password => _password;
}
