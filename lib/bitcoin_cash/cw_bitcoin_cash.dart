part of 'bitcoin_cash.dart';

class CWBitcoinCash extends BitcoinCash {
  @override
  String getCashAddrFormat(String address) => AddressUtils.getCashAddrFormat(address);

  @override
  WalletService createBitcoinCashWalletService(
      Box<WalletInfo> walletInfoSource, Box<UnspentCoinsInfo> unspentCoinSource, bool isDirect) {
    return BitcoinCashWalletService(walletInfoSource, unspentCoinSource, isDirect);
  }

  @override
  WalletCredentials createBitcoinCashNewWalletCredentials({
    required String name,
    WalletInfo? walletInfo,
    String? password,
  }) =>
      BitcoinCashNewWalletCredentials(name: name, walletInfo: walletInfo, password: password);

  @override
  WalletCredentials createBitcoinCashRestoreWalletFromSeedCredentials(
          {required String name, required String mnemonic, required String password}) =>
      BitcoinCashRestoreWalletFromSeedCredentials(
          name: name, mnemonic: mnemonic, password: password);

  @override
  TransactionPriority deserializeBitcoinCashTransactionPriority(int raw) =>
      BitcoinCashTransactionPriority.deserialize(raw: raw);

  @override
  TransactionPriority getDefaultTransactionPriority() => BitcoinCashTransactionPriority.medium;

  @override
  List<TransactionPriority> getTransactionPriorities() => BitcoinCashTransactionPriority.all;

  @override
  TransactionPriority getBitcoinCashTransactionPrioritySlow() =>
      BitcoinCashTransactionPriority.slow;

  @override
  String getMnemonic(int? strength) => throw UnimplementedError();

  @override
  Uint8List getSeedFromMnemonic(String seed) => throw UnimplementedError();
}
