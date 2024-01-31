import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_ethereum/default_ethereum_erc20_tokens.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_ethereum/erc20_balance.dart';
import 'package:cw_ethereum/ethereum_client.dart';
import 'package:cw_ethereum/ethereum_exceptions.dart';
import 'package:cw_ethereum/ethereum_formatter.dart';
import 'package:cw_ethereum/ethereum_transaction_credentials.dart';
import 'package:cw_ethereum/ethereum_transaction_history.dart';
import 'package:cw_ethereum/ethereum_transaction_info.dart';
import 'package:cw_ethereum/ethereum_transaction_model.dart';
import 'package:cw_ethereum/ethereum_transaction_priority.dart';
import 'package:cw_ethereum/ethereum_wallet_addresses.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:hive/hive.dart';
import 'package:hex/hex.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;

part 'ethereum_wallet.g.dart';

class EthereumWallet = EthereumWalletBase with _$EthereumWallet;

abstract class EthereumWalletBase
    extends WalletBase<ERC20Balance, EthereumTransactionHistory, EthereumTransactionInfo>
    with Store {
  EthereumWalletBase({
    required WalletInfo walletInfo,
    String? mnemonic,
    String? privateKey,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
    ERC20Balance? initialBalance,
    required this.isFlatpak,
  })  : syncStatus = NotConnectedSyncStatus(),
        _password = password,
        _mnemonic = mnemonic,
        _hexPrivateKey = privateKey,
        _isTransactionUpdating = false,
        _encryptionFileUtils = encryptionFileUtils,
        _client = EthereumClient(),
        walletAddresses = EthereumWalletAddresses(walletInfo),
        balance = ObservableMap<CryptoCurrency, ERC20Balance>.of(
            {CryptoCurrency.eth: initialBalance ?? ERC20Balance(BigInt.zero)}),
        super(walletInfo) {
    this.walletInfo = walletInfo;
    transactionHistory = EthereumTransactionHistory(
      walletInfo: walletInfo,
      password: password,
      encryptionFileUtils: encryptionFileUtils,
      isFlatpak: isFlatpak,
    );

    if (!CakeHive.isAdapterRegistered(Erc20Token.typeId)) {
      CakeHive.registerAdapter(Erc20TokenAdapter());
    }

    _sharedPrefs.complete(SharedPreferences.getInstance());
  }

  final bool isFlatpak;

  final String? _mnemonic;
  final String? _hexPrivateKey;
  final String _password;

  final EncryptionFileUtils _encryptionFileUtils;

  late final Box<Erc20Token> erc20TokensBox;

  late final Box<Erc20Token> ethereumErc20TokensBox;

  late final EthPrivateKey _ethPrivateKey;

  EthPrivateKey get ethPrivateKey => _ethPrivateKey;

  late EthereumClient _client;

  int? _gasPrice;
  int? _estimatedGas;
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
  late ObservableMap<CryptoCurrency, ERC20Balance> balance;

  Completer<SharedPreferences> _sharedPrefs = Completer();

  Future<void> init() async {
    await movePreviousErc20BoxConfigsToNewBox();

    await walletAddresses.init();
    await transactionHistory.init();
    _ethPrivateKey = await getPrivateKey(
      mnemonic: _mnemonic,
      privateKey: _hexPrivateKey,
      password: _password,
    );
    walletAddresses.address = _ethPrivateKey.address.toString();
    await save();
  }

  /// Majorly for backward compatibility for previous configs that have been set.
  Future<void> movePreviousErc20BoxConfigsToNewBox() async {
    // Opens a box specific to this wallet
    ethereumErc20TokensBox = await CakeHive.openBox<Erc20Token>(
        "${walletInfo.name.replaceAll(" ", "_")}_${Erc20Token.ethereumBoxName}");

    //Open the previous token configs box
    erc20TokensBox = await CakeHive.openBox<Erc20Token>(Erc20Token.boxName);

    // Check if it's empty, if it is, we stop the flow and return.
    if (erc20TokensBox.isEmpty) {
      // If it's empty, but the new wallet specific box is also empty,
      // we load the initial tokens to the new box.
      if (ethereumErc20TokensBox.isEmpty) addInitialTokens();
      return;
    }

    final allValues = erc20TokensBox.values.toList();

    // Clear and delete the old token box
    await erc20TokensBox.clear();
    await erc20TokensBox.deleteFromDisk();

    // Add all the previous tokens with configs to the new box
    ethereumErc20TokensBox.addAll(allValues);
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int? amount) {
    try {
      if (priority is EthereumTransactionPriority) {
        final priorityFee = EtherAmount.fromInt(EtherUnit.gwei, priority.tip).getInWei.toInt();
        return (_gasPrice! + priorityFee) * (_estimatedGas ?? 0);
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
  void close() {
    _client.stop();
    _transactionsUpdateTimer?.cancel();
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    try {
      syncStatus = ConnectingSyncStatus();

      final isConnected = _client.connect(node);

      if (!isConnected) {
        throw Exception("Ethereum Node connection failed");
      }

      _client.setListeners(_ethPrivateKey.address, _onNewTransaction);

      _setTransactionUpdateTimer();

      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    final _credentials = credentials as EthereumTransactionCredentials;
    final outputs = _credentials.outputs;
    final hasMultiDestination = outputs.length > 1;

    final CryptoCurrency transactionCurrency =
        balance.keys.firstWhere((element) => element.title == _credentials.currency.title);

    final _erc20Balance = balance[transactionCurrency]!;
    BigInt totalAmount = BigInt.zero;
    int exponent = transactionCurrency is Erc20Token ? transactionCurrency.decimal : 18;
    num amountToEthereumMultiplier = pow(10, exponent);

    // so far this can not be made with Ethereum as Ethereum does not support multiple recipients
    if (hasMultiDestination) {
      if (outputs.any((item) => item.sendAll || (item.formattedCryptoAmount ?? 0) <= 0)) {
        throw EthereumTransactionCreationException(transactionCurrency);
      }

      final totalOriginalAmount = EthereumFormatter.parseEthereumAmountToDouble(
          outputs.fold(0, (acc, value) => acc + (value.formattedCryptoAmount ?? 0)));
      totalAmount = BigInt.from(totalOriginalAmount * amountToEthereumMultiplier);

      if (_erc20Balance.balance < totalAmount) {
        throw EthereumTransactionCreationException(transactionCurrency);
      }
    } else {
      final output = outputs.first;
      // since the fees are taken from Ethereum
      // then no need to subtract the fees from the amount if send all
      final BigInt allAmount;
      if (transactionCurrency is Erc20Token) {
        allAmount = _erc20Balance.balance;
      } else {
        allAmount = _erc20Balance.balance -
            BigInt.from(calculateEstimatedFee(_credentials.priority!, null));
      }
      final totalOriginalAmount =
          EthereumFormatter.parseEthereumAmountToDouble(output.formattedCryptoAmount ?? 0);
      totalAmount = output.sendAll
          ? allAmount
          : BigInt.from(totalOriginalAmount * amountToEthereumMultiplier);

      if (_erc20Balance.balance < totalAmount) {
        throw EthereumTransactionCreationException(transactionCurrency);
      }
    }

    final pendingEthereumTransaction = await _client.signTransaction(
      privateKey: _ethPrivateKey,
      toAddress: _credentials.outputs.first.isParsedAddress
          ? _credentials.outputs.first.extractedAddress!
          : _credentials.outputs.first.address,
      amount: totalAmount.toString(),
      gas: _estimatedGas!,
      priority: _credentials.priority!,
      currency: transactionCurrency,
      exponent: exponent,
      contractAddress:
          transactionCurrency is Erc20Token ? transactionCurrency.contractAddress : null,
    );

    return pendingEthereumTransaction;
  }

  Future<void> _updateTransactions() async {
    try {
      if (_isTransactionUpdating) {
        return;
      }
      bool isEtherscanEnabled = (await _sharedPrefs.future).getBool("use_etherscan") ?? true;
      if (!isEtherscanEnabled) {
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
  Future<Map<String, EthereumTransactionInfo>> fetchTransactions() async {
    final address = _ethPrivateKey.address.hex;
    final transactions = await _client.fetchTransactions(address);

    final List<Future<List<EthereumTransactionModel>>> erc20TokensTransactions = [];

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

    final Map<String, EthereumTransactionInfo> result = {};

    for (var transactionModel in transactions) {
      if (transactionModel.isError) {
        continue;
      }

      result[transactionModel.hash] = EthereumTransactionInfo(
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
        tokenSymbol: transactionModel.tokenSymbol ?? "ETH",
        to: transactionModel.to,
      );
    }

    return result;
  }

  @override
  Object get keys => throw UnimplementedError("keys");

  @override
  Future<void> rescan({required int height}) {
    throw UnimplementedError("rescan");
  }

  @override
  Future<void> save() async {
    await walletAddresses.updateAddressesInBox();
    final path = await makePath();
    await _encryptionFileUtils.write(path: path, password: _password, data: toJSON());
    await transactionHistory.save();
  }

  @override
  String? get seed => _mnemonic;

  @override
  String get privateKey => HEX.encode(_ethPrivateKey.privateKey);

  @action
  @override
  Future<void> startSync() async {
    try {
      syncStatus = AttemptingSyncStatus();
      await _updateBalance();
      await _updateTransactions();
      _gasPrice = await _client.getGasUnitPrice();
      _estimatedGas = await _client.getEstimatedGas();

      Timer.periodic(
          const Duration(minutes: 1), (timer) async => _gasPrice = await _client.getGasUnitPrice());
      Timer.periodic(const Duration(seconds: 10),
          (timer) async => _estimatedGas = await _client.getEstimatedGas());

      syncStatus = SyncedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  Future<String> makePath() async =>
      pathForWallet(name: walletInfo.name, type: walletInfo.type, isFlatpak: isFlatpak);

  String toJSON() => json.encode({
        'mnemonic': _mnemonic,
        'private_key': privateKey,
        'balance': balance[currency]!.toJSON(),
      });

  static Future<EthereumWallet> open({
    required String name,
    required String password,
    required WalletInfo walletInfo,
    required EncryptionFileUtils encryptionFileUtils,
    required bool isFlatpak,
  }) async {
    final path = await pathForWallet(name: name, type: walletInfo.type, isFlatpak: isFlatpak);
    final jsonSource = await encryptionFileUtils.read(path: path, password: password);
    final data = json.decode(jsonSource) as Map;
    final mnemonic = data['mnemonic'] as String?;
    final privateKey = data['private_key'] as String?;
    final balance = ERC20Balance.fromJSON(data['balance'] as String) ?? ERC20Balance(BigInt.zero);

    return EthereumWallet(
      walletInfo: walletInfo,
      password: password,
      mnemonic: mnemonic,
      privateKey: privateKey,
      initialBalance: balance,
      encryptionFileUtils: encryptionFileUtils,
      isFlatpak: isFlatpak,
    );
  }

  Future<void> _updateBalance() async {
    balance[currency] = await _fetchEthBalance();

    await _fetchErc20Balances();
    await save();
  }

  Future<ERC20Balance> _fetchEthBalance() async {
    final balance = await _client.getBalance(_ethPrivateKey.address);
    return ERC20Balance(balance.getInWei);
  }

  Future<void> _fetchErc20Balances() async {
    for (var token in ethereumErc20TokensBox.values) {
      try {
        if (token.enabled) {
          balance[token] = await _client.fetchERC20Balances(
            _ethPrivateKey.address,
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

    const _hdPathEthereum = "m/44'/60'/0'/0";
    const index = 0;
    final addressAtIndex = root.derivePath("$_hdPathEthereum/$index");

    return EthPrivateKey.fromHex(HEX.encode(addressAtIndex.privateKey as List<int>));
  }

  Future<void>? updateBalance() async => await _updateBalance();

  List<Erc20Token> get erc20Currencies => ethereumErc20TokensBox.values.toList();

  Future<void> addErc20Token(Erc20Token token) async {
    String? iconPath;
    try {
      iconPath = CryptoCurrency.all
          .firstWhere((element) => element.title.toUpperCase() == token.symbol.toUpperCase())
          .iconPath;
    } catch (_) {}

    final _token = Erc20Token(
      name: token.name,
      symbol: token.symbol,
      contractAddress: token.contractAddress,
      decimal: token.decimal,
      enabled: token.enabled,
      tag: token.tag ?? "ETH",
      iconPath: iconPath,
    );

    await ethereumErc20TokensBox.put(_token.contractAddress, _token);

    if (_token.enabled) {
      balance[_token] = await _client.fetchERC20Balances(
        _ethPrivateKey.address,
        _token.contractAddress,
      );
    } else {
      balance.remove(_token);
    }
  }

  Future<void> deleteErc20Token(Erc20Token token) async {
    await token.delete();

    balance.remove(token);
    _updateBalance();
  }

  Future<Erc20Token?> getErc20Token(String contractAddress) async =>
      await _client.getErc20Token(contractAddress);

  void _onNewTransaction() {
    _updateBalance();
    _updateTransactions();
  }

  void addInitialTokens() {
    final initialErc20Tokens = DefaultErc20Tokens().initialErc20Tokens;

    initialErc20Tokens.forEach((token) => ethereumErc20TokensBox.put(token.contractAddress, token));
  }

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    final currentWalletPath =
        await pathForWallet(name: walletInfo.name, type: type, isFlatpak: isFlatpak);
    final currentWalletFile = File(currentWalletPath);

    final currentDirPath =
        await pathForWalletDir(name: walletInfo.name, type: type, isFlatpak: isFlatpak);
    final currentTransactionsFile = File('$currentDirPath/$transactionsHistoryFileName');

    // Copies current wallet files into new wallet name's dir and files
    if (currentWalletFile.existsSync()) {
      final newWalletPath =
          await pathForWallet(name: newWalletName, type: type, isFlatpak: isFlatpak);
      await currentWalletFile.copy(newWalletPath);
    }
    if (currentTransactionsFile.existsSync()) {
      final newDirPath =
          await pathForWalletDir(name: newWalletName, type: type, isFlatpak: isFlatpak);
      await currentTransactionsFile.copy('$newDirPath/$transactionsHistoryFileName');
    }

    // Delete old name's dir and files
    await Directory(currentDirPath).delete(recursive: true);
  }

  void _setTransactionUpdateTimer() {
    if (_transactionsUpdateTimer?.isActive ?? false) {
      _transactionsUpdateTimer!.cancel();
    }

    _transactionsUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateTransactions();
      _updateBalance();
    });
  }

  void updateEtherscanUsageState(bool isEnabled) {
    if (isEnabled) {
      _updateTransactions();
      _setTransactionUpdateTimer();
    } else {
      _transactionsUpdateTimer?.cancel();
    }
  }

  @override
  String get password => _password;

  @override
  String signMessage(String message, {String? address}) =>
      bytesToHex(_ethPrivateKey.signPersonalMessageToUint8List(ascii.encode(message)));

  Web3Client? getWeb3Client() => _client.getWeb3Client();
}
