part of 'wownero.dart';

class CWWowneroAccountList extends WowneroAccountList {
  CWWowneroAccountList(this._wallet);

  final Object _wallet;

  @override
  @computed
  ObservableList<Account> get accounts {
    final wowneroWallet = _wallet as WowneroWallet;
    final accounts = wowneroWallet.walletAddresses.accountList.accounts
        .map((acc) => Account(id: acc.id, label: acc.label, balance: acc.balance))
        .toList();
    return ObservableList<Account>.of(accounts);
  }

  @override
  void update(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.accountList.update();
  }

  @override
  void refresh(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.accountList.refresh();
  }

  @override
  List<Account> getAll(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.walletAddresses.accountList
        .getAll()
        .map((acc) => Account(id: acc.id, label: acc.label, balance: acc.balance))
        .toList();
  }

  @override
  Future<void> addAccount(Object wallet, {required String label}) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.walletAddresses.accountList.addAccount(label: label);
  }

  @override
  Future<void> setLabelAccount(Object wallet,
      {required int accountIndex, required String label}) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.walletAddresses.accountList
        .setLabelAccount(accountIndex: accountIndex, label: label);
  }
}

class CWWowneroSubaddressList extends WowneroSubaddressList {
  CWWowneroSubaddressList(this._wallet);

  final Object _wallet;

  @override
  @computed
  ObservableList<Subaddress> get subaddresses {
    final wowneroWallet = _wallet as WowneroWallet;
    final subAddresses = wowneroWallet.walletAddresses.subaddressList.subaddresses
        .map((sub) => Subaddress(id: sub.id, address: sub.address, label: sub.label))
        .toList();
    return ObservableList<Subaddress>.of(subAddresses);
  }

  @override
  void update(Object wallet, {required int accountIndex}) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.subaddressList.update(accountIndex: accountIndex);
  }

  @override
  void refresh(Object wallet, {required int accountIndex}) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.subaddressList.refresh(accountIndex: accountIndex);
  }

  @override
  List<Subaddress> getAll(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.walletAddresses.subaddressList
        .getAll()
        .map((sub) => Subaddress(id: sub.id, label: sub.label, address: sub.address))
        .toList();
  }

  @override
  Future<void> addSubaddress(Object wallet,
      {required int accountIndex, required String label}) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.walletAddresses.subaddressList
        .addSubaddress(accountIndex: accountIndex, label: label);
  }

  @override
  Future<void> setLabelSubaddress(Object wallet,
      {required int accountIndex, required int addressIndex, required String label}) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.walletAddresses.subaddressList
        .setLabelSubaddress(accountIndex: accountIndex, addressIndex: addressIndex, label: label);
  }
}

class CWWowneroWalletDetails extends WowneroWalletDetails {
  CWWowneroWalletDetails(this._wallet);

  final Object _wallet;

  @computed
  @override
  Account get account {
    final wowneroWallet = _wallet as WowneroWallet;
    final acc = wowneroWallet.walletAddresses.account;
    return Account(id: acc!.id, label: acc.label, balance: acc.balance);
  }

  @computed
  @override
  WowneroBalance get balance {
    throw Exception('Unimplemented');
    // return WowneroBalance();
    //return WowneroBalance(
    //	fullBalance: balance.fullBalance,
    //	unlockedBalance: balance.unlockedBalance);
  }
}

class CWWownero extends Wownero {
  @override
  WowneroAccountList getAccountList(Object wallet) => CWWowneroAccountList(wallet);

  @override
  WowneroSubaddressList getSubaddressList(Object wallet) => CWWowneroSubaddressList(wallet);

  @override
  TransactionHistoryBase getTransactionHistory(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.transactionHistory;
  }

  @override
  WowneroWalletDetails getWowneroWalletDetails(Object wallet) => CWWowneroWalletDetails(wallet);

  @override
  int getHeightByDate({required DateTime date}) => getWowneroHeightByDate(date: date);

  @override
  TransactionPriority getDefaultTransactionPriority() => MoneroTransactionPriority.automatic;

  @override
  TransactionPriority getWowneroTransactionPrioritySlow() => MoneroTransactionPriority.slow;

  @override
  TransactionPriority getWowneroTransactionPriorityAutomatic() =>
      MoneroTransactionPriority.automatic;

  @override
  TransactionPriority deserializeWowneroTransactionPriority({required int raw}) =>
      MoneroTransactionPriority.deserialize(raw: raw);

  @override
  List<TransactionPriority> getTransactionPriorities() => MoneroTransactionPriority.all;

