part of 'zano.dart';

class CWZano extends Zano {

  List<ZanoAsset> getZanoAssets(WalletBase wallet) => (wallet as ZanoWallet).zanoAssets.values.toList();

  @override
  Future<CryptoCurrency> addZanoAssetById(WalletBase wallet, String assetId) async => await (wallet as ZanoWallet).addZanoAssetById(assetId);

  @override
  Future<void> changeZanoAssetAvailability(WalletBase wallet, CryptoCurrency token) async => await (wallet as ZanoWallet).changeZanoAssetAvailability(token as ZanoAsset);

  @override
  Future<void> deleteZanoAsset(WalletBase wallet, CryptoCurrency token) async => await (wallet as ZanoWallet).deleteZanoAsset(token as ZanoAsset);

  @override
  Future<ZanoAsset?> getZanoAsset(WalletBase wallet, String assetId) async {
    final zanoWallet = wallet as ZanoWallet;
    return await zanoWallet.getZanoAsset(assetId);
  }

  // @override
  // TransactionHistoryBase getTransactionHistory(Object wallet) {
  //   final zanoWallet = wallet as ZanoWallet;
  //   return zanoWallet.transactionHistory;
  // }

  @override
  TransactionPriority getDefaultTransactionPriority() {
    return MoneroTransactionPriority.automatic;
  }

  @override
  TransactionPriority deserializeMoneroTransactionPriority({required int raw}) {
    return MoneroTransactionPriority.deserialize(raw: raw);
  }

  @override
  List<TransactionPriority> getTransactionPriorities() {
    return MoneroTransactionPriority.all;
  }

  @override
  List<String> getWordList(String language) {
    assert(language.toLowerCase() == LanguageList.english.toLowerCase());
    return EnglishMnemonics.words;
  }

  @override
  WalletCredentials createZanoRestoreWalletFromSeedCredentials(
      {required String name, required String password, required int height, required String passphrase, required String mnemonic}) {
    return ZanoRestoreWalletFromSeedCredentials(name: name, password: password, passphrase: passphrase, height: height, mnemonic: mnemonic);
  }

  @override
  WalletCredentials createZanoNewWalletCredentials({required String name, required String? password, required String? passphrase}) {
    return ZanoNewWalletCredentials(name: name, password: password, passphrase: passphrase);
  }

  @override
  Map<String, String> getKeys(Object wallet) {
    final zanoWallet = wallet as ZanoWallet;
    final keys = zanoWallet.keys;
    return <String, String>{
      'privateSpendKey': keys.privateSpendKey,
      'privateViewKey': keys.privateViewKey,
      'publicSpendKey': keys.publicSpendKey,
      'publicViewKey': keys.publicViewKey
    };
  }

  @override
  Object createZanoTransactionCredentials({required List<Output> outputs, required TransactionPriority priority, required CryptoCurrency currency}) {
    return ZanoTransactionCredentials(
      outputs: outputs
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
      priority: priority as MoneroTransactionPriority,
      currency: currency,
    );
  }

  @override
  double formatterIntAmountToDouble({required int amount, required CryptoCurrency currency, required bool forFee}) {
    // fee always counted in zano with default decimal points
    if (forFee) return ZanoFormatter.intAmountToDouble(amount);
    if (currency is ZanoAsset) return ZanoFormatter.intAmountToDouble(amount, currency.decimalPoint);
    return ZanoFormatter.intAmountToDouble(amount);
  }

  @override
  int formatterParseAmount({required String amount, required CryptoCurrency currency}) {
    if (currency is ZanoAsset) return ZanoFormatter.parseAmount(amount, currency.decimalPoint);
    return ZanoFormatter.parseAmount(amount);
  }

  // @override
  // int getTransactionInfoAccountId(TransactionInfo tx) {
  //   final zanoTransactionInfo = tx as ZanoTransactionInfo;
  //   return zanoTransactionInfo.accountIndex;
  // }

  @override
  WalletService createZanoWalletService(Box<WalletInfo> walletInfoSource) {
    return ZanoWalletService(walletInfoSource);
  }

  @override
  CryptoCurrency? assetOfTransaction(WalletBase wallet, TransactionInfo transaction) {
    transaction as ZanoTransactionInfo;
    if (transaction.tokenSymbol == CryptoCurrency.zano.title) {
      return CryptoCurrency.zano;
    }
    wallet as ZanoWallet;
    final asset = wallet.zanoAssets.values.firstWhereOrNull((element) => element?.ticker == transaction.tokenSymbol);
    return asset;
  }

  String getZanoAssetAddress(CryptoCurrency asset) => (asset as ZanoAsset).assetId;

  @override
  String getAddress(WalletBase wallet) => (wallet as ZanoWallet).walletAddresses.address;

  @override
  bool validateAddress(String address) => ZanoUtils.validateAddress(address);
}
