import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_bitcoin/bitcoin_wallet.dart';
import 'package:cw_bitcoin/litecoin_wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:collection/collection.dart';
import 'package:cw_bitcoin/address_from_output.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/bitcoin_transaction_priority.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/bitcoin_wallet_keys.dart';
import 'package:cw_bitcoin/electrum.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_derivations.dart';
import 'package:cw_bitcoin/electrum_transaction_history.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_bitcoin/exceptions.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_bitcoin/utils.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/get_height_by_date.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/unspent_coin_type.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as ledger;
import 'package:mobx/mobx.dart';
import 'package:rxdart/subjects.dart';
import 'package:sp_scanner/sp_scanner.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;

part 'electrum_wallet.g.dart';

class ElectrumWallet = ElectrumWalletBase with _$ElectrumWallet;

abstract class ElectrumWalletBase
    extends WalletBase<ElectrumBalance, ElectrumTransactionHistory, ElectrumTransactionInfo>
    with Store, WalletKeysFile {
  ElectrumWalletBase({
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required this.network,
    required this.encryptionFileUtils,
    String? xpub,
    String? mnemonic,
    Uint8List? seedBytes,
    this.passphrase,
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumClient? electrumClient,
    ElectrumBalance? initialBalance,
    CryptoCurrency? currency,
    this.alwaysScan,
  })  : accountHD =
            getAccountHDWallet(currency, network, seedBytes, xpub, walletInfo.derivationInfo),
        syncStatus = NotConnectedSyncStatus(),
        _password = password,
        _feeRates = <int>[],
        _isTransactionUpdating = false,
        isEnabledAutoGenerateSubaddress = true,
        unspentCoins = [],
        _scripthashesUpdateSubject = {},
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
    this.electrumClient = electrumClient ?? ElectrumClient();
    this.walletInfo = walletInfo;
    transactionHistory = ElectrumTransactionHistory(
      walletInfo: walletInfo,
      password: password,
      encryptionFileUtils: encryptionFileUtils,
    );

    reaction((_) => syncStatus, _syncStatusReaction);

    sharedPrefs.complete(SharedPreferences.getInstance());
  }

  static Bip32Slip10Secp256k1 getAccountHDWallet(CryptoCurrency? currency, BasedUtxoNetwork network,
      Uint8List? seedBytes, String? xpub, DerivationInfo? derivationInfo) {
    if (seedBytes == null && xpub == null) {
      throw Exception(
          "To create a Wallet you need either a seed or an xpub. This should not happen");
    }

    if (seedBytes != null) {
      switch (currency) {
        case CryptoCurrency.btc:
        case CryptoCurrency.ltc:
        case CryptoCurrency.tbtc:
          return Bip32Slip10Secp256k1.fromSeed(seedBytes, getKeyNetVersion(network)).derivePath(
                  _hardenedDerivationPath(derivationInfo?.derivationPath ?? electrum_path))
              as Bip32Slip10Secp256k1;
        case CryptoCurrency.bch:
          return bitcoinCashHDWallet(seedBytes);
        default:
          throw Exception("Unsupported currency");
      }
    }

    return Bip32Slip10Secp256k1.fromExtendedKey(xpub!, getKeyNetVersion(network));
  }

  static Bip32Slip10Secp256k1 bitcoinCashHDWallet(Uint8List seedBytes) =>
      Bip32Slip10Secp256k1.fromSeed(seedBytes).derivePath("m/44'/145'/0'") as Bip32Slip10Secp256k1;

  static int estimatedTransactionSize(int inputsCount, int outputsCounts) =>
      inputsCount * 68 + outputsCounts * 34 + 10;

  static Bip32KeyNetVersions? getKeyNetVersion(BasedUtxoNetwork network) {
    switch (network) {
      case LitecoinNetwork.mainnet:
        return Bip44Conf.litecoinMainNet.altKeyNetVer;
      default:
        return null;
    }
  }

  bool? alwaysScan;

  final Bip32Slip10Secp256k1 accountHD;
  final String? _mnemonic;

  Bip32Slip10Secp256k1 get hd => accountHD.childKey(Bip32KeyIndex(0));

  Bip32Slip10Secp256k1 get sideHd => accountHD.childKey(Bip32KeyIndex(1));

  final EncryptionFileUtils encryptionFileUtils;

  @override
  final String? passphrase;

  @override
  @observable
  bool isEnabledAutoGenerateSubaddress;

  late ElectrumClient electrumClient;
  Box<UnspentCoinsInfo> unspentCoinsInfo;

  @override
  late ElectrumWalletAddresses walletAddresses;

  @override
  @observable
  late ObservableMap<CryptoCurrency, ElectrumBalance> balance;

  @override
  @observable
  SyncStatus syncStatus;

  Set<String> get addressesSet => walletAddresses.allAddresses
      .where((element) => element.type != SegwitAddresType.mweb)
      .map((addr) => addr.address)
      .toSet();

  List<String> get scriptHashes => walletAddresses.addressesByReceiveType
      .where((addr) => RegexUtils.addressTypeFromStr(addr.address, network) is! MwebAddress)
      .map((addr) => (addr as BitcoinAddressRecord).getScriptHash(network))
      .toList();

  List<String> get publicScriptHashes => walletAddresses.allAddresses
      .where((addr) => !addr.isHidden)
      .where((addr) => RegexUtils.addressTypeFromStr(addr.address, network) is! MwebAddress)
      .map((addr) => addr.getScriptHash(network))
      .toList();

  String get xpub => accountHD.publicKey.toExtended;

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

  bool get hasSilentPaymentsScanning => type == WalletType.bitcoin;

  @observable
  bool nodeSupportsSilentPayments = true;
  @observable
  bool silentPaymentsScanningActive = false;

  bool _isTryingToConnect = false;

  Completer<SharedPreferences> sharedPrefs = Completer();

  Future<bool> checkIfMempoolAPIIsEnabled() async {
    bool isMempoolAPIEnabled = (await sharedPrefs.future).getBool("use_mempool_fee_api") ?? true;
    return isMempoolAPIEnabled;
  }

  @action
  Future<void> setSilentPaymentsScanning(bool active) async {
    silentPaymentsScanningActive = active;

    if (active) {
      syncStatus = AttemptingScanSyncStatus();

      final tip = await getUpdatedChainTip();

      if (tip == walletInfo.restoreHeight) {
        syncStatus = SyncedTipSyncStatus(tip);
        return;
      }

      if (tip > walletInfo.restoreHeight) {
        _setListeners(walletInfo.restoreHeight, chainTipParam: currentChainTip);
      }
    } else {
      alwaysScan = false;

      _isolate?.then((value) => value.kill(priority: Isolate.immediate));

      if (electrumClient.isConnected) {
        syncStatus = SyncedSyncStatus();
      } else {
        syncStatus = NotConnectedSyncStatus();
      }
    }
  }

  int? currentChainTip;

  Future<int> getCurrentChainTip() async {
    if ((currentChainTip ?? 0) > 0) {
      return currentChainTip!;
    }
    currentChainTip = await electrumClient.getCurrentBlockChainTip() ?? 0;

    return currentChainTip!;
  }

  Future<int> getUpdatedChainTip() async {
    final newTip = await electrumClient.getCurrentBlockChainTip();
    if (newTip != null && newTip > (currentChainTip ?? 0)) {
      currentChainTip = newTip;
    }
    return currentChainTip ?? 0;
  }

  @override
  BitcoinWalletKeys get keys => BitcoinWalletKeys(
        wif: WifEncoder.encode(hd.privateKey.raw, netVer: network.wifNetVer),
        privateKey: hd.privateKey.toHex(),
        publicKey: hd.publicKey.toHex(),
      );

  String _password;
  List<BitcoinUnspent> unspentCoins;
  List<int> _feeRates;

  // ignore: prefer_final_fields
  Map<String, BehaviorSubject<Object>?> _scripthashesUpdateSubject;

  // ignore: prefer_final_fields
  BehaviorSubject<Object>? _chainTipUpdateSubject;
  bool _isTransactionUpdating;
  Future<Isolate>? _isolate;

  void Function(FlutterErrorDetails)? _onError;
  Timer? _autoSaveTimer;
  StreamSubscription<dynamic>? _receiveStream;
  Timer? _updateFeeRateTimer;
  static const int _autoSaveInterval = 1;

  Future<void> init() async {
    await walletAddresses.init();
    await transactionHistory.init();
    await cleanUpDuplicateUnspentCoins();
    await save();

    _autoSaveTimer =
        Timer.periodic(Duration(minutes: _autoSaveInterval), (_) async => await save());
  }

  @action
  Future<void> _setListeners(int height, {int? chainTipParam, bool? doSingleScan}) async {
    if (this is! BitcoinWallet) return;
    final chainTip = chainTipParam ?? await getUpdatedChainTip();

    if (chainTip == height) {
      syncStatus = SyncedSyncStatus();
      return;
    }

    syncStatus = AttemptingScanSyncStatus();

    if (_isolate != null) {
      final runningIsolate = await _isolate!;
      runningIsolate.kill(priority: Isolate.immediate);
    }

    final receivePort = ReceivePort();
    _isolate = Isolate.spawn(
        startRefresh,
        ScanData(
          sendPort: receivePort.sendPort,
          silentAddress: walletAddresses.silentAddress!,
          network: network,
          height: height,
          chainTip: chainTip,
          electrumClient: ElectrumClient(),
          transactionHistoryIds: transactionHistory.transactions.keys.toList(),
          node: (await getNodeSupportsSilentPayments()) == true
              ? ScanNode(node!.uri, node!.useSSL)
              : null,
          labels: walletAddresses.labels,
          labelIndexes: walletAddresses.silentAddresses
              .where((addr) => addr.type == SilentPaymentsAddresType.p2sp && addr.index >= 1)
              .map((addr) => addr.index)
              .toList(),
          isSingleScan: doSingleScan ?? false,
        ));

    await _receiveStream?.cancel();
    _receiveStream = receivePort.listen((var message) async {
      if (message is Map<String, ElectrumTransactionInfo>) {
        for (final map in message.entries) {
          final txid = map.key;
          final tx = map.value;

          if (tx.unspents != null) {
            final existingTxInfo = transactionHistory.transactions[txid];
            final txAlreadyExisted = existingTxInfo != null;

            // Updating tx after re-scanned
            if (txAlreadyExisted) {
              existingTxInfo.amount = tx.amount;
              existingTxInfo.confirmations = tx.confirmations;
              existingTxInfo.height = tx.height;

              final newUnspents = tx.unspents!
                  .where((unspent) => !(existingTxInfo.unspents?.any((element) =>
                          element.hash.contains(unspent.hash) &&
                          element.vout == unspent.vout &&
                          element.value == unspent.value) ??
                      false))
                  .toList();

              if (newUnspents.isNotEmpty) {
                newUnspents.forEach(_updateSilentAddressRecord);

                existingTxInfo.unspents ??= [];
                existingTxInfo.unspents!.addAll(newUnspents);

                final newAmount = newUnspents.length > 1
                    ? newUnspents.map((e) => e.value).reduce((value, unspent) => value + unspent)
                    : newUnspents[0].value;

                if (existingTxInfo.direction == TransactionDirection.incoming) {
                  existingTxInfo.amount += newAmount;
                }

                // Updates existing TX
                transactionHistory.addOne(existingTxInfo);
                // Update balance record
                balance[currency]!.confirmed += newAmount;
              }
            } else {
              // else: First time seeing this TX after scanning
              tx.unspents!.forEach(_updateSilentAddressRecord);

              // Add new TX record
              transactionHistory.addMany(message);
              // Update balance record
              balance[currency]!.confirmed += tx.amount;
            }

            await updateAllUnspents();
          }
        }
      }

      if (message is SyncResponse) {
        if (message.syncStatus is UnsupportedSyncStatus) {
          nodeSupportsSilentPayments = false;
        }

        if (message.syncStatus is SyncingSyncStatus) {
          var status = message.syncStatus as SyncingSyncStatus;
          syncStatus = SyncingSyncStatus(status.blocksLeft, status.ptc);
        } else {
          syncStatus = message.syncStatus;
        }

        await walletInfo.updateRestoreHeight(message.height);
      }
    });
  }

  void _updateSilentAddressRecord(BitcoinSilentPaymentsUnspent unspent) {
    final silentAddress = walletAddresses.silentAddress!;
    final silentPaymentAddress = SilentPaymentAddress(
      version: silentAddress.version,
      B_scan: silentAddress.B_scan,
      B_spend: unspent.silentPaymentLabel != null
          ? silentAddress.B_spend.tweakAdd(
              BigintUtils.fromBytes(BytesUtils.fromHexString(unspent.silentPaymentLabel!)),
            )
          : silentAddress.B_spend,
      network: network,
    );

    final addressRecord = walletAddresses.silentAddresses
        .firstWhereOrNull((address) => address.address == silentPaymentAddress.toString());
    addressRecord?.txCount += 1;
    addressRecord?.balance += unspent.value;

    walletAddresses.addSilentAddresses(
      [unspent.bitcoinAddressRecord as BitcoinSilentPaymentAddressRecord],
    );
  }

  @action
  @override
  Future<void> startSync() async {
    try {
      if (syncStatus is SyncronizingSyncStatus) {
        return;
      }

      syncStatus = SyncronizingSyncStatus();

      if (hasSilentPaymentsScanning) {
        await _setInitialHeight();
      }

      await subscribeForUpdates();
      await updateTransactions();

      await updateAllUnspents();
      await updateBalance();
      await updateFeeRates();

      _updateFeeRateTimer ??=
          Timer.periodic(const Duration(minutes: 1), (timer) async => await updateFeeRates());

      if (alwaysScan == true) {
        _setListeners(walletInfo.restoreHeight);
      } else {
        if (syncStatus is LostConnectionSyncStatus) return;
        syncStatus = SyncedSyncStatus();
      }
    } catch (e, stacktrace) {
      printV(stacktrace);
      printV("startSync $e");
      syncStatus = FailedSyncStatus();
    }
  }

  @action
  Future<void> updateFeeRates() async {
    if (await checkIfMempoolAPIIsEnabled() && type == WalletType.bitcoin) {
      try {
        final response = await http
            .get(Uri.parse("https://mempool.cakewallet.com/api/v1/fees/recommended"))
            .timeout(Duration(seconds: 5));

        final result = json.decode(response.body) as Map<String, dynamic>;
        final slowFee = (result['economyFee'] as num?)?.toInt() ?? 0;
        int mediumFee = (result['hourFee'] as num?)?.toInt() ?? 0;
        int fastFee = (result['fastestFee'] as num?)?.toInt() ?? 0;
        if (slowFee == mediumFee) {
          mediumFee++;
        }
        while (fastFee <= mediumFee) {
          fastFee++;
        }
        _feeRates = [slowFee, mediumFee, fastFee];
        return;
      } catch (e) {
        printV(e);
      }
    }

    final feeRates = await electrumClient.feeRates(network: network);
    if (feeRates != [0, 0, 0]) {
      _feeRates = feeRates;
    } else if (isTestnet) {
      _feeRates = [1, 1, 1];
    }
  }

  Node? node;

  Future<bool> getNodeIsElectrs() async {
    if (node == null) {
      return false;
    }

    final version = await electrumClient.version();

    if (version.isNotEmpty) {
      final server = version[0];

      if (server.toLowerCase().contains('electrs')) {
        node!.isElectrs = true;
        node!.save();
        return node!.isElectrs!;
      }
    }

    node!.isElectrs = false;
    node!.save();
    return node!.isElectrs!;
  }

  Future<bool> getNodeSupportsSilentPayments() async {
    // As of today (august 2024), only ElectrumRS supports silent payments
    if (!(await getNodeIsElectrs())) {
      return false;
    }

    if (node == null) {
      return false;
    }

    try {
      final tweaksResponse = await electrumClient.getTweaks(height: 0);

      if (tweaksResponse != null) {
        node!.supportsSilentPayments = true;
        node!.save();
        return node!.supportsSilentPayments!;
      }
    } on RequestFailedTimeoutException catch (_) {
      node!.supportsSilentPayments = false;
      node!.save();
      return node!.supportsSilentPayments!;
    } catch (_) {}

    node!.supportsSilentPayments = false;
    node!.save();
    return node!.supportsSilentPayments!;
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    this.node = node;

    if (syncStatus is ConnectingSyncStatus) return;

    try {
      syncStatus = ConnectingSyncStatus();

      await _receiveStream?.cancel();
      await electrumClient.close();

      electrumClient.onConnectionStatusChange = _onConnectionStatusChange;

      await electrumClient.connectToUri(node.uri, useSSL: node.useSSL);
    } catch (e, stacktrace) {
      printV(stacktrace);
      printV("connectToNode $e");
      syncStatus = FailedSyncStatus();
    }
  }

  int get _dustAmount => 546;

  bool _isBelowDust(int amount) => amount <= _dustAmount && network != BitcoinNetwork.testnet;

  UtxoDetails _createUTXOS({
    required bool sendAll,
    required bool paysToSilentPayment,
    int credentialsAmount = 0,
    int? inputsCount,
    UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any,
  }) {
    List<UtxoWithAddress> utxos = [];
    List<Outpoint> vinOutpoints = [];
    List<ECPrivateInfo> inputPrivKeyInfos = [];
    final publicKeys = <String, PublicKeyWithDerivationPath>{};
    int allInputsAmount = 0;
    bool spendsSilentPayment = false;
    bool spendsUnconfirmedTX = false;

    int leftAmount = credentialsAmount;
    var availableInputs = unspentCoins.where((utx) {
      if (!utx.isSending || utx.isFrozen) {
        return false;
      }

      switch (coinTypeToSpendFrom) {
        case UnspentCoinType.mweb:
          return utx.bitcoinAddressRecord.type == SegwitAddresType.mweb;
        case UnspentCoinType.nonMweb:
          return utx.bitcoinAddressRecord.type != SegwitAddresType.mweb;
        case UnspentCoinType.any:
          return true;
      }
    }).toList();
    final unconfirmedCoins = availableInputs.where((utx) => utx.confirmations == 0).toList();

    // sort the unconfirmed coins so that mweb coins are first:
    availableInputs.sort((a, b) => a.bitcoinAddressRecord.type == SegwitAddresType.mweb ? -1 : 1);

    for (int i = 0; i < availableInputs.length; i++) {
      final utx = availableInputs[i];
      if (!spendsUnconfirmedTX) spendsUnconfirmedTX = utx.confirmations == 0;

      if (paysToSilentPayment) {
        // Check inputs for shared secret derivation
        if (utx.bitcoinAddressRecord.type == SegwitAddresType.p2wsh) {
          throw BitcoinTransactionSilentPaymentsNotSupported();
        }
      }

      allInputsAmount += utx.value;
      leftAmount = leftAmount - utx.value;

      final address = RegexUtils.addressTypeFromStr(utx.address, network);
      ECPrivate? privkey;
      bool? isSilentPayment = false;

      final hd =
          utx.bitcoinAddressRecord.isHidden ? walletAddresses.sideHd : walletAddresses.mainHd;

      if (utx.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) {
        final unspentAddress = utx.bitcoinAddressRecord as BitcoinSilentPaymentAddressRecord;
        privkey = walletAddresses.silentAddress!.b_spend.tweakAdd(
          BigintUtils.fromBytes(
            BytesUtils.fromHexString(unspentAddress.silentPaymentTweak!),
          ),
        );
        spendsSilentPayment = true;
        isSilentPayment = true;
      } else if (!isHardwareWallet) {
        privkey =
            generateECPrivate(hd: hd, index: utx.bitcoinAddressRecord.index, network: network);
      }

      vinOutpoints.add(Outpoint(txid: utx.hash, index: utx.vout));
      String pubKeyHex;

      if (privkey != null) {
        inputPrivKeyInfos.add(ECPrivateInfo(
          privkey,
          address.type == SegwitAddresType.p2tr,
          tweak: !isSilentPayment,
        ));

        pubKeyHex = privkey.getPublic().toHex();
      } else {
        pubKeyHex = hd.childKey(Bip32KeyIndex(utx.bitcoinAddressRecord.index)).publicKey.toHex();
      }

      final derivationPath =
          "${_hardenedDerivationPath(walletInfo.derivationInfo?.derivationPath ?? electrum_path)}"
          "/${utx.bitcoinAddressRecord.isHidden ? "1" : "0"}"
          "/${utx.bitcoinAddressRecord.index}";
      publicKeys[address.pubKeyHash()] = PublicKeyWithDerivationPath(pubKeyHex, derivationPath);

      utxos.add(
        UtxoWithAddress(
          utxo: BitcoinUtxo(
            txHash: utx.hash,
            value: BigInt.from(utx.value),
            vout: utx.vout,
            scriptType: _getScriptType(address),
            isSilentPayment: isSilentPayment,
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

    return UtxoDetails(
      availableInputs: availableInputs,
      unconfirmedCoins: unconfirmedCoins,
      utxos: utxos,
      vinOutpoints: vinOutpoints,
      inputPrivKeyInfos: inputPrivKeyInfos,
      publicKeys: publicKeys,
      allInputsAmount: allInputsAmount,
      spendsSilentPayment: spendsSilentPayment,
      spendsUnconfirmedTX: spendsUnconfirmedTX,
    );
  }

  Future<EstimatedTxResult> estimateSendAllTx(
    List<BitcoinOutput> outputs,
    int feeRate, {
    String? memo,
    bool hasSilentPayment = false,
    UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any,
  }) async {
    final utxoDetails = _createUTXOS(
      sendAll: true,
      paysToSilentPayment: hasSilentPayment,
      coinTypeToSpendFrom: coinTypeToSpendFrom,
    );

    int fee = await calcFee(
      utxos: utxoDetails.utxos,
      outputs: outputs,
      network: network,
      memo: memo,
      feeRate: feeRate,
      inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
      vinOutpoints: utxoDetails.vinOutpoints,
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
    if (_isBelowDust(amount)) {
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
      spendsSilentPayment: utxoDetails.spendsSilentPayment,
    );
  }

  Future<EstimatedTxResult> estimateTxForAmount(
    int credentialsAmount,
    List<BitcoinOutput> outputs,
    List<BitcoinOutput> updatedOutputs,
    int feeRate, {
    int? inputsCount,
    String? memo,
    bool? useUnconfirmed,
    bool hasSilentPayment = false,
    UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any,
  }) async {
    // Attempting to send less than the dust limit
    if (_isBelowDust(credentialsAmount)) {
      throw BitcoinTransactionNoDustException();
    }

    final utxoDetails = _createUTXOS(
      sendAll: false,
      credentialsAmount: credentialsAmount,
      inputsCount: inputsCount,
      paysToSilentPayment: hasSilentPayment,
      coinTypeToSpendFrom: coinTypeToSpendFrom,
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
          updatedOutputs,
          feeRate,
          inputsCount: utxoDetails.utxos.length + 1,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
          coinTypeToSpendFrom: coinTypeToSpendFrom,
        );
      }

      throw BitcoinTransactionWrongBalanceException();
    }

    final changeAddress = await walletAddresses.getChangeAddress(
      inputs: utxoDetails.availableInputs,
      outputs: updatedOutputs,
      coinTypeToSpendFrom: coinTypeToSpendFrom,
    );
    final address = RegexUtils.addressTypeFromStr(changeAddress.address, network);
    updatedOutputs.add(BitcoinOutput(
      address: address,
      value: BigInt.from(amountLeftForChangeAndFee),
      isChange: true,
    ));
    outputs.add(BitcoinOutput(
      address: address,
      value: BigInt.from(amountLeftForChangeAndFee),
      isChange: true,
    ));

    // Get Derivation path for change Address since it is needed in Litecoin and BitcoinCash hardware Wallets
    final changeDerivationPath =
        "${_hardenedDerivationPath(walletInfo.derivationInfo?.derivationPath ?? "m/0'")}"
        "/${changeAddress.isHidden ? "1" : "0"}"
        "/${changeAddress.index}";
    utxoDetails.publicKeys[address.pubKeyHash()] =
        PublicKeyWithDerivationPath('', changeDerivationPath);

    // calcFee updates the silent payment outputs to calculate the tx size accounting
    // for taproot addresses, but if more inputs are needed to make up for fees,
    // the silent payment outputs need to be recalculated for the new inputs
    var temp = outputs.map((output) => output).toList();
    int fee = await calcFee(
      utxos: utxoDetails.utxos,
      // Always take only not updated bitcoin outputs here so for every estimation
      // the SP outputs are re-generated to the proper taproot addresses
      outputs: temp,
      network: network,
      memo: memo,
      feeRate: feeRate,
      inputPrivKeyInfos: utxoDetails.inputPrivKeyInfos,
      vinOutpoints: utxoDetails.vinOutpoints,
    );

    updatedOutputs.clear();
    updatedOutputs.addAll(temp);

    if (fee == 0) {
      throw BitcoinTransactionNoFeeException();
    }

    int amount = credentialsAmount;
    final lastOutput = updatedOutputs.last;
    final amountLeftForChange = amountLeftForChangeAndFee - fee;

    if (_isBelowDust(amountLeftForChange)) {
      // If has change that is lower than dust, will end up with tx rejected by network rules
      // so remove the change amount
      updatedOutputs.removeLast();
      outputs.removeLast();

      if (amountLeftForChange < 0) {
        if (!spendingAllCoins) {
          return estimateTxForAmount(
            credentialsAmount,
            outputs,
            updatedOutputs,
            feeRate,
            inputsCount: utxoDetails.utxos.length + 1,
            memo: memo,
            useUnconfirmed: useUnconfirmed ?? spendingAllConfirmedCoins,
            hasSilentPayment: hasSilentPayment,
            coinTypeToSpendFrom: coinTypeToSpendFrom,
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
        spendsSilentPayment: utxoDetails.spendsSilentPayment,
      );
    } else {
      // Here, lastOutput already is change, return the amount left without the fee to the user's address.
      updatedOutputs[updatedOutputs.length - 1] = BitcoinOutput(
        address: lastOutput.address,
        value: BigInt.from(amountLeftForChange),
        isSilentPayment: lastOutput.isSilentPayment,
        isChange: true,
      );
      outputs[outputs.length - 1] = BitcoinOutput(
        address: lastOutput.address,
        value: BigInt.from(amountLeftForChange),
        isSilentPayment: lastOutput.isSilentPayment,
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
        spendsSilentPayment: utxoDetails.spendsSilentPayment,
      );
    }
  }

  Future<int> calcFee({
    required List<UtxoWithAddress> utxos,
    required List<BitcoinBaseOutput> outputs,
    required BasedUtxoNetwork network,
    String? memo,
    required int feeRate,
    List<ECPrivateInfo>? inputPrivKeyInfos,
    List<Outpoint>? vinOutpoints,
  }) async {
    int estimatedSize;
    if (network is BitcoinCashNetwork) {
      estimatedSize = ForkedTransactionBuilder.estimateTransactionSize(
        utxos: utxos,
        outputs: outputs,
        network: network,
        memo: memo,
      );
    } else {
      estimatedSize = BitcoinTransactionBuilder.estimateTransactionSize(
        utxos: utxos,
        outputs: outputs,
        network: network,
        memo: memo,
        inputPrivKeyInfos: inputPrivKeyInfos,
        vinOutpoints: vinOutpoints,
      );
    }

    return feeAmountWithFeeRate(feeRate, 0, 0, size: estimatedSize);
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    try {
      // start by updating unspent coins
      await updateAllUnspents();

      final outputs = <BitcoinOutput>[];
      final transactionCredentials = credentials as BitcoinTransactionCredentials;
      final hasMultiDestination = transactionCredentials.outputs.length > 1;
      final sendAll = !hasMultiDestination && transactionCredentials.outputs.first.sendAll;
      final memo = transactionCredentials.outputs.first.memo;
      final coinTypeToSpendFrom = transactionCredentials.coinTypeToSpendFrom;

      int credentialsAmount = 0;
      bool hasSilentPayment = false;

      for (final out in transactionCredentials.outputs) {
        final outputAmount = out.formattedCryptoAmount!;

        if (!sendAll && _isBelowDust(outputAmount)) {
          throw BitcoinTransactionNoDustException();
        }

        if (hasMultiDestination) {
          if (out.sendAll) {
            throw BitcoinTransactionWrongBalanceException();
          }
        }

        credentialsAmount += outputAmount;

        final address = RegexUtils.addressTypeFromStr(
            out.isParsedAddress ? out.extractedAddress! : out.address, network);
        final isSilentPayment = address is SilentPaymentAddress;

        if (isSilentPayment) {
          hasSilentPayment = true;
        }

        if (sendAll) {
          // The value will be changed after estimating the Tx size and deducting the fee from the total to be sent
          outputs.add(BitcoinOutput(
            address: address,
            value: BigInt.from(0),
            isSilentPayment: isSilentPayment,
          ));
        } else {
          outputs.add(BitcoinOutput(
            address: address,
            value: BigInt.from(outputAmount),
            isSilentPayment: isSilentPayment,
          ));
        }
      }

      final feeRateInt = transactionCredentials.feeRate != null
          ? transactionCredentials.feeRate!
          : feeRate(transactionCredentials.priority!);

      EstimatedTxResult estimatedTx;
      final updatedOutputs = outputs
          .map((e) => BitcoinOutput(
                address: e.address,
                value: e.value,
                isSilentPayment: e.isSilentPayment,
                isChange: e.isChange,
              ))
          .toList();

      if (sendAll) {
        estimatedTx = await estimateSendAllTx(
          updatedOutputs,
          feeRateInt,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
          coinTypeToSpendFrom: coinTypeToSpendFrom,
        );
      } else {
        estimatedTx = await estimateTxForAmount(
          credentialsAmount,
          outputs,
          updatedOutputs,
          feeRateInt,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
          coinTypeToSpendFrom: coinTypeToSpendFrom,
        );
      }

      if (walletInfo.isHardwareWallet) {
        final transaction = await buildHardwareWalletTransaction(
          utxos: estimatedTx.utxos,
          outputs: updatedOutputs,
          publicKeys: estimatedTx.publicKeys,
          fee: BigInt.from(estimatedTx.fee),
          network: network,
          memo: estimatedTx.memo,
          outputOrdering: BitcoinOrdering.none,
          enableRBF: true,
        );

        return PendingBitcoinTransaction(
          transaction,
          type,
          electrumClient: electrumClient,
          amount: estimatedTx.amount,
          fee: estimatedTx.fee,
          feeRate: feeRateInt.toString(),
          network: network,
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
          outputs: updatedOutputs,
          fee: BigInt.from(estimatedTx.fee),
          network: network,
          memo: estimatedTx.memo,
          outputOrdering: BitcoinOrdering.none,
          enableRBF: !estimatedTx.spendsUnconfirmedTX,
        );
      } else {
        txb = BitcoinTransactionBuilder(
          utxos: estimatedTx.utxos,
          outputs: updatedOutputs,
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

        if (utxo.utxo.isP2tr()) {
          hasTaprootInputs = true;
          return key.privkey.signTapRoot(
            txDigest,
            sighash: sighash,
            tweak: utxo.utxo.isSilentPayment != true,
          );
        } else {
          return key.privkey.signInput(txDigest, sigHash: sighash);
        }
      });

      return PendingBitcoinTransaction(
        transaction,
        type,
        electrumClient: electrumClient,
        amount: estimatedTx.amount,
        fee: estimatedTx.fee,
        feeRate: feeRateInt.toString(),
        network: network,
        hasChange: estimatedTx.hasChange,
        isSendAll: estimatedTx.isSendAll,
        hasTaprootInputs: hasTaprootInputs,
        utxos: estimatedTx.utxos,
        publicKeys: estimatedTx.publicKeys
      )..addListener((transaction) async {
          transactionHistory.addOne(transaction);
          if (estimatedTx.spendsSilentPayment) {
            transactionHistory.transactions.values.forEach((tx) {
              tx.unspents?.removeWhere(
                  (unspent) => estimatedTx.utxos.any((e) => e.utxo.txHash == unspent.hash));
              transactionHistory.addOne(tx);
            });
          }

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
    required BasedUtxoNetwork network,
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
        'account_index': walletAddresses.currentReceiveAddressIndexByType,
        'change_address_index': walletAddresses.currentChangeAddressIndexByType,
        'addresses': walletAddresses.allAddresses.map((addr) => addr.toJSON()).toList(),
        'address_page_type': walletInfo.addressPageType == null
            ? SegwitAddresType.p2wpkh.toString()
            : walletInfo.addressPageType.toString(),
        'balance': balance[currency]?.toJSON(),
        'derivationTypeIndex': walletInfo.derivationInfo?.derivationType?.index,
        'derivationPath': walletInfo.derivationInfo?.derivationPath,
        'silent_addresses': walletAddresses.silentAddresses.map((addr) => addr.toJSON()).toList(),
        'silent_address_index': walletAddresses.currentSilentAddressIndex.toString(),
        'mweb_addresses': walletAddresses.mwebAddresses.map((addr) => addr.toJSON()).toList(),
        'alwaysScan': alwaysScan,
      });

  int feeRate(TransactionPriority priority) {
    try {
      if (priority is BitcoinTransactionPriority) {
        return _feeRates[priority.raw];
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  int feeAmountForPriority(TransactionPriority priority, int inputsCount, int outputsCount,
          {int? size}) =>
      feeRate(priority) * (size ?? estimatedTransactionSize(inputsCount, outputsCount));

  int feeAmountWithFeeRate(int feeRate, int inputsCount, int outputsCount, {int? size}) =>
      feeRate * (size ?? estimatedTransactionSize(inputsCount, outputsCount));

  @override
  int calculateEstimatedFee(TransactionPriority? priority, int? amount,
      {int? outputsCount, int? size}) {
    if (priority is BitcoinTransactionPriority) {
      return calculateEstimatedFeeWithFeeRate(feeRate(priority), amount,
          outputsCount: outputsCount, size: size);
    }

    return 0;
  }

  int calculateEstimatedFeeWithFeeRate(int feeRate, int? amount, {int? outputsCount, int? size}) {
    if (size != null) {
      return feeAmountWithFeeRate(feeRate, 0, 0, size: size);
    }

    int inputsCount = 0;

    if (amount != null) {
      int totalValue = 0;

      for (final input in unspentCoins) {
        if (totalValue >= amount) {
          break;
        }

        if (input.isSending) {
          totalValue += input.value;
          inputsCount += 1;
        }
      }

      if (totalValue < amount) return 0;
    } else {
      for (final input in unspentCoins) {
        if (input.isSending) {
          inputsCount += 1;
        }
      }
    }

    // If send all, then we have no change value
    final _outputsCount = outputsCount ?? (amount != null ? 2 : 1);

    return feeAmountWithFeeRate(feeRate, inputsCount, _outputsCount);
  }

  @override
  Future<void> save() async {
    if (!(await WalletKeysFile.hasKeysFile(walletInfo.name, walletInfo.type))) {
      await saveKeysFile(_password, encryptionFileUtils);
      saveKeysFile(_password, encryptionFileUtils, true);
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

  @action
  @override
  Future<void> rescan({required int height, bool? doSingleScan}) async {
    silentPaymentsScanningActive = true;
    _setListeners(height, doSingleScan: doSingleScan);
  }

  @override
  Future<void> close({bool shouldCleanup = false}) async {
    try {
      await _receiveStream?.cancel();
      await electrumClient.close();
    } catch (_) {}
    _autoSaveTimer?.cancel();
    _updateFeeRateTimer?.cancel();
  }

  @action
  Future<void> updateAllUnspents() async {
    List<BitcoinUnspent> updatedUnspentCoins = [];

    final previousUnspentCoins = List<BitcoinUnspent>.from(unspentCoins.where((utxo) =>
    utxo.bitcoinAddressRecord.type != SegwitAddresType.mweb &&
        utxo.bitcoinAddressRecord is! BitcoinSilentPaymentAddressRecord));

    if (hasSilentPaymentsScanning) {
      // Update unspents stored from scanned silent payment transactions
      transactionHistory.transactions.values.forEach((tx) {
        if (tx.unspents != null) {
          updatedUnspentCoins.addAll(tx.unspents!);
        }
      });
    }

    // Set the balance of all non-silent payment and non-mweb addresses to 0 before updating
    walletAddresses.allAddresses
        .where((element) => element.type != SegwitAddresType.mweb)
        .forEach((addr) {
      if (addr is! BitcoinSilentPaymentAddressRecord) addr.balance = 0;
    });

    final addressFutures = walletAddresses.allAddresses
        .where((element) => element.type != SegwitAddresType.mweb)
        .map((address) => fetchUnspent(address))
        .toList();

    final results = await Future.wait(addressFutures);
    final failedCount = results.where((result) => result == null).length;

    if (failedCount == 0) {
      for (final result in results) {
        updatedUnspentCoins.addAll(result!);
      }
      unspentCoins = updatedUnspentCoins;
    } else {
      unspentCoins = handleFailedUtxoFetch(
        failedCount: failedCount,
        previousUnspentCoins: previousUnspentCoins,
        updatedUnspentCoins: updatedUnspentCoins,
        results: results,
      );
    }

    final currentWalletUnspentCoins =
        unspentCoinsInfo.values.where((element) => element.walletId == id);

    if (currentWalletUnspentCoins.length != updatedUnspentCoins.length) {
      unspentCoins.forEach((coin) => addCoinInfo(coin));
    }

    await updateCoins(unspentCoins);
    await _refreshUnspentCoinsInfo();
  }

  List<BitcoinUnspent> handleFailedUtxoFetch({
    required int failedCount,
    required List<BitcoinUnspent> previousUnspentCoins,
    required List<BitcoinUnspent> updatedUnspentCoins,
    required List<List<BitcoinUnspent>?> results,
  }) {

    if (failedCount == results.length) {
      printV("All UTXOs failed to fetch, falling back to previous UTXOs");
      return previousUnspentCoins;
    }

    final successfulUtxos = <BitcoinUnspent>[];
    for (final result in results) {
      if (result != null) {
        successfulUtxos.addAll(result);
      }
    }

    if (failedCount > 0 && successfulUtxos.isEmpty) {
      printV("Some UTXOs failed, but no successful UTXOs, falling back to previous UTXOs");
      return previousUnspentCoins;
    }

    if (failedCount > 0) {
      printV("Some UTXOs failed, updating with successful UTXOs");
      updatedUnspentCoins.addAll(successfulUtxos);
    }

    return updatedUnspentCoins;
  }

  Future<void> updateCoins(List<BitcoinUnspent> newUnspentCoins) async {
    if (newUnspentCoins.isEmpty) {
      return;
    }

    newUnspentCoins.forEach((coin) {
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

        if (coin.bitcoinAddressRecord is! BitcoinSilentPaymentAddressRecord)
          coin.bitcoinAddressRecord.balance += coinInfo.value;
      } else {
        addCoinInfo(coin);
      }
    });
  }

  @action
  Future<void> updateUnspentsForAddress(BitcoinAddressRecord address) async {
    final newUnspentCoins = await fetchUnspent(address);
    await updateCoins(newUnspentCoins ?? []);
  }

  @action
  Future<List<BitcoinUnspent>?> fetchUnspent(BitcoinAddressRecord address) async {
    List<BitcoinUnspent> updatedUnspentCoins = [];

    final unspents = await electrumClient.getListUnspent(address.getScriptHash(network));

    // Failed to fetch unspents
    if (unspents == null) return null;

    await Future.wait(unspents.map((unspent) async {
      try {
        final coin = BitcoinUnspent.fromJSON(address, unspent);
        final tx = await fetchTransactionInfo(hash: coin.hash);
        coin.isChange = address.isHidden;
        coin.confirmations = tx?.confirmations;

        updatedUnspentCoins.add(coin);
      } catch (_) {}
    }));

    return updatedUnspentCoins;
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
        isSilentPayment: coin is BitcoinSilentPaymentsUnspent,
      );

      await unspentCoinsInfo.add(newInfo);
    }
  }

  Future<void> _refreshUnspentCoinsInfo() async {
    try {
      final List<dynamic> keys = [];
      final currentWalletUnspentCoins =
          unspentCoinsInfo.values.where((record) => record.walletId == id);

      for (final element in currentWalletUnspentCoins) {
        if (RegexUtils.addressTypeFromStr(element.address, network) is MwebAddress) continue;

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

  Future<void> cleanUpDuplicateUnspentCoins() async {
    final currentWalletUnspentCoins =
        unspentCoinsInfo.values.where((element) => element.walletId == id);
    final Map<String, UnspentCoinsInfo> uniqueUnspentCoins = {};
    final List<dynamic> duplicateKeys = [];

    for (final unspentCoin in currentWalletUnspentCoins) {
      final key = '${unspentCoin.hash}:${unspentCoin.vout}';
      if (!uniqueUnspentCoins.containsKey(key)) {
        uniqueUnspentCoins[key] = unspentCoin;
      } else {
        duplicateKeys.add(unspentCoin.key);
      }
    }

    if (duplicateKeys.isNotEmpty) await unspentCoinsInfo.deleteAll(duplicateKeys);
  }

  int transactionVSize(String transactionHex) => BtcTransaction.fromRaw(transactionHex).getVSize();

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
        .where((output) =>
            !ownAddresses.contains(addressFromOutputScript(output.scriptPubKey, network)))
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
    return totalBalance - receiverAmount - remainingFee >= _dustAmount;
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
        final address = addressFromOutputScript(outTransaction.scriptPubKey, network);
        allInputsAmount += outTransaction.amount.toInt();

        final addressRecord =
            walletAddresses.allAddresses.firstWhere((element) => element.address == address);
        final btcAddress = RegexUtils.addressTypeFromStr(addressRecord.address, network);
        final privkey = generateECPrivate(
            hd: addressRecord.isHidden ? walletAddresses.sideHd : walletAddresses.mainHd,
            index: addressRecord.index,
            network: network);

        privateKeys.add(privkey);

        utxos.add(
          UtxoWithAddress(
            utxo: BitcoinUtxo(
              txHash: input.txId,
              value: outTransaction.amount,
              vout: vout,
              scriptType: _getScriptType(btcAddress),
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
              memo = utf8.decode(HEX.decode(opReturnData));
              continue;
            } catch (_) {
              throw Exception('Cannot decode OP_RETURN data');
            }
          }
        }

        final address = addressFromOutputScript(out.scriptPubKey, network);
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
            if (outputAmount > _dustAmount) {
              int deduction = (outputAmount - _dustAmount >= remainingFee)
                  ? remainingFee
                  : outputAmount - _dustAmount;
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
          final privkey = generateECPrivate(
            hd: utxo.bitcoinAddressRecord.isHidden
                ? walletAddresses.sideHd
                : walletAddresses.mainHd,
            index: utxo.bitcoinAddressRecord.index,
            network: network,
          );
          privateKeys.add(privkey);

          utxos.add(UtxoWithAddress(
            utxo: BitcoinUtxo(
                txHash: utxo.hash,
                value: BigInt.from(utxo.value),
                vout: utxo.vout,
                scriptType: _getScriptType(address)),
            ownerDetails:
                UtxoAddressDetails(publicKey: privkey.getPublic().toHex(), address: address),
          ));

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

          if (outputAmount > _dustAmount) {
            int deduction = (outputAmount - _dustAmount >= remainingFee)
                ? remainingFee
                : outputAmount - _dustAmount;

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
      final changeAddresses = walletAddresses.allAddresses.where((element) => element.isHidden);
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

        if (utxo.utxo.isP2tr()) {
          return key.signTapRoot(txDigest, sighash: sighash);
        } else {
          return key.signInput(txDigest, sigHash: sighash);
        }
      });

      return PendingBitcoinTransaction(
        transaction,
        type,
        electrumClient: electrumClient,
        amount: sendingAmount,
        fee: newFee,
        network: network,
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

  Future<ElectrumTransactionBundle> getTransactionExpanded(
      {required String hash, int? height}) async {
    String transactionHex;
    int? time;
    int? confirmations;

    final verboseTransaction = await electrumClient.getTransactionVerbose(hash: hash);

    if (verboseTransaction.isEmpty) {
      transactionHex = await electrumClient.getTransactionHex(hash: hash);

      if (height != null && height > 0 && await checkIfMempoolAPIIsEnabled()) {
        try {
          final blockHash = await http.get(
            Uri.parse(
              "https://mempool.cakewallet.com/api/v1/block-height/$height",
            ),
          );

          if (blockHash.statusCode == 200 &&
              blockHash.body.isNotEmpty &&
              jsonDecode(blockHash.body) != null) {
            final blockResponse = await http.get(
              Uri.parse(
                "https://mempool.cakewallet.com/api/v1/block/${blockHash.body}",
              ),
            );
            if (blockResponse.statusCode == 200 &&
                blockResponse.body.isNotEmpty &&
                jsonDecode(blockResponse.body)['timestamp'] != null) {
              time = int.parse(jsonDecode(blockResponse.body)['timestamp'].toString());
            }
          }
        } catch (_) {}
      }
    } else {
      transactionHex = verboseTransaction['hex'] as String;
      time = verboseTransaction['time'] as int?;
      confirmations = verboseTransaction['confirmations'] as int?;
    }

    if (height != null) {
      if (time == null && height > 0) {
        time = (getDateByBitcoinHeight(height).millisecondsSinceEpoch / 1000).round();
      }

      if (confirmations == null) {
        final tip = await getUpdatedChainTip();
        if (tip > 0 && height > 0) {
          // Add one because the block itself is the first confirmation
          confirmations = tip - height + 1;
        }
      }
    }

    final original = BtcTransaction.fromRaw(transactionHex);
    final ins = <BtcTransaction>[];

    for (final vin in original.inputs) {
      final verboseTransaction = await electrumClient.getTransactionVerbose(hash: vin.txId);

      final String inputTransactionHex;

      if (verboseTransaction.isEmpty) {
        inputTransactionHex = await electrumClient.getTransactionHex(hash: hash);
      } else {
        inputTransactionHex = verboseTransaction['hex'] as String;
      }

      ins.add(BtcTransaction.fromRaw(inputTransactionHex));
    }

    return ElectrumTransactionBundle(
      original,
      ins: ins,
      time: time,
      confirmations: confirmations ?? 0,
    );
  }

  Future<ElectrumTransactionInfo?> fetchTransactionInfo(
      {required String hash, int? height, bool? retryOnFailure}) async {
    try {
      return ElectrumTransactionInfo.fromElectrumBundle(
        await getTransactionExpanded(hash: hash, height: height),
        walletInfo.type,
        network,
        addresses: addressesSet,
        height: height,
      );
    } catch (e) {
      if (e is FormatException && retryOnFailure == true) {
        await Future.delayed(const Duration(seconds: 2));
        return fetchTransactionInfo(hash: hash, height: height);
      }
      return null;
    }
  }

  bool isMine(Script script) {
    final derivedAddress = addressFromOutputScript(script, network);
    return addressesSet.contains(derivedAddress);
  }

  @override
  Future<Map<String, ElectrumTransactionInfo>> fetchTransactions() async {
    try {
      final Map<String, ElectrumTransactionInfo> historiesWithDetails = {};

      if (type == WalletType.bitcoin) {
        await Future.wait(BITCOIN_ADDRESS_TYPES
            .map((type) => fetchTransactionsForAddressType(historiesWithDetails, type)));
      } else if (type == WalletType.bitcoinCash) {
        await Future.wait(BITCOIN_CASH_ADDRESS_TYPES
            .map((type) => fetchTransactionsForAddressType(historiesWithDetails, type)));
      } else if (type == WalletType.litecoin) {
        await Future.wait(LITECOIN_ADDRESS_TYPES
            .where((type) => type != SegwitAddresType.mweb)
            .map((type) => fetchTransactionsForAddressType(historiesWithDetails, type)));
      }

      transactionHistory.transactions.values.forEach((tx) async {
        final isPendingSilentPaymentUtxo =
            (tx.isPending || tx.confirmations == 0) && historiesWithDetails[tx.id] == null;

        if (isPendingSilentPaymentUtxo) {
          final info =
              await fetchTransactionInfo(hash: tx.id, height: tx.height, retryOnFailure: true);

          if (info != null) {
            tx.confirmations = info.confirmations;
            tx.isPending = tx.confirmations == 0;
            transactionHistory.addOne(tx);
            await transactionHistory.save();
          }
        }
      });

      return historiesWithDetails;
    } catch (e) {
      printV("fetchTransactions $e");
      return {};
    }
  }

  Future<void> fetchTransactionsForAddressType(
    Map<String, ElectrumTransactionInfo> historiesWithDetails,
    BitcoinAddressType type,
  ) async {
    final addressesByType = walletAddresses.allAddresses.where((addr) => addr.type == type);
    final hiddenAddresses = addressesByType.where((addr) => addr.isHidden == true);
    final receiveAddresses = addressesByType.where((addr) => addr.isHidden == false);
    walletAddresses.hiddenAddresses.addAll(hiddenAddresses.map((e) => e.address));
    await walletAddresses.saveAddressesInBox();
    await Future.wait(addressesByType.map((addressRecord) async {
      final history = await _fetchAddressHistory(addressRecord, await getCurrentChainTip());

      if (history.isNotEmpty) {
        addressRecord.txCount = history.length;
        historiesWithDetails.addAll(history);

        final matchedAddresses = addressRecord.isHidden ? hiddenAddresses : receiveAddresses;
        final isUsedAddressUnderGap = matchedAddresses.toList().indexOf(addressRecord) >=
            matchedAddresses.length -
                (addressRecord.isHidden
                    ? ElectrumWalletAddressesBase.defaultChangeAddressesCount
                    : ElectrumWalletAddressesBase.defaultReceiveAddressesCount);

        if (isUsedAddressUnderGap) {
          final prevLength = walletAddresses.allAddresses.length;

          // Discover new addresses for the same address type until the gap limit is respected
          await walletAddresses.discoverAddresses(
            matchedAddresses.toList(),
            addressRecord.isHidden,
            (address) async {
              await subscribeForUpdates();
              return _fetchAddressHistory(address, await getCurrentChainTip())
                  .then((history) => history.isNotEmpty ? address.address : null);
            },
            type: type,
          );

          final newLength = walletAddresses.allAddresses.length;

          if (newLength > prevLength) {
            await fetchTransactionsForAddressType(historiesWithDetails, type);
          }
        }
      }
    }));
  }

  Future<Map<String, ElectrumTransactionInfo>> _fetchAddressHistory(
      BitcoinAddressRecord addressRecord, int? currentHeight) async {
    String txid = "";

    try {
      final Map<String, ElectrumTransactionInfo> historiesWithDetails = {};

      final history = await electrumClient.getHistory(addressRecord.getScriptHash(network));

      if (history.isNotEmpty) {
        addressRecord.setAsUsed();

        await Future.wait(history.map((transaction) async {
          txid = transaction['tx_hash'] as String;
          final height = transaction['height'] as int;
          final storedTx = transactionHistory.transactions[txid];

          if (storedTx != null) {
            if (height > 0) {
              storedTx.height = height;
              // the tx's block itself is the first confirmation so add 1
              if ((currentHeight ?? 0) > 0) {
                storedTx.confirmations = currentHeight! - height + 1;
              }
              storedTx.isPending = storedTx.confirmations == 0;
            }

            historiesWithDetails[txid] = storedTx;
          } else {
            final tx = await fetchTransactionInfo(hash: txid, height: height, retryOnFailure: true);

            if (tx != null) {
              historiesWithDetails[txid] = tx;

              // Got a new transaction fetched, add it to the transaction history
              // instead of waiting all to finish, and next time it will be faster

              if (this is LitecoinWallet) {
                // if we have a peg out transaction with the same value
                // that matches this received transaction, mark it as being from a peg out:
                for (final tx2 in transactionHistory.transactions.values) {
                  final heightDiff = ((tx2.height ?? 0) - (tx.height ?? 0)).abs();
                  // this isn't a perfect matching algorithm since we don't have the right input/output information from these transaction models (the addresses are in different formats), but this should be more than good enough for now as it's extremely unlikely a user receives the EXACT same amount from 2 different sources and one of them is a peg out and the other isn't WITHIN 5 blocks of each other
                  if (tx2.additionalInfo["isPegOut"] == true &&
                      tx2.amount == tx.amount &&
                      heightDiff <= 5) {
                    tx.additionalInfo["fromPegOut"] = true;
                  }
                }
              }
              transactionHistory.addOne(tx);
              await transactionHistory.save();
            }
          }

          return Future.value(null);
        }));
      }

      return historiesWithDetails;
    } catch (e, stacktrace) {
      _onError?.call(FlutterErrorDetails(
        exception: "$txid - $e",
        stack: stacktrace,
        library: this.runtimeType.toString(),
      ));
      return {};
    }
  }

  Future<void> updateTransactions() async {
    printV("updateTransactions() called!");
    try {
      if (_isTransactionUpdating) {
        return;
      }
      currentChainTip = await getUpdatedChainTip();

      bool updated = false;
      transactionHistory.transactions.values.forEach((tx) {
        if ((tx.height ?? 0) > 0 && (currentChainTip ?? 0) > 0) {
          var confirmations = currentChainTip! - tx.height! + 1;
          if (confirmations < 0) {
            // if our chain tip is outdated then it could lead to negative confirmations so this is just a failsafe:
            confirmations = 0;
          }
          if (confirmations != tx.confirmations) {
            updated = true;
            tx.confirmations = confirmations;
            transactionHistory.addOne(tx);
          }
        }
      });

      if (updated) {
        await transactionHistory.save();
      }

      _isTransactionUpdating = true;
      await fetchTransactions();
      walletAddresses.updateReceiveAddresses();
      _isTransactionUpdating = false;
    } catch (e, stacktrace) {
      printV(stacktrace);
      printV(e);
      _isTransactionUpdating = false;
    }
  }

  Future<void> subscribeForUpdates() async {
    final unsubscribedScriptHashes = walletAddresses.allAddresses.where(
      (address) =>
          !_scripthashesUpdateSubject.containsKey(address.getScriptHash(network)) &&
          address.type != SegwitAddresType.mweb,
    );

    await Future.wait(unsubscribedScriptHashes.map((address) async {
      final sh = address.getScriptHash(network);
      if (!(_scripthashesUpdateSubject[sh]?.isClosed ?? true)) {
        try {
          await _scripthashesUpdateSubject[sh]?.close();
        } catch (e) {
          printV("failed to close: $e");
        }
      }
      try {
        _scripthashesUpdateSubject[sh] = await electrumClient.scripthashUpdate(sh);
      } catch (e) {
        printV("failed scripthashUpdate: $e");
      }
      _scripthashesUpdateSubject[sh]?.listen((event) async {
        try {
          await updateUnspentsForAddress(address);

          await updateBalance();

          await _fetchAddressHistory(address, await getCurrentChainTip());
        } catch (e, s) {
          printV("sub error: $e");
          _onError?.call(FlutterErrorDetails(
            exception: e,
            stack: s,
            library: this.runtimeType.toString(),
          ));
        }
      }, onError: (e, s) {
        printV("sub_listen error: $e $s");
      });
    }));
  }

  Future<ElectrumBalance> fetchBalances() async {
    final addresses = walletAddresses.allAddresses
        .where((address) => RegexUtils.addressTypeFromStr(address.address, network) is! MwebAddress)
        .toList();
    final balanceFutures = <Future<Map<String, dynamic>>>[];
    for (var i = 0; i < addresses.length; i++) {
      final addressRecord = addresses[i];
      final sh = addressRecord.getScriptHash(network);
      final balanceFuture = electrumClient.getBalance(sh);
      balanceFutures.add(balanceFuture);
    }

    var totalFrozen = 0;
    var totalConfirmed = 0;
    var totalUnconfirmed = 0;

    if (hasSilentPaymentsScanning) {
      // Add values from unspent coins that are not fetched by the address list
      // i.e. scanned silent payments
      transactionHistory.transactions.values.forEach((tx) {
        if (tx.unspents != null) {
          tx.unspents!.forEach((unspent) {
            if (unspent.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) {
              if (unspent.isFrozen) totalFrozen += unspent.value;
              totalConfirmed += unspent.value;
            }
          });
        }
      });
    }

    unspentCoinsInfo.values.forEach((info) {
      unspentCoins.forEach((element) {
        if (element.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) return;

        if (element.hash == info.hash &&
            element.vout == info.vout &&
            info.isFrozen &&
            element.bitcoinAddressRecord.address == info.address &&
            element.value == info.value) {
          totalFrozen += element.value;
        }
      });
    });

    final balances = await Future.wait(balanceFutures);

    if (balances.isNotEmpty && balances.first['confirmed'] == null) {
      // if we got null balance responses from the server, set our connection status to lost and return our last known balance:
      printV("got null balance responses from the server, setting connection status to lost");
      syncStatus = LostConnectionSyncStatus();
      return balance[currency] ?? ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
    }

    for (var i = 0; i < balances.length; i++) {
      final addressRecord = addresses[i];
      final balance = balances[i];
      final confirmed = balance['confirmed'] as int? ?? 0;
      final unconfirmed = balance['unconfirmed'] as int? ?? 0;
      totalConfirmed += confirmed;
      totalUnconfirmed += unconfirmed;

      addressRecord.balance = confirmed + unconfirmed;
      if (confirmed > 0 || unconfirmed > 0) {
        addressRecord.setAsUsed();
      }
    }

    return ElectrumBalance(
      confirmed: totalConfirmed,
      unconfirmed: totalUnconfirmed,
      frozen: totalFrozen,
    );
  }

  Future<void> updateBalance() async {
    printV("updateBalance() called!");
    balance[currency] = await fetchBalances();
    await save();
  }

  @override
  void setExceptionHandler(void Function(FlutterErrorDetails) onError) => _onError = onError;

  @override
  Future<String> signMessage(String message, {String? address = null}) async {
    final index = address != null
        ? walletAddresses.allAddresses.firstWhere((element) => element.address == address).index
        : null;
    final HD = index == null ? hd : hd.childKey(Bip32KeyIndex(index));
    final priv = ECPrivate.fromHex(HD.privateKey.privKey.toHex());

    String messagePrefix = '\x18Bitcoin Signed Message:\n';
    final hexEncoded = priv.signMessage(utf8.encode(message), messagePrefix: messagePrefix);
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
      sigDecodedBytes = hex.decode(signature);
    }

    if (sigDecodedBytes.length != 64 && sigDecodedBytes.length != 65) {
      throw ArgumentException(
          "signature must be 64 bytes without recover-id or 65 bytes with recover-id");
    }

    String messagePrefix = '\x18Bitcoin Signed Message:\n';
    final messageHash = QuickCrypto.sha256Hash(
        BitcoinSignerUtils.magicMessage(utf8.encode(message), messagePrefix));

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

  Future<void> _setInitialHeight() async {
    if (_chainTipUpdateSubject != null) return;

    currentChainTip = await getUpdatedChainTip();

    if ((currentChainTip == null || currentChainTip! == 0) && walletInfo.restoreHeight == 0) {
      await walletInfo.updateRestoreHeight(currentChainTip!);
    }

    _chainTipUpdateSubject = electrumClient.chainTipSubscribe();
    _chainTipUpdateSubject?.listen((e) async {
      final event = e as Map<String, dynamic>;
      final height = int.tryParse(event['height'].toString());

      if (height != null) {
        currentChainTip = height;

        if (alwaysScan == true && syncStatus is SyncedSyncStatus) {
          _setListeners(walletInfo.restoreHeight);
        }
      }
    });
  }

  static String _hardenedDerivationPath(String derivationPath) =>
      derivationPath.substring(0, derivationPath.lastIndexOf("'") + 1);

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
            syncStatus is! SyncronizingSyncStatus) {
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

  void _syncStatusReaction(SyncStatus syncStatus) async {
    printV("SYNC_STATUS_CHANGE: ${syncStatus}");
    if (syncStatus is SyncingSyncStatus) {
      return;
    }

    if (syncStatus is NotConnectedSyncStatus || syncStatus is LostConnectionSyncStatus) {
      // Needs to re-subscribe to all scripthashes when reconnected
      _scripthashesUpdateSubject = {};

      if (_isTryingToConnect) return;

      _isTryingToConnect = true;

      Timer(Duration(seconds: 5), () {
        if (this.syncStatus is NotConnectedSyncStatus ||
            this.syncStatus is LostConnectionSyncStatus) {
          this.electrumClient.connectToUri(
                node!.uri,
                useSSL: node!.useSSL ?? false,
              );
        }
        _isTryingToConnect = false;
      });
    }

    // Message is shown on the UI for 3 seconds, revert to synced
    if (syncStatus is SyncedTipSyncStatus) {
      Timer(Duration(seconds: 3), () {
        if (this.syncStatus is SyncedTipSyncStatus) this.syncStatus = SyncedSyncStatus();
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
        final address = addressFromOutputScript(outTransaction.scriptPubKey, network);

        if (address.isNotEmpty) inputAddresses.add(address);
      }

      for (int i = 0; i < bundle.originalTransaction.outputs.length; i++) {
        final out = bundle.originalTransaction.outputs[i];
        final address = addressFromOutputScript(out.scriptPubKey, network);

        if (address.isNotEmpty) outputAddresses.add(address);

        // Check if the script contains OP_RETURN
        final script = out.scriptPubKey.script;
        if (script.contains('OP_RETURN')) {
          final index = script.indexOf('OP_RETURN');
          if (index + 1 <= script.length) {
            try {
              final opReturnData = script[index + 1].toString();
              final decodedString = utf8.decode(HEX.decode(opReturnData));
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

class ScanNode {
  final Uri uri;
  final bool? useSSL;

  ScanNode(this.uri, this.useSSL);
}

class ScanData {
  final SendPort sendPort;
  final SilentPaymentOwner silentAddress;
  final int height;
  final ScanNode? node;
  final BasedUtxoNetwork network;
  final int chainTip;
  final ElectrumClient electrumClient;
  final List<String> transactionHistoryIds;
  final Map<String, String> labels;
  final List<int> labelIndexes;
  final bool isSingleScan;

  ScanData({
    required this.sendPort,
    required this.silentAddress,
    required this.height,
    required this.node,
    required this.network,
    required this.chainTip,
    required this.electrumClient,
    required this.transactionHistoryIds,
    required this.labels,
    required this.labelIndexes,
    required this.isSingleScan,
  });

  factory ScanData.fromHeight(ScanData scanData, int newHeight) {
    return ScanData(
      sendPort: scanData.sendPort,
      silentAddress: scanData.silentAddress,
      height: newHeight,
      node: scanData.node,
      network: scanData.network,
      chainTip: scanData.chainTip,
      transactionHistoryIds: scanData.transactionHistoryIds,
      electrumClient: scanData.electrumClient,
      labels: scanData.labels,
      labelIndexes: scanData.labelIndexes,
      isSingleScan: scanData.isSingleScan,
    );
  }
}

class SyncResponse {
  final int height;
  final SyncStatus syncStatus;

  SyncResponse(this.height, this.syncStatus);
}

Future<void> startRefresh(ScanData scanData) async {
  int syncHeight = scanData.height;
  int initialSyncHeight = syncHeight;

  BehaviorSubject<Object>? tweaksSubscription = null;

  final electrumClient = scanData.electrumClient;
  await electrumClient.connectToUri(
    scanData.node?.uri ?? Uri.parse("tcp://electrs.cakewallet.com:50001"),
    useSSL: scanData.node?.useSSL ?? false,
  );

  int getCountPerRequest(int syncHeight) {
    if (scanData.isSingleScan) {
      return 1;
    }

    final amountLeft = scanData.chainTip - syncHeight + 1;
    return amountLeft;
  }

  if (tweaksSubscription == null) {
    final receiver = Receiver(
      scanData.silentAddress.b_scan.toHex(),
      scanData.silentAddress.B_spend.toHex(),
      scanData.network == BitcoinNetwork.testnet,
      scanData.labelIndexes,
      scanData.labelIndexes.length,
    );

    // Initial status UI update, send how many blocks in total to scan
    final initialCount = getCountPerRequest(syncHeight);
    scanData.sendPort.send(SyncResponse(syncHeight, StartingScanSyncStatus(syncHeight)));

    tweaksSubscription = await electrumClient.tweaksSubscribe(
      height: syncHeight,
      count: initialCount,
    );

    Future<void> listenFn(t) async {
      final tweaks = t as Map<String, dynamic>;
      final msg = tweaks["message"];
      // success or error msg
      final noData = msg != null;

      if (noData) {
        // re-subscribe to continue receiving messages, starting from the next unscanned height
        final nextHeight = syncHeight + 1;
        final nextCount = getCountPerRequest(nextHeight);

        if (nextCount > 0) {
          tweaksSubscription?.close();

          final nextTweaksSubscription = electrumClient.tweaksSubscribe(
            height: nextHeight,
            count: nextCount,
          );
          nextTweaksSubscription?.listen(listenFn);
        }

        return;
      }

      // Continuous status UI update, send how many blocks left to scan
      final syncingStatus = scanData.isSingleScan
          ? SyncingSyncStatus(1, 0)
          : SyncingSyncStatus.fromHeightValues(scanData.chainTip, initialSyncHeight, syncHeight);
      scanData.sendPort.send(SyncResponse(syncHeight, syncingStatus));

      final blockHeight = tweaks.keys.first;
      final tweakHeight = int.parse(blockHeight);

      try {
        final blockTweaks = tweaks[blockHeight] as Map<String, dynamic>;

        for (var j = 0; j < blockTweaks.keys.length; j++) {
          final txid = blockTweaks.keys.elementAt(j);
          final details = blockTweaks[txid] as Map<String, dynamic>;
          final outputPubkeys = (details["output_pubkeys"] as Map<dynamic, dynamic>);
          final tweak = details["tweak"].toString();

          try {
            // scanOutputs called from rust here
            final addToWallet = scanOutputs(
              outputPubkeys.values.toList(),
              tweak,
              receiver,
            );

            if (addToWallet.isEmpty) {
              // no results tx, continue to next tx
              continue;
            }

            // placeholder ElectrumTransactionInfo object to update values based on new scanned unspent(s)
            final txInfo = ElectrumTransactionInfo(
              WalletType.bitcoin,
              id: txid,
              height: tweakHeight,
              amount: 0,
              fee: 0,
              direction: TransactionDirection.incoming,
              isPending: false,
              isReplaced: false,
              date: scanData.network == BitcoinNetwork.mainnet
                  ? getDateByBitcoinHeight(tweakHeight)
                  : DateTime.now(),
              confirmations: scanData.chainTip - tweakHeight + 1,
              unspents: [],
              isReceivedSilentPayment: true,
            );

            addToWallet.forEach((label, value) {
              (value as Map<String, dynamic>).forEach((output, tweak) {
                final t_k = tweak.toString();

                final receivingOutputAddress = ECPublic.fromHex(output)
                    .toTaprootAddress(tweak: false)
                    .toAddress(scanData.network);

                int? amount;
                int? pos;
                outputPubkeys.entries.firstWhere((k) {
                  final isMatchingOutput = k.value[0] == output;
                  if (isMatchingOutput) {
                    amount = int.parse(k.value[1].toString());
                    pos = int.parse(k.key.toString());
                    return true;
                  }
                  return false;
                });

                final receivedAddressRecord = BitcoinSilentPaymentAddressRecord(
                  receivingOutputAddress,
                  index: 0,
                  isHidden: false,
                  isUsed: true,
                  network: scanData.network,
                  silentPaymentTweak: t_k,
                  type: SegwitAddresType.p2tr,
                  txCount: 1,
                  balance: amount!,
                );

                final unspent = BitcoinSilentPaymentsUnspent(
                  receivedAddressRecord,
                  txid,
                  amount!,
                  pos!,
                  silentPaymentTweak: t_k,
                  silentPaymentLabel: label == "None" ? null : label,
                );

                txInfo.unspents!.add(unspent);
                txInfo.amount += unspent.value;
              });
            });

            scanData.sendPort.send({txInfo.id: txInfo});
          } catch (_) {}
        }
      } catch (_) {}

      syncHeight = tweakHeight;

      if (tweakHeight >= scanData.chainTip || scanData.isSingleScan) {
        if (tweakHeight >= scanData.chainTip)
          scanData.sendPort.send(SyncResponse(
            syncHeight,
            SyncedTipSyncStatus(scanData.chainTip),
          ));

        if (scanData.isSingleScan) {
          scanData.sendPort.send(SyncResponse(syncHeight, SyncedSyncStatus()));
        }

        await tweaksSubscription!.close();
        await electrumClient.close();
      }
    }

    tweaksSubscription?.listen(listenFn);
  }

  if (tweaksSubscription == null) {
    return scanData.sendPort.send(
      SyncResponse(syncHeight, UnsupportedSyncStatus()),
    );
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
    required this.spendsSilentPayment,
    required this.spendsUnconfirmedTX,
  });

  final List<UtxoWithAddress> utxos;
  final List<ECPrivateInfo> inputPrivKeyInfos;
  final Map<String, PublicKeyWithDerivationPath> publicKeys; // PubKey to derivationPath
  final int fee;
  final int amount;
  final bool spendsSilentPayment;

  // final bool sendsToSilentPayment;
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

BitcoinAddressType _getScriptType(BitcoinBaseAddress type) {
  if (type is P2pkhAddress) {
    return P2pkhAddressType.p2pkh;
  } else if (type is P2shAddress) {
    return P2shAddressType.p2wpkhInP2sh;
  } else if (type is P2wshAddress) {
    return SegwitAddresType.p2wsh;
  } else if (type is P2trAddress) {
    return SegwitAddresType.p2tr;
  } else if (type is MwebAddress) {
    return SegwitAddresType.mweb;
  } else if (type is SilentPaymentsAddresType) {
    return SilentPaymentsAddresType.p2sp;
  } else {
    return SegwitAddresType.p2wpkh;
  }
}

class UtxoDetails {
  final List<BitcoinUnspent> availableInputs;
  final List<BitcoinUnspent> unconfirmedCoins;
  final List<UtxoWithAddress> utxos;
  final List<Outpoint> vinOutpoints;
  final List<ECPrivateInfo> inputPrivKeyInfos;
  final Map<String, PublicKeyWithDerivationPath> publicKeys; // PubKey to derivationPath
  final int allInputsAmount;
  final bool spendsSilentPayment;
  final bool spendsUnconfirmedTX;

  UtxoDetails({
    required this.availableInputs,
    required this.unconfirmedCoins,
    required this.utxos,
    required this.vinOutpoints,
    required this.inputPrivKeyInfos,
    required this.publicKeys,
    required this.allInputsAmount,
    required this.spendsSilentPayment,
    required this.spendsUnconfirmedTX,
  });
}
