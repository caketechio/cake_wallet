import 'dart:async';
import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/bitcoin_wallet_snapshot.dart';
import 'package:cw_bitcoin/electrum_worker/methods/methods.dart';
import 'package:cw_bitcoin/exceptions.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_bitcoin/psbt_transaction_builder.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_bitcoin/electrum_derivations.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:hive/hive.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:mobx/mobx.dart';
import 'package:collection/collection.dart';

part 'bitcoin_wallet.g.dart';

class BitcoinWallet = BitcoinWalletBase with _$BitcoinWallet;

abstract class BitcoinWalletBase extends ElectrumWallet with Store {
  @observable
  bool nodeSupportsSilentPayments = true;
  @observable
  bool silentPaymentsScanningActive = false;
  @observable
  bool allowedToSwitchNodesForScanning = false;

  BitcoinWalletBase({
    required super.password,
    required super.walletInfo,
    required super.unspentCoinsInfo,
    required super.encryptionFileUtils,
    required super.hdWallets,
    super.mnemonic,
    super.xpub,
    BasedUtxoNetwork? networkParam,
    super.initialBalance,
    super.passphrase,
    super.alwaysScan,
    super.initialUnspentCoins,
    super.didInitialSync,
    Map<String, dynamic>? walletAddressesSnapshot,
  }) : super(
          network: networkParam == null
              ? BitcoinNetwork.mainnet
              : networkParam == BitcoinNetwork.mainnet
                  ? BitcoinNetwork.mainnet
                  : BitcoinNetwork.testnet,
          currency:
              networkParam == BitcoinNetwork.testnet ? CryptoCurrency.tbtc : CryptoCurrency.btc,
        ) {
    if (walletAddressesSnapshot != null) {
      walletAddresses = BitcoinWalletAddressesBase.fromJson(
        walletAddressesSnapshot,
        walletInfo,
        network: network,
        isHardwareWallet: isHardwareWallet,
        hdWallets: hdWallets,
      );
    } else {
      this.walletAddresses = BitcoinWalletAddresses(
        walletInfo,
        network: networkParam ?? network,
        isHardwareWallet: isHardwareWallet,
        hdWallets: hdWallets,
      );
    }

    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
    });
  }

  @override
  int get dustAmount => network == BitcoinNetwork.testnet ? 0 : 546;

  Future<bool> get mempoolAPIEnabled async {
    bool isMempoolAPIEnabled = (await sharedPrefs.future).getBool("use_mempool_fee_api") ?? true;
    return isMempoolAPIEnabled;
  }

  static Future<BitcoinWallet> create({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required EncryptionFileUtils encryptionFileUtils,
    String? passphrase,
    BasedUtxoNetwork? network,
  }) async {
    final hdWallets = await ElectrumWalletBase.getAccountHDWallets(
      walletInfo: walletInfo,
      network: network ?? BitcoinNetwork.mainnet,
      mnemonic: mnemonic,
      passphrase: passphrase,
    );

    return BitcoinWallet(
      mnemonic: mnemonic,
      passphrase: passphrase ?? "",
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      encryptionFileUtils: encryptionFileUtils,
      networkParam: network,
      hdWallets: hdWallets,
    );
  }

  static Future<BitcoinWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
    required bool alwaysScan,
  }) async {
    final network = walletInfo.network != null
        ? BasedUtxoNetwork.fromName(walletInfo.network!)
        : BitcoinNetwork.mainnet;

    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);

    BitcoinWalletSnapshot? snp = null;

    try {
      snp = await BitcoinWalletSnapshot.load(
        encryptionFileUtils,
        name,
        walletInfo,
        password,
        network,
      );
    } catch (e) {
      if (!hasKeysFile) rethrow;
    }

    final WalletKeysData keysData;
    // Migrate wallet from the old scheme to then new .keys file scheme
    if (!hasKeysFile) {
      keysData = WalletKeysData(
        mnemonic: snp!.mnemonic,
        xPub: snp.xpub,
        passphrase: snp.passphrase,
      );
    } else {
      keysData = await WalletKeysFile.readKeysFile(
        name,
        walletInfo.type,
        password,
        encryptionFileUtils,
      );
    }

    walletInfo.derivationInfo ??= DerivationInfo();

    // set the default if not present:
    walletInfo.derivationInfo!.derivationPath ??= snp?.derivationPath ?? electrum_path;
    walletInfo.derivationInfo!.derivationType ??= snp?.derivationType ?? DerivationType.electrum;

    final hdWallets = await ElectrumWalletBase.getAccountHDWallets(
      walletInfo: walletInfo,
      network: network,
      mnemonic: keysData.mnemonic,
      passphrase: keysData.passphrase,
      xpub: keysData.xPub,
    );

    return BitcoinWallet(
      mnemonic: keysData.mnemonic,
      xpub: keysData.xPub,
      password: password,
      passphrase: keysData.passphrase,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialBalance: snp?.balance,
      encryptionFileUtils: encryptionFileUtils,
      networkParam: network,
      alwaysScan: alwaysScan,
      initialUnspentCoins: snp?.unspentCoins,
      didInitialSync: snp?.didInitialSync,
      walletAddressesSnapshot: snp?.walletAddressesSnapshot,
      hdWallets: hdWallets,
    );
  }

  Future<bool> getNodeIsElectrs() async {
    if (node?.isElectrs != null) {
      return node!.isElectrs!;
    }

    final isNamedElectrs = node?.uri.host.contains("electrs") ?? false;
    if (isNamedElectrs) {
      node!.isElectrs = true;
      node!.save();
      return true;
    }

    final isNamedFulcrum = node!.uri.host.contains("fulcrum");
    if (isNamedFulcrum) {
      node!.isElectrs = false;
      node!.save();
      return false;
    }

    final version = await waitSendWorker(ElectrumWorkerGetVersionRequest());

    if (version is List<String> && version.isNotEmpty) {
      final server = version[0];

      if (server.toLowerCase().contains('electrs')) {
        node!.isElectrs = true;
      }
    } else if (version is String && version.toLowerCase().contains('electrs')) {
      node!.isElectrs = true;
    } else {
      node!.isElectrs = false;
    }

    node!.save();
    return node!.isElectrs!;
  }

  Future<bool> getNodeSupportsSilentPayments() async {
    if (node?.supportsSilentPayments != null) {
      return node!.supportsSilentPayments!;
    }

    // As of today (august 2024), only ElectrumRS supports silent payments
    final isElectrs = await getNodeIsElectrs();
    if (!isElectrs) {
      node!.supportsSilentPayments = false;
    }

    if (node!.supportsSilentPayments == null) {
      try {
        final workerResponse = (await waitSendWorker(ElectrumWorkerCheckTweaksRequest())) as String;
        final tweaksResponse = ElectrumWorkerCheckTweaksResponse.fromJson(
          json.decode(workerResponse) as Map<String, dynamic>,
        );
        final supportsScanning = tweaksResponse.result == true;

        if (supportsScanning) {
          node!.supportsSilentPayments = true;
        } else {
          node!.supportsSilentPayments = false;
        }
      } catch (_) {
        node!.supportsSilentPayments = false;
      }
    }
    node!.save();
    return node!.supportsSilentPayments!;
  }

  LedgerConnection? _ledgerConnection;
  BitcoinLedgerApp? _bitcoinLedgerApp;

  @override
  void setLedgerConnection(LedgerConnection connection) {
    _ledgerConnection = connection;
    _bitcoinLedgerApp = BitcoinLedgerApp(_ledgerConnection!,
        derivationPath: walletInfo.derivationInfo!.derivationPath!);
  }

  @override
  Future<BtcTransaction> buildHardwareWalletTransaction({
    required List<BitcoinBaseOutput> outputs,
    required BigInt fee,
    required List<UtxoWithAddress> utxos,
    required Map<String, PublicKeyWithDerivationPath> publicKeys,
    String? memo,
    bool enableRBF = false,
    BitcoinOrdering inputOrdering = BitcoinOrdering.bip69,
    BitcoinOrdering outputOrdering = BitcoinOrdering.bip69,
  }) async {
    final masterFingerprint = await _bitcoinLedgerApp!.getMasterFingerprint();

    final psbtReadyInputs = <PSBTReadyUtxoWithAddress>[];
    for (final utxo in utxos) {
      final rawTx = await getTransactionHex(hash: utxo.utxo.txHash);
      final publicKeyAndDerivationPath = publicKeys[utxo.ownerDetails.address.pubKeyHash()]!;

      psbtReadyInputs.add(PSBTReadyUtxoWithAddress(
        utxo: utxo.utxo,
        rawTx: rawTx,
        ownerDetails: utxo.ownerDetails,
        ownerDerivationPath: publicKeyAndDerivationPath.derivationPath,
        ownerMasterFingerprint: masterFingerprint,
        ownerPublicKey: publicKeyAndDerivationPath.publicKey,
      ));
    }

    final psbt =
        PSBTTransactionBuild(inputs: psbtReadyInputs, outputs: outputs, enableRBF: enableRBF);

    final rawHex = await _bitcoinLedgerApp!.signPsbt(psbt: psbt.psbt);
    return BtcTransaction.fromRaw(BytesUtils.toHexString(rawHex));
  }

  @override
  Future<String> signMessage(String message, {String? address = null}) async {
    if (walletInfo.isHardwareWallet) {
      final addressEntry = address != null
          ? walletAddresses.allAddresses.firstWhere((element) => element.address == address)
          : null;
      final index = addressEntry?.index ?? 0;
      final isChange = addressEntry?.isChange == true ? 1 : 0;
      final accountPath = walletInfo.derivationInfo?.derivationPath;
      final derivationPath = accountPath != null ? "$accountPath/$isChange/$index" : null;

      final signature = await _bitcoinLedgerApp!
          .signMessage(message: ascii.encode(message), signDerivationPath: derivationPath);
      return base64Encode(signature);
    }

    return super.signMessage(message, address: address);
  }

  @override
  Future<void> updateFeeRates() async {
    workerSendPort!.send(
      ElectrumWorkerGetFeesRequest(mempoolAPIEnabled: await mempoolAPIEnabled).toJson(),
    );
  }

  @override
  Future<ElectrumTransactionBundle> getTransactionExpanded({required String hash}) async {
    return await waitSendWorker(
      ElectrumWorkerTxExpandedRequest(
        txHash: hash,
        currentChainTip: currentChainTip!,
        mempoolAPIEnabled: await mempoolAPIEnabled,
      ),
    ) as ElectrumTransactionBundle;
  }

  @override
  Future<ElectrumWorkerGetHistoryRequest> getUpdateTransactionsRequest([
    List<BitcoinAddressRecord>? addresses,
  ]) async {
    return ElectrumWorkerGetHistoryRequest(
      addresses: addresses ?? walletAddresses.allAddresses.toList(),
      storedTxs: transactionHistory.transactions.values.toList(),
      walletType: type,
      // If we still don't have currentChainTip, txs will still be fetched but shown
      // with confirmations as 0 but will be auto fixed on onHeadersResponse
      chainTip: currentChainTip ?? -1,
      network: network,
      mempoolAPIEnabled: await mempoolAPIEnabled,
    );
  }

  @action
  Future<void> setSilentPaymentsScanning(bool active, [int? height, bool? doSingleScan]) async {
    silentPaymentsScanningActive = active;
    final nodeSupportsSilentPayments = await getNodeSupportsSilentPayments();
    final isAllowedToScan = nodeSupportsSilentPayments || allowedToSwitchNodesForScanning;

    if (active && isAllowedToScan) {
      syncStatus = AttemptingScanSyncStatus();

      final tip = currentChainTip!;
      final beginHeight = height ?? walletInfo.restoreHeight;

      if (tip == beginHeight) {
        syncStatus = SyncedTipSyncStatus(tip);
        return;
      }

      if (tip > beginHeight) {
        _requestTweakScanning(beginHeight, doSingleScan: doSingleScan);
      }
    } else if (syncStatus is! SyncedSyncStatus) {
      await waitSendWorker(ElectrumWorkerStopScanningRequest());
      await startSync();
    }
  }

  @override
  @action
  Future<void> updateAllUnspents([Set<String>? scripthashes, bool? wait]) async {
    await super.updateAllUnspents(scripthashes, wait);

    final walletAddresses = this.walletAddresses as BitcoinWalletAddresses;

    walletAddresses.silentPaymentAddresses.forEach((addressRecord) {
      addressRecord.txCount = 0;
      addressRecord.balance = 0;
    });
    walletAddresses.receivedSPAddresses.forEach((addressRecord) {
      addressRecord.txCount = 0;
      addressRecord.balance = 0;
    });

    final silentPaymentWallet = walletAddresses.silentPaymentWallet;

    unspentCoins.forEach((unspent) {
      if (unspent.bitcoinAddressRecord is BitcoinReceivedSPAddressRecord) {
        _updateSilentAddressRecord(unspent);

        final receiveAddressRecord = unspent.bitcoinAddressRecord as BitcoinReceivedSPAddressRecord;
        final silentPaymentAddress = SilentPaymentAddress(
          version: silentPaymentWallet!.version,
          B_scan: silentPaymentWallet.B_scan,
          B_spend: receiveAddressRecord.labelHex != null
              ? silentPaymentWallet.B_spend.tweakAdd(
                  BigintUtils.fromBytes(
                    BytesUtils.fromHexString(receiveAddressRecord.labelHex!),
                  ),
                )
              : silentPaymentWallet.B_spend,
        );

        walletAddresses.silentPaymentAddresses.forEach((addressRecord) {
          if (addressRecord.address == silentPaymentAddress.toAddress(network)) {
            addressRecord.txCount += 1;
            addressRecord.balance += unspent.value;
          }
        });
        walletAddresses.receivedSPAddresses.forEach((addressRecord) {
          if (addressRecord.address == receiveAddressRecord.address) {
            addressRecord.txCount += 1;
            addressRecord.balance += unspent.value;
          }
        });
      }
    });

    await walletAddresses.updateAddressesInBox();
  }

  @override
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
      if (coin.bitcoinAddressRecord is! BitcoinSilentPaymentAddressRecord)
        coin.bitcoinAddressRecord.balance += coinInfo.value;
    } else {
      addCoinInfo(coin);
    }
  }

  @override
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

  @action
  @override
  Future<void> rescan({required int height, bool? doSingleScan}) async {
    setSilentPaymentsScanning(true, height, doSingleScan);
  }

  @action
  void _updateSilentAddressRecord(BitcoinUnspent unspent) {
    final walletAddresses = this.walletAddresses as BitcoinWalletAddresses;
    walletAddresses.addReceivedSPAddresses(
      [unspent.bitcoinAddressRecord as BitcoinReceivedSPAddressRecord],
    );
  }

  @override
  @action
  Future<void> handleWorkerResponse(dynamic message) async {
    super.handleWorkerResponse(message);

    Map<String, dynamic> messageJson;
    if (message is String) {
      messageJson = jsonDecode(message) as Map<String, dynamic>;
    } else {
      messageJson = message as Map<String, dynamic>;
    }
    final workerMethod = messageJson['method'] as String;
    final workerError = messageJson['error'] as String?;

    switch (workerMethod) {
      case ElectrumRequestMethods.tweaksSubscribeMethod:
        if (workerError != null) {
          printV(messageJson);
          // _onConnectionStatusChange(ConnectionStatus.failed);
          break;
        }

        final response = ElectrumWorkerTweaksSubscribeResponse.fromJson(messageJson);
        onTweaksSyncResponse(response.result);
        break;
    }
  }

  @action
  Future<void> onTweaksSyncResponse(TweaksSyncResponse result) async {
    if (result.transactions?.isNotEmpty == true) {
      (walletAddresses as BitcoinWalletAddresses).silentPaymentAddresses.forEach((addressRecord) {
        addressRecord.txCount = 0;
        addressRecord.balance = 0;
      });
      (walletAddresses as BitcoinWalletAddresses).receivedSPAddresses.forEach((addressRecord) {
        addressRecord.txCount = 0;
        addressRecord.balance = 0;
      });

      for (final map in result.transactions!.entries) {
        final txid = map.key;
        final data = map.value;
        final tx = data.txInfo;
        final unspents = data.unspents;

        if (unspents.isNotEmpty) {
          final existingTxInfo = transactionHistory.transactions[txid];
          final txAlreadyExisted = existingTxInfo != null;

          // Updating tx after re-scanned
          if (txAlreadyExisted) {
            existingTxInfo.amount = tx.amount;
            existingTxInfo.confirmations = tx.confirmations;
            existingTxInfo.height = tx.height;

            final newUnspents = unspents
                .where(
                  (unspent) => !unspentCoins.any((element) =>
                      element.hash.contains(unspent.hash) &&
                      element.vout == unspent.vout &&
                      element.value == unspent.value),
                )
                .toList();

            if (newUnspents.isNotEmpty) {
              newUnspents.forEach(_updateSilentAddressRecord);

              unspentCoins.addAll(newUnspents);
              unspentCoins.forEach(updateCoin);

              await refreshUnspentCoinsInfo();

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
            unspentCoins.forEach(_updateSilentAddressRecord);

            transactionHistory.addOne(tx);
            balance[currency]!.confirmed += tx.amount;
          }

          await updateAllUnspents();
        }
      }
    }

    final newSyncStatus = result.syncStatus;

    if (newSyncStatus != null) {
      if (newSyncStatus is UnsupportedSyncStatus) {
        nodeSupportsSilentPayments = false;
      }

      if (newSyncStatus is SyncingSyncStatus) {
        syncStatus = SyncingSyncStatus(newSyncStatus.blocksLeft, newSyncStatus.ptc);
      } else {
        syncStatus = newSyncStatus;

        if (newSyncStatus is SyncedSyncStatus) {
          silentPaymentsScanningActive = false;
        }
      }

      final height = result.height;
      if (height != null && result.wasSingleBlock == false) {
        await walletInfo.updateRestoreHeight(height);
      }
    }
  }

  @action
  Future<void> _requestTweakScanning(int height, {bool? doSingleScan}) async {
    if (currentChainTip == null) {
      throw Exception("currentChainTip is null");
    }

    final chainTip = currentChainTip!;

    if (chainTip == height) {
      syncStatus = SyncedSyncStatus();
      return;
    }

    syncStatus = AttemptingScanSyncStatus();

    final walletAddresses = this.walletAddresses as BitcoinWalletAddresses;
    workerSendPort!.send(
      ElectrumWorkerTweaksSubscribeRequest(
        scanData: ScanData(
          silentPaymentsWallets: walletAddresses.silentPaymentWallets,
          network: network,
          height: height,
          chainTip: chainTip,
          transactionHistoryIds: transactionHistory.transactions.keys.toList(),
          labels: walletAddresses.labels,
          labelIndexes: walletAddresses.silentPaymentAddresses
              .where((addr) => addr.type == SilentPaymentsAddresType.p2sp && addr.labelIndex >= 1)
              .map((addr) => addr.labelIndex)
              .toList(),
          isSingleScan: doSingleScan ?? false,
          shouldSwitchNodes:
              !(await getNodeSupportsSilentPayments()) && allowedToSwitchNodesForScanning,
        ),
      ).toJson(),
    );
  }

  @override
  @action
  Future<void> onHeadersResponse(ElectrumHeaderResponse response) async {
    super.onHeadersResponse(response);

    _setInitialScanHeight();

    // New headers received, start scanning
    if (alwaysScan == true && syncStatus is SyncedSyncStatus) {
      _requestTweakScanning(walletInfo.restoreHeight);
    }
  }

  Future<void> _setInitialScanHeight() async {
    final validChainTip = currentChainTip != null && currentChainTip != 0;
    if (validChainTip && walletInfo.restoreHeight == 0) {
      await walletInfo.updateRestoreHeight(currentChainTip!);
    }
  }

  @override
  @action
  void syncStatusReaction(SyncStatus syncStatus) {
    switch (syncStatus.runtimeType) {
      case SyncingSyncStatus:
        return;
      case SyncedTipSyncStatus:
        silentPaymentsScanningActive = false;

        // Message is shown on the UI for 3 seconds, then reverted to synced
        Timer(Duration(seconds: 3), () {
          if (this.syncStatus is SyncedTipSyncStatus) this.syncStatus = SyncedSyncStatus();
        });
        break;
      default:
        super.syncStatusReaction(syncStatus);
    }
  }

  @override
  int calcFee({
    required List<UtxoWithAddress> utxos,
    required List<BitcoinBaseOutput> outputs,
    String? memo,
    required int feeRate,
    List<ECPrivateInfo>? inputPrivKeyInfos,
    List<Outpoint>? vinOutpoints,
  }) =>
      feeRate *
      BitcoinTransactionBuilder.estimateTransactionSize(
        utxos: utxos,
        outputs: outputs,
        network: network,
        memo: memo,
        inputPrivKeyInfos: inputPrivKeyInfos,
        vinOutpoints: vinOutpoints,
      );

  @override
  BitcoinTxCreateUtxoDetails createUTXOS({
    required bool sendAll,
    bool paysToSilentPayment = false,
    int credentialsAmount = 0,
    int? inputsCount,
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
      // TODO: unspent coin isSending not toggled
      if (!utx.isSending || utx.isFrozen) {
        return false;
      }
      return true;
    }).toList();
    final unconfirmedCoins = availableInputs.where((utx) => utx.confirmations == 0).toList();

    for (int i = 0; i < availableInputs.length; i++) {
      final utx = availableInputs[i];
      if (!spendsUnconfirmedTX) spendsUnconfirmedTX = utx.confirmations == 0;

      if (paysToSilentPayment) {
        // Check inputs for shared secret derivation
        if (utx.bitcoinAddressRecord.type == SegwitAddressType.p2wsh) {
          throw BitcoinTransactionSilentPaymentsNotSupported();
        }
      }

      allInputsAmount += utx.value;
      leftAmount = leftAmount - utx.value;

      final address = RegexUtils.addressTypeFromStr(utx.address, network);
      ECPrivate? privkey;
      bool? isSilentPayment = false;

      if (utx.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord) {
        privkey = (utx.bitcoinAddressRecord as BitcoinReceivedSPAddressRecord).getSpendKey(
          (walletAddresses as BitcoinWalletAddresses).silentPaymentWallets,
          network,
        );
        spendsSilentPayment = true;
        isSilentPayment = true;
      } else if (!isHardwareWallet) {
        final addressRecord = (utx.bitcoinAddressRecord as BitcoinAddressRecord);
        final path = addressRecord.derivationInfo.derivationPath
            .addElem(Bip32KeyIndex(
              BitcoinAddressUtils.getAccountFromChange(addressRecord.isChange),
            ))
            .addElem(Bip32KeyIndex(addressRecord.index));

        privkey = ECPrivate.fromBip32(bip32: hdWallet.derive(path));
      }

      vinOutpoints.add(Outpoint(txid: utx.hash, index: utx.vout));
      String pubKeyHex;

      if (privkey != null) {
        inputPrivKeyInfos.add(ECPrivateInfo(
          privkey,
          address.type == SegwitAddressType.p2tr,
          tweak: !isSilentPayment,
        ));

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

    return BitcoinTxCreateUtxoDetails(
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

  @override
  Future<BitcoinEstimatedTx> estimateSendAllTx(
    List<BitcoinOutput> outputs,
    int feeRate, {
    String? memo,
    bool hasSilentPayment = false,
  }) async {
    final utxoDetails = createUTXOS(sendAll: true, paysToSilentPayment: hasSilentPayment);

    int fee = await calcFee(
      utxos: utxoDetails.utxos,
      outputs: outputs,
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
    if (isBelowDust(amount)) {
      throw BitcoinTransactionNoDustException();
    }

    if (outputs.length == 1) {
      outputs[0] = BitcoinOutput(address: outputs.last.address, value: BigInt.from(amount));
    }

    return BitcoinEstimatedTx(
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

  @override
  Future<BitcoinEstimatedTx> estimateTxForAmount(
    int credentialsAmount,
    List<BitcoinOutput> outputs,
    int feeRate, {
    List<BitcoinOutput>? updatedOutputs,
    int? inputsCount,
    String? memo,
    bool? useUnconfirmed,
    bool hasSilentPayment = false,
    bool isFakeTx = false,
  }) async {
    if (updatedOutputs == null) {
      updatedOutputs = outputs.map((output) => output).toList();
    }

    // Attempting to send less than the dust limit
    if (!isFakeTx && isBelowDust(credentialsAmount)) {
      throw BitcoinTransactionNoDustException();
    }

    final utxoDetails = createUTXOS(
      sendAll: false,
      credentialsAmount: credentialsAmount,
      inputsCount: inputsCount,
      paysToSilentPayment: hasSilentPayment,
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
          updatedOutputs: updatedOutputs,
          inputsCount: utxoDetails.utxos.length + 1,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
          isFakeTx: isFakeTx,
        );
      }

      throw BitcoinTransactionWrongBalanceException();
    }

    final changeAddress = await walletAddresses.getChangeAddress();
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
        (changeAddress as BitcoinAddressRecord).derivationInfo.derivationPath.toString();
    utxoDetails.publicKeys[address.pubKeyHash()] =
        PublicKeyWithDerivationPath('', changeDerivationPath);

    // calcFee updates the silent payment outputs to calculate the tx size accounting
    // for taproot addresses, but if more inputs are needed to make up for fees,
    // the silent payment outputs need to be recalculated for the new inputs
    var temp = outputs.map((output) => output).toList();
    int fee = calcFee(
      utxos: utxoDetails.utxos,
      // Always take only not updated bitcoin outputs here so for every estimation
      // the SP outputs are re-generated to the proper taproot addresses
      outputs: temp,
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

    if (!isFakeTx && isBelowDust(amountLeftForChange)) {
      // If has change that is lower than dust, will end up with tx rejected by network rules
      // so remove the change amount
      updatedOutputs.removeLast();
      outputs.removeLast();

      if (amountLeftForChange < 0) {
        if (!spendingAllCoins) {
          return estimateTxForAmount(
            credentialsAmount,
            outputs,
            feeRate,
            updatedOutputs: updatedOutputs,
            inputsCount: utxoDetails.utxos.length + 1,
            memo: memo,
            useUnconfirmed: useUnconfirmed ?? spendingAllConfirmedCoins,
            hasSilentPayment: hasSilentPayment,
            isFakeTx: isFakeTx,
          );
        } else {
          throw BitcoinTransactionWrongBalanceException();
        }
      }

      return BitcoinEstimatedTx(
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

      return BitcoinEstimatedTx(
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

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    try {
      final outputs = <BitcoinOutput>[];
      final transactionCredentials = credentials as BitcoinTransactionCredentials;
      final hasMultiDestination = transactionCredentials.outputs.length > 1;
      final sendAll = !hasMultiDestination && transactionCredentials.outputs.first.sendAll;
      final memo = transactionCredentials.outputs.first.memo;

      int credentialsAmount = 0;
      bool hasSilentPayment = false;

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

      BitcoinEstimatedTx estimatedTx;
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
        );
      } else {
        estimatedTx = await estimateTxForAmount(
          credentialsAmount,
          outputs,
          feeRateInt,
          updatedOutputs: updatedOutputs,
          memo: memo,
          hasSilentPayment: hasSilentPayment,
        );
      }

      if (walletInfo.isHardwareWallet) {
        final transaction = await buildHardwareWalletTransaction(
          utxos: estimatedTx.utxos,
          outputs: updatedOutputs,
          publicKeys: estimatedTx.publicKeys,
          fee: BigInt.from(estimatedTx.fee),
          memo: estimatedTx.memo,
          outputOrdering: BitcoinOrdering.none,
          enableRBF: true,
        );

        return PendingBitcoinTransaction(
          transaction,
          type,
          sendWorker: waitSendWorker,
          amount: estimatedTx.amount,
          fee: estimatedTx.fee,
          feeRate: feeRateInt.toString(),
          hasChange: estimatedTx.hasChange,
          isSendAll: estimatedTx.isSendAll,
          hasTaprootInputs: false, // ToDo: (Konsti) Support Taproot
        )..addListener((transaction) async {
            transactionHistory.addOne(transaction);
            await updateBalance();
          });
      }

      final txb = BitcoinTransactionBuilder(
        utxos: estimatedTx.utxos,
        outputs: updatedOutputs,
        fee: BigInt.from(estimatedTx.fee),
        network: network,
        memo: estimatedTx.memo,
        outputOrdering: BitcoinOrdering.none,
        enableRBF: !estimatedTx.spendsUnconfirmedTX,
      );

      bool hasTaprootInputs = false;

      final transaction = txb.buildTransaction((txDigest, utxo, publicKey, sighash) {
        String error = "Cannot find private key.";

        ECPrivateInfo? key;

        if (estimatedTx.inputPrivKeyInfos.isEmpty) {
          error += "\nNo private keys generated.";
        } else {
          error += "\nAddress: ${utxo.ownerDetails.address.toAddress(network)}";

          try {
            key = estimatedTx.inputPrivKeyInfos.firstWhere((element) {
              final elemPubkey = element.privkey.getPublic().toHex();
              if (elemPubkey == publicKey) {
                return true;
              } else {
                error += "\nExpected: $publicKey";
                error += "\nPubkey: $elemPubkey";
                return false;
              }
            });
          } catch (_) {
            throw Exception(error);
          }
        }

        if (key == null) {
          throw Exception(error);
        }

        if (utxo.utxo.isP2tr) {
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
        sendWorker: waitSendWorker,
        amount: estimatedTx.amount,
        fee: estimatedTx.fee,
        feeRate: feeRateInt.toString(),
        hasChange: estimatedTx.hasChange,
        isSendAll: estimatedTx.isSendAll,
        hasTaprootInputs: hasTaprootInputs,
        utxos: estimatedTx.utxos,
        hasSilentPayment: hasSilentPayment,
      )..addListener((transaction) async {
          transactionHistory.addOne(transaction);
          if (estimatedTx.spendsSilentPayment) {
            transactionHistory.transactions.values.forEach((tx) {
              // tx.unspents?.removeWhere(
              //     (unspent) => estimatedTx.utxos.any((e) => e.utxo.txHash == unspent.hash));
              transactionHistory.addOne(tx);
            });
          }

          unspentCoins
              .removeWhere((utxo) => estimatedTx.utxos.any((e) => e.utxo.txHash == utxo.hash));

          await updateBalance();
        });
    } catch (e) {
      throw e;
    }
  }

  @override
  @action
  Future<void> onUnspentResponse(Map<String, List<ElectrumUtxo>> unspents) async {
    final silentPaymentUnspents = unspentCoins
        .where((utxo) =>
            utxo.bitcoinAddressRecord is BitcoinSilentPaymentAddressRecord ||
            utxo.bitcoinAddressRecord is BitcoinReceivedSPAddressRecord)
        .toList();

    unspentCoins.clear();
    unspentCoins.addAll(silentPaymentUnspents);

    super.onUnspentResponse(unspents);
  }
}

class BitcoinEstimatedTx extends ElectrumEstimatedTx {
  BitcoinEstimatedTx({
    required super.utxos,
    required super.inputPrivKeyInfos,
    required super.publicKeys,
    required super.fee,
    required super.amount,
    required super.hasChange,
    required super.isSendAll,
    required super.spendsUnconfirmedTX,
    super.memo,
    this.spendsSilentPayment = false,
  });

  final bool spendsSilentPayment;
}

class BitcoinTxCreateUtxoDetails extends ElectrumTxCreateUtxoDetails {
  final bool spendsSilentPayment;

  BitcoinTxCreateUtxoDetails({
    required super.availableInputs,
    required super.unconfirmedCoins,
    required super.utxos,
    required super.vinOutpoints,
    required super.inputPrivKeyInfos,
    required super.publicKeys,
    required super.allInputsAmount,
    required super.spendsUnconfirmedTX,
    this.spendsSilentPayment = false,
  });
}
