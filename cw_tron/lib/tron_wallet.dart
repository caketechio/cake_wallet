import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_tron/default_tron_tokens.dart';
import 'package:cw_tron/tron_abi.dart';
import 'package:cw_tron/tron_balance.dart';
import 'package:cw_tron/tron_client.dart';
import 'package:cw_tron/tron_exception.dart';
import 'package:cw_tron/tron_token.dart';
import 'package:cw_tron/tron_transaction_credentials.dart';
import 'package:cw_tron/tron_transaction_history.dart';
import 'package:cw_tron/tron_transaction_info.dart';
import 'package:cw_tron/tron_wallet_addresses.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:on_chain/on_chain.dart';

part 'tron_wallet.g.dart';

class TronWallet = TronWalletBase with _$TronWallet;

abstract class TronWalletBase
    extends WalletBase<TronBalance, TronTransactionHistory, TronTransactionInfo>
    with Store, WalletKeysFile {
  TronWalletBase({
    required WalletInfo walletInfo,
    String? mnemonic,
    String? privateKey,
    required String password,
    TronBalance? initialBalance,
    required this.encryptionFileUtils,
  })  : syncStatus = const NotConnectedSyncStatus(),
        _password = password,
        _mnemonic = mnemonic,
        _hexPrivateKey = privateKey,
        _client = TronClient(),
        walletAddresses = TronWalletAddresses(walletInfo),
        balance = ObservableMap<CryptoCurrency, TronBalance>.of(
          {CryptoCurrency.trx: initialBalance ?? TronBalance(BigInt.zero)},
        ),
        super(walletInfo) {
    this.walletInfo = walletInfo;
    transactionHistory = TronTransactionHistory(
        walletInfo: walletInfo, password: password, encryptionFileUtils: encryptionFileUtils);

    if (!CakeHive.isAdapterRegistered(TronToken.typeId)) {
      CakeHive.registerAdapter(TronTokenAdapter());
    }
  }

  final String? _mnemonic;
  final String? _hexPrivateKey;
  final String _password;
  final EncryptionFileUtils encryptionFileUtils;

  late final Box<TronToken> tronTokensBox;

  late final TronPrivateKey _tronPrivateKey;

  late final TronPublicKey _tronPublicKey;

  TronPublicKey get tronPublicKey => _tronPublicKey;

  TronPrivateKey get tronPrivateKey => _tronPrivateKey;

  late String _tronAddress;

  late final TronClient _client;

  Timer? _transactionsUpdateTimer;

  @override
  WalletAddresses walletAddresses;

  @observable
  String? nativeTxEstimatedFee;

  @observable
  String? trc20EstimatedFee;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  late ObservableMap<CryptoCurrency, TronBalance> balance;

  Future<void> init() async {
    await initTronTokensBox();

    await walletAddresses.init();
    await transactionHistory.init();
    _tronPrivateKey = await getPrivateKey(
      mnemonic: _mnemonic,
      privateKey: _hexPrivateKey,
      password: _password,
    );

    _tronPublicKey = _tronPrivateKey.publicKey();

    _tronAddress = _tronPublicKey.toAddress().toString();

    walletAddresses.address = _tronAddress;

    await save();
  }

  static Future<TronWallet> open({
    required String name,
    required String password,
    required WalletInfo walletInfo,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);
    final path = await pathForWallet(name: name, type: walletInfo.type);

    Map<String, dynamic>? data;
    try {
      final jsonSource = await encryptionFileUtils.read(path: path, password: password);

      data = json.decode(jsonSource) as Map<String, dynamic>;
    } catch (e) {
      if (!hasKeysFile) rethrow;
    }

    final balance = TronBalance.fromJSON(data?['balance'] as String) ?? TronBalance(BigInt.zero);

    final WalletKeysData keysData;
    // Migrate wallet from the old scheme to then new .keys file scheme
    if (!hasKeysFile) {
      final mnemonic = data!['mnemonic'] as String?;
      final privateKey = data['private_key'] as String?;

      keysData = WalletKeysData(mnemonic: mnemonic, privateKey: privateKey);
    } else {
      keysData = await WalletKeysFile.readKeysFile(
        name,
        walletInfo.type,
        password,
        encryptionFileUtils,
      );
    }

    return TronWallet(
      walletInfo: walletInfo,
      password: password,
      mnemonic: keysData.mnemonic,
      privateKey: keysData.privateKey,
      initialBalance: balance,
      encryptionFileUtils: encryptionFileUtils,
    );
  }

  void addInitialTokens() {
    final initialTronTokens = DefaultTronTokens().initialTronTokens;

    for (var token in initialTronTokens) {
      tronTokensBox.put(token.contractAddress, token);
    }
  }

  Future<void> initTronTokensBox() async {
    final boxName = "${walletInfo.name.replaceAll(" ", "_")}_${TronToken.boxName}";

    tronTokensBox = await CakeHive.openBox<TronToken>(boxName);
  }

  String idFor(String name, WalletType type) => '${walletTypeToString(type).toLowerCase()}_$name';

  Future<TronPrivateKey> getPrivateKey({
    String? mnemonic,
    String? privateKey,
    required String password,
  }) async {
    assert(mnemonic != null || privateKey != null);

    if (privateKey != null) return TronPrivateKey(privateKey);

    final seed = bip39.mnemonicToSeed(mnemonic!);

    // Derive a TRON private key from the seed
    final bip44 = Bip44.fromSeed(seed, Bip44Coins.tron);

    final childKey = bip44.deriveDefaultPath;

    return TronPrivateKey.fromBytes(childKey.privateKey.raw);
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int? amount) => 0;

  @override
  Future<void> changePassword(String password) => throw UnimplementedError("changePassword");

  @override
  void close({bool? switchingToSameWalletType}) {
    _transactionsUpdateTimer?.cancel();
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

      _getEstimatedFees();
      _setTransactionUpdateTimer();

      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  Future<void> _getEstimatedFees() async {
    final nativeFee = await _getNativeTxFee();
    nativeTxEstimatedFee = TronHelper.fromSun(BigInt.from(nativeFee));

    final trc20Fee = await _getTrc20TxFee();
    trc20EstimatedFee = TronHelper.fromSun(BigInt.from(trc20Fee));

    log('Native Estimated Fee: $nativeTxEstimatedFee');
    log('TRC20 Estimated Fee: $trc20EstimatedFee');
  }

  Future<int> _getNativeTxFee() async {
    try {
      final fee = await _client.getEstimatedFee(_tronPublicKey.toAddress());
      return fee;
    } catch (e) {
      log(e.toString());
      return 0;
    }
  }

  Future<int> _getTrc20TxFee() async {
    try {
      final trc20fee = await _client.getTRCEstimatedFee(_tronPublicKey.toAddress());
      return trc20fee;
    } catch (e) {
      log(e.toString());
      return 0;
    }
  }

  @action
  @override
  Future<void> startSync() async {
    try {
      syncStatus = AttemptingSyncStatus();
      await _updateBalance();
      await fetchTransactions();
      fetchTrc20ExcludedTransactions();

      syncStatus = SyncedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    final tronCredentials = credentials as TronTransactionCredentials;

    final outputs = tronCredentials.outputs;

    final hasMultiDestination = outputs.length > 1;

    final CryptoCurrency transactionCurrency =
        balance.keys.firstWhere((element) => element.title == tronCredentials.currency.title);

    final walletBalanceForCurrency = balance[transactionCurrency]!.balance;

    BigInt totalAmount = BigInt.zero;
    bool shouldSendAll = false;
    if (hasMultiDestination) {
      if (outputs.any((item) => item.sendAll || (item.formattedCryptoAmount ?? 0) <= 0)) {
        throw TronTransactionCreationException(transactionCurrency);
      }

      final totalAmountFromCredentials =
          outputs.fold(0, (acc, value) => acc + (value.formattedCryptoAmount ?? 0));

      totalAmount = BigInt.from(totalAmountFromCredentials);

      if (walletBalanceForCurrency < totalAmount) {
        throw TronTransactionCreationException(transactionCurrency);
      }
    } else {
      final output = outputs.first;

      shouldSendAll = output.sendAll;

      if (shouldSendAll) {
        totalAmount = walletBalanceForCurrency;
      } else {
        final totalOriginalAmount = double.parse(output.cryptoAmount ?? '0.0');
        totalAmount = TronHelper.toSun(totalOriginalAmount.toString());
      }

      if (walletBalanceForCurrency < totalAmount || totalAmount < BigInt.zero) {
        throw TronTransactionCreationException(transactionCurrency);
      }
    }

    final tronBalance = balance[CryptoCurrency.trx]?.balance ?? BigInt.zero;

    final pendingTransaction = await _client.signTransaction(
      ownerPrivKey: _tronPrivateKey,
      toAddress: tronCredentials.outputs.first.isParsedAddress
          ? tronCredentials.outputs.first.extractedAddress!
          : tronCredentials.outputs.first.address,
      amount: TronHelper.fromSun(totalAmount),
      currency: transactionCurrency,
      tronBalance: tronBalance,
      sendAll: shouldSendAll,
    );

    return pendingTransaction;
  }

  @override
  Future<Map<String, TronTransactionInfo>> fetchTransactions() async {
    final address = _tronAddress;

    final transactions = await _client.fetchTransactions(address);

    final Map<String, TronTransactionInfo> result = {};

    final contract = ContractABI.fromJson(trc20Abi, isTron: true);

    final ownerAddress = TronAddress(_tronAddress);

    for (var transactionModel in transactions) {
      if (transactionModel.isError) {
        continue;
      }

      // Filter out spam transaactions that involve receiving TRC10 assets transaction, we deal with TRX and TRC20 transactions
      if (transactionModel.contracts?.first.type == "TransferAssetContract") {
        continue;
      }

      String? tokenSymbol;
      if (transactionModel.contractAddress != null) {
        final tokenAddress = TronAddress(transactionModel.contractAddress!);

        tokenSymbol = (await _client.getTokenDetail(
              contract,
              "symbol",
              ownerAddress,
              tokenAddress,
            ) as String?) ??
            '';
      }

      result[transactionModel.hash] = TronTransactionInfo(
        id: transactionModel.hash,
        tronAmount: transactionModel.amount ?? BigInt.zero,
        direction: TronAddress(transactionModel.from!, visible: false).toAddress() == address
            ? TransactionDirection.outgoing
            : TransactionDirection.incoming,
        blockTime: transactionModel.date,
        txFee: transactionModel.fee,
        tokenSymbol: tokenSymbol ?? "TRX",
        to: transactionModel.to,
        from: transactionModel.from,
        isPending: false,
      );
    }

    transactionHistory.addMany(result);

    await transactionHistory.save();

    return transactionHistory.transactions;
  }

  Future<void> fetchTrc20ExcludedTransactions() async {
    final address = _tronAddress;

    final transactions = await _client.fetchTrc20ExcludedTransactions(address);

    final Map<String, TronTransactionInfo> result = {};

    for (var transactionModel in transactions) {
      if (transactionHistory.transactions.containsKey(transactionModel.hash)) {
        continue;
      }

      result[transactionModel.hash] = TronTransactionInfo(
        id: transactionModel.hash,
        tronAmount: transactionModel.amount ?? BigInt.zero,
        direction: transactionModel.from! == address
            ? TransactionDirection.outgoing
            : TransactionDirection.incoming,
        blockTime: transactionModel.date,
        txFee: transactionModel.fee,
        tokenSymbol: transactionModel.tokenSymbol ?? "TRX",
        to: transactionModel.to,
        from: transactionModel.from,
        isPending: false,
      );
    }

    transactionHistory.addMany(result);

    await transactionHistory.save();
  }

  @override
  Object get keys => throw UnimplementedError("keys");

  @override
  Future<void> rescan({required int height}) => throw UnimplementedError("rescan");

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
  String get privateKey => _tronPrivateKey.toHex();

  @override
  WalletKeysData get walletKeysData => WalletKeysData(mnemonic: _mnemonic, privateKey: privateKey);

  String toJSON() => json.encode({
        'mnemonic': _mnemonic,
        'private_key': privateKey,
        'balance': balance[currency]!.toJSON(),
      });

  Future<void> _updateBalance() async {
    balance[currency] = await _fetchTronBalance();

    await _fetchTronTokenBalances();
    await save();
  }

  Future<TronBalance> _fetchTronBalance() async {
    final balance = await _client.getBalance(_tronPublicKey.toAddress());
    return TronBalance(balance);
  }

  Future<void> _fetchTronTokenBalances() async {
    for (var token in tronTokensBox.values) {
      try {
        if (token.enabled) {
          balance[token] = await _client.fetchTronTokenBalances(
            _tronAddress,
            token.contractAddress,
          );
        } else {
          balance.remove(token);
        }
      } catch (_) {}
    }
  }

  @override
  Future<void>? updateBalance() async => await _updateBalance();

  List<TronToken> get tronTokenCurrencies => tronTokensBox.values.toList();

  Future<void> addTronToken(TronToken token) async {
    String? iconPath;
    try {
      iconPath = CryptoCurrency.all
          .firstWhere((element) => element.title.toUpperCase() == token.symbol.toUpperCase())
          .iconPath;
    } catch (_) {}

    final newToken = TronToken(
      name: token.name,
      symbol: token.symbol,
      contractAddress: token.contractAddress,
      decimal: token.decimal,
      enabled: token.enabled,
      tag: token.tag ?? "TRX",
      iconPath: iconPath,
    );

    await tronTokensBox.put(newToken.contractAddress, newToken);

    if (newToken.enabled) {
      balance[newToken] = await _client.fetchTronTokenBalances(
        _tronAddress,
        newToken.contractAddress,
      );
    } else {
      balance.remove(newToken);
    }
  }

  Future<void> deleteTronToken(TronToken token) async {
    await token.delete();

    balance.remove(token);
    await _removeTokenTransactionsInHistory(token);
    _updateBalance();
  }

  Future<void> _removeTokenTransactionsInHistory(TronToken token) async {
    transactionHistory.transactions.removeWhere((key, value) => value.tokenSymbol == token.title);
    await transactionHistory.save();
  }

  Future<TronToken?> getTronToken(String contractAddress) async =>
      await _client.getTronToken(contractAddress, _tronAddress);

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    const transactionHistoryFileNameForWallet = 'tron_transactions.json';

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

    _transactionsUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      _updateBalance();
      await fetchTransactions();
      fetchTrc20ExcludedTransactions();
    });
  }

  @override
  Future<String> signMessage(String message, {String? address}) async {
    return _tronPrivateKey.signPersonalMessage(ascii.encode(message));
  }

  @override
  Future<bool> verifyMessage(String message, String signature, {String? address}) async {
    if (address == null) {
      return false;
    }
    TronPublicKey pubKey = TronPublicKey.fromPersonalSignature(ascii.encode(message), signature)!;
    return pubKey.toAddress().toString() == address;
  }

  String getTronBase58AddressFromHex(String hexAddress) => TronAddress(hexAddress).toAddress();

  void updateScanProviderUsageState(bool isEnabled) {
    if (isEnabled) {
      fetchTransactions();
      fetchTrc20ExcludedTransactions();
      _setTransactionUpdateTimer();
    } else {
      _transactionsUpdateTimer?.cancel();
    }
  }

  @override
  String get password => _password;
}
