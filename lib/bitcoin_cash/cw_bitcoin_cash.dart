part of 'bitcoin_cash.dart';

class CWBitcoinCash extends BitcoinCash {
  @override
  String getMnemonic(int? strength) => Mnemonic.generate();

  @override
  Uint8List getSeedFromMnemonic(String seed) => Mnemonic.toSeed(seed);

  @override
  WalletService createBitcoinCashWalletService(
      Box<WalletInfo> walletInfoSource, Box<UnspentCoinsInfo> unspentCoinSource) {
    return BitcoinCashWalletService(walletInfoSource, unspentCoinSource);
  }

  @override
  WalletCredentials createBitcoinCashNewWalletCredentials({
    required String name,
    WalletInfo? walletInfo,
  }) =>
      BitcoinCashNewWalletCredentials(name: name, walletInfo: walletInfo);

  @override
  WalletCredentials createBitcoinCashRestoreWalletFromSeedCredentials(
          {required String name, required String mnemonic, required String password}) =>
      BitcoinCashRestoreWalletFromSeedCredentials(
          name: name, mnemonic: mnemonic, password: password);

  @override
  TransactionPriority deserializeBitcoinCashTransactionPriority(int raw) =>
      BitcoinTransactionPriority.deserialize(raw: raw);

  @override
  TransactionPriority getDefaultTransactionPriority() => BitcoinTransactionPriority.medium;

  @override
  List<TransactionPriority> getTransactionPriorities() => BitcoinTransactionPriority.all;
}
