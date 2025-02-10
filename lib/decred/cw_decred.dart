part of 'decred.dart';

class CWDecred extends Decred {
  CWDecred() {
    // initialize the service for creating and loading dcr wallets.
    DecredWalletService.init();
  }

  @override
  WalletCredentials createDecredNewWalletCredentials(
          {required String name, WalletInfo? walletInfo}) =>
      DecredNewWalletCredentials(name: name, walletInfo: walletInfo);

  @override
  WalletCredentials createDecredRestoreWalletFromSeedCredentials(
          {required String name, required String mnemonic, required String password}) =>
      DecredRestoreWalletFromSeedCredentials(name: name, mnemonic: mnemonic, password: password);

  @override
  WalletCredentials createDecredRestoreWalletFromPubkeyCredentials(
          {required String name, required String pubkey, required String password}) =>
      DecredRestoreWalletFromPubkeyCredentials(name: name, pubkey: pubkey, password: password);

  @override
  WalletService createDecredWalletService(
      Box<WalletInfo> walletInfoSource, Box<UnspentCoinsInfo> unspentCoinSource) {
    return DecredWalletService(walletInfoSource, unspentCoinSource);
  }

  @override
  List<TransactionPriority> getTransactionPriorities() => DecredTransactionPriority.all;

  @override
  TransactionPriority getDecredTransactionPriorityMedium() => DecredTransactionPriority.medium;

  @override
  TransactionPriority getDecredTransactionPrioritySlow() => DecredTransactionPriority.slow;

  @override
  TransactionPriority deserializeDecredTransactionPriority(int raw) =>
      DecredTransactionPriority.deserialize(raw: raw);

  @override
  Object createDecredTransactionCredentials(List<Output> outputs, TransactionPriority priority) =>
      DecredTransactionCredentials(
          outputs
              .map((out) => OutputInfo(
                  fiatAmount: out.fiatAmount,
                  cryptoAmount: out.cryptoAmount,
                  address: out.address,
                  note: out.note,
                  sendAll: out.sendAll,
                  extractedAddress: out.extractedAddress,
                  isParsedAddress: out.isParsedAddress,
                  formattedCryptoAmount: out.formattedCryptoAmount))
              .toList(),
          priority: priority as DecredTransactionPriority);

  List<AddressInfo> getAddressInfos(Object wallet) {
    final decredWallet = wallet as DecredWallet;
    return decredWallet.walletAddresses.getAddressInfos();
  }

  @override
  Future<void> updateAddress(Object wallet, String address, String label) async {
    final decredWallet = wallet as DecredWallet;
    await decredWallet.walletAddresses.updateAddress(address, label);
  }

  @override
  Future<void> generateNewAddress(Object wallet, String label) async {
    final decredWallet = wallet as DecredWallet;
    await decredWallet.walletAddresses.generateNewAddress(label);
  }

  @override
  String formatterDecredAmountToString({required int amount}) =>
      decredAmountToString(amount: amount);

  @override
  double formatterDecredAmountToDouble({required int amount}) =>
      decredAmountToDouble(amount: amount);

  @override
  int formatterStringDoubleToDecredAmount(String amount) => stringDoubleToDecredAmount(amount);

  @override
  List<Unspent> getUnspents(Object wallet) {
    final decredWallet = wallet as DecredWallet;
    return decredWallet.unspents();
  }

  @override
  void updateUnspents(Object wallet) async {
    final decredWallet = wallet as DecredWallet;
    decredWallet.unspents();
  }

  @override
  int heightByDate(DateTime date) {
    final genesisBlocktime = DateTime.fromMillisecondsSinceEpoch(1454954400 * 1000);
    final minutesDiff = date.difference(genesisBlocktime).inMinutes;
    // Decred has five minute blocks on mainnet.
    // NOTE: This is off by about a day but is currently unused by decred as we
    // rescan from the wallet birthday.
    return minutesDiff ~/ 5;
  }

  @override
  List<String> getDecredWordList() => wordlist;

  @override
  String pubkey(Object wallet) {
    final decredWallet = wallet as DecredWallet;
    return decredWallet.pubkey;
  }
}