  @override
  List<String> getWowneroWordList(String language) {
    if (language.startsWith("POLYSEED_")) {
      final lang = language.replaceAll("POLYSEED_", "");
      return PolyseedLang.getByEnglishName(lang).words;
    }
    if (language.startsWith("WOWSEED_")) {
      final lang = language.replaceAll("WOWSEED_", "");
      return PolyseedLang.getByEnglishName(lang).words;
    }
    switch (language.toLowerCase()) {
      case 'english':
        return EnglishMnemonics.words;
      case 'chinese (simplified)':
        return ChineseSimplifiedMnemonics.words;
      case 'dutch':
        return DutchMnemonics.words;
      case 'german':
        return GermanMnemonics.words;
      case 'japanese':
        return JapaneseMnemonics.words;
      case 'portuguese':
        return PortugueseMnemonics.words;
      case 'russian':
        return RussianMnemonics.words;
      case 'spanish':
        return SpanishMnemonics.words;
      case 'french':
        return FrenchMnemonics.words;
      case 'italian':
        return ItalianMnemonics.words;
      default:
        return EnglishMnemonics.words;
    }
  }

  @override
  WalletCredentials createWowneroRestoreWalletFromKeysCredentials(
          {required String name,
          required String spendKey,
          required String viewKey,
          required String address,
          required String password,
          required String language,
          required int height}) =>
      WowneroRestoreWalletFromKeysCredentials(
          name: name,
          spendKey: spendKey,
          viewKey: viewKey,
          address: address,
          password: password,
          language: language,
          height: height);

  @override
  WalletCredentials createWowneroRestoreWalletFromSeedCredentials(
          {required String name,
          required String password,
          required String passphrase,
          required int height,
          required String mnemonic}) =>
      WowneroRestoreWalletFromSeedCredentials(
          name: name, password: password, passphrase: passphrase, height: height, mnemonic: mnemonic);

  @override
  WalletCredentials createWowneroNewWalletCredentials(
          {required String name,
          required String language,
          required bool isPolyseed,
          String? password}) =>
      WowneroNewWalletCredentials(
          name: name, password: password, language: language, isPolyseed: isPolyseed);

  @override
  Map<String, String> getKeys(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    final keys = wowneroWallet.keys;
    return <String, String>{
      'privateSpendKey': keys.privateSpendKey,
      'privateViewKey': keys.privateViewKey,
      'publicSpendKey': keys.publicSpendKey,
      'publicViewKey': keys.publicViewKey,
      'passphrase': keys.passphrase
    };
  }

  @override
  Object createWowneroTransactionCreationCredentials(
          {required List<Output> outputs, required TransactionPriority priority}) =>
      WowneroTransactionCreationCredentials(
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
          priority: priority as MoneroTransactionPriority);

  @override
  Object createWowneroTransactionCreationCredentialsRaw(
          {required List<OutputInfo> outputs, required TransactionPriority priority}) =>
      WowneroTransactionCreationCredentials(
          outputs: outputs, priority: priority as MoneroTransactionPriority);

  @override
  String formatterWowneroAmountToString({required int amount}) =>
      wowneroAmountToString(amount: amount);

  @override
  double formatterWowneroAmountToDouble({required int amount}) =>
      wowneroAmountToDouble(amount: amount);

  @override
  int formatterWowneroParseAmount({required String amount}) => wowneroParseAmount(amount: amount);

  @override
  Account getCurrentAccount(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    final acc = wowneroWallet.walletAddresses.account;
    return Account(id: acc!.id, label: acc.label, balance: acc.balance);
  }

  @override
  void setCurrentAccount(Object wallet, int id, String label, String? balance) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.account =
        wownero_account.Account(id: id, label: label, balance: balance);
  }

  @override
  void onStartup() => wownero_wallet_api.onStartup();

  @override
  int getTransactionInfoAccountId(TransactionInfo tx) {
    final wowneroTransactionInfo = tx as WowneroTransactionInfo;
    return wowneroTransactionInfo.accountIndex;
  }

  @override
  WalletService createWowneroWalletService(
          Box<WalletInfo> walletInfoSource, Box<UnspentCoinsInfo> unspentCoinSource) =>
      WowneroWalletService(walletInfoSource, unspentCoinSource);

  @override
  String getTransactionAddress(Object wallet, int accountIndex, int addressIndex) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.getTransactionAddress(accountIndex, addressIndex);
  }

  @override
  String getSubaddressLabel(Object wallet, int accountIndex, int addressIndex) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.getSubaddressLabel(accountIndex, addressIndex);
  }

  @override
  Map<String, String> pendingTransactionInfo(Object transaction) {
    final ptx = transaction as PendingWowneroTransaction;
    return {'id': ptx.id, 'hex': ptx.hex, 'key': ptx.txKey};
  }

  @override
  List<Unspent> getUnspents(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.unspentCoins;
  }

  @override
  Future<void> updateUnspents(Object wallet) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.updateUnspent();
  }

  @override
  Future<int> getCurrentHeight() async {
    return wownero_wallet_api.getCurrentHeight();
  }

  String getLegacySeed(Object wallet, String langName) =>
      (wallet as WowneroWalletBase).seedLegacy(langName);

  @override
  void wownerocCheck() {
    checkIfMoneroCIsFine();
  }
}
