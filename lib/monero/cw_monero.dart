part of 'monero.dart';

class CWMoneroAccountList extends MoneroAccountList {
  CWMoneroAccountList(this._wallet);

  final Object _wallet;

  @override
  @computed
  ObservableList<Account> get accounts {
    final moneroWallet = _wallet as MoneroWallet;
    final accounts = moneroWallet.walletAddresses.accountList.accounts
        .map((acc) => Account(id: acc.id, label: acc.label, balance: acc.balance))
        .toList();
    return ObservableList<Account>.of(accounts);
  }

  @override
  void update(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    moneroWallet.walletAddresses.accountList.update();
  }

  @override
  void refresh(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    moneroWallet.walletAddresses.accountList.refresh();
  }

  @override
  List<Account> getAll(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.walletAddresses.accountList
        .getAll()
        .map((acc) => Account(id: acc.id, label: acc.label, balance: acc.balance))
        .toList();
  }

  @override
  Future<void> addAccount(Object wallet, {required String label}) async {
    final moneroWallet = wallet as MoneroWallet;
    await moneroWallet.walletAddresses.accountList.addAccount(label: label);
  }

  @override
  Future<void> setLabelAccount(Object wallet,
      {required int accountIndex, required String label}) async {
    final moneroWallet = wallet as MoneroWallet;
    await moneroWallet.walletAddresses.accountList
        .setLabelAccount(accountIndex: accountIndex, label: label);
  }
}

class CWMoneroSubaddressList extends MoneroSubaddressList {
  CWMoneroSubaddressList(this._wallet);

  final Object _wallet;

  @override
  @computed
  ObservableList<Subaddress> get subaddresses {
    final moneroWallet = _wallet as MoneroWallet;
    final subAddresses = moneroWallet.walletAddresses.subaddressList.subaddresses
        .map((sub) => Subaddress(
          id: sub.id,
          address: sub.address,
          label: sub.label,
          received: sub.balance??"unknown",
          txCount: sub.txCount??0,
        ))
        .toList();
    return ObservableList<Subaddress>.of(subAddresses);
  }

  @override
  void update(Object wallet, {required int accountIndex}) {
    final moneroWallet = wallet as MoneroWallet;
    moneroWallet.walletAddresses.subaddressList.update(accountIndex: accountIndex);
  }

  @override
  void refresh(Object wallet, {required int accountIndex}) {
    final moneroWallet = wallet as MoneroWallet;
    moneroWallet.walletAddresses.subaddressList.refresh(accountIndex: accountIndex);
  }

  @override
  List<Subaddress> getAll(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.walletAddresses.subaddressList
        .getAll()
        .map((sub) => Subaddress(
          id: sub.id,
          label: sub.label,
          address: sub.address,
          txCount: sub.txCount??0,
          received: sub.balance??'unknown'))
        .toList();
  }

  @override
  Future<void> addSubaddress(Object wallet,
      {required int accountIndex, required String label}) async {
    final moneroWallet = wallet as MoneroWallet;
    return await moneroWallet.walletAddresses.subaddressList
        .addSubaddress(accountIndex: accountIndex, label: label);
  }

  @override
  Future<void> setLabelSubaddress(Object wallet,
      {required int accountIndex, required int addressIndex, required String label}) async {
    final moneroWallet = wallet as MoneroWallet;
    await moneroWallet.walletAddresses.subaddressList
        .setLabelSubaddress(accountIndex: accountIndex, addressIndex: addressIndex, label: label);
  }
}

class CWMoneroWalletDetails extends MoneroWalletDetails {
  CWMoneroWalletDetails(this._wallet);

  final Object _wallet;

  @computed
  @override
  Account get account {
    final moneroWallet = _wallet as MoneroWallet;
    final acc = moneroWallet.walletAddresses.account;
    return Account(id: acc!.id, label: acc.label, balance: acc.balance);
  }

  @computed
  @override
  MoneroBalance get balance {
    throw Exception('Unimplemented');
    // return MoneroBalance();
    //return MoneroBalance(
    //	fullBalance: balance.fullBalance,
    //	unlockedBalance: balance.unlockedBalance);
  }
}

class CWMonero extends Monero {
  @override
  MoneroAccountList getAccountList(Object wallet) => CWMoneroAccountList(wallet);

  @override
  MoneroSubaddressList getSubaddressList(Object wallet) => CWMoneroSubaddressList(wallet);

  @override
  TransactionHistoryBase getTransactionHistory(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.transactionHistory;
  }

  @override
  MoneroWalletDetails getMoneroWalletDetails(Object wallet) => CWMoneroWalletDetails(wallet);

  @override
  int getHeightByDate({required DateTime date}) => getMoneroHeigthByDate(date: date);

  @override
  TransactionPriority getDefaultTransactionPriority() => MoneroTransactionPriority.automatic;

  @override
  TransactionPriority getMoneroTransactionPrioritySlow() => MoneroTransactionPriority.slow;

  @override
  TransactionPriority getMoneroTransactionPriorityAutomatic() =>
      MoneroTransactionPriority.automatic;

  @override
  TransactionPriority deserializeMoneroTransactionPriority({required int raw}) =>
      MoneroTransactionPriority.deserialize(raw: raw);

  @override
  List<TransactionPriority> getTransactionPriorities() => MoneroTransactionPriority.all;

