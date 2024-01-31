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
import 'package:cw_ethereum/erc20_balance.dart';
import 'package:cw_ethereum/ethereum_formatter.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_polygon/default_polygon_erc20_tokens.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_polygon/polygon_client.dart';
import 'package:cw_polygon/polygon_exceptions.dart';
import 'package:cw_polygon/polygon_formatter.dart';
import 'package:cw_polygon/polygon_transaction_credentials.dart';
import 'package:cw_polygon/polygon_transaction_history.dart';
import 'package:cw_polygon/polygon_transaction_info.dart';
import 'package:cw_polygon/polygon_transaction_model.dart';
import 'package:cw_polygon/polygon_transaction_priority.dart';
import 'package:cw_polygon/polygon_wallet_addresses.dart';
import 'package:hive/hive.dart';
import 'package:hex/hex.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;

part 'polygon_wallet.g.dart';

class PolygonWallet = PolygonWalletBase with _$PolygonWallet;

abstract class PolygonWalletBase
    extends WalletBase<ERC20Balance, PolygonTransactionHistory, PolygonTransactionInfo> with Store {
  PolygonWalletBase({
    required WalletInfo walletInfo,
    String? mnemonic,
    String? privateKey,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
    ERC20Balance? initialBalance,
    required this.isFlatpak,
  })  : syncStatus = const NotConnectedSyncStatus(),
        _password = password,
        _mnemonic = mnemonic,
        _hexPrivateKey = privateKey,
        _isTransactionUpdating = false,
        _encryptionFileUtils = encryptionFileUtils,
        _client = PolygonClient(),
        walletAddresses = PolygonWalletAddresses(walletInfo),
        balance = ObservableMap<CryptoCurrency, ERC20Balance>.of(
            {CryptoCurrency.maticpoly: initialBalance ?? ERC20Balance(BigInt.zero)}),
        super(walletInfo) {
    this.walletInfo = walletInfo;
    transactionHistory =
        PolygonTransactionHistory(walletInfo: walletInfo, password: password, isFlatpak: isFlatpak);

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

  late final Box<Erc20Token> polygonErc20TokensBox;

  late final EthPrivateKey _polygonPrivateKey;

  late final PolygonClient _client;

  EthPrivateKey get polygonPrivateKey => _polygonPrivateKey;

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

  final Completer<SharedPreferences> _sharedPrefs = Completer();

  Future<void> init() async {
    final boxName = "${walletInfo.name.replaceAll(" ", "_")}_ ${Erc20Token.polygonBoxName}";
    if (await CakeHive.boxExists(boxName)) {
      polygonErc20TokensBox = await CakeHive.openBox<Erc20Token>(boxName);
    } else {
      polygonErc20TokensBox = await CakeHive.openBox<Erc20Token>(boxName.replaceAll(" ", ""));
    }
    await walletAddresses.init();
    await transactionHistory.init();
    _polygonPrivateKey = await getPrivateKey(
      mnemonic: _mnemonic,
      privateKey: _hexPrivateKey,
      password: _password,
    );
    walletAddresses.address = _polygonPrivateKey.address.toString();
    await save();
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int? amount) {
    try {
      if (priority is PolygonTransactionPriority) {
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
        throw Exception("Polygon Node connection failed");
      }

      _client.setListeners(_polygonPrivateKey.address, _onNewTransaction);

      _setTransactionUpdateTimer();

      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    final credentials0 = credentials as PolygonTransactionCredentials;
    final outputs = credentials0.outputs;
    final hasMultiDestination = outputs.length > 1;

    final CryptoCurrency transactionCurrency =
        balance.keys.firstWhere((element) => element.title == credentials0.currency.title);

    final erc20Balance = balance[transactionCurrency]!;
    BigInt totalAmount = BigInt.zero;
    int exponent = transactionCurrency is Erc20Token ? transactionCurrency.decimal : 18;
    num amountToPolygonMultiplier = pow(10, exponent);

    // so far this can not be made with Polygon as Polygon does not support multiple recipients
    if (hasMultiDestination) {
      if (outputs.any((item) => item.sendAll || (item.formattedCryptoAmount ?? 0) <= 0)) {
        throw PolygonTransactionCreationException(transactionCurrency);
      }

      final totalOriginalAmount = PolygonFormatter.parsePolygonAmountToDouble(
          outputs.fold(0, (acc, value) => acc + (value.formattedCryptoAmount ?? 0)));
      totalAmount = BigInt.from(totalOriginalAmount * amountToPolygonMultiplier);

      if (erc20Balance.balance < totalAmount) {
        throw PolygonTransactionCreationException(transactionCurrency);
      }
    } else {
      final output = outputs.first;
      // since the fees are taken from Ethereum
      // then no need to subtract the fees from the amount if send all
      final BigInt allAmount;
      if (transactionCurrency is Erc20Token) {
        allAmount = erc20Balance.balance;
      } else {
        allAmount =
            erc20Balance.balance - BigInt.from(calculateEstimatedFee(credentials0.priority!, null));
      }
      final totalOriginalAmount =
          EthereumFormatter.parseEthereumAmountToDouble(output.formattedCryptoAmount ?? 0);
      totalAmount =
          output.sendAll ? allAmount : BigInt.from(totalOriginalAmount * amountToPolygonMultiplier);

      if (erc20Balance.balance < totalAmount) {
        throw PolygonTransactionCreationException(transactionCurrency);
      }
    }

    final pendingPolygonTransaction = await _client.signTransaction(
      privateKey: _polygonPrivateKey,
      toAddress: credentials0.outputs.first.isParsedAddress
          ? credentials0.outputs.first.extractedAddress!
          : credentials0.outputs.first.address,
      amount: totalAmount.toString(),
      gas: _estimatedGas!,
      priority: credentials0.priority!,
      currency: transactionCurrency,
      exponent: exponent,
      contractAddress:
          transactionCurrency is Erc20Token ? transactionCurrency.contractAddress : null,
    );

    return pendingPolygonTransaction;
  }

  Future<void> _updateTransactions() async {
    try {
      if (_isTransactionUpdating) {
        return;
      }
      bool isPolygonScanEnabled = (await _sharedPrefs.future).getBool("use_polygonscan") ?? true;
      if (!isPolygonScanEnabled) {
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
  Future<Map<String, PolygonTransactionInfo>> fetchTransactions() async {
    final address = _polygonPrivateKey.address.hex;
    final transactions = await _client.fetchTransactions(address);

    final List<Future<List<PolygonTransactionModel>>> polygonErc20TokensTransactions = [];

    for (var token in balance.keys) {
      if (token is Erc20Token) {
        polygonErc20TokensTransactions.add(
          _client.fetchTransactions(
            address,
            contractAddress: token.contractAddress,
          ),
        );
      }
    }

    final tokensTransaction = await Future.wait(polygonErc20TokensTransactions);
    transactions.addAll(tokensTransaction.expand((element) => element));

    final Map<String, PolygonTransactionInfo> result = {};

    for (var transactionModel in transactions) {
      if (transactionModel.isError) {
        continue;
      }

      result[transactionModel.hash] = PolygonTransactionInfo(
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
  String get privateKey => HEX.encode(_polygonPrivateKey.privateKey);

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

  static Future<PolygonWallet> open(
      {required String name,
      required String password,
      required WalletInfo walletInfo,
      required EncryptionFileUtils encryptionFileUtils,
      required bool isFlatpak}) async {
    final path = await pathForWallet(name: name, type: walletInfo.type, isFlatpak: isFlatpak);
    final jsonSource = await encryptionFileUtils.read(path: path, password: password);
    final data = json.decode(jsonSource) as Map;
    final mnemonic = data['mnemonic'] as String?;
    final privateKey = data['private_key'] as String?;
    final balance = ERC20Balance.fromJSON(data['balance'] as String) ?? ERC20Balance(BigInt.zero);

    return PolygonWallet(
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
    balance[currency] = await _fetchMaticBalance();

    await _fetchErc20Balances();
    await save();
  }

  Future<ERC20Balance> _fetchMaticBalance() async {
    final balance = await _client.getBalance(_polygonPrivateKey.address);
    return ERC20Balance(balance.getInWei);
  }

  Future<void> _fetchErc20Balances() async {
    for (var token in polygonErc20TokensBox.values) {
      try {
        if (token.enabled) {
          balance[token] = await _client.fetchERC20Balances(
            _polygonPrivateKey.address,
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

    const hdPathPolygon = "m/44'/60'/0'/0";
    const index = 0;
    final addressAtIndex = root.derivePath("$hdPathPolygon/$index");

    return EthPrivateKey.fromHex(HEX.encode(addressAtIndex.privateKey as List<int>));
  }

  @override
  Future<void>? updateBalance() async => await _updateBalance();

  List<Erc20Token> get erc20Currencies => polygonErc20TokensBox.values.toList();

  Future<void> addErc20Token(Erc20Token token) async {
    String? iconPath;
    try {
      iconPath = CryptoCurrency.all
          .firstWhere((element) => element.title.toUpperCase() == token.symbol.toUpperCase())
          .iconPath;
    } catch (_) {}

    final token0 = Erc20Token(
      name: token.name,
      symbol: token.symbol,
      contractAddress: token.contractAddress,
      decimal: token.decimal,
      enabled: token.enabled,
      tag: token.tag ?? "POLY",
      iconPath: iconPath,
    );

    await polygonErc20TokensBox.put(token0.contractAddress, token0);

    if (token0.enabled) {
      balance[token0] = await _client.fetchERC20Balances(
        _polygonPrivateKey.address,
        token0.contractAddress,
      );
    } else {
      balance.remove(token0);
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
    final initialErc20Tokens = DefaultPolygonErc20Tokens().initialPolygonErc20Tokens;

    for (var token in initialErc20Tokens) {
      polygonErc20TokensBox.put(token.contractAddress, token);
    }
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

  void updatePolygonScanUsageState(bool isEnabled) {
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
      bytesToHex(_polygonPrivateKey.signPersonalMessageToUint8List(ascii.encode(message)));

  Web3Client? getWeb3Client() => _client.getWeb3Client();
}
