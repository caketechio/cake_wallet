part of 'ethereum.dart';

class CWEthereum extends Ethereum {
  @override
  List<String> getEthereumWordList(String language) => EthereumMnemonics.englishWordlist;

  WalletService createEthereumWalletService(
          Box<WalletInfo> walletInfoSource, bool isDirect, bool isFlatpak) =>
      EthereumWalletService(walletInfoSource, isDirect, isFlatpak);

  @override
  WalletCredentials createEthereumNewWalletCredentials({
    required String name,
    WalletInfo? walletInfo,
    String? password,
  }) =>
      EthereumNewWalletCredentials(name: name, walletInfo: walletInfo, password: password);

  @override
  WalletCredentials createEthereumRestoreWalletFromSeedCredentials({
    required String name,
    required String mnemonic,
    required String password,
  }) =>
      EthereumRestoreWalletFromSeedCredentials(name: name, password: password, mnemonic: mnemonic);

  @override
  WalletCredentials createEthereumRestoreWalletFromPrivateKey({
    required String name,
    required String privateKey,
    required String password,
  }) =>
      EthereumRestoreWalletFromPrivateKey(name: name, password: password, privateKey: privateKey);

  @override
  String getAddress(WalletBase wallet) => (wallet as EthereumWallet).walletAddresses.address;

  @override
  String getPrivateKey(WalletBase wallet) {
    final privateKeyHolder = (wallet as EthereumWallet).ethPrivateKey;
    String stringKey = bytesToHex(privateKeyHolder.privateKey);
    return stringKey;
  }

  @override
  String getPublicKey(WalletBase wallet) {
    final privateKeyInUnitInt = (wallet as EthereumWallet).ethPrivateKey;
    final publicKey = privateKeyInUnitInt.address.hex;
    return publicKey;
  }

  @override
  TransactionPriority getDefaultTransactionPriority() => EthereumTransactionPriority.medium;

  @override
  TransactionPriority getEthereumTransactionPrioritySlow() => EthereumTransactionPriority.slow;

  @override
  List<TransactionPriority> getTransactionPriorities() => EthereumTransactionPriority.all;

  @override
  TransactionPriority deserializeEthereumTransactionPriority(int raw) =>
      EthereumTransactionPriority.deserialize(raw: raw);

  Object createEthereumTransactionCredentials(
    List<Output> outputs, {
    required TransactionPriority priority,
    required CryptoCurrency currency,
    int? feeRate,
  }) =>
      EthereumTransactionCredentials(
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
        priority: priority as EthereumTransactionPriority,
        currency: currency,
        feeRate: feeRate,
      );

  Object createEthereumTransactionCredentialsRaw(
    List<OutputInfo> outputs, {
    TransactionPriority? priority,
    required CryptoCurrency currency,
    required int feeRate,
  }) =>
      EthereumTransactionCredentials(
        outputs,
        priority: priority as EthereumTransactionPriority?,
        currency: currency,
        feeRate: feeRate,
      );

  @override
  int formatterEthereumParseAmount(String amount) => EthereumFormatter.parseEthereumAmount(amount);

  @override
  double formatterEthereumAmountToDouble(
      {TransactionInfo? transaction, BigInt? amount, int exponent = 18}) {
    assert(transaction != null || amount != null);

    if (transaction != null) {
      transaction as EthereumTransactionInfo;
      return transaction.ethAmount / BigInt.from(10).pow(transaction.exponent);
    } else {
      return (amount!) / BigInt.from(10).pow(exponent);
    }
  }

  @override
  List<Erc20Token> getERC20Currencies(WalletBase wallet) {
    final ethereumWallet = wallet as EthereumWallet;
    return ethereumWallet.erc20Currencies;
  }

  @override
  Future<void> addErc20Token(WalletBase wallet, Erc20Token token) async =>
      await (wallet as EthereumWallet).addErc20Token(token);

  @override
  Future<void> deleteErc20Token(WalletBase wallet, Erc20Token token) async =>
      await (wallet as EthereumWallet).deleteErc20Token(token);

  @override
  Future<Erc20Token?> getErc20Token(WalletBase wallet, String contractAddress) async {
    final ethereumWallet = wallet as EthereumWallet;
    return await ethereumWallet.getErc20Token(contractAddress);
  }

  @override
  CryptoCurrency assetOfTransaction(WalletBase wallet, TransactionInfo transaction) {
    transaction as EthereumTransactionInfo;
    if (transaction.tokenSymbol == CryptoCurrency.eth.title) {
      return CryptoCurrency.eth;
    }

    wallet as EthereumWallet;
    return wallet.erc20Currencies
        .firstWhere((element) => transaction.tokenSymbol == element.symbol);
  }

  @override
  void updateEtherscanUsageState(WalletBase wallet, bool isEnabled) {
    (wallet as EthereumWallet).updateEtherscanUsageState(isEnabled);
  }

  @override
  Web3Client? getWeb3Client(WalletBase wallet) {
    return (wallet as EthereumWallet).getWeb3Client();
  }
}