  @override
  List<String> getMoneroWordList(String language) {
    if (language.startsWith("POLYSEED_")) {
      final lang = language.replaceAll("POLYSEED_", "");
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
  WalletCredentials createMoneroRestoreWalletFromKeysCredentials(
          {required String name,
          required String spendKey,
          required String viewKey,
          required String address,
          required String password,
          required String language,
          required int height,
          HardwareWalletType? hardwareWalletType}) =>
      MoneroRestoreWalletFromKeysCredentials(
          name: name,
          spendKey: spendKey,
          viewKey: viewKey,
          address: address,
          password: password,
          language: language,
          height: height,
          hardwareWalletType: hardwareWalletType);

  @override
  WalletCredentials createMoneroRestoreWalletFromHardwareCredentials({
    required String name,
    required String password,
    required int height,
    required ledger.LedgerConnection ledgerConnection,
  }) =>
      MoneroRestoreWalletFromHardwareCredentials(
          name: name,
          password: password,
          height: height,
          ledgerConnection: ledgerConnection);

  @override
  WalletCredentials createMoneroRestoreWalletFromSeedCredentials(
          {required String name,
          required String password,
          required String passphrase,
          required int height,
          required String mnemonic}) =>
      MoneroRestoreWalletFromSeedCredentials(
          name: name, password: password, passphrase: passphrase, height: height, mnemonic: mnemonic);

  @override
  WalletCredentials createMoneroNewWalletCredentials({
    required String name,
    required String language,
    required bool isPolyseed,
    required String? passphrase,
    String? password}) =>
      MoneroNewWalletCredentials(
        name: name, password: password, language: language, isPolyseed: isPolyseed, passphrase: passphrase);

  @override
  Map<String, String> getKeys(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    final keys = moneroWallet.keys;
    return <String, String>{
      'primaryAddress': keys.primaryAddress,
      'privateSpendKey': keys.privateSpendKey,
      'privateViewKey': keys.privateViewKey,
      'publicSpendKey': keys.publicSpendKey,
      'publicViewKey': keys.publicViewKey,
      'passphrase': keys.passphrase
    };
  }

  @override
  int? getRestoreHeight(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.restoreHeight;
  }

  @override
  Object createMoneroTransactionCreationCredentials(
          {required List<Output> outputs, required TransactionPriority priority}) =>
      MoneroTransactionCreationCredentials(
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
  Object createMoneroTransactionCreationCredentialsRaw(
          {required List<OutputInfo> outputs, required TransactionPriority priority}) =>
      MoneroTransactionCreationCredentials(
          outputs: outputs, priority: priority as MoneroTransactionPriority);

  @override
  String formatterMoneroAmountToString({required int amount}) =>
      moneroAmountToString(amount: amount);

  @override
  double formatterMoneroAmountToDouble({required int amount}) =>
      moneroAmountToDouble(amount: amount);

  @override
  int formatterMoneroParseAmount({required String amount}) => moneroParseAmount(amount: amount);

  @override
  Account getCurrentAccount(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    final acc = moneroWallet.walletAddresses.account;
    return Account(id: acc!.id, label: acc.label, balance: acc.balance);
  }

  @override
  void setCurrentAccount(Object wallet, int id, String label, String? balance) {
    final moneroWallet = wallet as MoneroWallet;
    moneroWallet.walletAddresses.account =
        monero_account.Account(id: id, label: label, balance: balance);
  }

  @override
  void onStartup() => monero_wallet_api.onStartup();

  @override
  int getTransactionInfoAccountId(TransactionInfo tx) {
    final moneroTransactionInfo = tx as MoneroTransactionInfo;
    return moneroTransactionInfo.accountIndex;
  }

  @override
  WalletService createMoneroWalletService(
          Box<WalletInfo> walletInfoSource, Box<UnspentCoinsInfo> unspentCoinSource) =>
      MoneroWalletService(walletInfoSource, unspentCoinSource);

  @override
  String getTransactionAddress(Object wallet, int accountIndex, int addressIndex) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.getTransactionAddress(accountIndex, addressIndex);
  }

  @override
  String getSubaddressLabel(Object wallet, int accountIndex, int addressIndex) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.getSubaddressLabel(accountIndex, addressIndex);
  }

  @override
  Map<String, String> pendingTransactionInfo(Object transaction) {
    final ptx = transaction as PendingMoneroTransaction;
    return {'id': ptx.id, 'hex': ptx.hex, 'key': ptx.txKey};
  }

  @override
  List<Unspent> getUnspents(Object wallet) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.unspentCoins;
  }

  @override
  Future<void> updateUnspents(Object wallet) async {
    final moneroWallet = wallet as MoneroWallet;
    await moneroWallet.updateUnspent();
  }

  @override
  Future<int> getCurrentHeight() async {
    return monero_wallet_api.getCurrentHeight();
  }
  
  @override
  bool importKeyImagesUR(Object wallet, String ur) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.importKeyImagesUR(ur);
  }


  @override
  Future<bool> commitTransactionUR(Object wallet, String ur) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.submitTransactionUR(ur);
  }

  @override
  String exportOutputsUR(Object wallet, bool all) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.exportOutputsUR(all);
  }

  @override
  bool needExportOutputs(Object wallet, int amount) {
    final moneroWallet = wallet as MoneroWallet;
    return moneroWallet.needExportOutputs(amount);
  }

  @override
  void monerocCheck() {
    checkIfMoneroCIsFine();
  }

  @override
  void setLedgerConnection(Object wallet, ledger.LedgerConnection connection) {
    final moneroWallet = wallet as MoneroWallet;
    moneroWallet.setLedgerConnection(connection);
  }

  void resetLedgerConnection() {
    disableLedgerExchange();
  }

  @override
  void setGlobalLedgerConnection(ledger.LedgerConnection connection) {
    gLedger = connection;
    keepAlive(connection);
  }

  bool isViewOnly() {
    return isViewOnlyBySpendKey();
  }
}
