part of 'polygon.dart';

class CWPolygon extends Polygon {
  @override
  List<String> getPolygonWordList(String language) => EthereumMnemonics.englishWordlist;

  WalletService createPolygonWalletService(
          Box<WalletInfo> walletInfoSource, bool isDirect, bool isFlatpak) =>
      PolygonWalletService(walletInfoSource, isDirect, isFlatpak);

  @override
  WalletCredentials createPolygonNewWalletCredentials(
          {required String name, WalletInfo? walletInfo, String? password}) =>
      PolygonNewWalletCredentials(name: name, walletInfo: walletInfo, password: password);

  @override
  WalletCredentials createPolygonRestoreWalletFromSeedCredentials({
    required String name,
    required String mnemonic,
    required String password,
  }) =>
      PolygonRestoreWalletFromSeedCredentials(name: name, password: password, mnemonic: mnemonic);

  @override
  WalletCredentials createPolygonRestoreWalletFromPrivateKey({
    required String name,
    required String privateKey,
    required String password,
  }) =>
      PolygonRestoreWalletFromPrivateKey(name: name, password: password, privateKey: privateKey);

  @override
  String getAddress(WalletBase wallet) => (wallet as PolygonWallet).walletAddresses.address;

  @override
  String getPrivateKey(WalletBase wallet) {
    final privateKeyHolder = (wallet as PolygonWallet).polygonPrivateKey;
    String stringKey = bytesToHex(privateKeyHolder.privateKey);
    return stringKey;
  }

  @override
  String getPublicKey(WalletBase wallet) {
    final privateKeyInUnitInt = (wallet as PolygonWallet).polygonPrivateKey;
    final publicKey = privateKeyInUnitInt.address.hex;
    return publicKey;
  }

  @override
  TransactionPriority getDefaultTransactionPriority() => PolygonTransactionPriority.medium;

  @override
  TransactionPriority getPolygonTransactionPrioritySlow() => PolygonTransactionPriority.slow;

  @override
  List<TransactionPriority> getTransactionPriorities() => PolygonTransactionPriority.all;

  @override
  TransactionPriority deserializePolygonTransactionPriority(int raw) =>
      PolygonTransactionPriority.deserialize(raw: raw);

  Object createPolygonTransactionCredentials(
    List<Output> outputs, {
    required TransactionPriority priority,
    required CryptoCurrency currency,
    int? feeRate,
  }) =>
      PolygonTransactionCredentials(
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
        priority: priority as PolygonTransactionPriority,
        currency: currency,
        feeRate: feeRate,
      );

  Object createPolygonTransactionCredentialsRaw(
    List<OutputInfo> outputs, {
    TransactionPriority? priority,
    required CryptoCurrency currency,
    required int feeRate,
  }) =>
      PolygonTransactionCredentials(
        outputs,
        priority: priority as PolygonTransactionPriority?,
        currency: currency,
        feeRate: feeRate,
      );

  @override
  int formatterPolygonParseAmount(String amount) => PolygonFormatter.parsePolygonAmount(amount);

  @override
  double formatterPolygonAmountToDouble(
      {TransactionInfo? transaction, BigInt? amount, int exponent = 18}) {
    assert(transaction != null || amount != null);

    if (transaction != null) {
      transaction as PolygonTransactionInfo;
      return transaction.ethAmount / BigInt.from(10).pow(transaction.exponent);
    } else {
      return (amount!) / BigInt.from(10).pow(exponent);
    }
  }

  @override
  List<Erc20Token> getERC20Currencies(WalletBase wallet) {
    final polygonWallet = wallet as PolygonWallet;
    return polygonWallet.erc20Currencies;
  }

  @override
  Future<void> addErc20Token(WalletBase wallet, Erc20Token token) async =>
      await (wallet as PolygonWallet).addErc20Token(token);

  @override
  Future<void> deleteErc20Token(WalletBase wallet, Erc20Token token) async =>
      await (wallet as PolygonWallet).deleteErc20Token(token);

  @override
  Future<Erc20Token?> getErc20Token(WalletBase wallet, String contractAddress) async {
    final polygonWallet = wallet as PolygonWallet;
    return await polygonWallet.getErc20Token(contractAddress);
  }

  @override
  CryptoCurrency assetOfTransaction(WalletBase wallet, TransactionInfo transaction) {
    transaction as PolygonTransactionInfo;
    if (transaction.tokenSymbol == CryptoCurrency.maticpoly.title) {
      return CryptoCurrency.maticpoly;
    }

    wallet as PolygonWallet;
    return wallet.erc20Currencies.firstWhere(
        (element) => transaction.tokenSymbol.toLowerCase() == element.symbol.toLowerCase());
  }

  @override
  void updatePolygonScanUsageState(WalletBase wallet, bool isEnabled) {
    (wallet as PolygonWallet).updatePolygonScanUsageState(isEnabled);
  }

  @override
  Web3Client? getWeb3Client(WalletBase wallet) {
    return (wallet as PolygonWallet).getWeb3Client();
  }
}
