import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:breez_sdk/breez_sdk.dart';
import 'package:breez_sdk/bridge_generated.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_lightning/lightning_balance.dart';
import 'package:cw_lightning/lightning_transaction_info.dart';
import 'package:cw_lightning/lightning_transaction_priority.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:flutter/foundation.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_lightning/.secrets.g.dart' as secrets;
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

part 'lightning_wallet.g.dart';

class LightningWallet = LightningWalletBase with _$LightningWallet;

abstract class LightningWalletBase extends ElectrumWallet with Store {
  bool _isTransactionUpdating;

  @override
  @observable
  SyncStatus syncStatus;

  LightningWalletBase({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required Uint8List seedBytes,
    required EncryptionFileUtils encryptionFileUtils,
    String? addressPageType,
    List<BitcoinAddressRecord>? initialAddresses,
    LightningBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
  })  : _isTransactionUpdating = false,
        syncStatus = NotConnectedSyncStatus(),
        _balance = ObservableMap<CryptoCurrency, LightningBalance>(),
        mnemonic = mnemonic,
        seedBytes = seedBytes,
        super(
          password: password,
          walletInfo: walletInfo,
          unspentCoinsInfo: unspentCoinsInfo,
          network: BitcoinNetwork.mainnet,
          initialAddresses: initialAddresses,
          initialBalance: initialBalance,
          seedBytes: seedBytes,
          encryptionFileUtils: encryptionFileUtils,
          currency: CryptoCurrency.btcln,
        ) {
    _balance[CryptoCurrency.btcln] =
        initialBalance ?? LightningBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
    walletAddresses = BitcoinWalletAddresses(
      walletInfo,
      initialAddresses: initialAddresses,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      mainHd: super.hd,
      sideHd: super.accountHD.childKey(Bip32KeyIndex(1)),
      network: network,
    );

    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
    });
  }

  late final ObservableMap<CryptoCurrency, LightningBalance> _balance;
  StreamSubscription<List<Payment>>? _paymentsSub;
  StreamSubscription<NodeState?>? _nodeStateSub;
  StreamSubscription<LogEntry>? _logStream;
  StreamSubscription<InvoicePaidDetails>? _invoiceSub;
  late final BreezSDK _sdk;

  late final Uint8List seedBytes;
  String mnemonic;
  @override
  String get seed => mnemonic;

  Map<String, int> incomingPayments = <String, int>{};

  RecommendedFees recommendedFees = RecommendedFees(
    economyFee: 0,
    fastestFee: 0,
    halfHourFee: 0,
    hourFee: 0,
    minimumFee: 0,
  );

  @override
  @computed
  ObservableMap<CryptoCurrency, LightningBalance> get balance => _balance;

  static Future<LightningWallet> create(
      {required String mnemonic,
      required String password,
      required WalletInfo walletInfo,
      required Box<UnspentCoinsInfo> unspentCoinsInfo,
      required EncryptionFileUtils encryptionFileUtils,
      String? addressPageType,
      List<BitcoinAddressRecord>? initialAddresses,
      LightningBalance? initialBalance,
      Map<String, int>? initialRegularAddressIndex,
      Map<String, int>? initialChangeAddressIndex}) async {
    return LightningWallet(
      mnemonic: mnemonic,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: initialAddresses,
      initialBalance: initialBalance,
      seedBytes: await universalMnemonictoSeedBytes(
        mnemonic,
        derivationType: walletInfo.derivationInfo?.derivationType,
      ),
      encryptionFileUtils: encryptionFileUtils,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      addressPageType: addressPageType,
    );
  }

  static Future<LightningWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final snp = await ElectrumWalletSnapshot.load(
      encryptionFileUtils,
      name,
      walletInfo.type,
      password,
      BitcoinNetwork.mainnet,
    );

    return LightningWallet(
      mnemonic: snp.mnemonic!,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: snp.addresses,
      initialBalance: LightningBalance(
        confirmed: snp.balance.confirmed,
        unconfirmed: snp.balance.unconfirmed,
        frozen: snp.balance.frozen,
      ),
      seedBytes: await universalMnemonictoSeedBytes(
        snp.mnemonic!,
        derivationType: walletInfo.derivationInfo?.derivationType,
      ),
      encryptionFileUtils: encryptionFileUtils,
      initialRegularAddressIndex: snp.regularAddressIndex,
      initialChangeAddressIndex: snp.changeAddressIndex,
      addressPageType: snp.addressPageType,
    );
  }

  Future<void> _handleNodeState(NodeState? nodeState) async {
    if (nodeState == null) return;
    _balance[CryptoCurrency.btcln] = LightningBalance(
      confirmed: nodeState.maxPayableMsat ~/ 1000,
      unconfirmed: nodeState.maxReceivableMsat ~/ 1000,
      frozen: nodeState.onchainBalanceMsat ~/ 1000,
    );
  }

  Future<void> _handlePayments(List<Payment> payments) async {
    _isTransactionUpdating = true;
    final txs = convertToTxInfo(payments);
    await alertIncomingTxs(txs);
    transactionHistory.addMany(txs);
    _isTransactionUpdating = false;
    if (txs.isNotEmpty) {
      await updateBalance();
    }
  }

  Future<void> _handleInvoicePaid(InvoicePaidDetails details) async {
    _isTransactionUpdating = true;

    if (details.payment == null) {
      return;
    }

    final txs = convertToTxInfo([details.payment!]);
    await alertIncomingTxs(txs);
    transactionHistory.addMany(txs);
    _isTransactionUpdating = false;
    if (txs.isNotEmpty) {
      await updateBalance();
    }
  }

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    await stopBreez(true);
    await super.renameWalletFiles(newWalletName);
    await setupBreez(seedBytes);
  }

  void _logSdkEntries(LogEntry entry) {
    switch (entry.level) {
      case "ERROR":
      case "WARN":
        // case "INFO":
        // case "DEBUG":
        // case "TRACE":
        print("BREEZ:${entry.level}: ${entry.line}");
        break;
    }
  }

  Future<void> setupBreez(Uint8List seedBytes) async {
    _sdk = await BreezSDK();
    await _logStream?.cancel();
    _logStream = _sdk.logStream.listen(_logSdkEntries);

    try {
      if (!(await _sdk.isInitialized())) {
        _sdk.initialize();
      }
    } catch (e) {
      print("Error initializing Breez: $e");
      return;
    }

    GreenlightCredentials greenlightCredentials = GreenlightCredentials(
      developerKey: base64.decode(secrets.greenlightKey),
      developerCert: base64.decode(secrets.greenlightCert),
    );

    NodeConfig breezNodeConfig = NodeConfig.greenlight(
      config: GreenlightNodeConfig(
        partnerCredentials: greenlightCredentials,
        inviteCode: null,
      ),
    );
    Config breezConfig = await _sdk.defaultConfig(
      envType: EnvironmentType.Production,
      apiKey: secrets.breezApiKey,
      nodeConfig: breezNodeConfig,
    );

    String workingDir = await pathForWalletDir(name: walletInfo.name, type: type);
    workingDir = "$workingDir/breez/";

    new Directory(workingDir).createSync(recursive: true);
    breezConfig = breezConfig.copyWith(workingDir: workingDir);

    // disconnect if already connected
    try {
      if (await _sdk.isInitialized()) {
        await _sdk.disconnect();
      }
    } catch (e, s) {
      print("ERROR disconnecting from Breez: $e\n$s");
    }

    try {
      await _sdk.connect(
        req: ConnectRequest(
          config: breezConfig,
          seed: seedBytes,
        ),
      );
    } catch (e, s) {
      print("Error connecting to Breez: $e\n$s");
    }

    await _nodeStateSub?.cancel();
    _nodeStateSub = _sdk.nodeStateStream.listen((event) {
      _handleNodeState(event);
    });
    await _handleNodeState(await _sdk.nodeInfo());

    await _paymentsSub?.cancel();
    _paymentsSub = _sdk.paymentsStream.listen((List<Payment> payments) {
      _handlePayments(payments);
    });
    await _handlePayments(await _sdk.listPayments(req: ListPaymentsRequest()));

    await _invoiceSub?.cancel();
    _invoiceSub = _sdk.invoicePaidStream.listen((InvoicePaidDetails details) {
      _handleInvoicePaid(details);
    });

    print("initialized breez: ${(await _sdk.isInitialized())}");
  }

  Future<void> stopBreez(bool disconnect) async {
    if (disconnect) {
      if (await _sdk.isInitialized()) {
        await _sdk.disconnect();
      }
    }
    await _nodeStateSub?.cancel();
    await _paymentsSub?.cancel();
    await _invoiceSub?.cancel();
    await _logStream?.cancel();
  }

  @action
  @override
  Future<void> startSync() async {
    try {
      syncStatus = AttemptingSyncStatus();
      await updateTransactions();
      await fetchFees();
      syncStatus = SyncedSyncStatus();
    } catch (e) {
      print(e);
      syncStatus = FailedSyncStatus();
      rethrow;
    }
  }

  @override
  Future<void> changePassword(String password) {
    throw UnimplementedError("changePassword");
  }

  @action
  void _onConnectionStatusChange(bool? isConnected) {
    if (syncStatus is SyncingSyncStatus) return;

    if (isConnected == true && syncStatus is! SyncedSyncStatus) {
      syncStatus = ConnectedSyncStatus();
    } else if (isConnected == false) {
      syncStatus = LostConnectionSyncStatus();
    } else if (isConnected != true && syncStatus is! ConnectingSyncStatus) {
      syncStatus = NotConnectedSyncStatus();
    }
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    try {
      syncStatus = ConnectingSyncStatus();
      await updateTransactions();
      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      print(e);
      syncStatus = FailedSyncStatus();
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    throw UnimplementedError("createTransaction");
  }

  Future<void> alertIncomingTxs(Map<String, LightningTransactionInfo> transactions) async {
    for (var tx in transactions.values) {
      // transaction is a receive that we haven't seen before:
      if (tx.direction == TransactionDirection.incoming &&
          transactionHistory.transactions[tx.id] == null) {
        incomingPayments[tx.id] = tx.amount;
      }
    }
  }

  Future<bool> updateTransactions() async {
    try {
      if (_isTransactionUpdating) {
        return false;
      }

      _isTransactionUpdating = true;
      final transactions = await fetchTransactions();
      await alertIncomingTxs(transactions);
      transactionHistory.addMany(transactions);
      await transactionHistory.save();
      _isTransactionUpdating = false;
      return true;
    } catch (_) {
      _isTransactionUpdating = false;
      return false;
    }
  }

  Map<String, LightningTransactionInfo> convertToTxInfo(List<Payment> payments) {
    Map<String, LightningTransactionInfo> transactions = {};

    for (Payment tx in payments) {
      bool pending = tx.status == PaymentStatus.Pending;
      if (tx.status == PaymentStatus.Complete) {
        pending = false;
      }

      bool isSend =
          tx.paymentType == PaymentType.Sent || tx.paymentType == PaymentType.ClosedChannel;
      transactions[tx.id] = LightningTransactionInfo(
        isPending: pending,
        id: tx.id,
        amount: tx.amountMsat ~/ 1000,
        fee: tx.feeMsat ~/ 1000,
        date: DateTime.fromMillisecondsSinceEpoch(tx.paymentTime * 1000),
        direction: isSend ? TransactionDirection.outgoing : TransactionDirection.incoming,
        isChannelClose: tx.paymentType == PaymentType.ClosedChannel,
      );
    }
    return transactions;
  }

  @override
  Future<Map<String, LightningTransactionInfo>> fetchTransactions() async {
    final payments = await _sdk.listPayments(req: ListPaymentsRequest());
    final transactions = convertToTxInfo(payments);

    return transactions;
  }

  @override
  Future<void> rescan({
    required int height,
    int? chainTip,
    ScanData? scanData,
    bool? doSingleScan,
    bool? usingElectrs,
  }) async {
    await updateTransactions();
  }

  @override
  Future<void> init() async {
    await super.init();
    // initialize breez:
    try {
      await setupBreez(seedBytes);
    } catch (e) {
      print("Error initializing Breez: $e");
    }
  }

  String toJSON() => json.encode({
        'mnemonic': mnemonic,
        'account_index': walletAddresses.currentReceiveAddressIndexByType,
        'change_address_index': walletAddresses.currentChangeAddressIndexByType,
        'addresses': walletAddresses.allAddresses.map((addr) => addr.toJSON()).toList(),
        'address_page_type': walletInfo.addressPageType == null
            ? SegwitAddresType.p2wpkh.toString()
            : walletInfo.addressPageType.toString(),
        'balance': balance[currency]?.toJSON(),
        'network_type': network == BitcoinNetwork.testnet ? 'testnet' : 'mainnet',
      });

  Future<void> updateBalance() async {
    await _handleNodeState(await _sdk.nodeInfo());
  }

  Future<String> makePath() async => pathForWallet(name: walletInfo.name, type: walletInfo.type);

  @override
  Future<void> close({bool? switchingToSameWalletType}) async {
    try {
      await electrumClient.close();
    } catch (_) {}
    try {
      bool shouldDisconnect = switchingToSameWalletType == null || !switchingToSameWalletType;
      await stopBreez(shouldDisconnect);
    } catch (e, s) {
      print("Error stopping breez: $e\n$s");
    }
  }

  Future<int> calculateEstimatedFeeAsync(TransactionPriority? priority, int? amount) async {
    if (priority is LightningTransactionPriority) {
      int feeRate = this.feeRate(priority);
      return getEstimatedFeeWithFeeRate(feeRate, amount);
    }
    return 0;
  }

  Future<int> getEstimatedFeeWithFeeRate(int feeRate, int? amount) async {
    try {
      if (amount == null) {
        amount = 0;
      }

      PrepareOnchainPaymentResponse prepareRes = await _sdk.prepareOnchainPayment(
        req: PrepareOnchainPaymentRequest(
          amountSat: amount,
          amountType: SwapAmountType.Send,
          claimTxFeerate: feeRate,
        ),
      );

      print("Sender amount: ${prepareRes.senderAmountSat} sats");
      print("Recipient amount: ${prepareRes.recipientAmountSat} sats");
      print("Total fees: ${prepareRes.totalFees} sats");
      return prepareRes.totalFees;
    } catch (e) {
      print("Error calculating fee: $e");
      return 0;
    }
  }

  @override
  int feeRate(TransactionPriority priority) {
    try {
      if (priority is LightningTransactionPriority) {
        switch (priority) {
          case LightningTransactionPriority.economy:
            return recommendedFees.economyFee;
          case LightningTransactionPriority.fastest:
            return recommendedFees.fastestFee;
          case LightningTransactionPriority.halfhour:
            return recommendedFees.halfHourFee;
          case LightningTransactionPriority.hour:
            return recommendedFees.hourFee;
          case LightningTransactionPriority.minimum:
            return recommendedFees.minimumFee;
          case LightningTransactionPriority.custom:
            throw Exception("Use getEstimatedFeeWithFeeRate instead!");
        }
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> fetchFees() async {
    recommendedFees = await _sdk.recommendedFees();
  }
}
