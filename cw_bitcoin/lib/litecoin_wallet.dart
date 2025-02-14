import 'dart:async';
import 'dart:convert';

import 'package:convert/convert.dart' as convert;
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/exceptions.dart';
import 'package:cw_bitcoin/litecoin_wallet_snapshot.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/mweb_utxo.dart';
import 'package:cw_core/unspent_coin_type.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/node.dart';
import 'package:cw_mweb/mwebd.pbgrpc.dart';
import 'package:fixnum/fixnum.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:blockchain_utils/signer/ecdsa_signing_key.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/litecoin_wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:hive/hive.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:ledger_litecoin/ledger_litecoin.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_mweb/cw_mweb.dart';
import 'package:bitcoin_base/src/crypto/keypair/sign_utils.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'litecoin_wallet.g.dart';

class LitecoinWallet = LitecoinWalletBase with _$LitecoinWallet;

abstract class LitecoinWalletBase extends ElectrumWallet with Store {
  LitecoinWalletBase({
    required super.password,
    required super.walletInfo,
    required super.unspentCoinsInfo,
    required super.encryptionFileUtils,
    required super.hdWallets,
    super.mnemonic,
    super.xpub,
    String? passphrase,
    super.initialBalance,
    int? initialMwebHeight,
    super.alwaysScan,
    super.didInitialSync,
    Map<String, dynamic>? walletAddressesSnapshot,
  }) : super(
          network: LitecoinNetwork.mainnet,
          currency: CryptoCurrency.ltc,
        ) {
    mwebEnabled = alwaysScan ?? false;

    if (walletAddressesSnapshot != null) {
      walletAddresses = LitecoinWalletAddressesBase.fromJson(
        walletAddressesSnapshot,
        walletInfo,
        network: network,
        isHardwareWallet: isHardwareWallet,
        hdWallets: hdWallets,
      );
    } else {
      walletAddresses = LitecoinWalletAddresses(
        walletInfo,
        network: network,
        mwebEnabled: mwebEnabled,
        isHardwareWallet: walletInfo.isHardwareWallet,
        hdWallets: hdWallets,
      );
    }

    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
    });
    reaction((_) => mwebSyncStatus, (status) async {
      if (mwebSyncStatus is FailedSyncStatus) {
        // we failed to connect to mweb, check if we are connected to the litecoin node:		        await CwMweb.stop();
        await Future.delayed(const Duration(seconds: 5));

        if ((currentChainTip ?? 0) == 0) {
          // we aren't connected to the litecoin node, so the current electrum_wallet reactions will take care of this case for us
        } else {
          // we're connected to the litecoin node, but we failed to connect to mweb, try again after a few seconds:
          await CwMweb.stop();
          await Future.delayed(const Duration(seconds: 5));
          startSync();
        }
      } else if (mwebSyncStatus is SyncingSyncStatus) {
        syncStatus = mwebSyncStatus;
      } else if (mwebSyncStatus is SynchronizingSyncStatus) {
        if (syncStatus is! SynchronizingSyncStatus) {
          syncStatus = mwebSyncStatus;
        }
      } else if (mwebSyncStatus is SyncedSyncStatus) {
        if (syncStatus is! SyncedSyncStatus) {
          syncStatus = mwebSyncStatus;
        }
      }
    });
  }

  @override
  LitecoinNetwork get network => LitecoinNetwork.mainnet;

  Bip32Slip10Secp256k1? get mwebHd => (walletAddresses as LitecoinWalletAddresses).mwebHd;

  late final Box<MwebUtxo> mwebUtxosBox;
  Timer? _syncTimer;
  Timer? _feeRatesTimer;
  Timer? _processingTimer;
  StreamSubscription<Utxo>? _utxoStream;
  late bool mwebEnabled;
  bool processingUtxos = false;

  @observable
  SyncStatus mwebSyncStatus = NotConnectedSyncStatus();

  List<int> get scanSecret => mwebHd!.childKey(Bip32KeyIndex(0x80000000)).privateKey.privKey.raw;
  List<int> get spendSecret => mwebHd!.childKey(Bip32KeyIndex(0x80000001)).privateKey.privKey.raw;

  static Future<LitecoinWallet> create({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required EncryptionFileUtils encryptionFileUtils,
    String? passphrase,
    List<BitcoinAddressRecord>? initialAddresses,
    List<LitecoinMWEBAddressRecord>? initialMwebAddresses,
    ElectrumBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
  }) async {
    final hdWallets = await ElectrumWalletBase.getAccountHDWallets(
      walletInfo: walletInfo,
      network: LitecoinNetwork.mainnet,
      mnemonic: mnemonic,
      passphrase: passphrase,
    );

    return LitecoinWallet(
      mnemonic: mnemonic,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialBalance: initialBalance,
      encryptionFileUtils: encryptionFileUtils,
      passphrase: passphrase,
      hdWallets: hdWallets,
    );
  }

  static Future<LitecoinWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required bool alwaysScan,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);

    LitecoinWalletSnapshot? snp = null;

    try {
      snp = await LitecoinWalletSnapshot.load(
        encryptionFileUtils,
        name,
        walletInfo,
        password,
        LitecoinNetwork.mainnet,
      );
    } catch (e) {
      if (!hasKeysFile) rethrow;
    }

    final WalletKeysData keysData;
    // Migrate wallet from the old scheme to then new .keys file scheme
    if (!hasKeysFile) {
      keysData =
          WalletKeysData(mnemonic: snp!.mnemonic, xPub: snp.xpub, passphrase: snp.passphrase);
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
    walletInfo.derivationInfo!.derivationPath ??= snp?.derivationPath ?? ELECTRUM_PATH;
    walletInfo.derivationInfo!.derivationType ??= snp?.derivationType ?? DerivationType.electrum;

    final hdWallets = await ElectrumWalletBase.getAccountHDWallets(
      walletInfo: walletInfo,
      network: LitecoinNetwork.mainnet,
      mnemonic: keysData.mnemonic,
      passphrase: keysData.passphrase,
      xpub: keysData.xPub,
    );

    return LitecoinWallet(
      mnemonic: keysData.mnemonic,
      xpub: keysData.xPub,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialBalance: snp?.balance,
      passphrase: keysData.passphrase,
      encryptionFileUtils: encryptionFileUtils,
      alwaysScan: snp?.alwaysScan,
      didInitialSync: snp?.didInitialSync,
      hdWallets: hdWallets,
    );
  }

  Future<void> waitForMwebAddresses() async {
    printV("waitForMwebAddresses() called!");
    // ensure that we have the full 1000 mweb addresses generated before continuing:
    // should no longer be needed, but leaving here just in case
    await (walletAddresses as LitecoinWalletAddresses).ensureMwebAddressUpToIndexExists(1020);
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    await super.connectToNode(node: node);

    final prefs = await SharedPreferences.getInstance();
    final mwebNodeUri = prefs.getString("mwebNodeUri") ?? "ltc-electrum.cakewallet.com:9333";
    await CwMweb.setNodeUriOverride(mwebNodeUri);
  }

  @action
  @override
  Future<void> startSync() async {
    printV("startSync() called!");
    printV("STARTING SYNC - MWEB ENABLED: $mwebEnabled");
    if (!mwebEnabled) {
      try {
        // in case we're switching from a litecoin wallet that had mweb enabled
        CwMweb.stop();
      } catch (_) {}
      super.startSync();
      return;
    }

    if (mwebSyncStatus is SynchronizingSyncStatus) {
      return;
    }

    printV("STARTING SYNC - MWEB ENABLED: $mwebEnabled");
    _syncTimer?.cancel();
    try {
      mwebSyncStatus = SynchronizingSyncStatus();
      try {
        await subscribeForStatuses();
      } catch (e) {
        printV("failed to subcribe for updates: $e");
      }
      updateFeeRates();
      _feeRatesTimer?.cancel();
      _feeRatesTimer =
          Timer.periodic(const Duration(minutes: 1), (timer) async => await updateFeeRates());

      printV("START SYNC FUNCS");
      await waitForMwebAddresses();
      await processMwebUtxos();
      await updateTransactions();
      await updateUnspent();
      await updateBalance();
    } catch (e) {
      printV("failed to start mweb sync: $e");
      syncStatus = FailedSyncStatus();
      return;
    }

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 3000), (timer) async {
      if (mwebSyncStatus is FailedSyncStatus) {
        _syncTimer?.cancel();
        return;
      }

      final nodeHeight = await currentChainTip ?? 0;

      if (nodeHeight == 0) {
        // we aren't connected to the ltc node yet
        if (mwebSyncStatus is! NotConnectedSyncStatus) {
          mwebSyncStatus = FailedSyncStatus(error: "litecoin node isn't connected");
        }
        return;
      }

      // update the current chain tip so that confirmation calculations are accurate:
      currentChainTip = nodeHeight;

      final resp = await CwMweb.status(StatusRequest());

      try {
        if (resp.blockHeaderHeight < nodeHeight) {
          int h = resp.blockHeaderHeight;
          mwebSyncStatus = SyncingSyncStatus(nodeHeight - h, h / nodeHeight);
        } else if (resp.mwebHeaderHeight < nodeHeight) {
          int h = resp.mwebHeaderHeight;
          mwebSyncStatus = SyncingSyncStatus(nodeHeight - h, h / nodeHeight);
        } else if (resp.mwebUtxosHeight < nodeHeight) {
          mwebSyncStatus = SyncingSyncStatus(1, 0.999);
        } else {
          bool confirmationsUpdated = false;
          if (resp.mwebUtxosHeight > walletInfo.restoreHeight) {
            await walletInfo.updateRestoreHeight(resp.mwebUtxosHeight);
            await checkMwebUtxosSpent();
            // update the confirmations for each transaction:
            for (final tx in transactionHistory.transactions.values) {
              if (tx.height == null || tx.height == 0) {
                // update with first confirmation on next block since it hasn't been confirmed yet:
                tx.height = resp.mwebUtxosHeight;
                continue;
              }

              final confirmations = (resp.mwebUtxosHeight - tx.height!) + 1;

              // if the confirmations haven't changed, skip updating:
              if (tx.confirmations == confirmations) continue;

              // if an outgoing tx is now confirmed, delete the utxo from the box (delete the unspent coin):
              if (confirmations >= 2 && tx.direction == TransactionDirection.outgoing) {
                for (var coin in unspentCoins) {
                  if (tx.inputAddresses?.contains(coin.address) ?? false) {
                    final utxo = mwebUtxosBox.get(coin.address);
                    if (utxo != null) {
                      printV("deleting utxo ${coin.address} @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
                      await mwebUtxosBox.delete(coin.address);
                    }
                  }
                }
              }

              tx.confirmations = confirmations;
              tx.isPending = false;
              transactionHistory.addOne(tx);
              confirmationsUpdated = true;
            }
            if (confirmationsUpdated) {
              await transactionHistory.save();
              await updateTransactions();
            }
          }

          // prevent unnecessary reaction triggers:
          if (mwebSyncStatus is! SyncedSyncStatus) {
            // mwebd is synced, but we could still be processing incoming utxos:
            if (!processingUtxos) {
              mwebSyncStatus = SyncedSyncStatus();
            }
          }
          return;
        }
      } catch (e) {
        printV("error syncing: $e");
        mwebSyncStatus = FailedSyncStatus(error: e.toString());
      }
    });
  }

  @action
  @override
  Future<void> stopSync() async {
    printV("stopSync() called!");
    _syncTimer?.cancel();
    _utxoStream?.cancel();
    _feeRatesTimer?.cancel();
    await CwMweb.stop();
    printV("stopped syncing!");
  }

  Future<void> initMwebUtxosBox() async {
    final boxName = "${walletInfo.name.replaceAll(" ", "_")}_${MwebUtxo.boxName}";

    mwebUtxosBox = await CakeHive.openBox<MwebUtxo>(boxName);
  }

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    // rename the hive box:
    final oldBoxName = "${walletInfo.name.replaceAll(" ", "_")}_${MwebUtxo.boxName}";
    final newBoxName = "${newWalletName.replaceAll(" ", "_")}_${MwebUtxo.boxName}";

    final oldBox = await CakeHive.openBox<MwebUtxo>(oldBoxName);
    mwebUtxosBox = await CakeHive.openBox<MwebUtxo>(newBoxName);
    for (final key in oldBox.keys) {
      await mwebUtxosBox.put(key, oldBox.get(key)!);
    }
    oldBox.deleteFromDisk();

    await super.renameWalletFiles(newWalletName);
  }

  @action
  @override
  Future<void> rescan({required int height}) async {
    _syncTimer?.cancel();
    await walletInfo.updateRestoreHeight(height);

    // go through mwebUtxos and clear any that are above the new restore height:
    if (height == 0) {
      await mwebUtxosBox.clear();
      transactionHistory.clear();
    } else {
      for (final utxo in mwebUtxosBox.values) {
        if (utxo.height > height) {
          await mwebUtxosBox.delete(utxo.outputId);
        }
      }
      // TODO: remove transactions that are above the new restore height!
    }

    // reset coin balances and txCount to 0:
    unspentCoins.forEach((coin) {
      coin.bitcoinAddressRecord.balance = 0;
      coin.bitcoinAddressRecord.txCount = 0;
    });

    for (var addressRecord in walletAddresses.allAddresses) {
      addressRecord.balance = 0;
      addressRecord.txCount = 0;
    }

    await startSync();
  }

  @override
  Future<void> init() async {
    await super.init();
    await initMwebUtxosBox();
  }

  Future<void> handleIncoming(MwebUtxo utxo) async {
    printV("handleIncoming() called!");
    final status = await CwMweb.status(StatusRequest());
    var date = DateTime.now();
    var confirmations = 0;
    if (utxo.height > 0) {
      date = DateTime.fromMillisecondsSinceEpoch(utxo.blockTime * 1000);
      confirmations = status.blockHeaderHeight - utxo.height + 1;
    }
    var tx = transactionHistory.transactions.values
        .firstWhereOrNull((tx) => tx.outputAddresses?.contains(utxo.outputId) ?? false);

    if (tx == null) {
      tx = ElectrumTransactionInfo(
        WalletType.litecoin,
        id: utxo.outputId,
        height: utxo.height,
        amount: utxo.value.toInt(),
        fee: 0,
        direction: TransactionDirection.incoming,
        isPending: utxo.height == 0,
        date: date,
        confirmations: confirmations,
        inputAddresses: [],
        outputAddresses: [utxo.outputId],
        isReplaced: false,
      );
    } else {
      if (tx.confirmations != confirmations || tx.height != utxo.height) {
        tx.height = utxo.height;
        tx.confirmations = confirmations;
        tx.isPending = utxo.height == 0;
      }
    }

    bool isNew = transactionHistory.transactions[tx.id] == null;

    if (!(tx.outputAddresses?.contains(utxo.address) ?? false)) {
      tx.outputAddresses?.add(utxo.address);
      isNew = true;
    }

    if (isNew) {
      final addressRecord = walletAddresses.allAddresses
          .firstWhereOrNull((addressRecord) => addressRecord.address == utxo.address);
      if (addressRecord == null) {
        printV("we don't have this address in the wallet! ${utxo.address}");
        return;
      }

      // update the txCount:
      addressRecord.txCount++;
      addressRecord.balance += utxo.value.toInt();
      addressRecord.setAsUsed();
    }

    transactionHistory.addOne(tx);

    if (isNew) {
      // update the unconfirmed balance when a new tx is added:
      // we do this after adding the tx to the history so that sub address balances are updated correctly
      // (since that calculation is based on the tx history)
      await updateBalance();
    }
  }

  Future<void> processMwebUtxos() async {
    printV("processMwebUtxos() called!");
    if (!mwebEnabled) {
      return;
    }

    int restoreHeight = walletInfo.restoreHeight;
    printV("SCANNING FROM HEIGHT: $restoreHeight");
    final req = UtxosRequest(scanSecret: scanSecret, fromHeight: restoreHeight);

    // process new utxos as they come in:
    await _utxoStream?.cancel();
    ResponseStream<Utxo>? responseStream = await CwMweb.utxos(req);
    if (responseStream == null) {
      throw Exception("failed to get utxos stream!");
    }
    _utxoStream = responseStream.listen(
      (Utxo sUtxo) async {
        // we're processing utxos, so our balance could still be innacurate:
        if (mwebSyncStatus is! SynchronizingSyncStatus && mwebSyncStatus is! SyncingSyncStatus) {
          mwebSyncStatus = SynchronizingSyncStatus();
          processingUtxos = true;
          _processingTimer?.cancel();
          _processingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
            processingUtxos = false;
            timer.cancel();
          });
        }

        final utxo = MwebUtxo(
          address: sUtxo.address,
          blockTime: sUtxo.blockTime,
          height: sUtxo.height,
          outputId: sUtxo.outputId,
          value: sUtxo.value.toInt(),
        );

        if (mwebUtxosBox.containsKey(utxo.outputId)) {
          // we've already stored this utxo, skip it:
          // but do update the utxo height if it's somehow different:
          final existingUtxo = mwebUtxosBox.get(utxo.outputId);
          if (existingUtxo!.height != utxo.height) {
            printV(
                "updating utxo height for $utxo.outputId: ${existingUtxo.height} -> ${utxo.height}");
            existingUtxo.height = utxo.height;
            await mwebUtxosBox.put(utxo.outputId, existingUtxo);
          }
          return;
        }

        await updateUnspent();
        await updateBalance();

        final mwebAddrs = (walletAddresses as LitecoinWalletAddresses).mwebAddrs;

        // don't process utxos with addresses that are not in the mwebAddrs list:
        if (utxo.address.isNotEmpty && !mwebAddrs.contains(utxo.address)) {
          return;
        }

        await mwebUtxosBox.put(utxo.outputId, utxo);

        await handleIncoming(utxo);
      },
      onError: (error) {
        printV("error in utxo stream: $error");
        mwebSyncStatus = FailedSyncStatus(error: error.toString());
      },
      cancelOnError: true,
    );
  }

  Future<void> deleteSpentUtxos() async {
    printV("deleteSpentUtxos() called!");
    final chainHeight = currentChainTip;
    final status = await CwMweb.status(StatusRequest());
    if (chainHeight == null || status.blockHeaderHeight != chainHeight) return;
    if (status.mwebUtxosHeight != chainHeight) return; // we aren't synced

    // delete any spent utxos with >= 2 confirmations:
    final spentOutputIds = mwebUtxosBox.values
        .where((utxo) => utxo.spent && (chainHeight - utxo.height) >= 2)
        .map((utxo) => utxo.outputId)
        .toList();

    if (spentOutputIds.isEmpty) return;

    final resp = await CwMweb.spent(SpentRequest(outputId: spentOutputIds));
    final spent = resp.outputId;
    if (spent.isEmpty) return;

    for (final outputId in spent) {
      await mwebUtxosBox.delete(outputId);
    }
  }

  Future<void> checkMwebUtxosSpent() async {
    printV("checkMwebUtxosSpent() called!");
    if (!mwebEnabled) {
      return;
    }

    final pendingOutgoingTransactions = transactionHistory.transactions.values
        .where((tx) => tx.direction == TransactionDirection.outgoing && tx.isPending);

    // check if any of the pending outgoing transactions are now confirmed:
    bool updatedAny = false;
    for (final tx in pendingOutgoingTransactions) {
      updatedAny = await isConfirmed(tx) || updatedAny;
    }

    await deleteSpentUtxos();

    // get output ids of all the mweb utxos that have > 0 height:
    final outputIds = mwebUtxosBox.values
        .where((utxo) => utxo.height > 0 && !utxo.spent)
        .map((utxo) => utxo.outputId)
        .toList();

    final resp = await CwMweb.spent(SpentRequest(outputId: outputIds));
    final spent = resp.outputId;
    if (spent.isEmpty) return;

    final status = await CwMweb.status(StatusRequest());
    final height = await currentChainTip;
    if (height == null || status.blockHeaderHeight != height) return;
    if (status.mwebUtxosHeight != height) return; // we aren't synced
    int amount = 0;
    Set<String> inputAddresses = {};
    var output = convert.AccumulatorSink<Digest>();
    var input = sha256.startChunkedConversion(output);

    for (final outputId in spent) {
      final utxo = mwebUtxosBox.get(outputId);
      await mwebUtxosBox.delete(outputId);
      if (utxo == null) continue;
      final addressRecord = walletAddresses.allAddresses
          .firstWhere((addressRecord) => addressRecord.address == utxo.address);
      if (!inputAddresses.contains(utxo.address)) {
        addressRecord.txCount++;
      }
      addressRecord.balance -= utxo.value.toInt();
      amount += utxo.value.toInt();
      inputAddresses.add(utxo.address);
      input.add(hex.decode(outputId));
    }

    if (inputAddresses.isEmpty) return;
    input.close();
    var digest = output.events.single;
    final tx = ElectrumTransactionInfo(
      WalletType.litecoin,
      id: digest.toString(),
      height: height,
      amount: amount,
      fee: 0,
      direction: TransactionDirection.outgoing,
      isPending: false,
      date: DateTime.fromMillisecondsSinceEpoch(status.blockTime * 1000),
      confirmations: 1,
      inputAddresses: inputAddresses.toList(),
      outputAddresses: [],
      isReplaced: false,
    );

    transactionHistory.addOne(tx);
    await transactionHistory.save();

    if (updatedAny) {
      await updateBalance();
    }
  }

  // checks if a pending transaction is now confirmed, and updates the tx info accordingly:
  Future<bool> isConfirmed(ElectrumTransactionInfo tx) async {
    if (!mwebEnabled) return false;
    if (!tx.isPending) return false;

    final isMwebTx = (tx.inputAddresses?.any((addr) => addr.contains("mweb")) ?? false) ||
        (tx.outputAddresses?.any((addr) => addr.contains("mweb")) ?? false);

    if (!isMwebTx) {
      return false;
    }

    final outputId = <String>[], target = <String>{};
    final isHash = RegExp(r'^[a-f0-9]{64}$').hasMatch;
    final spendingOutputIds = tx.inputAddresses?.where(isHash) ?? [];
    final payingToOutputIds = tx.outputAddresses?.where(isHash) ?? [];
    outputId.addAll(spendingOutputIds);
    outputId.addAll(payingToOutputIds);
    target.addAll(spendingOutputIds);

    for (final outputId in payingToOutputIds) {
      final spendingTx = transactionHistory.transactions.values
          .firstWhereOrNull((tx) => tx.inputAddresses?.contains(outputId) ?? false);
      if (spendingTx != null && !spendingTx.isPending) {
        target.add(outputId);
      }
    }

    if (outputId.isEmpty) {
      return false;
    }

    final resp = await CwMweb.spent(SpentRequest(outputId: outputId));
    if (!setEquals(resp.outputId.toSet(), target)) {
      return false;
    }

    final status = await CwMweb.status(StatusRequest());
    tx.height = status.mwebUtxosHeight;
    tx.confirmations = 1;
    tx.isPending = false;
    await transactionHistory.save();
    return true;
  }

  Future<void> updateUnspent() async {
    printV("updateUnspent() called!");
    await checkMwebUtxosSpent();
    await updateAllUnspents();
  }

  @override
  @action
  Future<void> updateAllUnspents([Set<String>? scripthashes, bool? wait]) async {
    if (!mwebEnabled) {
      await super.updateAllUnspents(scripthashes, wait);
      return;
    }

    // add the mweb unspents to the list:
    List<BitcoinUnspent> mwebUnspentCoins = [];
    // update mweb unspents:
    final mwebAddrs = (walletAddresses as LitecoinWalletAddresses).mwebAddrs;
    mwebUtxosBox.keys.forEach((dynamic oId) {
      final String outputId = oId as String;
      final utxo = mwebUtxosBox.get(outputId);
      if (utxo == null || utxo.spent) {
        return;
      }
      if (utxo.address.isEmpty) {
        // not sure if a bug or a special case but we definitely ignore these
        return;
      }
      final addressRecord = walletAddresses.allAddresses
          .firstWhereOrNull((addressRecord) => addressRecord.address == utxo.address);

      if (addressRecord == null) {
        printV("utxo contains an address that is not in the wallet: ${utxo.address}");
        return;
      }
      final unspent = BitcoinUnspent(
        addressRecord,
        outputId,
        utxo.value.toInt(),
        mwebAddrs.indexOf(utxo.address),
        utxo.height,
      );
      if (unspent.vout == 0) {
        unspent.isChange = true;
      }
      mwebUnspentCoins.add(unspent);
    });

    // copy coin control attributes to mwebCoins:
    // await updateCoins(mwebUnspentCoins);
    // get regular ltc unspents (this resets unspentCoins):
    await super.updateAllUnspents();
    // add the mwebCoins:
    unspentCoins.addAll(mwebUnspentCoins);
  }

  // @override
  Future<void> updateBalance([Set<String>? scripthashes, bool? wait]) async {
    await super.updateBalance(scripthashes, true);
    final balance = this.balance[currency]!;

    if (!mwebEnabled) {
      return;
    }

    // update unspent balances:
    await updateUnspent();

    int confirmed = balance.confirmed;
    int unconfirmed = balance.unconfirmed;
    int confirmedMweb = 0;
    int unconfirmedMweb = 0;
    try {
      mwebUtxosBox.values.forEach((utxo) {
        if (utxo.height > 0) {
          confirmedMweb += utxo.value.toInt();
        } else {
          unconfirmedMweb += utxo.value.toInt();
        }
      });
      if (unconfirmedMweb > 0) {
        unconfirmedMweb = -1 * (confirmedMweb - unconfirmedMweb);
      }
    } catch (_) {}

    for (var addressRecord in walletAddresses.allAddresses) {
      addressRecord.balance = 0;
      addressRecord.txCount = 0;
    }

    unspentCoins.forEach((coin) {
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
        coin.bitcoinAddressRecord.balance += coinInfo.value;
      } else {
        super.addCoinInfo(coin);
      }
    });

    // update the txCount for each address using the tx history, since we can't rely on mwebd
    // to have an accurate count, we should just keep it in sync with what we know from the tx history:
    for (final tx in transactionHistory.transactions.values) {
      // if (tx.isPending) continue;
      if (tx.inputAddresses == null || tx.outputAddresses == null) {
        continue;
      }
      final txAddresses = tx.inputAddresses! + tx.outputAddresses!;
      for (final address in txAddresses) {
        final addressRecord = walletAddresses.allAddresses
            .firstWhereOrNull((addressRecord) => addressRecord.address == address);
        if (addressRecord == null) {
          continue;
        }
        addressRecord.txCount++;
      }
    }

    this.balance[currency] = ElectrumBalance(
      confirmed: confirmed,
      unconfirmed: unconfirmed,
      frozen: balance.frozen,
      secondConfirmed: confirmedMweb,
      secondUnconfirmed: unconfirmedMweb,
    );
  }

  @override
  ElectrumTxCreateUtxoDetails createUTXOS({
    required bool sendAll,
    int credentialsAmount = 0,
    int? inputsCount,
    UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any,
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

      switch (coinTypeToSpendFrom) {
        case UnspentCoinType.mweb:
          return utx.bitcoinAddressRecord.type == SegwitAddressType.mweb;
        case UnspentCoinType.nonMweb:
          return utx.bitcoinAddressRecord.type != SegwitAddressType.mweb;
        case UnspentCoinType.any:
          return true;
      }
    }).toList();
    final unconfirmedCoins = availableInputs.where((utx) => utx.confirmations == 0).toList();

    // sort the unconfirmed coins so that mweb coins are first:
    availableInputs.sort((a, b) => a.bitcoinAddressRecord.type == SegwitAddressType.mweb ? -1 : 1);

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

        privkey = ECPrivate.fromBip32(bip32: hdWallet.derive(path));
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

    return ElectrumTxCreateUtxoDetails(
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

  Future<ElectrumEstimatedTx> estimateSendAllTxMweb(
    List<BitcoinOutput> outputs,
    int feeRate, {
    String? memo,
    UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any,
  }) async {
    final utxoDetails = createUTXOS(sendAll: true, coinTypeToSpendFrom: coinTypeToSpendFrom);

    int fee = await calcFeeMweb(
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

    return ElectrumEstimatedTx(
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

  Future<ElectrumEstimatedTx> estimateTxForAmountMweb(
    int credentialsAmount,
    List<BitcoinOutput> outputs,
    int feeRate, {
    int? inputsCount,
    String? memo,
    bool? useUnconfirmed,
    UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any,
  }) async {
    // Attempting to send less than the dust limit
    if (isBelowDust(credentialsAmount)) {
      throw BitcoinTransactionNoDustException();
    }

    final utxoDetails = createUTXOS(
      sendAll: false,
      credentialsAmount: credentialsAmount,
      inputsCount: inputsCount,
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
        return estimateTxForAmountMweb(
          credentialsAmount,
          outputs,
          feeRate,
          inputsCount: utxoDetails.utxos.length + 1,
          memo: memo,
          coinTypeToSpendFrom: coinTypeToSpendFrom,
        );
      }

      throw BitcoinTransactionWrongBalanceException();
    }

    final changeAddress = await (walletAddresses as LitecoinWalletAddresses).getChangeAddress(
      inputs: utxoDetails.availableInputs,
      outputs: outputs,
      coinTypeToSpendFrom: coinTypeToSpendFrom,
    );
    final address = RegexUtils.addressTypeFromStr(changeAddress.address, network);
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

    int fee = await calcFeeMweb(
      utxos: utxoDetails.utxos,
      // Always take only not updated bitcoin outputs here so for every estimation
      // the SP outputs are re-generated to the proper taproot addresses
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

    if (isBelowDust(amountLeftForChange)) {
      // If has change that is lower than dust, will end up with tx rejected by network rules
      // so remove the change amount
      outputs.removeLast();
      outputs.removeLast();

      if (amountLeftForChange < 0) {
        if (!spendingAllCoins) {
          return estimateTxForAmountMweb(
            credentialsAmount,
            outputs,
            feeRate,
            inputsCount: utxoDetails.utxos.length + 1,
            memo: memo,
            useUnconfirmed: useUnconfirmed ?? spendingAllConfirmedCoins,
            coinTypeToSpendFrom: coinTypeToSpendFrom,
          );
        } else {
          throw BitcoinTransactionWrongBalanceException();
        }
      }

      return ElectrumEstimatedTx(
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

      return ElectrumEstimatedTx(
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

  Future<int> calcFeeMweb({
    required List<UtxoWithAddress> utxos,
    required List<BitcoinBaseOutput> outputs,
    String? memo,
    required int feeRate,
  }) async {
    bool spendsMweb = utxos.any((utxo) => utxo.utxo.scriptType == SegwitAddressType.mweb);
    bool paysToMweb = outputs
        .any((output) => output.toOutput.scriptPubKey.getAddressType() == SegwitAddressType.mweb);

    bool isRegular = !spendsMweb && !paysToMweb;
    bool isMweb = spendsMweb || paysToMweb;

    if (isMweb && !mwebEnabled) {
      throw Exception("MWEB is not enabled! can't calculate fee without starting the mweb server!");
      // TODO: likely the change address is mweb and just not updated
    }

    if (isRegular) {
      return await super.calcFee(
        utxos: utxos,
        outputs: outputs,
        memo: memo,
        feeRate: feeRate,
      );
    }

    if (outputs.length == 1 && outputs[0].toOutput.amount == BigInt.zero) {
      outputs = [
        BitcoinScriptOutput(
          script: outputs[0].toOutput.scriptPubKey,
          value: utxos.sumOfUtxosValue(),
        )
      ];
    }

    // https://github.com/ltcmweb/mwebd?tab=readme-ov-file#fee-estimation
    final preOutputSum =
        outputs.fold<BigInt>(BigInt.zero, (acc, output) => acc + output.toOutput.amount);
    var fee = utxos.sumOfUtxosValue() - preOutputSum;

    // determines if the fee is correct:
    BigInt _sumOutputAmounts(List<TxOutput> outputs) {
      BigInt sum = BigInt.zero;
      for (final e in outputs) {
        sum += e.amount;
      }
      return sum;
    }

    final sum1 = _sumOutputAmounts(outputs.map((e) => e.toOutput).toList()) + fee;
    final sum2 = utxos.sumOfUtxosValue();
    if (sum1 != sum2) {
      printV("@@@@@ WE HAD TO ADJUST THE FEE! @@@@@@@@");
      final diff = sum2 - sum1;
      // add the difference to the fee (abs value):
      fee += diff.abs();
    }

    final txb =
        BitcoinTransactionBuilder(utxos: utxos, outputs: outputs, fee: fee, network: network);
    final resp = await CwMweb.create(CreateRequest(
        rawTx: txb.buildTransaction((a, b, c, d) => '').toBytes(),
        scanSecret: scanSecret,
        spendSecret: spendSecret,
        feeRatePerKb: Int64(feeRate * 1000),
        dryRun: true));
    final tx = BtcTransaction.fromRaw(hex.encode(resp.rawTx));
    final posUtxos = utxos
        .where((utxo) => tx.inputs
            .any((input) => input.txId == utxo.utxo.txHash && input.txIndex == utxo.utxo.vout))
        .toList();
    final posOutputSum = tx.outputs.fold<int>(0, (acc, output) => acc + output.amount.toInt());
    final mwebInputSum = utxos.sumOfUtxosValue() - posUtxos.sumOfUtxosValue();
    final expectedPegin = max(0, (preOutputSum - mwebInputSum).toInt());
    var feeIncrease = posOutputSum - expectedPegin;
    if (expectedPegin > 0 && fee == BigInt.zero) {
      feeIncrease += await super.calcFee(
            utxos: posUtxos,
            outputs: tx.outputs
                .map((output) =>
                    BitcoinScriptOutput(script: output.scriptPubKey, value: output.amount))
                .toList(),
            memo: memo,
            feeRate: feeRate,
          ) +
          feeRate * 41;
    }
    return fee.toInt() + feeIncrease;
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    final transactionCredentials = credentials as BitcoinTransactionCredentials;

    try {
      late PendingBitcoinTransaction tx;

      try {
        final data = getCreateTxDataFromCredentials(credentials);
        final coinTypeToSpendFrom = transactionCredentials.coinTypeToSpendFrom;

        ElectrumEstimatedTx estimatedTx;
        if (data.sendAll) {
          estimatedTx = await estimateSendAllTxMweb(
            data.outputs,
            data.feeRate,
            memo: data.memo,
            coinTypeToSpendFrom: coinTypeToSpendFrom,
          );
        } else {
          estimatedTx = await estimateTxForAmountMweb(
            data.amount,
            data.outputs,
            data.feeRate,
            memo: data.memo,
            coinTypeToSpendFrom: coinTypeToSpendFrom,
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

          tx = PendingBitcoinTransaction(
            transaction,
            type,
            sendWorker: waitSendWorker,
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
        } else {
          final txb = BitcoinTransactionBuilder(
            utxos: estimatedTx.utxos,
            outputs: data.outputs,
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

          tx = PendingBitcoinTransaction(
            transaction,
            type,
            sendWorker: waitSendWorker,
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
        }
      } catch (e) {
        throw e;
      }

      tx.isMweb = mwebEnabled;

      if (!mwebEnabled) {
        tx.changeAddressOverride = (await (walletAddresses as LitecoinWalletAddresses)
                .getChangeAddress(coinTypeToSpendFrom: UnspentCoinType.nonMweb))
            .address;
        return tx;
      }
      await waitForMwebAddresses();

      final resp = await CwMweb.create(CreateRequest(
        rawTx: hex.decode(tx.hex),
        scanSecret: scanSecret,
        spendSecret: spendSecret,
        feeRatePerKb: Int64.parseInt(tx.feeRate) * 1000,
      ));
      final tx2 = BtcTransaction.fromRaw(hex.encode(resp.rawTx));

      bool hasMwebInput = false;
      bool hasMwebOutput = false;
      bool hasRegularOutput = false;

      for (final output in transactionCredentials.outputs) {
        final address = output.address.toLowerCase();
        final extractedAddress = output.extractedAddress?.toLowerCase();

        if (address.contains("mweb")) {
          hasMwebOutput = true;
        }
        if (!address.contains("mweb")) {
          hasRegularOutput = true;
        }
        if (extractedAddress != null && extractedAddress.isNotEmpty) {
          if (extractedAddress.contains("mweb")) {
            hasMwebOutput = true;
          }
          if (!extractedAddress.contains("mweb")) {
            hasRegularOutput = true;
          }
        }
      }

      // check if mweb inputs are used:
      for (final utxo in tx.utxos) {
        if (utxo.utxo.scriptType == SegwitAddressType.mweb) {
          hasMwebInput = true;
        }
      }

      // could probably be simplified but left for clarity:
      bool isPegIn = !hasMwebInput && hasMwebOutput;
      bool isPegOut = hasMwebInput && hasRegularOutput;
      bool isRegular = !hasMwebInput && !hasMwebOutput;
      bool shouldNotUseMwebChange = isPegIn || isRegular || !hasMwebInput;
      tx.changeAddressOverride = (await (walletAddresses as LitecoinWalletAddresses)
              .getChangeAddress(
                  coinTypeToSpendFrom:
                      shouldNotUseMwebChange ? UnspentCoinType.nonMweb : UnspentCoinType.any))
          .address;
      if (isRegular) {
        tx.isMweb = false;
        return tx;
      }

      final status = await CwMweb.status(StatusRequest());

      // check if any of the inputs of this transaction are hog-ex:
      // this list is only non-mweb inputs:
      tx2.inputs.forEach((txInput) {
        bool isHogEx = true;

        final utxo = unspentCoins
            .firstWhere((utxo) => utxo.hash == txInput.txId && utxo.vout == txInput.txIndex);

        // TODO: detect actual hog-ex inputs

        if (!isHogEx) {
          return;
        }

        int confirmations = utxo.confirmations ?? 0;
        if (confirmations == 0 && utxo.height != null) {
          confirmations = status.mwebUtxosHeight - utxo.height!;
        }

        if (confirmations < 6) {
          throw Exception(
              "A transaction input has less than 6 confirmations, please try again later.");
        }
      });

      tx.hexOverride = tx2
          .copyWith(
              witnesses: tx2.inputs.asMap().entries.map((e) {
            final utxo = unspentCoins
                .firstWhere((utxo) => utxo.hash == e.value.txId && utxo.vout == e.value.txIndex);
            final key = ECPrivate.fromBip32(
                bip32: hdWallet.derive((utxo.bitcoinAddressRecord as BitcoinAddressRecord)
                    .derivationInfo
                    .derivationPath));
            final digest = tx2.getTransactionSegwitDigit(
              txInIndex: e.key,
              script: key.getPublic().toP2pkhAddress().toScriptPubKey(),
              amount: BigInt.from(utxo.value),
            );
            return TxWitnessInput(stack: [key.signInput(digest), key.getPublic().toHex()]);
          }).toList())
          .toHex();
      tx.outputAddresses = resp.outputId;

      return tx
        ..addListener((transaction) async {
          final addresses = <String>{};
          transaction.inputAddresses?.forEach((id) async {
            final utxo = mwebUtxosBox.get(id);
            // await mwebUtxosBox.delete(id); // gets deleted in checkMwebUtxosSpent
            if (utxo == null) return;
            // mark utxo as spent so we add it to the unconfirmed balance (as negative):
            utxo.spent = true;
            await mwebUtxosBox.put(id, utxo);
            final addressRecord = walletAddresses.allAddresses
                .firstWhere((addressRecord) => addressRecord.address == utxo.address);
            if (!addresses.contains(utxo.address)) {
              addresses.add(utxo.address);
            }
            addressRecord.balance -= utxo.value.toInt();
          });
          transaction.inputAddresses?.addAll(addresses);
          printV("isPegIn: $isPegIn, isPegOut: $isPegOut");
          transaction.additionalInfo["isPegIn"] = isPegIn;
          transaction.additionalInfo["isPegOut"] = isPegOut;
          transactionHistory.addOne(transaction);
          await updateUnspent();
          await updateBalance();
        });
    } catch (e, s) {
      printV(e);
      printV(s);
      if (e.toString().contains("commit failed")) {
        printV(e);
        throw Exception("Transaction commit failed (no peers responded), please try again.");
      }
      rethrow;
    }
  }

  @action
  Future<void> refreshUnspentCoinsInfo() async {
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

  @override
  Future<void> save() async {
    await super.save();
  }

  @override
  Future<void> close({bool shouldCleanup = false}) async {
    _utxoStream?.cancel();
    _feeRatesTimer?.cancel();
    _syncTimer?.cancel();
    _processingTimer?.cancel();
    if (shouldCleanup) {
      try {
        await stopSync();
      } catch (_) {}
    }
    await super.close(shouldCleanup: shouldCleanup);
  }

  Future<void> setMwebEnabled(bool enabled) async {
    if (mwebEnabled == enabled &&
        alwaysScan == enabled &&
        (walletAddresses as LitecoinWalletAddresses).mwebEnabled == enabled) {
      return;
    }

    alwaysScan = enabled;
    mwebEnabled = enabled;
    (walletAddresses as LitecoinWalletAddresses).mwebEnabled = enabled;
    await save();
    try {
      await stopSync();
    } catch (_) {}
    await startSync();
  }

  Future<StatusResponse> getStatusRequest() async {
    final resp = await CwMweb.status(StatusRequest());
    return resp;
  }

  @override
  Future<String> signMessage(String message, {String? address = null}) async {
    Bip32Slip10Secp256k1 HD = hdWallet;

    final record = walletAddresses.allAddresses.firstWhere((element) => element.address == address);

    if (record.isChange) {
      HD = HD.childKey(Bip32KeyIndex(1));
    } else {
      HD = HD.childKey(Bip32KeyIndex(0));
    }

    HD = HD.childKey(Bip32KeyIndex(record.index));
    final priv = ECPrivate.fromHex(HD.privateKey.privKey.toHex());

    final privateKey = ECDSAPrivateKey.fromBytes(
      priv.toBytes(),
      Curves.generatorSecp256k1,
    );

    final signature =
        signLitecoinMessage(utf8.encode(message), privateKey: privateKey, bipPrive: priv.prive);

    return base64Encode(signature);
  }

  List<int> _magicPrefix(List<int> message, List<int> messagePrefix) {
    final encodeLength = IntUtils.encodeVarint(message.length);

    return [...messagePrefix, ...encodeLength, ...message];
  }

  List<int> signLitecoinMessage(List<int> message,
      {required ECDSAPrivateKey privateKey, required Bip32PrivateKey bipPrive}) {
    String messagePrefix = '\x19Litecoin Signed Message:\n';
    final messageHash = QuickCrypto.sha256Hash(magicMessage(message, messagePrefix));
    final signingKey = EcdsaSigningKey(privateKey);
    ECDSASignature ecdsaSign =
        signingKey.signDigestDeterminstic(digest: messageHash, hashFunc: () => SHA256());
    final n = Curves.generatorSecp256k1.order! >> 1;
    BigInt newS;
    if (ecdsaSign.s.compareTo(n) > 0) {
      newS = Curves.generatorSecp256k1.order! - ecdsaSign.s;
    } else {
      newS = ecdsaSign.s;
    }
    final rawSig = ECDSASignature(ecdsaSign.r, newS);
    final rawSigBytes = rawSig.toBytes(BitcoinSignerUtils.baselen);

    final pub = bipPrive.publicKey;
    final ECDomainParameters curve = ECCurve_secp256k1();
    final point = curve.curve.decodePoint(pub.point.toBytes());

    final rawSigEc = ECSignature(rawSig.r, rawSig.s);

    final recId = SignUtils.findRecoveryId(
      SignUtils.getHexString(messageHash, offset: 0, length: messageHash.length),
      rawSigEc,
      Uint8List.fromList(pub.uncompressed),
    );

    final v = recId + 27 + (point!.isCompressed ? 4 : 0);

    final combined = Uint8List.fromList([v, ...rawSigBytes]);

    return combined;
  }

  List<int> magicMessage(List<int> message, String messagePrefix) {
    final prefixBytes = StringUtils.encode(messagePrefix);
    final magic = _magicPrefix(message, prefixBytes);
    return QuickCrypto.sha256Hash(magic);
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
          "litecoin signature must be 64 bytes without recover-id or 65 bytes with recover-id");
    }

    String messagePrefix = '\x19Litecoin Signed Message:\n';
    final messageHash = QuickCrypto.sha256Hash(magicMessage(utf8.encode(message), messagePrefix));

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

  LedgerConnection? _ledgerConnection;
  LitecoinLedgerApp? _litecoinLedgerApp;

  @override
  void setLedgerConnection(LedgerConnection connection) {
    _ledgerConnection = connection;
    _litecoinLedgerApp = LitecoinLedgerApp(_ledgerConnection!,
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
    final readyInputs = <LedgerTransaction>[];
    for (final utxo in utxos) {
      final rawTx =
          (await getTransactionExpanded(hash: utxo.utxo.txHash)).originalTransaction.toHex();
      final publicKeyAndDerivationPath = publicKeys[utxo.ownerDetails.address.pubKeyHash()]!;

      readyInputs.add(LedgerTransaction(
        rawTx: rawTx,
        outputIndex: utxo.utxo.vout,
        ownerPublicKey: Uint8List.fromList(hex.decode(publicKeyAndDerivationPath.publicKey)),
        ownerDerivationPath: publicKeyAndDerivationPath.derivationPath,
        // sequence: enableRBF ? 0x1 : 0xffffffff,
        sequence: 0xffffffff,
      ));
    }

    String? changePath;
    for (final output in outputs) {
      final maybeChangePath = publicKeys[(output as BitcoinOutput).address.pubKeyHash()];
      if (maybeChangePath != null) changePath ??= maybeChangePath.derivationPath;
    }

    final rawHex = await _litecoinLedgerApp!.createTransaction(
        inputs: readyInputs,
        outputs: outputs
            .map((e) => TransactionOutput.fromBigInt((e as BitcoinOutput).value,
                Uint8List.fromList(e.address.toScriptPubKey().toBytes())))
            .toList(),
        changePath: changePath,
        sigHashType: 0x01,
        additionals: ["bech32"],
        isSegWit: true,
        useTrustedInputForSegwit: true);

    return BtcTransaction.fromRaw(rawHex);
  }
}
