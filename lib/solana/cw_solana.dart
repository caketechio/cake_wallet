part of 'solana.dart';

class CWSolana extends Solana {
  @override
  List<String> getSolanaWordList(String language) => SolanaMnemonics.englishWordlist;

  WalletService createSolanaWalletService(Box<WalletInfo> walletInfoSource, bool isDirect) =>
      SolanaWalletService(walletInfoSource, isDirect);

  @override
  WalletCredentials createSolanaNewWalletCredentials({
    required String name,
    String? mnemonic,
    String? parentAddress,
    WalletInfo? walletInfo,
    String? password,
    String? passphrase,
  }) =>
      SolanaNewWalletCredentials(
        name: name,
        walletInfo: walletInfo,
        password: password,
        mnemonic: mnemonic,
        parentAddress: parentAddress,
        passphrase: passphrase,
      );

  @override
  WalletCredentials createSolanaRestoreWalletFromSeedCredentials({
    required String name,
    required String mnemonic,
    required String password,
    String? passphrase,
  }) =>
      SolanaRestoreWalletFromSeedCredentials(
        name: name,
        password: password,
        mnemonic: mnemonic,
        passphrase: passphrase,
      );

  @override
  WalletCredentials createSolanaRestoreWalletFromPrivateKey({
    required String name,
    required String privateKey,
    required String password,
  }) =>
      SolanaRestoreWalletFromPrivateKey(name: name, password: password, privateKey: privateKey);

  @override
  String getAddress(WalletBase wallet) => (wallet as SolanaWallet).walletAddresses.address;

  @override
  String getPrivateKey(WalletBase wallet) => (wallet as SolanaWallet).privateKey;

  @override
  String getPublicKey(WalletBase wallet) =>
      (wallet as SolanaWallet).solanaPublicKey.toAddress().address;
  Object createSolanaTransactionCredentials(
    List<Output> outputs, {
    required CryptoCurrency currency,
  }) =>
      SolanaTransactionCredentials(
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
        currency: currency,
      );

  Object createSolanaTransactionCredentialsRaw(
    List<OutputInfo> outputs, {
    required CryptoCurrency currency,
  }) =>
      SolanaTransactionCredentials(outputs, currency: currency);

  @override
  List<SPLToken> getSPLTokenCurrencies(WalletBase wallet) {
    final solanaWallet = wallet as SolanaWallet;
    return solanaWallet.splTokenCurrencies;
  }

  @override
  Future<void> addSPLToken(
    WalletBase wallet,
    CryptoCurrency token,
    String contractAddress,
  ) async {
    final splToken = SPLToken(
      name: token.name,
      symbol: token.title,
      mintAddress: contractAddress,
      decimal: token.decimals,
      mint: token.name.toUpperCase(),
      enabled: token.enabled,
      iconPath: token.iconPath,
    );

    await (wallet as SolanaWallet).addSPLToken(splToken);
  }

  @override
  Future<void> deleteSPLToken(WalletBase wallet, CryptoCurrency token) async =>
      await (wallet as SolanaWallet).deleteSPLToken(token as SPLToken);

  @override
  Future<SPLToken?> getSPLToken(WalletBase wallet, String mintAddress) async {
    final solanaWallet = wallet as SolanaWallet;
    return await solanaWallet.getSPLToken(mintAddress);
  }

  @override
  CryptoCurrency assetOfTransaction(WalletBase wallet, TransactionInfo transaction) {
    transaction as SolanaTransactionInfo;
    if (transaction.tokenSymbol == CryptoCurrency.sol.title) {
      return CryptoCurrency.sol;
    }

    wallet as SolanaWallet;

    return wallet.splTokenCurrencies.firstWhere(
      (element) => transaction.tokenSymbol == element.symbol,
    );
  }

  @override
  double getTransactionAmountRaw(TransactionInfo transactionInfo) {
    return (transactionInfo as SolanaTransactionInfo).solAmount.toDouble();
  }

  @override
  String getTokenAddress(CryptoCurrency asset) => (asset as SPLToken).mintAddress;

  @override
  List<int>? getValidationLength(CryptoCurrency type) {
    if (type is SPLToken) {
      return [32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44];
    }

    return null;
  }

  @override
  double? getEstimateFees(WalletBase wallet) {
    return (wallet as SolanaWallet).estimatedFee;
  }
}
