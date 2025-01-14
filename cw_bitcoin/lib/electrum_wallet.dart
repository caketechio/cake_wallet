import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/electrum_worker/electrum_worker.dart';
import 'package:cw_bitcoin/electrum_worker/electrum_worker_methods.dart';
import 'package:cw_bitcoin/electrum_worker/electrum_worker_params.dart';
import 'package:cw_bitcoin/electrum_worker/methods/methods.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:collection/collection.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/bitcoin_wallet_keys.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_transaction_history.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_bitcoin/exceptions.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/get_height_by_date.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as ledger;
import 'package:mobx/mobx.dart';

part 'electrum_wallet.g.dart';

class ElectrumWallet = ElectrumWalletBase with _$ElectrumWallet;

abstract class ElectrumWalletBase
    extends WalletBase<ElectrumBalance, ElectrumTransactionHistory, ElectrumTransactionInfo>
    with Store, WalletKeysFile {
  ReceivePort? receivePort;
  SendPort? workerSendPort;
  StreamSubscription<dynamic>? _workerSubscription;
  Isolate? _workerIsolate;
  final Map<int, dynamic> _responseCompleters = {};
  final Map<int, dynamic> _errorCompleters = {};
  int _messageId = 0;

  ElectrumWalletBase({
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required this.network,
    required this.encryptionFileUtils,
    Map<CWBitcoinDerivationType, Bip32Slip10Secp256k1>? hdWallets,
    String? xpub,
    String? mnemonic,
    List<int>? seedBytes,
    this.passphrase,
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumBalance? initialBalance,
    CryptoCurrency? currency,
    this.alwaysScan,
    required this.mempoolAPIEnabled,
    List<BitcoinUnspent>? initialUnspentCoins,
  })  : hdWallets = hdWallets ??
            {
              CWBitcoinDerivationType.bip39: getAccountHDWallet(
                currency,
                network,
                seedBytes,
                xpub,
                walletInfo.derivationInfo,
              )
            },
        syncStatus = NotConnectedSyncStatus(),
        _password = password,
        isEnabledAutoGenerateSubaddress = true,
        unspentCoins = BitcoinUnspentCoins.of(initialUnspentCoins ?? []),
        scripthashesListening = [],
        balance = ObservableMap<CryptoCurrency, ElectrumBalance>.of(currency != null
            ? {
                currency: initialBalance ??
                    ElectrumBalance(
                      confirmed: 0,
                      unconfirmed: 0,
                      frozen: 0,
                    )
              }
            : {}),
        this.unspentCoinsInfo = unspentCoinsInfo,
        this.isTestnet = !network.isMainnet,
        this._mnemonic = mnemonic,
        super(walletInfo) {
    this.walletInfo = walletInfo;
    transactionHistory = ElectrumTransactionHistory(
      walletInfo: walletInfo,
      password: password,
      encryptionFileUtils: encryptionFileUtils,
    );

    reaction((_) => syncStatus, syncStatusReaction);

    sharedPrefs.complete(SharedPreferences.getInstance());
  }

  // Sends a request to the worker and returns a future that completes when the worker responds
  Future<dynamic> sendWorker(ElectrumWorkerRequest request) {
    final messageId = ++_messageId;

    final completer = Completer<dynamic>();
    _responseCompleters[messageId] = completer;

    final json = request.toJson();
    json['id'] = messageId;
    workerSendPort!.send(json);

    try {
      return completer.future.timeout(Duration(seconds: 30));
    } catch (e) {
      _errorCompleters.addAll({messageId: e});
      _responseCompleters.remove(messageId);
      rethrow;
    }
  }

  @action
  Future<void> handleWorkerResponse(dynamic message) async {
    // printV('Main: received message: $message');

    Map<String, dynamic> messageJson;
    if (message is String) {
      messageJson = jsonDecode(message) as Map<String, dynamic>;
    } else {
      messageJson = message as Map<String, dynamic>;
    }

    final workerMethod = messageJson['method'] as String;
    final workerError = messageJson['error'] as String?;
    final responseId = messageJson['id'] as int?;

    if (responseId != null && _responseCompleters.containsKey(responseId)) {
      _responseCompleters[responseId]!.complete(message);
      _responseCompleters.remove(responseId);
    }

    switch (workerMethod) {
      case ElectrumWorkerMethods.connectionMethod:
        if (workerError != null) {
          _onConnectionStatusChange(ConnectionStatus.failed);
          break;
        }

        final response = ElectrumWorkerConnectionResponse.fromJson(messageJson);
        _onConnectionStatusChange(response.result);
        break;
      case ElectrumRequestMethods.headersSubscribeMethod:
        final response = ElectrumWorkerHeadersSubscribeResponse.fromJson(messageJson);
        await onHeadersResponse(response.result);
        break;
      case ElectrumRequestMethods.getBalanceMethod:
        final response = ElectrumWorkerGetBalanceResponse.fromJson(messageJson);
        onBalanceResponse(response.result);
        break;
      case ElectrumRequestMethods.getHistoryMethod:
        final response = ElectrumWorkerGetHistoryResponse.fromJson(messageJson);
        onHistoriesResponse(response.result);
        break;
      case ElectrumRequestMethods.listunspentMethod:
        final response = ElectrumWorkerListUnspentResponse.fromJson(messageJson);
        onUnspentResponse(response.result);
        break;
      case ElectrumRequestMethods.estimateFeeMethod:
        final response = ElectrumWorkerGetFeesResponse.fromJson(messageJson);
        onFeesResponse(response.result);
        break;
    }
  }

  static Bip32Slip10Secp256k1 getAccountHDWallet(CryptoCurrency? currency, BasedUtxoNetwork network,
      List<int>? seedBytes, String? xpub, DerivationInfo? derivationInfo) {
    if (seedBytes == null && xpub == null) {
      throw Exception(
          "To create a Wallet you need either a seed or an xpub. This should not happen");
    }

    if (seedBytes != null) {
      return Bip32Slip10Secp256k1.fromSeed(seedBytes);
    }

    return Bip32Slip10Secp256k1.fromExtendedKey(xpub!, getKeyNetVersion(network));
  }

  static Bip32KeyNetVersions? getKeyNetVersion(BasedUtxoNetwork network) {
    switch (network) {
      case LitecoinNetwork.mainnet:
        return Bip44Conf.litecoinMainNet.altKeyNetVer;
      default:
        return null;
    }
  }

  bool? alwaysScan;
  bool mempoolAPIEnabled;
  bool _updatingHistories = false;

  final Map<CWBitcoinDerivationType, Bip32Slip10Secp256k1> hdWallets;
  Bip32Slip10Secp256k1 get bip32 => walletAddresses.hdWallet;
  final String? _mnemonic;

  final EncryptionFileUtils encryptionFileUtils;

  @override
  final String? passphrase;

  @override
  @observable
  bool isEnabledAutoGenerateSubaddress;

  ApiProvider? apiProvider;
  Box<UnspentCoinsInfo> unspentCoinsInfo;

  @override
  late ElectrumWalletAddresses walletAddresses;

  @override
  @observable
  late ObservableMap<CryptoCurrency, ElectrumBalance> balance;

  @override
  @observable
  SyncStatus syncStatus;

  List<String> get addressesSet =>
      walletAddresses.allAddresses.map((addr) => addr.address).toList();

  List<String> get scriptHashes => walletAddresses.addressesOnReceiveScreen
      .map((addr) => (addr as BitcoinAddressRecord).scriptHash)
      .toList();

  List<String> get publicScriptHashes => walletAddresses.allAddresses
      .where((addr) => !addr.isChange)
      .map((addr) => addr.scriptHash)
      .toList();

  String get xpub => bip32.publicKey.toExtended;

  @override
  String? get seed => _mnemonic;

  @override
  WalletKeysData get walletKeysData =>
      WalletKeysData(mnemonic: _mnemonic, xPub: xpub, passphrase: passphrase);

  @override
  String get password => _password;

  BasedUtxoNetwork network;

  @override
  bool isTestnet;

  bool _isTryingToConnect = false;

  Completer<SharedPreferences> sharedPrefs = Completer();

  @observable
  int? currentChainTip;

  @override
  BitcoinWalletKeys get keys => BitcoinWalletKeys(
        wif: WifEncoder.encode(bip32.privateKey.raw, netVer: network.wifNetVer),
        privateKey: bip32.privateKey.toHex(),
        publicKey: bip32.publicKey.toHex(),
      );

  String _password;
  BitcoinUnspentCoins unspentCoins;

  @observable
  TransactionPriorities? feeRates;

  int feeRate(TransactionPriority priority) {
    return feeRates![priority];
  }

  @observable
  List<String> scripthashesListening;

  bool _chainTipListenerOn = false;
  // TODO: improve this
  int _syncedTimes = 0;

  void Function(FlutterErrorDetails)? _onError;
  Timer? _autoSaveTimer;
  Timer? _updateFeeRateTimer;
  static const int _autoSaveInterval = 1;

  Future<void> init() async {
    await walletAddresses.init();
    await transactionHistory.init();

    _autoSaveTimer =
        Timer.periodic(Duration(minutes: _autoSaveInterval), (_) async => await save());
  }

  @action
  @override
  Future<void> startSync() async {
    try {
      if (syncStatus is SynchronizingSyncStatus) {
        return;
      }

      syncStatus = SynchronizingSyncStatus();

      // INFO: FIRST (always): Call subscribe for headers, wait for completion to update currentChainTip (needed for other methods)
      await sendWorker(ElectrumWorkerHeadersSubscribeRequest());

      _syncedTimes = 0;

      // INFO: SECOND: Start loading transaction histories for every address, this will help discover addresses until the unused gap limit has been reached, which will help finding the full balance and unspents next
      await updateTransactions();

      // INFO: THIRD: Get the full wallet's balance with all addresses considered
      await updateBalance();

      // INFO: FOURTH: Finish getting unspent coins for all the addresses
      await updateAllUnspents();

      // INFO: FIFTH: Get the latest recommended fee rates and start update timer
      await updateFeeRates();
      _updateFeeRateTimer ??=
          Timer.periodic(const Duration(seconds: 5), (timer) async => await updateFeeRates());

      if (_syncedTimes == 3) {
        syncStatus = SyncedSyncStatus();
      }

      await save();
    } catch (e, stacktrace) {
      printV(stacktrace);
      printV("startSync $e");
      syncStatus = FailedSyncStatus();
    }
  }

  @action
  void callError(FlutterErrorDetails error) {
    _onError?.call(error);
  }

  @action
  Future<void> updateFeeRates() async {
    workerSendPort!.send(
      ElectrumWorkerGetFeesRequest(mempoolAPIEnabled: mempoolAPIEnabled).toJson(),
    );
  }

  @action
  Future<void> onFeesResponse(TransactionPriorities? result) async {
    if (result != null) {
      feeRates = result;
    }
  }

  Node? node;

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    this.node = node;

    try {
      syncStatus = ConnectingSyncStatus();

      if (_workerIsolate != null) {
        _workerIsolate!.kill(priority: Isolate.immediate);
        _workerSubscription?.cancel();
        receivePort?.close();
      }

      receivePort = ReceivePort();

      _workerIsolate = await Isolate.spawn<SendPort>(ElectrumWorker.run, receivePort!.sendPort);

      _workerSubscription = receivePort!.listen((message) {
        if (message is SendPort) {
          workerSendPort = message;
          workerSendPort!.send(
            ElectrumWorkerConnectionRequest(
              uri: node.uri,
              useSSL: node.useSSL ?? false,
              network: network,
              walletType: walletInfo.type,
            ).toJson(),
          );
        } else {
          handleWorkerResponse(message);
        }
      });
    } catch (e, stacktrace) {
      printV(stacktrace);
      printV("connectToNode $e");
      syncStatus = FailedSyncStatus();
    }
  }

  int get dustAmount => 546;

  bool isBelowDust(int amount) => amount <= dustAmount;

  TxCreateUtxoDetails createUTXOS({
    required bool sendAll,
    int credentialsAmount = 0,
    int? inputsCount,
  }) {
    List<UtxoWithAddress> utxos = [];
    List<Outpoint> vinOutpoints = [];
    List<ECPrivateInfo> inputPrivKeyInfos = [];
    final publicKeys = <String, PublicKeyWithDerivationPath>{};
    int allInputsAmount = 0;
    bool spendsUnconfirmedTX = false;

    int leftAmount = credentialsAmount;
    var availableInputs = unspentCoins.where((utx) {
      if (!utx.isSending || utx.isFrozen) {
        return false;
      }

      return true;
    }).toList();
    final unconfirmedCoins = availableInputs.where((utx) => utx.confirmations == 0).toList();

    for (int i = 0; i < availableInputs.length; i++) {
      final utx = availableInputs[i];
      if (!spendsUnconfirmedTX) spendsUnconfirmedTX = utx.confirmations == 0;

      allInputsAmount += utx.value;
      leftAmount = leftAmount - utx.value;

      final address = RegexUtils.addressTypeFromStr(utx.address, network);
      ECPrivate? privkey;

      if (!isHardwareWallet) {
        final addressRecord = (utx.bitcoinAddressRecord as BitcoinAddressRecord);
        final path = addressRecord.derivationInfo.derivationPath
            .addElem(Bip32KeyIndex(
              BitcoinAddressUtils.getAccountFromChange(addressRecord.isChange),
            ))
            .addElem(Bip32KeyIndex(addressRecord.index));

        privkey = ECPrivate.fromBip32(bip32: bip32.derive(path));
      }

      vinOutpoints.add(Outpoint(txid: utx.hash, index: utx.vout));
      String pubKeyHex;

      if (privkey != null) {
        inputPrivKeyInfos.add(ECPrivateInfo(privkey, address.type == SegwitAddressType.p2tr));

        pubKeyHex = privkey.getPublic().toHex();
      } else {
        pubKeyHex = walletAddresses.hdWallet
            .childKey(Bip32KeyIndex(utx.bitcoinAddressRecord.index))
            .publicKey
            .toHex();
      }

      if (utx.bitcoinAddressRecord is BitcoinAddressRecord) {
        final derivationPath = (utx.bitcoinAddressRecord as BitcoinAddressRecord)
            .derivationInfo
            .derivationPath
            .toString();
        publicKeys[address.pubKeyHash()] = PublicKeyWithDerivationPath(pubKeyHex, derivationPath);
      }

      utxos.add(
        UtxoWithAddress(
          utxo: BitcoinUtxo(
            txHash: utx.hash,
            value: BigInt.from(utx.value),
            vout: utx.vout,
            scriptType: BitcoinAddressUtils.getScriptType(address),
          ),
          ownerDetails: UtxoAddressDetails(
            publicKey: pubKeyHex,
            address: address,
          ),
        ),
      );

      // sendAll continues for all inputs
      if (!sendAll) {
        bool amountIsAcquired = leftAmount <= 0;
        if ((inputsCount == null && amountIsAcquired) || inputsCount == i + 1) {
          break;
        }
      }
    }

    if (utxos.isEmpty) {
      throw BitcoinTransactionNoInputsException();
    }

    return TxCreateUtxoDetails(
      availableInputs: availableInputs,
      unconfirmedCoins: unconfirmedCoins,
      utxos: utxos,
      vinOutpoints: vinOutpoints,
      inputPrivKeyInfos: inputPrivKeyInfos,
      publicKeys: publicKeys,
      allInputsAmount: allInputsAmount,
      spendsUnconfirmedTX: spendsUnconfirmedTX,
    );
  }

  Future<EstimatedTxResult> estimateSendAllTx(
    List<BitcoinOutput> outputs,
    int feeRate, {
    String? memo,
  }) async {
    final utxoDetails = createUTXOS(sendAll: true);

    int fee = await calcFee(
      utxos: utxoDetails.utxos,
      outputs: outputs,
      memo: memo,
      feeRate: feeRate,
    );

    if (fee == 0) {
      throw BitcoinTransactionNoFeeException();
    }

    // Here, when sending all, the output amount equals to the input value - fee to fully spend every input on the transaction and have no amount left for change
    int amount = utxoDetails.allInputsAmount - fee;

    if (amount <= 0) {
      throw BitcoinTransactionWrongBalanceException(amount: utxoDetails.allInputsAmount + fee);
    }

    // Attempting to send less than the dust limit
    if (isBelowDust(amount)) {
      throw BitcoinTransactionNoDustException();
    }

    if (outputs.length == 1) {
      outputs[0] = BitcoinOutput(address: outputs.last.address, value: BigInt.from(amount));
    }

    return EstimatedTxResult(
      utxos: utxoDetails.utxos,
      inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
      publicKeys: utxoDetails.publicKeys,
      fee: fee,
      amount: amount,
      isSendAll: true,
      hasChange: false,
      memo: memo,
      spendsUnconfirmedTX: utxoDetails.spendsUnconfirmedTX,
    );
  }

  Future<EstimatedTxResult> estimateTxForAmount(
    int credentialsAmount,
    List<BitcoinOutput> outputs,
    int feeRate, {
    int? inputsCount,
    String? memo,
    bool? useUnconfirmed,
    bool isFakeTx = false,
  }) async {
    // Attempting to send less than the dust limit
    if (!isFakeTx && isBelowDust(credentialsAmount)) {
      throw BitcoinTransactionNoDustException();
    }

    final utxoDetails = createUTXOS(
      sendAll: false,
      credentialsAmount: credentialsAmount,
      inputsCount: inputsCount,
    );

    final spendingAllCoins = utxoDetails.availableInputs.length == utxoDetails.utxos.length;
    final spendingAllConfirmedCoins = !utxoDetails.spendsUnconfirmedTX &&
        utxoDetails.utxos.length ==
            utxoDetails.availableInputs.length - utxoDetails.unconfirmedCoins.length;

    // How much is being spent - how much is being sent
    int amountLeftForChangeAndFee = utxoDetails.allInputsAmount - credentialsAmount;

    if (amountLeftForChangeAndFee <= 0) {
      if (!spendingAllCoins) {
        return estimateTxForAmount(
          credentialsAmount,
          outputs,
          feeRate,
          inputsCount: utxoDetails.utxos.length + 1,
          memo: memo,
          isFakeTx: isFakeTx,
        );
      }

      throw BitcoinTransactionWrongBalanceException();
    }

    final changeAddress = await walletAddresses.getChangeAddress(
      inputs: utxoDetails.availableInputs,
      outputs: outputs,
    );
    final address = RegexUtils.addressTypeFromStr(changeAddress.address, network);
    outputs.add(BitcoinOutput(
      address: address,
      value: BigInt.from(amountLeftForChangeAndFee),
      isChange: true,
    ));

    final changeDerivationPath =
        (changeAddress as BitcoinAddressRecord).derivationInfo.derivationPath.toString();
    utxoDetails.publicKeys[address.pubKeyHash()] =
        PublicKeyWithDerivationPath('', changeDerivationPath);

    int fee = calcFee(
      utxos: utxoDetails.utxos,
      outputs: outputs,
      memo: memo,
      feeRate: feeRate,
    );

    if (fee == 0) {
      throw BitcoinTransactionNoFeeException();
    }

    int amount = credentialsAmount;
    final lastOutput = outputs.last;
    final amountLeftForChange = amountLeftForChangeAndFee - fee;

    if (!isFakeTx && isBelowDust(amountLeftForChange)) {
      // If has change that is lower than dust, will end up with tx rejected by network rules
      // so remove the change amount
      outputs.removeLast();
      outputs.removeLast();

      if (amountLeftForChange < 0) {
        if (!spendingAllCoins) {
          return estimateTxForAmount(
            credentialsAmount,
            outputs,
            feeRate,
            inputsCount: utxoDetails.utxos.length + 1,
            memo: memo,
            useUnconfirmed: useUnconfirmed ?? spendingAllConfirmedCoins,
            isFakeTx: isFakeTx,
          );
        } else {
          throw BitcoinTransactionWrongBalanceException();
        }
      }

      return EstimatedTxResult(
        utxos: utxoDetails.utxos,
        inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
        publicKeys: utxoDetails.publicKeys,
        fee: fee,
        amount: amount,
        hasChange: false,
        isSendAll: spendingAllCoins,
        memo: memo,
        spendsUnconfirmedTX: utxoDetails.spendsUnconfirmedTX,
      );
    } else {
      // Here, lastOutput already is change, return the amount left without the fee to the user's address.
      outputs[outputs.length - 1] = BitcoinOutput(
        address: lastOutput.address,
        value: BigInt.from(amountLeftForChange),
        isChange: true,
      );

      return EstimatedTxResult(
        utxos: utxoDetails.utxos,
        inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
        publicKeys: utxoDetails.publicKeys,
        fee: fee,
        amount: amount,
        hasChange: true,
        isSendAll: spendingAllCoins,
        memo: memo,
        spendsUnconfirmedTX: utxoDetails.spendsUnconfirmedTX,
      );
    }
  }

  int calcFee({
    required List<UtxoWithAddress> utxos,
    required List<BitcoinBaseOutput> outputs,
    String? memo,
    required int feeRate,
  }) =>
      feeRate *
      BitcoinTransactionBuilder.estimateTransactionSize(
        utxos: utxos,
        outputs: outputs,
        network: network,
        memo: memo,
      );

  CreateTxData getCreateTxDataFromCredentials(Object credentials) {
    final outputs = <BitcoinOutput>[];
    final transactionCredentials = credentials as BitcoinTransactionCredentials;
    final hasMultiDestination = transactionCredentials.outputs.length > 1;
    final sendAll = !hasMultiDestination && transactionCredentials.outputs.first.sendAll;
    final memo = transactionCredentials.outputs.first.memo;

    int credentialsAmount = 0;

    for (final out in transactionCredentials.outputs) {
      final outputAmount = out.formattedCryptoAmount!;

      if (!sendAll && isBelowDust(outputAmount)) {
        throw BitcoinTransactionNoDustException();
      }

      if (hasMultiDestination) {
        if (out.sendAll) {
          throw BitcoinTransactionWrongBalanceException();
        }
      }

      credentialsAmount += outputAmount;

      final address = RegexUtils.addressTypeFromStr(
        out.isParsedAddress ? out.extractedAddress! : out.address,
        network,
      );

      if (sendAll) {
        outputs.add(
          BitcoinOutput(
            address: address,
            // Send all: The value of the single existing output will be updated
            // after estimating the Tx size and deducting the fee from the total to be sent
            value: BigInt.from(0),
          ),
        );
      } else {
        outputs.add(
          BitcoinOutput(
            address: address,
            value: BigInt.from(outputAmount),
          ),
        );
      }
    }

    final feeRateInt = transactionCredentials.feeRate != null
        ? transactionCredentials.feeRate!
        : feeRate(transactionCredentials.priority!);

    return CreateTxData(
      sendAll: sendAll,
      amount: credentialsAmount,
      outputs: outputs,
      feeRate: feeRateInt,
      memo: memo,
    );
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    try {
      final data = getCreateTxDataFromCredentials(credentials);

      EstimatedTxResult estimatedTx;
      if (data.sendAll) {
        estimatedTx = await estimateSendAllTx(
          data.outputs,
          data.feeRate,
          memo: data.memo,
        );
      } else {
        estimatedTx = await estimateTxForAmount(
          data.amount,
          data.outputs,
          data.feeRate,
          memo: data.memo,
        );
      }

      if (walletInfo.isHardwareWallet) {
        final transaction = await buildHardwareWalletTransaction(
          utxos: estimatedTx.utxos,
          outputs: data.outputs,
          publicKeys: estimatedTx.publicKeys,
          fee: BigInt.from(estimatedTx.fee),
          memo: estimatedTx.memo,
          outputOrdering: BitcoinOrdering.none,
          enableRBF: true,
        );

        return PendingBitcoinTransaction(
          transaction,
          type,
          sendWorker: sendWorker,
          amount: estimatedTx.amount,
          fee: estimatedTx.fee,
          feeRate: data.feeRate.toString(),
          hasChange: estimatedTx.hasChange,
          isSendAll: estimatedTx.isSendAll,
          hasTaprootInputs: false, // ToDo: (Konsti) Support Taproot
        )..addListener((transaction) async {
            transactionHistory.addOne(transaction);
            await updateBalance();
            await updateAllUnspents();
          });
      }

      BasedBitcoinTransacationBuilder txb;
      if (network is BitcoinCashNetwork) {
        txb = ForkedTransactionBuilder(
          utxos: estimatedTx.utxos,
          outputs: data.outputs,
          fee: BigInt.from(estimatedTx.fee),
          network: network,
          memo: estimatedTx.memo,
          outputOrdering: BitcoinOrdering.none,
          enableRBF: !estimatedTx.spendsUnconfirmedTX,
        );
      } else {
        txb = BitcoinTransactionBuilder(
          utxos: estimatedTx.utxos,
          outputs: data.outputs,
          fee: BigInt.from(estimatedTx.fee),
          network: network,
          memo: estimatedTx.memo,
          outputOrdering: BitcoinOrdering.none,
          enableRBF: !estimatedTx.spendsUnconfirmedTX,
        );
      }

      bool hasTaprootInputs = false;

      final transaction = txb.buildTransaction((txDigest, utxo, publicKey, sighash) {
        String error = "Cannot find private key.";

        ECPrivateInfo? key;

        if (estimatedTx.inputPrivKeyInfos.isEmpty) {
          error += "\nNo private keys generated.";
        } else {
          error += "\nAddress: ${utxo.ownerDetails.address.toAddress(network)}";

          key = estimatedTx.inputPrivKeyInfos.firstWhereOrNull((element) {
            final elemPubkey = element.privkey.getPublic().toHex();
            if (elemPubkey == publicKey) {
              return true;
            } else {
              error += "\nExpected: $publicKey";
              error += "\nPubkey: $elemPubkey";
              return false;
            }
          });
        }

        if (key == null) {
          throw Exception(error);
        }

        if (utxo.utxo.isP2tr) {
          hasTaprootInputs = true;
          return key.privkey.signTapRoot(txDigest, sighash: sighash);
        } else {
          return key.privkey.signInput(txDigest, sigHash: sighash);
        }
      });

      return PendingBitcoinTransaction(
        transaction,
        type,
        sendWorker: sendWorker,
        amount: estimatedTx.amount,
        fee: estimatedTx.fee,
        feeRate: data.feeRate.toString(),
        hasChange: estimatedTx.hasChange,
        isSendAll: estimatedTx.isSendAll,
        hasTaprootInputs: hasTaprootInputs,
        utxos: estimatedTx.utxos,
      )..addListener((transaction) async {
          transactionHistory.addOne(transaction);

          unspentCoins
              .removeWhere((utxo) => estimatedTx.utxos.any((e) => e.utxo.txHash == utxo.hash));

          await updateBalance();
          await updateAllUnspents();
        });
    } catch (e) {
      throw e;
    }
  }

  void setLedgerConnection(ledger.LedgerConnection connection) => throw UnimplementedError();

  Future<BtcTransaction> buildHardwareWalletTransaction({
    required List<BitcoinBaseOutput> outputs,
    required BigInt fee,
    required List<UtxoWithAddress> utxos,
    required Map<String, PublicKeyWithDerivationPath> publicKeys,
    String? memo,
    bool enableRBF = false,
    BitcoinOrdering inputOrdering = BitcoinOrdering.bip69,
    BitcoinOrdering outputOrdering = BitcoinOrdering.bip69,
  }) async =>
      throw UnimplementedError();

  String toJSON() => json.encode({
        'mnemonic': _mnemonic,
        'xpub': xpub,
        'passphrase': passphrase ?? '',
        'walletAddresses': walletAddresses.toJson(),
        'address_page_type': walletInfo.addressPageType == null
            ? SegwitAddressType.p2wpkh.toString()
            : walletInfo.addressPageType.toString(),
        'balance': balance[currency]?.toJSON(),
        'derivationTypeIndex': walletInfo.derivationInfo?.derivationType?.index,
        'derivationPath': walletInfo.derivationInfo?.derivationPath,
        'alwaysScan': alwaysScan,
        'unspents': unspentCoins.map((e) => e.toJson()).toList(),
      });

  int estimatedTransactionSize({
    required List<BitcoinAddressType> inputTypes,
    required List<BitcoinAddressType> outputTypes,
    String? memo,
    bool enableRBF = true,
  }) =>
      BitcoinTransactionBuilder.estimateTransactionSizeFromTypes(
        inputTypes: inputTypes,
        outputTypes: outputTypes,
        network: network,
        memo: memo,
        enableRBF: enableRBF,
      );

  int feeAmountForPriority(
    TransactionPriority priority, {
    required List<BitcoinAddressType> inputTypes,
    required List<BitcoinAddressType> outputTypes,
    String? memo,
    bool enableRBF = true,
  }) =>
      feeRate(priority) *
      estimatedTransactionSize(
        inputTypes: inputTypes,
        outputTypes: outputTypes,
        memo: memo,
        enableRBF: enableRBF,
      );

  int feeAmountWithFeeRate(
    int feeRate, {
    required List<BitcoinAddressType> inputTypes,
    required List<BitcoinAddressType> outputTypes,
    String? memo,
    bool enableRBF = true,
  }) =>
      feeRate *
      estimatedTransactionSize(
        inputTypes: inputTypes,
        outputTypes: outputTypes,
        memo: memo,
        enableRBF: enableRBF,
      );

  @override
  Future<int> calculateEstimatedFee(
    TransactionPriority priority, {
    List<String> outputAddresses = const [],
    String? memo,
    bool enableRBF = true,
  }) async {
    return estimatedFeeForOutputsWithFeeRate(
      feeRate: feeRate(priority),
      outputAddresses: outputAddresses,
      memo: memo,
      enableRBF: enableRBF,
    );
  }

  // Estimates the fee for paying to the given outputs
  // using the wallet's available unspent coins as inputs
  Future<int> estimatedFeeForOutputsWithFeeRate({
    required int feeRate,
    required List<String> outputAddresses,
    String? memo,
    bool enableRBF = true,
  }) async {
    final fakePublicKey = ECPrivate.random().getPublic();
    final fakeOutputs = <BitcoinOutput>[];
    final outputTypes =
        outputAddresses.map((e) => BitcoinAddressUtils.addressTypeFromStr(e, network)).toList();

    for (final outputType in outputTypes) {
      late BitcoinBaseAddress address;
      switch (outputType) {
        case P2pkhAddressType.p2pkh:
          address = fakePublicKey.toP2pkhAddress();
          break;
        case P2shAddressType.p2pkInP2sh:
          address = fakePublicKey.toP2pkhInP2sh();
          break;
        case SegwitAddressType.p2wpkh:
          address = fakePublicKey.toP2wpkhAddress();
          break;
        case P2shAddressType.p2pkhInP2sh:
          address = fakePublicKey.toP2pkhInP2sh();
          break;
        case SegwitAddressType.p2wsh:
          address = fakePublicKey.toP2wshAddress();
          break;
        case SegwitAddressType.p2tr:
          address = fakePublicKey.toTaprootAddress();
          break;
        default:
          throw const FormatException('Invalid output type');
      }

      fakeOutputs.add(BitcoinOutput(address: address, value: BigInt.from(0)));
    }

    final estimatedFakeTx = await estimateTxForAmount(
      0,
      fakeOutputs,
      feeRate,
      memo: memo,
      isFakeTx: true,
    );
    final inputTypes = estimatedFakeTx.utxos.map((e) => e.ownerDetails.address.type).toList();

    return feeAmountWithFeeRate(
      feeRate,
      inputTypes: inputTypes,
      outputTypes: outputTypes,
      memo: memo,
      enableRBF: enableRBF,
    );
  }

  @override
  Future<void> save() async {
    if (!(await WalletKeysFile.hasKeysFile(walletInfo.name, walletInfo.type))) {
      await saveKeysFile(_password, encryptionFileUtils);
      await saveKeysFile(_password, encryptionFileUtils, true);
    }

    final path = await makePath();
    await encryptionFileUtils.write(path: path, password: _password, data: toJSON());
    await transactionHistory.save();
  }

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
  Future<void> changePassword(String password) async {
    _password = password;
    await save();
    await transactionHistory.changePassword(password);
  }

  @override
  Future<void> rescan({required int height}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> close({bool shouldCleanup = false}) async {
    try {
      _workerIsolate!.kill(priority: Isolate.immediate);
      await _workerSubscription?.cancel();
      receivePort?.close();
    } catch (_) {}
    _autoSaveTimer?.cancel();
    _updateFeeRateTimer?.cancel();
  }

  @action
  Future<void> updateAllUnspents() async {
    workerSendPort!.send(
      ElectrumWorkerListUnspentRequest(
        scripthashes: walletAddresses.allScriptHashes.toList(),
      ).toJson(),
    );
  }

  @action
  void updateCoin(BitcoinUnspent coin) {
    final coinInfoList = unspentCoinsInfo.values.where(
      (element) =>
          element.walletId.contains(id) &&
          element.hash.contains(coin.hash) &&
          element.vout == coin.vout,
    );

    if (coinInfoList.isNotEmpty) {
      final coinInfo = coinInfoList.first;

      coin.isFrozen = coinInfo.isFrozen;
      coin.isSending = coinInfo.isSending;
      coin.note = coinInfo.note;
    } else {
      addCoinInfo(coin);
    }
  }

  @action
  Future<void> onUnspentResponse(Map<String, List<ElectrumUtxo>> unspents) async {
    final updatedUnspentCoins = <BitcoinUnspent>[];

    await Future.wait(unspents.entries.map((entry) async {
      final unspent = entry.value;
      final scriptHash = entry.key;

      final addressRecord = walletAddresses.allAddresses.firstWhereOrNull(
        (element) => element.scriptHash == scriptHash,
      );

      if (addressRecord == null) {
        return null;
      }

      await Future.wait(unspent.map((unspent) async {
        final coin = BitcoinUnspent.fromJSON(addressRecord, unspent.toJson());
        coin.isChange = addressRecord.isChange;
        final tx = await fetchTransactionInfo(hash: coin.hash);
        if (tx != null) {
          coin.confirmations = tx.confirmations;
        }

        updatedUnspentCoins.add(coin);
      }));
    }));

    unspentCoins.addAll(updatedUnspentCoins);
    unspentCoins.forEach(updateCoin);

    await refreshUnspentCoinsInfo();

    _syncedTimes++;
    if (_syncedTimes == 3) {
      syncStatus = SyncedSyncStatus();
    }
  }

  @action
  Future<void> addCoinInfo(BitcoinUnspent coin) async {
    // Check if the coin is already in the unspentCoinsInfo for the wallet
    final existingCoinInfo = unspentCoinsInfo.values
        .firstWhereOrNull((element) => element.walletId == walletInfo.id && element == coin);

    if (existingCoinInfo == null) {
      final newInfo = UnspentCoinsInfo(
        walletId: id,
        hash: coin.hash,
        isFrozen: coin.isFrozen,
        isSending: coin.isSending,
        noteRaw: coin.note,
        address: coin.bitcoinAddressRecord.address,
        value: coin.value,
        vout: coin.vout,
        isChange: coin.isChange,
        isSilentPayment: coin.address is BitcoinReceivedSPAddressRecord,
      );

      await unspentCoinsInfo.add(newInfo);
    }
  }

  Future<void> refreshUnspentCoinsInfo() async {
    try {
      final List<dynamic> keys = [];
      final currentWalletUnspentCoins =
          unspentCoinsInfo.values.where((record) => record.walletId == id);

      for (final element in currentWalletUnspentCoins) {
        final existUnspentCoins = unspentCoins.where((coin) => element == coin);

        if (existUnspentCoins.isEmpty) {
          keys.add(element.key);
        }
      }

      if (keys.isNotEmpty) {
        await unspentCoinsInfo.deleteAll(keys);
      }
    } catch (e) {
      printV("refreshUnspentCoinsInfo $e");
    }
  }

  @action
  Future<void> onHeadersResponse(ElectrumHeaderResponse response) async {
    currentChainTip = response.height;

    bool updated = false;
    transactionHistory.transactions.values.forEach((tx) {
      if (tx.height != null && tx.height! > 0) {
        final newConfirmations = currentChainTip! - tx.height! + 1;

        if (tx.confirmations != newConfirmations) {
          tx.confirmations = newConfirmations;
          tx.isPending = tx.confirmations == 0;
          updated = true;
        }
      }
    });

    if (updated) {
      await save();
    }
  }

  @action
  Future<void> subscribeForHeaders() async {
    if (_chainTipListenerOn) return;

    workerSendPort!.send(ElectrumWorkerHeadersSubscribeRequest().toJson());
    _chainTipListenerOn = true;
  }

  @action
  Future<void> onHistoriesResponse(List<AddressHistoriesResponse> histories) async {
    if (histories.isEmpty || _updatingHistories) {
      _updatingHistories = false;
      _syncedTimes++;
      if (_syncedTimes == 3) {
        syncStatus = SyncedSyncStatus();
      }

      return;
    }

    _updatingHistories = true;

    final addressesWithHistory = <BitcoinAddressRecord>[];
    BitcoinAddressType? lastDiscoveredType;

    for (final addressHistory in histories) {
      final txs = addressHistory.txs;

      if (txs.isNotEmpty) {
        final addressRecord = addressHistory.addressRecord;
        final isChange = addressRecord.isChange;

        final addressList =
            (isChange ? walletAddresses.changeAddresses : walletAddresses.receiveAddresses).where(
                (element) =>
                    element.type == addressRecord.type &&
                    element.cwDerivationType == addressRecord.cwDerivationType);
        final totalAddresses = addressList.length;

        final gapLimit = (isChange
            ? ElectrumWalletAddressesBase.defaultChangeAddressesCount
            : ElectrumWalletAddressesBase.defaultReceiveAddressesCount);

        addressesWithHistory.add(addressRecord);

        for (final tx in txs) {
          transactionHistory.addOne(tx);
        }

        final hasUsedAddressesUnderGap = addressRecord.index >= totalAddresses - gapLimit;

        if (hasUsedAddressesUnderGap && lastDiscoveredType != addressRecord.type) {
          lastDiscoveredType = addressRecord.type;

          // Discover new addresses for the same address type until the gap limit is respected
          final newAddresses = await walletAddresses.discoverNewAddresses(
            isChange: isChange,
            derivationType: addressRecord.cwDerivationType,
            addressType: addressRecord.type,
            derivationInfo: BitcoinAddressUtils.getDerivationFromType(
              addressRecord.type,
              isElectrum: [
                CWBitcoinDerivationType.electrum,
                CWBitcoinDerivationType.old_electrum,
              ].contains(addressRecord.cwDerivationType),
            ),
          );
          walletAddresses.updateAdresses(newAddresses);

          final newAddressList =
              (isChange ? walletAddresses.changeAddresses : walletAddresses.receiveAddresses).where(
                  (element) =>
                      element.type == addressRecord.type &&
                      element.cwDerivationType == addressRecord.cwDerivationType);
          printV(
              "discovered ${newAddresses.length} new addresses, new total: ${newAddressList.length}");

          if (newAddresses.isNotEmpty) {
            // Update the transactions for the new discovered addresses
            await updateTransactions(newAddresses);
          }
        }
      }
    }

    if (addressesWithHistory.isNotEmpty) {
      walletAddresses.updateAdresses(addressesWithHistory);
    }

    walletAddresses.updateHiddenAddresses();
    _updatingHistories = false;

    _syncedTimes++;
    if (_syncedTimes == 3) {
      syncStatus = SyncedSyncStatus();
    }
  }

  Future<String?> canReplaceByFee(ElectrumTransactionInfo tx) async {
    try {
      final bundle = await getTransactionExpanded(hash: tx.txHash);
      _updateInputsAndOutputs(tx, bundle);
      if (bundle.confirmations > 0) return null;
      return bundle.originalTransaction.canReplaceByFee ? bundle.originalTransaction.toHex() : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isChangeSufficientForFee(String txId, int newFee) async {
    final bundle = await getTransactionExpanded(hash: txId);
    final outputs = bundle.originalTransaction.outputs;

    final ownAddresses = walletAddresses.allAddresses.map((addr) => addr.address).toSet();

    final receiverAmount = outputs
        .where(
          (output) => !ownAddresses.contains(
            BitcoinAddressUtils.addressFromOutputScript(output.scriptPubKey, network),
          ),
        )
        .fold<int>(0, (sum, output) => sum + output.amount.toInt());

    if (receiverAmount == 0) {
      throw Exception("Receiver output not found.");
    }

    final availableInputs = unspentCoins.where((utxo) => utxo.isSending && !utxo.isFrozen).toList();
    int totalBalance = availableInputs.fold<int>(
        0, (previousValue, element) => previousValue + element.value.toInt());

    int allInputsAmount = 0;
    for (int i = 0; i < bundle.originalTransaction.inputs.length; i++) {
      final input = bundle.originalTransaction.inputs[i];
      final inputTransaction = bundle.ins[i];
      final vout = input.txIndex;
      final outTransaction = inputTransaction.outputs[vout];
      allInputsAmount += outTransaction.amount.toInt();
    }

    int totalOutAmount = bundle.originalTransaction.outputs
        .fold<int>(0, (previousValue, element) => previousValue + element.amount.toInt());
    var currentFee = allInputsAmount - totalOutAmount;

    int remainingFee = (newFee - currentFee > 0) ? newFee - currentFee : newFee;
    return totalBalance - receiverAmount - remainingFee >= dustAmount;
  }

  Future<PendingBitcoinTransaction> replaceByFee(String hash, int newFee) async {
    try {
      final bundle = await getTransactionExpanded(hash: hash);

      final utxos = <UtxoWithAddress>[];
      final outputs = <BitcoinOutput>[];
      List<ECPrivate> privateKeys = [];

      var allInputsAmount = 0;
      String? memo;

      // Add original inputs
      for (var i = 0; i < bundle.originalTransaction.inputs.length; i++) {
        final input = bundle.originalTransaction.inputs[i];
        final inputTransaction = bundle.ins[i];
        final vout = input.txIndex;
        final outTransaction = inputTransaction.outputs[vout];
        final address =
            BitcoinAddressUtils.addressFromOutputScript(outTransaction.scriptPubKey, network);
        allInputsAmount += outTransaction.amount.toInt();

        final addressRecord =
            walletAddresses.allAddresses.firstWhere((element) => element.address == address);
        final btcAddress = RegexUtils.addressTypeFromStr(addressRecord.address, network);
        final path = addressRecord.derivationInfo.derivationPath
            .addElem(Bip32KeyIndex(
              BitcoinAddressUtils.getAccountFromChange(addressRecord.isChange),
            ))
            .addElem(Bip32KeyIndex(addressRecord.index));

        final privkey = ECPrivate.fromBip32(bip32: bip32.derive(path));

        privateKeys.add(privkey);

        utxos.add(
          UtxoWithAddress(
            utxo: BitcoinUtxo(
              txHash: input.txId,
              value: outTransaction.amount,
              vout: vout,
              scriptType: BitcoinAddressUtils.getScriptType(btcAddress),
            ),
            ownerDetails:
                UtxoAddressDetails(publicKey: privkey.getPublic().toHex(), address: btcAddress),
          ),
        );
      }

      // Add original outputs
      for (final out in bundle.originalTransaction.outputs) {
        final script = out.scriptPubKey.script;
        if (script.contains('OP_RETURN') && memo == null) {
          final index = script.indexOf('OP_RETURN');
          if (index + 1 <= script.length) {
            try {
              final opReturnData = script[index + 1].toString();
              memo = StringUtils.decode(BytesUtils.fromHexString(opReturnData));
              continue;
            } catch (_) {
              throw Exception('Cannot decode OP_RETURN data');
            }
          }
        }

        final address = BitcoinAddressUtils.addressFromOutputScript(out.scriptPubKey, network);
        final btcAddress = RegexUtils.addressTypeFromStr(address, network);
        outputs.add(BitcoinOutput(address: btcAddress, value: BigInt.from(out.amount.toInt())));
      }

      // Calculate the total amount and fees
      int totalOutAmount =
          outputs.fold<int>(0, (previousValue, output) => previousValue + output.value.toInt());
      int currentFee = allInputsAmount - totalOutAmount;
      int remainingFee = newFee - currentFee;

      if (remainingFee <= 0) {
        throw Exception("New fee must be higher than the current fee.");
      }

      // Deduct fee from change outputs first, if possible
      if (remainingFee > 0) {
        final changeAddresses = walletAddresses.allAddresses.where((element) => element.isHidden);
        for (int i = outputs.length - 1; i >= 0; i--) {
          final output = outputs[i];
          final isChange = changeAddresses
              .any((element) => element.address == output.address.toAddress(network));

          if (isChange) {
            int outputAmount = output.value.toInt();
            if (outputAmount > dustAmount) {
              int deduction = (outputAmount - dustAmount >= remainingFee)
                  ? remainingFee
                  : outputAmount - dustAmount;
              outputs[i] = BitcoinOutput(
                  address: output.address, value: BigInt.from(outputAmount - deduction));
              remainingFee -= deduction;

              if (remainingFee <= 0) break;
            }
          }
        }
      }

      // If still not enough, add UTXOs until the fee is covered
      if (remainingFee > 0) {
        final unusedUtxos = unspentCoins
            .where((utxo) => utxo.isSending && !utxo.isFrozen && utxo.confirmations! > 0)
            .toList();

        for (final utxo in unusedUtxos) {
          final address = RegexUtils.addressTypeFromStr(utxo.address, network);
          final privkey = ECPrivate.fromBip32(bip32: bip32);
          privateKeys.add(privkey);

          utxos.add(
            UtxoWithAddress(
              utxo: BitcoinUtxo(
                  txHash: utxo.hash,
                  value: BigInt.from(utxo.value),
                  vout: utxo.vout,
                  scriptType: BitcoinAddressUtils.getScriptType(address)),
              ownerDetails:
                  UtxoAddressDetails(publicKey: privkey.getPublic().toHex(), address: address),
            ),
          );

          allInputsAmount += utxo.value;
          remainingFee -= utxo.value;

          if (remainingFee < 0) {
            final changeOutput = outputs.firstWhereOrNull((output) => walletAddresses.allAddresses
                .any((addr) => addr.address == output.address.toAddress(network)));
            if (changeOutput != null) {
              final newValue = changeOutput.value.toInt() + (-remainingFee);
              outputs[outputs.indexOf(changeOutput)] =
                  BitcoinOutput(address: changeOutput.address, value: BigInt.from(newValue));
            } else {
              final changeAddress = await walletAddresses.getChangeAddress();
              outputs.add(BitcoinOutput(
                  address: RegexUtils.addressTypeFromStr(changeAddress.address, network),
                  value: BigInt.from(-remainingFee)));
            }

            remainingFee = 0;
            break;
          }

          if (remainingFee <= 0) break;
        }
      }

      // Deduct from the receiver's output if remaining fee is still greater than 0
      if (remainingFee > 0) {
        for (int i = 0; i < outputs.length; i++) {
          final output = outputs[i];
          int outputAmount = output.value.toInt();

          if (outputAmount > dustAmount) {
            int deduction = (outputAmount - dustAmount >= remainingFee)
                ? remainingFee
                : outputAmount - dustAmount;

            outputs[i] = BitcoinOutput(
                address: output.address, value: BigInt.from(outputAmount - deduction));
            remainingFee -= deduction;

            if (remainingFee <= 0) break;
          }
        }
      }

      // Final check if the remaining fee couldn't be deducted
      if (remainingFee > 0) {
        throw Exception("Not enough funds to cover the fee.");
      }

      // Identify all change outputs
      final changeAddresses = walletAddresses.changeAddresses;
      final List<BitcoinOutput> changeOutputs = outputs
          .where((output) => changeAddresses
              .any((element) => element.address == output.address.toAddress(network)))
          .toList();

      int totalChangeAmount =
          changeOutputs.fold<int>(0, (sum, output) => sum + output.value.toInt());

      // The final amount that the receiver will receive
      int sendingAmount = allInputsAmount - newFee - totalChangeAmount;

      final txb = BitcoinTransactionBuilder(
        utxos: utxos,
        outputs: outputs,
        fee: BigInt.from(newFee),
        network: network,
        memo: memo,
        outputOrdering: BitcoinOrdering.none,
        enableRBF: true,
      );

      final transaction = txb.buildTransaction((txDigest, utxo, publicKey, sighash) {
        final key =
            privateKeys.firstWhereOrNull((element) => element.getPublic().toHex() == publicKey);
        if (key == null) {
          throw Exception("Cannot find private key");
        }

        if (utxo.utxo.isP2tr) {
          return key.signTapRoot(txDigest, sighash: sighash);
        } else {
          return key.signInput(txDigest, sigHash: sighash);
        }
      });

      return PendingBitcoinTransaction(
        transaction,
        type,
        sendWorker: sendWorker,
        amount: sendingAmount,
        fee: newFee,
        hasChange: changeOutputs.isNotEmpty,
        feeRate: newFee.toString(),
      )..addListener((transaction) async {
          transactionHistory.transactions.values.forEach((tx) {
            if (tx.id == hash) {
              tx.isReplaced = true;
              tx.isPending = false;
              transactionHistory.addOne(tx);
            }
          });
          transactionHistory.addOne(transaction);
          await updateBalance();
          await updateAllUnspents();
        });
    } catch (e) {
      throw e;
    }
  }

  Future<ElectrumTransactionBundle> getTransactionExpanded({required String hash}) async {
    return await sendWorker(
      ElectrumWorkerTxExpandedRequest(
        txHash: hash,
        currentChainTip: currentChainTip!,
        mempoolAPIEnabled: mempoolAPIEnabled,
      ),
    ) as ElectrumTransactionBundle;
  }

  Future<ElectrumTransactionInfo?> fetchTransactionInfo({required String hash, int? height}) async {
    try {
      return ElectrumTransactionInfo.fromElectrumBundle(
        await getTransactionExpanded(hash: hash),
        walletInfo.type,
        network,
        addresses: walletAddresses.allAddresses.map((e) => e.address).toSet(),
        height: height,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  @action
  Future<Map<String, ElectrumTransactionInfo>> fetchTransactions() async {
    throw UnimplementedError();
  }

  @action
  Future<void> updateTransactions([List<BitcoinAddressRecord>? addresses]) async {
    workerSendPort!.send(ElectrumWorkerGetHistoryRequest(
      addresses: walletAddresses.allAddresses.toList(),
      storedTxs: transactionHistory.transactions.values.toList(),
      walletType: type,
      // If we still don't have currentChainTip, txs will still be fetched but shown
      // with confirmations as 0 but will be auto fixed on onHeadersResponse
      chainTip: currentChainTip ?? getBitcoinHeightByDate(date: DateTime.now()),
      network: network,
      mempoolAPIEnabled: mempoolAPIEnabled,
    ).toJson());
  }

  @action
  Future<void> subscribeForUpdates([Iterable<String>? unsubscribedScriptHashes]) async {
    unsubscribedScriptHashes ??= walletAddresses.allScriptHashes.where(
      (sh) => !scripthashesListening.contains(sh),
    );

    Map<String, String> scripthashByAddress = {};
    walletAddresses.allAddresses.forEach((addressRecord) {
      scripthashByAddress[addressRecord.address] = addressRecord.scriptHash;
    });

    workerSendPort!.send(
      ElectrumWorkerScripthashesSubscribeRequest(
        scripthashByAddress: scripthashByAddress,
      ).toJson(),
    );

    scripthashesListening.addAll(scripthashByAddress.values);
  }

  @action
  void onBalanceResponse(ElectrumBalance balanceResult) {
    var totalFrozen = 0;
    var totalConfirmed = balanceResult.confirmed;
    var totalUnconfirmed = balanceResult.unconfirmed;

    unspentCoins.forInfo(unspentCoinsInfo.values).forEach((unspentCoinInfo) {
      if (unspentCoinInfo.isFrozen) {
        totalFrozen += unspentCoinInfo.value;
      }
    });

    balance[currency] = ElectrumBalance(
      confirmed: totalConfirmed,
      unconfirmed: totalUnconfirmed,
      frozen: totalFrozen,
    );

    _syncedTimes++;
    if (_syncedTimes == 3) {
      syncStatus = SyncedSyncStatus();
    }
  }

  @action
  Future<void> updateBalance() async {
    workerSendPort!.send(ElectrumWorkerGetBalanceRequest(
      scripthashes: walletAddresses.allScriptHashes,
    ).toJson());
  }

  @override
  void setExceptionHandler(void Function(FlutterErrorDetails) onError) => _onError = onError;

  Future<String> signMessage(String message, {String? address = null}) async {
    final record = walletAddresses.getFromAddresses(address!);

    final path = Bip32PathParser.parse(walletInfo.derivationInfo!.derivationPath!)
        .addElem(
          Bip32KeyIndex(BitcoinAddressUtils.getAccountFromChange(record.isChange)),
        )
        .addElem(Bip32KeyIndex(record.index));

    final priv = ECPrivate.fromHex(bip32.derive(path).privateKey.toHex());

    final hexEncoded = priv.signMessage(StringUtils.encode(message));
    final decodedSig = hex.decode(hexEncoded);
    return base64Encode(decodedSig);
  }

  @override
  Future<bool> verifyMessage(String message, String signature, {String? address = null}) async {
    if (address == null) {
      return false;
    }

    List<int> sigDecodedBytes = [];

    if (signature.endsWith('=')) {
      sigDecodedBytes = base64.decode(signature);
    } else {
      sigDecodedBytes = BytesUtils.fromHexString(signature);
    }

    if (sigDecodedBytes.length != 64 && sigDecodedBytes.length != 65) {
      throw ArgumentException(
          "signature must be 64 bytes without recover-id or 65 bytes with recover-id");
    }

    String messagePrefix = '\x18Bitcoin Signed Message:\n';
    final messageHash = QuickCrypto.sha256Hash(
        BitcoinSignerUtils.magicMessage(StringUtils.encode(message), messagePrefix));

    List<int> correctSignature =
        sigDecodedBytes.length == 65 ? sigDecodedBytes.sublist(1) : List.from(sigDecodedBytes);
    List<int> rBytes = correctSignature.sublist(0, 32);
    List<int> sBytes = correctSignature.sublist(32);
    final sig = ECDSASignature(BigintUtils.fromBytes(rBytes), BigintUtils.fromBytes(sBytes));

    List<int> possibleRecoverIds = [0, 1];

    final baseAddress = RegexUtils.addressTypeFromStr(address, network);

    for (int recoveryId in possibleRecoverIds) {
      final pubKey = sig.recoverPublicKey(messageHash, Curves.generatorSecp256k1, recoveryId);

      final recoveredPub = ECPublic.fromBytes(pubKey!.toBytes());

      String? recoveredAddress;

      if (baseAddress is P2pkAddress) {
        recoveredAddress = recoveredPub.toP2pkAddress().toAddress(network);
      } else if (baseAddress is P2pkhAddress) {
        recoveredAddress = recoveredPub.toP2pkhAddress().toAddress(network);
      } else if (baseAddress is P2wshAddress) {
        recoveredAddress = recoveredPub.toP2wshAddress().toAddress(network);
      } else if (baseAddress is P2wpkhAddress) {
        recoveredAddress = recoveredPub.toP2wpkhAddress().toAddress(network);
      }

      if (recoveredAddress == address) {
        return true;
      }
    }

    return false;
  }

  @action
  void _onConnectionStatusChange(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        if (syncStatus is NotConnectedSyncStatus ||
            syncStatus is LostConnectionSyncStatus ||
            syncStatus is ConnectingSyncStatus) {
          syncStatus = ConnectedSyncStatus();
        }

        break;
      case ConnectionStatus.disconnected:
        if (syncStatus is! NotConnectedSyncStatus &&
            syncStatus is! ConnectingSyncStatus &&
            syncStatus is! SynchronizingSyncStatus) {
          syncStatus = NotConnectedSyncStatus();
        }
        break;
      case ConnectionStatus.failed:
        if (syncStatus is! LostConnectionSyncStatus) {
          syncStatus = LostConnectionSyncStatus();
        }
        break;
      case ConnectionStatus.connecting:
        if (syncStatus is! ConnectingSyncStatus) {
          syncStatus = ConnectingSyncStatus();
        }
        break;
      default:
    }
  }

  @action
  void syncStatusReaction(SyncStatus syncStatus) {
    final isDisconnectedStatus =
        syncStatus is NotConnectedSyncStatus || syncStatus is LostConnectionSyncStatus;

    if (syncStatus is ConnectingSyncStatus || isDisconnectedStatus) {
      // Needs to re-subscribe to all scripthashes when reconnected
      scripthashesListening = [];
      _chainTipListenerOn = false;
    }

    if (isDisconnectedStatus) {
      if (_isTryingToConnect) return;

      _isTryingToConnect = true;

      Timer(Duration(seconds: 5), () {
        if (this.syncStatus is NotConnectedSyncStatus ||
            this.syncStatus is LostConnectionSyncStatus) {
          if (node == null) return;

          connectToNode(node: this.node!);
        }
        _isTryingToConnect = false;
      });
    }
  }

  void _updateInputsAndOutputs(ElectrumTransactionInfo tx, ElectrumTransactionBundle bundle) {
    tx.inputAddresses = tx.inputAddresses?.where((address) => address.isNotEmpty).toList();

    if (tx.inputAddresses == null ||
        tx.inputAddresses!.isEmpty ||
        tx.outputAddresses == null ||
        tx.outputAddresses!.isEmpty) {
      List<String> inputAddresses = [];
      List<String> outputAddresses = [];

      for (int i = 0; i < bundle.originalTransaction.inputs.length; i++) {
        final input = bundle.originalTransaction.inputs[i];
        final inputTransaction = bundle.ins[i];
        final vout = input.txIndex;
        final outTransaction = inputTransaction.outputs[vout];
        final address =
            BitcoinAddressUtils.addressFromOutputScript(outTransaction.scriptPubKey, network);

        if (address.isNotEmpty) inputAddresses.add(address);
      }

      for (int i = 0; i < bundle.originalTransaction.outputs.length; i++) {
        final out = bundle.originalTransaction.outputs[i];
        final address = BitcoinAddressUtils.addressFromOutputScript(out.scriptPubKey, network);

        if (address.isNotEmpty) outputAddresses.add(address);

        // Check if the script contains OP_RETURN
        final script = out.scriptPubKey.script;
        if (script.contains('OP_RETURN')) {
          final index = script.indexOf('OP_RETURN');
          if (index + 1 <= script.length) {
            try {
              final opReturnData = script[index + 1].toString();
              final decodedString = StringUtils.decode(BytesUtils.fromHexString(opReturnData));
              outputAddresses.add('OP_RETURN:$decodedString');
            } catch (_) {
              outputAddresses.add('OP_RETURN:');
            }
          }
        }
      }
      tx.inputAddresses = inputAddresses;
      tx.outputAddresses = outputAddresses;

      transactionHistory.addOne(tx);
    }
  }
}

class EstimatedTxResult {
  EstimatedTxResult({
    required this.utxos,
    required this.inputPrivKeyInfos,
    required this.publicKeys,
    required this.fee,
    required this.amount,
    required this.hasChange,
    required this.isSendAll,
    this.memo,
    this.spendsSilentPayment = false,
    required this.spendsUnconfirmedTX,
  });

  final List<UtxoWithAddress> utxos;
  final List<ECPrivateInfo> inputPrivKeyInfos;
  final Map<String, PublicKeyWithDerivationPath> publicKeys; // PubKey to derivationPath
  final int fee;
  final int amount;
  final bool spendsSilentPayment;

  final bool hasChange;
  final bool isSendAll;
  final String? memo;
  final bool spendsUnconfirmedTX;
}

class PublicKeyWithDerivationPath {
  const PublicKeyWithDerivationPath(this.publicKey, this.derivationPath);

  final String derivationPath;
  final String publicKey;
}

class TxCreateUtxoDetails {
  final List<BitcoinUnspent> availableInputs;
  final List<BitcoinUnspent> unconfirmedCoins;
  final List<UtxoWithAddress> utxos;
  final List<Outpoint> vinOutpoints;
  final List<ECPrivateInfo> inputPrivKeyInfos;
  final Map<String, PublicKeyWithDerivationPath> publicKeys; // PubKey to derivationPath
  final int allInputsAmount;
  final bool spendsSilentPayment;
  final bool spendsUnconfirmedTX;

  TxCreateUtxoDetails({
    required this.availableInputs,
    required this.unconfirmedCoins,
    required this.utxos,
    required this.vinOutpoints,
    required this.inputPrivKeyInfos,
    required this.publicKeys,
    required this.allInputsAmount,
    this.spendsSilentPayment = false,
    required this.spendsUnconfirmedTX,
  });
}

class BitcoinUnspentCoins extends ObservableSet<BitcoinUnspent> {
  BitcoinUnspentCoins() : super();

  static BitcoinUnspentCoins of(Iterable<BitcoinUnspent> unspentCoins) {
    final coins = BitcoinUnspentCoins();
    coins.addAll(unspentCoins);
    return coins;
  }

  List<UnspentCoinsInfo> forInfo(Iterable<UnspentCoinsInfo> unspentCoinsInfo) {
    return unspentCoinsInfo.where((element) {
      final info = this.firstWhereOrNull(
        (info) =>
            element.hash == info.hash &&
            element.vout == info.vout &&
            element.address == info.bitcoinAddressRecord.address &&
            element.value == info.value,
      );

      return info != null;
    }).toList();
  }

  List<BitcoinUnspent> fromInfo(Iterable<UnspentCoinsInfo> unspentCoinsInfo) {
    return this.where((element) {
      final info = unspentCoinsInfo.firstWhereOrNull(
        (info) =>
            element.hash == info.hash &&
            element.vout == info.vout &&
            element.bitcoinAddressRecord.address == info.address &&
            element.value == info.value,
      );

      return info != null;
    }).toList();
  }
}

class CreateTxData {
  final int amount;
  final int feeRate;
  final List<BitcoinOutput> outputs;
  final bool sendAll;
  final String? memo;

  CreateTxData({
    required this.amount,
    required this.feeRate,
    required this.outputs,
    required this.sendAll,
    required this.memo,
  });
}
