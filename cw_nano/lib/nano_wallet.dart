import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/n2_node.dart';
import 'package:cw_core/nano_account.dart';
import 'package:cw_core/nano_account_info_response.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:cw_nano/nano_balance.dart';
import 'package:cw_nano/nano_client.dart';
import 'package:cw_nano/nano_transaction_credentials.dart';
import 'package:cw_nano/nano_transaction_history.dart';
import 'package:cw_nano/nano_transaction_info.dart';
import 'package:cw_nano/nano_wallet_addresses.dart';
import 'package:cw_nano/nano_wallet_keys.dart';
import 'package:cw_nano/pending_nano_transaction.dart';
import 'package:mobx/mobx.dart';
import 'package:nanoutil/nanoutil.dart';

part 'nano_wallet.g.dart';

class NanoWallet = NanoWalletBase with _$NanoWallet;

abstract class NanoWalletBase
    extends WalletBase<NanoBalance, NanoTransactionHistory, NanoTransactionInfo>
    with Store, WalletKeysFile {
  NanoWalletBase({
    required WalletInfo walletInfo,
    required String mnemonic,
    required String password,
    NanoBalance? initialBalance,
    required EncryptionFileUtils encryptionFileUtils,
    this.passphrase,
  })  : syncStatus = NotConnectedSyncStatus(),
        _password = password,
        _mnemonic = mnemonic,
        _derivationType = walletInfo.derivationInfo!.derivationType!,
        _isTransactionUpdating = false,
        _encryptionFileUtils = encryptionFileUtils,
        _client = NanoClient(),
        walletAddresses = NanoWalletAddresses(walletInfo),
        balance = ObservableMap<CryptoCurrency, NanoBalance>.of({
          CryptoCurrency.nano: initialBalance ??
              NanoBalance(currentBalance: BigInt.zero, receivableBalance: BigInt.zero)
        }),
        super(walletInfo) {
    this.walletInfo = walletInfo;
    transactionHistory = NanoTransactionHistory(
      walletInfo: walletInfo,
      password: password,
      encryptionFileUtils: encryptionFileUtils,
    );
    if (!CakeHive.isAdapterRegistered(NanoAccount.typeId)) {
      CakeHive.registerAdapter(NanoAccountAdapter());
    }
  }

  String _mnemonic;
  final String _password;
  DerivationType _derivationType;

  final EncryptionFileUtils _encryptionFileUtils;

  String? _privateKey;
  String? _publicAddress;
  String? _hexSeed;
  Timer? _receiveTimer;

  String? _representativeAddress;
  int repScore = 100;

  bool get isRepOk => repScore >= 90;

  late final NanoClient _client;
  bool _isTransactionUpdating;

  @override
  NanoWalletAddresses walletAddresses;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  late ObservableMap<CryptoCurrency, NanoBalance> balance;

  @override
  String get password => _password;

  static const int POLL_INTERVAL_SECONDS = 10;

  // initialize the different forms of private / public key we'll need:
  Future<void> init() async {
    if (_derivationType == DerivationType.unknown) {
      _derivationType = DerivationType.nano;
    }

    // our "mnemonic" is actually a hex form seed:
    if (!_mnemonic.contains(' ')) {
      _hexSeed = _mnemonic;
      _mnemonic = "";
    }

    if (_hexSeed == null) {
      if (_derivationType == DerivationType.nano) {
        _hexSeed = bip39.mnemonicToEntropy(_mnemonic).toUpperCase();
      } else {
        _hexSeed = await NanoDerivations.hdMnemonicListToSeed(_mnemonic.split(' '));
      }
    }

    final String type = (_derivationType == DerivationType.nano) ? "standard" : "hd";
    NanoDerivationType derivationType = NanoDerivations.stringToType(type);

    _privateKey = await NanoDerivations.universalSeedToPrivate(
      _hexSeed!,
      index: 0,
      type: derivationType,
    );
    _publicAddress = await NanoDerivations.universalSeedToAddress(
      _hexSeed!,
      index: 0,
      type: derivationType,
    );
    this.walletInfo.address = _publicAddress!;

    await walletAddresses.init();
    await transactionHistory.init();
    await save();
  }

  @override
  Future<int> calculateEstimatedFee(TransactionPriority priority) async => 0; // always 0 :)

  @override
  Future<void> changePassword(String password) => throw UnimplementedError("changePassword");

  @override
  Future<void> close({bool shouldCleanup = false}) async {
    _client.stop();
    _receiveTimer?.cancel();
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    try {
      syncStatus = ConnectingSyncStatus();
      final isConnected = _client.connect(node);
      if (!isConnected) {
        throw Exception("Nano Node connection failed");
      }

      try {
        await _updateBalance();
        await updateTransactions();
        await _updateRep();
        await _receiveAll();
      } catch (e) {
        printV(e);
      }

      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      printV(e);
      syncStatus = FailedSyncStatus();
    }
  }

  @override
  Future<void> connectToPowNode({required Node node}) async => _client.connectPow(node);

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    credentials = credentials as NanoTransactionCredentials;

    BigInt runningAmount = BigInt.zero;
    await _updateBalance();
    BigInt runningBalance = balance[currency]?.currentBalance ?? BigInt.zero;

    final List<Map<String, String>> blocks = [];
    String? previousHash;

    for (var txOut in credentials.outputs) {
      late BigInt amt;
      if (txOut.sendAll) {
        amt = balance[currency]?.currentBalance ?? BigInt.zero;
      } else {
        amt = BigInt.tryParse(NanoAmounts.getAmountAsRaw(
                txOut.cryptoAmount?.replaceAll(',', '.') ?? "0", NanoAmounts.rawPerNano)) ??
            BigInt.zero;
      }

      if (balance[currency]?.currentBalance != null && amt > balance[currency]!.currentBalance) {
        throw Exception("Trying to send more than entire balance!");
      }

      runningBalance = runningBalance - amt;

      final block = await _client.constructSendBlock(
        amountRaw: amt.toString(),
        destinationAddress: txOut.isParsedAddress ? txOut.extractedAddress! : txOut.address,
        privateKey: _privateKey!,
        balanceAfterTx: runningBalance,
        previousHash: previousHash,
      );
      previousHash = NanoSignatures.computeStateHash(
        NanoBasedCurrency.NANO,
        block["account"]!,
        block["previous"]!,
        block["representative"]!,
        BigInt.parse(block["balance"]!),
        block["link"]!,
      );

      blocks.add(block);
      runningAmount += amt;
    }

    try {
      if (runningAmount > balance[currency]!.currentBalance || runningBalance < BigInt.zero) {
        throw Exception(("Trying to send more than entire balance!"));
      }
    } catch (e) {
      rethrow;
    }

    return PendingNanoTransaction(
      amount: runningAmount,
      id: "",
      nanoClient: _client,
      blocks: blocks,
    );
  }

  Future<void> _receiveAll() async {
    await _updateBalance();
    int blocksReceived = await this._client.confirmAllReceivable(
          destinationAddress: _publicAddress!,
          privateKey: _privateKey!,
        );

    if (blocksReceived > 0) {
      await Future<void>.delayed(Duration(seconds: 3));
      _updateBalance();
      updateTransactions();
    }
  }

  Future<bool> updateTransactions() async {
    try {
      if (_isTransactionUpdating) {
        return false;
      }

      _isTransactionUpdating = true;
      final transactions = await fetchTransactions();
      transactionHistory.addMany(transactions);
      await transactionHistory.save();
      _isTransactionUpdating = false;
      return true;
    } catch (_) {
      _isTransactionUpdating = false;
      return false;
    }
  }

  @override
  Future<Map<String, NanoTransactionInfo>> fetchTransactions() async {
    String address = _publicAddress!;

    final transactions = await _client.fetchTransactions(address);

    final Map<String, NanoTransactionInfo> result = {};

    for (var transactionModel in transactions) {
      final bool isSend = transactionModel.type == "send";
      result[transactionModel.hash] = NanoTransactionInfo(
        id: transactionModel.hash,
        amountRaw: transactionModel.amount,
        height: transactionModel.height,
        direction: isSend ? TransactionDirection.outgoing : TransactionDirection.incoming,
        confirmed: transactionModel.confirmed,
        date: transactionModel.date ?? DateTime.now(),
        confirmations: transactionModel.confirmed ? 1 : 0,
        to: isSend ? transactionModel.account : address,
        from: isSend ? address : transactionModel.account,
      );
    }

    return result;
  }

  @override
  NanoWalletKeys get keys => NanoWalletKeys(seedKey: _hexSeed!);

  @override
  String? get privateKey => _privateKey!;

  @override
  Future<void> rescan({required int height}) async {
    updateTransactions();
    _updateBalance();
    return;
  }

  @override
  Future<void> save() async {
    if (!(await WalletKeysFile.hasKeysFile(walletInfo.name, walletInfo.type))) {
      await saveKeysFile(_password, _encryptionFileUtils);
      saveKeysFile(_password, _encryptionFileUtils, true);
    }

    await walletAddresses.updateAddressesInBox();
    final path = await makePath();
    await _encryptionFileUtils.write(path: path, password: _password, data: toJSON());
    await transactionHistory.save();
  }

  @override
  String? get seed => _mnemonic.isNotEmpty ? _mnemonic : null;

  String get hexSeed => _hexSeed!;

  @override
  WalletKeysData get walletKeysData => WalletKeysData(mnemonic: _mnemonic, altMnemonic: hexSeed);

  String get representative => _representativeAddress ?? "";

  @action
  @override
  Future<void> startSync() async {
    try {
      syncStatus = AttemptingSyncStatus();

      // setup a timer to receive transactions periodically:
      _receiveTimer?.cancel();
      _receiveTimer = Timer.periodic(const Duration(seconds: POLL_INTERVAL_SECONDS), (timer) async {
        // get our balance:
        await _updateBalance();
        // if we have anything to receive, process it:
        if (balance[currency]!.receivableBalance > BigInt.zero) {
          await _receiveAll();
        }
      });

      // also run once, immediately:
      await _updateBalance();
      bool updateSuccess = await updateTransactions();
      if (!updateSuccess) {
        syncStatus = FailedSyncStatus();
        return;
      }

      syncStatus = SyncedSyncStatus();
    } catch (e) {
      printV(e);
      syncStatus = FailedSyncStatus();
      rethrow;
    }
  }

  String toJSON() => json.encode({
        'seedKey': _hexSeed,
        'mnemonic': _mnemonic,
        'currentBalance': balance[currency]?.currentBalance.toString() ?? "0",
        'receivableBalance': balance[currency]?.receivableBalance.toString() ?? "0",
        'derivationType': _derivationType.toString()
      });

  static Future<NanoWallet> open({
    required String name,
    required String password,
    required WalletInfo walletInfo,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);
    final path = await pathForWallet(name: name, type: walletInfo.type);

    Map<String, dynamic>? data = null;
    try {
      final jsonSource = await encryptionFileUtils.read(path: path, password: password);

      data = json.decode(jsonSource) as Map<String, dynamic>;
    } catch (e) {
      if (!hasKeysFile) rethrow;
    }

    final balance = NanoBalance.fromRawString(
      currentBalance: data?['currentBalance'] as String? ?? "0",
      receivableBalance: data?['receivableBalance'] as String? ?? "0",
    );

    final WalletKeysData keysData;
    // Migrate wallet from the old scheme to then new .keys file scheme
    if (!hasKeysFile) {
      final mnemonic = data!['mnemonic'] as String;
      final isHexSeed = !mnemonic.contains(' ');

      keysData = WalletKeysData(
          mnemonic: isHexSeed ? null : mnemonic, altMnemonic: isHexSeed ? mnemonic : null);
    } else {
      keysData = await WalletKeysFile.readKeysFile(
        name,
        walletInfo.type,
        password,
        encryptionFileUtils,
      );
    }

    DerivationType derivationType = DerivationType.nano;
    if (data?['derivationType'] == "DerivationType.bip39") {
      derivationType = DerivationType.bip39;
    }

    walletInfo.derivationInfo ??= DerivationInfo(derivationType: derivationType);
    walletInfo.derivationInfo!.derivationType ??= derivationType;

    return NanoWallet(
      walletInfo: walletInfo,
      password: password,
      mnemonic: keysData.mnemonic!,
      initialBalance: balance,
      encryptionFileUtils: encryptionFileUtils,
    );
    // init() should always be run after this!
  }

  Future<void> _updateBalance() async {
    var oldBalance = balance[currency];
    try {
      balance[currency] = await _client.getBalance(_publicAddress!);
    } catch (e) {
      printV("Failed to get balance $e");
      // if we don't have a balance, we should at least create one, since it's a late binding
      // otherwise, it's better to just leave it as whatever it was before:
      if (balance[currency] == null) {
        balance[currency] =
            NanoBalance(currentBalance: BigInt.zero, receivableBalance: BigInt.zero);
      }
    }
    // don't save unnecessarily:
    // trying to save too frequently can cause problems with the file system
    // since nano is updated frequently this can be a problem, so we only save if there is a change:
    if (oldBalance == null ||
        balance[currency]!.currentBalance != oldBalance.currentBalance ||
        balance[currency]!.receivableBalance != oldBalance.receivableBalance) {
      await save();
    }
  }

  Future<void> _updateRep() async {
    try {
      AccountInfoResponse accountInfo = (await _client.getAccountInfo(_publicAddress!))!;
      _representativeAddress = accountInfo.representative;
    } catch (e) {
      // account not found:
      _representativeAddress = await _client.getRepFromPrefs();
      throw Exception("Failed to get representative address $e");
    }

    repScore = await _client.getRepScore(_representativeAddress!);
  }

  Future<void> regenerateAddress() async {
    final NanoDerivationType type = (_derivationType == DerivationType.nano)
        ? NanoDerivationType.STANDARD
        : NanoDerivationType.HD;
    _privateKey = await NanoDerivations.universalSeedToPrivate(
      _hexSeed!,
      index: this.walletAddresses.account!.id,
      type: type,
    );
    _publicAddress = await NanoDerivations.universalSeedToAddress(
      _hexSeed!,
      index: this.walletAddresses.account!.id,
      type: type,
    );

    this.walletInfo.address = _publicAddress!;
    this.walletAddresses.address = _publicAddress!;
  }

  Future<void> changeRep(String address) async {
    try {
      final String hash = await _client.changeRep(
        privateKey: _privateKey!,
        repAddress: address,
        ourAddress: _publicAddress!,
      );
      if (hash.isNotEmpty) {
        _representativeAddress = address;
      }
    } catch (e) {
      throw Exception("Failed to change representative address $e");
    }
  }

  Future<List<N2Node>> getN2Reps() async {
    return _client.getN2Reps();
  }

  Future<void>? updateBalance() async => await _updateBalance();

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    final currentWalletPath = await pathForWallet(name: walletInfo.name, type: type);
    final currentWalletFile = File(currentWalletPath);

    final currentDirPath = await pathForWalletDir(name: walletInfo.name, type: type);
    final currentTransactionsFile = File('$currentDirPath/$transactionsHistoryFileName');

    // Copies current wallet files into new wallet name's dir and files
    if (currentWalletFile.existsSync()) {
      final newWalletPath = await pathForWallet(name: newWalletName, type: type);
      await currentWalletFile.copy(newWalletPath);
    }
    if (currentTransactionsFile.existsSync()) {
      final newDirPath = await pathForWalletDir(name: newWalletName, type: type);
      await currentTransactionsFile.copy('$newDirPath/$transactionsHistoryFileName');
    }

    // Delete old name's dir and files
    await Directory(currentDirPath).delete(recursive: true);
  }

  @override
  Future<String> signMessage(String message, {String? address = null}) async {
    return NanoSignatures.signMessage(message, privateKey!);
  }

  @override
  Future<bool> verifyMessage(String message, String signature, {String? address = null}) async {
    if (address == null) {
      return false;
    }
    return await NanoSignatures.verifyMessage(message, signature, address);
  }

  @override
  final String? passphrase;
}
