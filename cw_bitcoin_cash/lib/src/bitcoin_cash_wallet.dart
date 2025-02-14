import 'package:bitbox/bitbox.dart' as bitbox;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/electrum_wallet_snapshot.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

import 'bitcoin_cash_base.dart';

part 'bitcoin_cash_wallet.g.dart';

class BitcoinCashWallet = BitcoinCashWalletBase with _$BitcoinCashWallet;

abstract class BitcoinCashWalletBase extends ElectrumWallet with Store {
  BitcoinCashWalletBase({
    required super.mnemonic,
    required super.password,
    required super.walletInfo,
    required super.unspentCoinsInfo,
    required super.encryptionFileUtils,
    required super.hdWallets,
    super.passphrase,
    BitcoinAddressType? addressPageType,
    super.initialBalance,
    super.didInitialSync,
    Map<String, dynamic>? walletAddressesSnapshot,
  }) : super(
          network: BitcoinCashNetwork.mainnet,
          currency: CryptoCurrency.bch,
        ) {
    if (walletAddressesSnapshot != null) {
      walletAddresses = BitcoinCashWalletAddressesBase.fromJson(
        walletAddressesSnapshot,
        walletInfo,
        network: network,
        isHardwareWallet: isHardwareWallet,
        hdWallets: hdWallets,
      );
    } else {
      this.walletAddresses = BitcoinCashWalletAddresses(
        walletInfo,
        network: network,
        isHardwareWallet: isHardwareWallet,
        hdWallets: hdWallets,
      );
    }

    autorun((_) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = this.isEnabledAutoGenerateSubaddress;
    });
  }

  @override
  BitcoinCashNetwork get network => BitcoinCashNetwork.mainnet;

  @override
  int estimatedTransactionSize({
    required List<BitcoinAddressType> inputTypes,
    required List<BitcoinAddressType> outputTypes,
    String? memo,
    bool enableRBF = true,
  }) =>
      ForkedTransactionBuilder.estimateTransactionSizeFromTypes(
        inputTypes: inputTypes,
        outputTypes: outputTypes,
        network: network,
        memo: memo,
        enableRBF: enableRBF,
      );

  static Future<BitcoinCashWallet> create({
    required String mnemonic,
    required String password,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required EncryptionFileUtils encryptionFileUtils,
    String? passphrase,
    String? addressPageType,
    ElectrumBalance? initialBalance,
  }) async {
    final hdWallets = await ElectrumWalletBase.getAccountHDWallets(
      walletInfo: walletInfo,
      network: BitcoinCashNetwork.mainnet,
      mnemonic: mnemonic,
      passphrase: passphrase,
    );

    return BitcoinCashWallet(
      mnemonic: mnemonic,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialBalance: initialBalance,
      encryptionFileUtils: encryptionFileUtils,
      addressPageType: P2pkhAddressType.p2pkh,
      passphrase: passphrase,
      hdWallets: hdWallets,
    );
  }

  static Future<BitcoinCashWallet> open({
    required String name,
    required WalletInfo walletInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfo,
    required String password,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);

    ElectrumWalletSnapshot? snp = null;

    try {
      snp = await ElectrumWalletSnapshot.load(
        encryptionFileUtils,
        name,
        walletInfo,
        password,
        BitcoinCashNetwork.mainnet,
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

    final hdWallets = await ElectrumWalletBase.getAccountHDWallets(
      walletInfo: walletInfo,
      network: BitcoinCashNetwork.mainnet,
      mnemonic: keysData.mnemonic,
      passphrase: keysData.passphrase,
      xpub: keysData.xPub,
    );

    return BitcoinCashWallet(
      mnemonic: keysData.mnemonic!,
      password: password,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfo,
      initialBalance: snp?.balance,
      encryptionFileUtils: encryptionFileUtils,
      addressPageType: P2pkhAddressType.p2pkh,
      passphrase: keysData.passphrase,
      didInitialSync: snp?.didInitialSync,
      hdWallets: hdWallets,
    );
  }

  bitbox.ECPair generateKeyPair({required Bip32Slip10Secp256k1 hd, required int index}) =>
      bitbox.ECPair.fromPrivateKey(
        Uint8List.fromList(hd.childKey(Bip32KeyIndex(index)).privateKey.raw),
      );

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
    final priv = ECPrivate.fromWif(
      WifEncoder.encode(HD.privateKey.raw, netVer: network.wifNetVer),
      netVersion: network.wifNetVer,
    );
    return priv.signMessage(StringUtils.encode(message));
  }

  @override
  int calcFee({
    required List<UtxoWithAddress> utxos,
    required List<BitcoinBaseOutput> outputs,
    String? memo,
    required int feeRate,
  }) =>
      feeRate *
      ForkedTransactionBuilder.estimateTransactionSize(
        utxos: utxos,
        outputs: outputs,
        network: network,
        memo: memo,
      );
}
