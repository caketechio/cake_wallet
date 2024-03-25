part of 'bitcoin.dart';

class CWBitcoin extends Bitcoin {
  @override
  TransactionPriority getMediumTransactionPriority() => BitcoinTransactionPriority.medium;

  @override
  WalletCredentials createBitcoinRestoreWalletFromSeedCredentials(
          {required String name, required String mnemonic, required String password}) =>
      BitcoinRestoreWalletFromSeedCredentials(name: name, mnemonic: mnemonic, password: password);

  @override
  WalletCredentials createBitcoinRestoreWalletFromWIFCredentials(
          {required String name,
          required String password,
          required String wif,
          WalletInfo? walletInfo}) =>
      BitcoinRestoreWalletFromWIFCredentials(
          name: name, password: password, wif: wif, walletInfo: walletInfo);

  @override
  WalletCredentials createBitcoinNewWalletCredentials(
          {required String name, WalletInfo? walletInfo}) =>
      BitcoinNewWalletCredentials(name: name, walletInfo: walletInfo);

  @override
  List<String> getWordList() => wordlist;

  @override
  Map<String, String> getWalletKeys(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    final keys = bitcoinWallet.keys;

    return <String, String>{
      'wif': keys.wif,
      'privateKey': keys.privateKey,
      'publicKey': keys.publicKey
    };
  }

  @override
  List<TransactionPriority> getTransactionPriorities() => BitcoinTransactionPriority.all;

  @override
  List<TransactionPriority> getLitecoinTransactionPriorities() => LitecoinTransactionPriority.all;

  @override
  TransactionPriority deserializeBitcoinTransactionPriority(int raw) =>
      BitcoinTransactionPriority.deserialize(raw: raw);

  @override
  TransactionPriority deserializeLitecoinTransactionPriority(int raw) =>
      LitecoinTransactionPriority.deserialize(raw: raw);

  @override
  int getFeeRate(Object wallet, TransactionPriority priority) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.feeRate(priority);
  }

  @override
  Future<void> generateNewAddress(Object wallet, String label) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    await bitcoinWallet.walletAddresses.generateNewAddress(label: label);
    await wallet.save();
  }

  @override
  Future<void> updateAddress(Object wallet, String address, String label) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    bitcoinWallet.walletAddresses.updateAddress(address, label);
    await wallet.save();
  }

  @override
  Object createBitcoinTransactionCredentials(List<Output> outputs,
          {required TransactionPriority priority, int? feeRate}) =>
      BitcoinTransactionCredentials(
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
          priority: priority as BitcoinTransactionPriority,
          feeRate: feeRate);

  @override
  Object createBitcoinTransactionCredentialsRaw(List<OutputInfo> outputs,
          {TransactionPriority? priority, required int feeRate}) =>
      BitcoinTransactionCredentials(outputs,
          priority: priority != null ? priority as BitcoinTransactionPriority : null,
          feeRate: feeRate);

  @override
  List<String> getAddresses(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.walletAddresses.addressesByReceiveType
        .map((BitcoinAddressRecord addr) => addr.address)
        .toList();
  }

  @override
  @computed
  List<ElectrumSubAddress> getSubAddresses(Object wallet) {
    final electrumWallet = wallet as ElectrumWallet;
    return electrumWallet.walletAddresses.addressesByReceiveType
        .map((BitcoinAddressRecord addr) => ElectrumSubAddress(
            id: addr.index,
            name: addr.name,
            address: addr.address,
            txCount: addr.txCount,
            balance: addr.balance,
            isChange: addr.isHidden))
        .toList();
  }

  @override
  Future<int> estimateFakeSendAllTxAmount(Object wallet, TransactionPriority priority) async {
    final electrumWallet = wallet as ElectrumWallet;
    final sk = ECPrivate.random();

    final p2shAddr = sk.getPublic().toP2pkhInP2sh();
    final p2wpkhAddr = sk.getPublic().toP2wpkhAddress();
    try {
      final estimatedTx = await electrumWallet.estimateTxFeeAndInputsToUse(
          0,
          true,
          // Deposit address + change address
          [p2shAddr, p2wpkhAddr],
          [
            BitcoinOutput(address: p2shAddr, value: BigInt.zero),
            BitcoinOutput(address: p2wpkhAddr, value: BigInt.zero)
          ],
          null,
          priority as BitcoinTransactionPriority);

      return estimatedTx.amount;
    } catch (_) {
      return 0;
    }
  }

  @override
  String getAddress(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.walletAddresses.address;
  }

  @override
  String formatterBitcoinAmountToString({required int amount}) =>
      bitcoinAmountToString(amount: amount);

  @override
  double formatterBitcoinAmountToDouble({required int amount}) =>
      bitcoinAmountToDouble(amount: amount);

  @override
  int formatterStringDoubleToBitcoinAmount(String amount) => stringDoubleToBitcoinAmount(amount);

  @override
  String bitcoinTransactionPriorityWithLabel(TransactionPriority priority, int rate) =>
      (priority as BitcoinTransactionPriority).labelWithRate(rate);

  @override
  List<BitcoinUnspent> getUnspents(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.unspentCoins;
  }

  Future<void> updateUnspents(Object wallet) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    await bitcoinWallet.updateUnspent();
  }

  WalletService createBitcoinWalletService(
      Box<WalletInfo> walletInfoSource, Box<UnspentCoinsInfo> unspentCoinSource) {
    return BitcoinWalletService(walletInfoSource, unspentCoinSource);
  }

  WalletService createLitecoinWalletService(
      Box<WalletInfo> walletInfoSource, Box<UnspentCoinsInfo> unspentCoinSource) {
    return LitecoinWalletService(walletInfoSource, unspentCoinSource);
  }

  @override
  TransactionPriority getBitcoinTransactionPriorityMedium() => BitcoinTransactionPriority.medium;

  @override
  TransactionPriority getLitecoinTransactionPriorityMedium() => LitecoinTransactionPriority.medium;

  @override
  TransactionPriority getBitcoinTransactionPrioritySlow() => BitcoinTransactionPriority.slow;

  @override
  TransactionPriority getLitecoinTransactionPrioritySlow() => LitecoinTransactionPriority.slow;

  @override
  Future<void> setAddressType(Object wallet, dynamic option) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    await bitcoinWallet.walletAddresses.setAddressType(option as BitcoinAddressType);
  }

  @override
  ReceivePageOption getSelectedAddressType(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return BitcoinReceivePageOption.fromType(bitcoinWallet.walletAddresses.addressPageType);
  }

  @override
  List<ReceivePageOption> getBitcoinReceivePageOptions() => BitcoinReceivePageOption.all;

  @override
  BitcoinAddressType getBitcoinAddressType(ReceivePageOption option) {
    switch (option) {
      case BitcoinReceivePageOption.p2pkh:
        return P2pkhAddressType.p2pkh;
      case BitcoinReceivePageOption.p2sh:
        return P2shAddressType.p2wpkhInP2sh;
      case BitcoinReceivePageOption.p2tr:
        return SegwitAddresType.p2tr;
      case BitcoinReceivePageOption.p2wsh:
        return SegwitAddresType.p2wsh;
      case BitcoinReceivePageOption.p2wpkh:
      default:
        return SegwitAddresType.p2wpkh;
    }
  }

  @override
	void setTorOnly(Object wallet, bool torOnly) {
		final electrumWallet = wallet as ElectrumWallet;
		electrumWallet.setTorOnly(torOnly);
	}
}
