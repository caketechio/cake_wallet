import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/address_from_output.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_derivations.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_bitcoin/payjoin/manager.dart';
import 'package:cw_bitcoin/payjoin/storage.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_bitcoin/psbt/v0_finalizer.dart';
import 'package:cw_bitcoin/psbt/signer.dart';
import 'package:cw_bitcoin/psbt/transaction_builder.dart';
import 'package:cw_bitcoin/psbt/v0_deserialize.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/payjoin_session.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:ledger_bitcoin/psbt.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:mobx/mobx.dart';

part 'bitcoin_wallet.g.dart';

class BitcoinWallet = BitcoinWalletBase with _$BitcoinWallet;

abstract class BitcoinWalletBase extends ElectrumWallet with Store {
  BitcoinWalletBase({
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required Box<PayjoinSession> payjoinBox,
    required EncryptionFileUtils encryptionFileUtils,
    Uint8List? seedBytes,
    String? mnemonic,
    String? xpub,
    String? addressPageType,
    BasedUtxoNetwork? networkParam,
    List<BitcoinAddressRecord>? initialAddresses,
    ElectrumBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
    String? passphrase,
    List<BitcoinSilentPaymentAddressRecord>? initialSilentAddresses,
    int initialSilentAddressIndex = 0,
    bool? alwaysScan,
  }) : super(
          mnemonic: mnemonic,
          passphrase: passphrase,
          xpub: xpub,
          password: password,
          walletInfo: walletInfo,
          unspentCoinsInfo: unspentCoinsInfo,
          network: networkParam == null
              ? BitcoinNetwork.mainnet
              : networkParam == BitcoinNetwork.mainnet
                  ? BitcoinNetwork.mainnet
                  : BitcoinNetwork.testnet,
          initialAddresses: initialAddresses,
          initialBalance: initialBalance,
          seedBytes: seedBytes,
          encryptionFileUtils: encryptionFileUtils,
          currency: networkParam == BitcoinNetwork.testnet
              ? CryptoCurrency.tbtc
              : CryptoCurrency.btc,
          alwaysScan: alwaysScan,
        ) {
    // in a standard BIP44 wallet, mainHd derivation path = m/84'/0'/0'/0 (account 0, index unspecified here)
    // the sideHd derivation path = m/84'/0'/0'/1 (account 1, index unspecified here)
    // String derivationPath = walletInfo.derivationInfo!.derivationPath!;
    // String sideDerivationPath = derivationPath.substring(0, derivationPath.length - 1) + "1";
    // final hd = bitcoin.HDWallet.fromSeed(seedBytes, network: networkType);

    payjoinManager = PayjoinManager(PayjoinStorage(payjoinBox), this);
    walletAddresses = BitcoinWalletAddresses(
      walletInfo,
      initialAddresses: initialAddresses,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      initialSilentAddresses: initialSilentAddresses,
      initialSilentAddressIndex: initialSilentAddressIndex,
      mainHd: hd,
      sideHd: accountHD.childKey(Bip32KeyIndex(1)),
      network: networkParam ?? network,
      masterHd:
          seedBytes != null ? Bip32Slip10Secp256k1.fromSeed(seedBytes) : null,
      isHardwareWallet: walletInfo.isHardwareWallet,
      payjoinManager: payjoinManager
    );

    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress =
          this.isEnabledAutoGenerateSubaddress;
    });
  }

  static Future<BitcoinWallet> create({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required Box<PayjoinSession> payjoinBox,
    required EncryptionFileUtils encryptionFileUtils,
    String? passphrase,
    String? addressPageType,
    BasedUtxoNetwork? network,
    List<BitcoinAddressRecord>? initialAddresses,
    List<BitcoinSilentPaymentAddressRecord>? initialSilentAddresses,
    ElectrumBalance? initialBalance,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
    int initialSilentAddressIndex = 0,
  }) async {
    late Uint8List seedBytes;

    switch (walletInfo.derivationInfo?.derivationType) {
      case DerivationType.bip39:
        seedBytes = await bip39.mnemonicToSeed(
          mnemonic,
          passphrase: passphrase ?? "",
        );
        break;
      case DerivationType.electrum:
      default:
        seedBytes =
            await mnemonicToSeedBytes(mnemonic, passphrase: passphrase ?? "");
        break;
    }

    return BitcoinWallet(
      mnemonic: mnemonic,
      passphrase: passphrase ?? "",
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: initialAddresses,
      initialSilentAddresses: initialSilentAddresses,
      initialSilentAddressIndex: initialSilentAddressIndex,
      initialBalance: initialBalance,
      encryptionFileUtils: encryptionFileUtils,
      seedBytes: seedBytes,
      initialRegularAddressIndex: initialRegularAddressIndex,
      initialChangeAddressIndex: initialChangeAddressIndex,
      addressPageType: addressPageType,
      networkParam: network,
      payjoinBox: payjoinBox,
    );
  }

  static Future<BitcoinWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required Box<PayjoinSession> payjoinBox,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
    required bool alwaysScan,
  }) async {
    final network = walletInfo.network != null
        ? BasedUtxoNetwork.fromName(walletInfo.network!)
        : BitcoinNetwork.mainnet;

    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);

    ElectrumWalletSnapshot? snp = null;

    try {
      snp = await ElectrumWalletSnapshot.load(
        encryptionFileUtils,
        name,
        walletInfo.type,
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
    walletInfo.derivationInfo!.derivationPath ??=
        snp?.derivationPath ?? electrum_path;
    walletInfo.derivationInfo!.derivationType ??=
        snp?.derivationType ?? DerivationType.electrum;

    Uint8List? seedBytes = null;
    final mnemonic = keysData.mnemonic;
    final passphrase = keysData.passphrase;

    if (mnemonic != null) {
      switch (walletInfo.derivationInfo!.derivationType) {
        case DerivationType.electrum:
          seedBytes =
              await mnemonicToSeedBytes(mnemonic, passphrase: passphrase ?? "");
          break;
        case DerivationType.bip39:
        default:
          seedBytes = await bip39.mnemonicToSeed(
            mnemonic,
            passphrase: passphrase ?? '',
          );
          break;
      }
    }

    return BitcoinWallet(
      mnemonic: mnemonic,
      xpub: keysData.xPub,
      password: password,
      passphrase: passphrase,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialAddresses: snp?.addresses,
      initialSilentAddresses: snp?.silentAddresses,
      initialSilentAddressIndex: snp?.silentAddressIndex ?? 0,
      initialBalance: snp?.balance,
      encryptionFileUtils: encryptionFileUtils,
      seedBytes: seedBytes,
      initialRegularAddressIndex: snp?.regularAddressIndex,
      initialChangeAddressIndex: snp?.changeAddressIndex,
      addressPageType: snp?.addressPageType,
      networkParam: network,
      alwaysScan: alwaysScan,
      payjoinBox: payjoinBox
    );
  }

  LedgerConnection? _ledgerConnection;
  BitcoinLedgerApp? _bitcoinLedgerApp;

  @override
  void setLedgerConnection(LedgerConnection connection) {
    _ledgerConnection = connection;
    _bitcoinLedgerApp = BitcoinLedgerApp(_ledgerConnection!,
        derivationPath: walletInfo.derivationInfo!.derivationPath!);
  }

  late final PayjoinManager payjoinManager;

  Future<PsbtV2> buildPsbt({
    required List<BitcoinBaseOutput> outputs,
    required BigInt fee,
    required BasedUtxoNetwork network,
    required List<UtxoWithAddress> utxos,
    required Map<String, PublicKeyWithDerivationPath> publicKeys,
    required Uint8List masterFingerprint,
    String? memo,
    bool enableRBF = false,
    BitcoinOrdering inputOrdering = BitcoinOrdering.bip69,
    BitcoinOrdering outputOrdering = BitcoinOrdering.bip69,
  }) async {
    final psbtReadyInputs = <PSBTReadyUtxoWithAddress>[];
    for (final utxo in utxos) {
      final rawTx =
          await electrumClient.getTransactionHex(hash: utxo.utxo.txHash);
      final publicKeyAndDerivationPath =
          publicKeys[utxo.ownerDetails.address.pubKeyHash()]!;

      psbtReadyInputs.add(PSBTReadyUtxoWithAddress(
        utxo: utxo.utxo,
        rawTx: rawTx,
        ownerDetails: utxo.ownerDetails,
        ownerDerivationPath: publicKeyAndDerivationPath.derivationPath,
        ownerMasterFingerprint: masterFingerprint,
        ownerPublicKey: publicKeyAndDerivationPath.publicKey,
      ));
    }

    return PSBTTransactionBuild(
            inputs: psbtReadyInputs, outputs: outputs, enableRBF: enableRBF)
        .psbt;
  }

  @override
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
  }) async {
    final masterFingerprint = await _bitcoinLedgerApp!.getMasterFingerprint();

    final psbt = await buildPsbt(
      outputs: outputs,
      fee: fee,
      network: network,
      utxos: utxos,
      publicKeys: publicKeys,
      masterFingerprint: masterFingerprint,
      memo: memo,
      enableRBF: enableRBF,
      inputOrdering: inputOrdering,
      outputOrdering: outputOrdering,
    );

    final rawHex = await _bitcoinLedgerApp!.signPsbt(psbt: psbt);
    return BtcTransaction.fromRaw(BytesUtils.toHexString(rawHex));
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    credentials = credentials as BitcoinTransactionCredentials;

    final tx = (await super.createTransaction(credentials)) as PendingBitcoinTransaction;

    final payjoinUri = credentials.payjoinUri;
    if (payjoinUri == null) return tx;

    final transaction = await buildPsbt(
        utxos: tx.utxos,
        outputs: tx.outputs.map((e) => BitcoinOutput(
          address: addressFromScript(e.scriptPubKey),
          value: e.amount,
          isSilentPayment: e.isSilentPayment,
          isChange: e.isChange,
        )).toList(),
        fee: BigInt.from(tx.fee),
        network: network,
        memo: credentials.outputs.first.memo,
        outputOrdering: BitcoinOrdering.none,
        enableRBF: true,
        publicKeys: tx.publicKeys!,
        masterFingerprint: Uint8List(0)
    );

    final originalPsbt = await signPsbt(base64.encode(transaction.asPsbtV0()), getUtxoWithPrivateKeys());

    tx.commitOverride = () async {
      final sender = await payjoinManager.initSender(
          payjoinUri, originalPsbt, int.parse(tx.feeRate));
      payjoinManager.spawnNewSender(
          sender: sender, pjUrl: payjoinUri, amount: BigInt.from(tx.amount));
    };

    return tx;
  }

  List<UtxoWithPrivateKey> getUtxoWithPrivateKeys() => unspentCoins
      .where((e) => (e.isSending && !e.isFrozen))
      .map((unspent) => UtxoWithPrivateKey.fromUnspent(unspent, this))
      .toList();

  Future<void> commitPsbt(String finalizedPsbt) {
    final psbt = PsbtV2()..deserializeV0(base64.decode(finalizedPsbt));

    final btcTx =
        BtcTransaction.fromRaw(BytesUtils.toHexString(psbt.extract()));

    return PendingBitcoinTransaction(
      btcTx,
      type,
      electrumClient: electrumClient,
      amount: 0,
      fee: 0,
      feeRate: "",
      network: network,
      hasChange: true,
    ).commit();
  }

  Future<String> signPsbt(
      String preProcessedPsbt, List<UtxoWithPrivateKey> utxos) async {
    final psbt = PsbtV2()..deserializeV0(base64Decode(preProcessedPsbt));

    await psbt.signWithUTXO(utxos, (txDigest, utxo, key, sighash) {
      return utxo.utxo.isP2tr()
          ? key.signTapRoot(
              txDigest,
              sighash: sighash,
              tweak: utxo.utxo.isSilentPayment != true,
            )
          : key.signInput(txDigest, sigHash: sighash);
    }, (txId, vout) async {
      final txHex = await electrumClient.getTransactionHex(hash: txId);
      final output = BtcTransaction.fromRaw(txHex).outputs[vout];
      return TaprootAmountScriptPair(output.amount, output.scriptPubKey);
    });

    psbt.finalizeV0();
    return base64Encode(psbt.asPsbtV0());
  }

  @override
  Future<String> signMessage(String message, {String? address = null}) async {
    if (walletInfo.isHardwareWallet) {
      final addressEntry = address != null
          ? walletAddresses.allAddresses
              .firstWhere((element) => element.address == address)
          : null;
      final index = addressEntry?.index ?? 0;
      final isChange = addressEntry?.isHidden == true ? 1 : 0;
      final accountPath = walletInfo.derivationInfo?.derivationPath;
      final derivationPath =
          accountPath != null ? "$accountPath/$isChange/$index" : null;

      final signature = await _bitcoinLedgerApp!.signMessage(
          message: ascii.encode(message), signDerivationPath: derivationPath);
      return base64Encode(signature);
    }

    return super.signMessage(message, address: address);
  }
}
