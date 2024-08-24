part of 'lightning.dart';

class CWLightning extends Lightning {
  @override
  String formatterLightningAmountToString({required int amount}) =>
      bitcoinAmountToString(amount: amount * 100000000);

  @override
  double formatterLightningAmountToDouble({required int amount}) =>
      bitcoinAmountToDouble(amount: amount * 100000000);

  @override
  int formatterStringDoubleToLightningAmount(String amount) =>
      stringDoubleToBitcoinAmount(amount * 100000000);

  WalletService createLightningWalletService(
      Box<WalletInfo> walletInfoSource, Box<UnspentCoinsInfo> unspentCoinSource, bool isDirect) {
    return LightningWalletService(walletInfoSource, unspentCoinSource, isDirect);
  }

  @override
  List<LightningReceivePageOption> getLightningReceivePageOptions() =>
      LightningReceivePageOption.all;

  @override
  ReceivePageOption getOptionInvoice() => LightningReceivePageOption.lightningInvoice;

  @override
  ReceivePageOption getOptionOnchain() => LightningReceivePageOption.lightningOnchain;

  @override
  String satsToLightningString(int sats) {
    const bitcoinAmountLength = 8;
    const bitcoinAmountDivider = 100000000;
    const lightningAmountDivider = 1;
    final bitcoinAmountFormat = NumberFormat()
      ..maximumFractionDigits = bitcoinAmountLength
      ..minimumFractionDigits = 1;

    String formattedAmount = bitcoinAmountFormat.format(sats);
    return formattedAmount.substring(0, formattedAmount.length - 2);
  }

  @override
  String bitcoinAmountToLightningString({required int amount}) {
    final bitcoinAmountFormat = NumberFormat()
      ..maximumFractionDigits = bitcoinAmountLength
      ..minimumFractionDigits = 1;
    String formattedAmount =
        bitcoinAmountFormat.format(cryptoAmountToDouble(amount: amount, divider: 1));
    return formattedAmount.substring(0, formattedAmount.length - 2);
  }

  @override
  int bitcoinAmountToLightningAmount({required int amount}) {
    return amount * 100000000;
  }

  @override
  double bitcoinDoubleToLightningDouble({required double amount}) {
    return amount * 100000000;
  }

  @override
  double lightningDoubleToBitcoinDouble({required double amount}) {
    return amount / 100000000;
  }

  @override
  Map<String, int> getIncomingPayments(Object wallet) {
    return (wallet as LightningWallet).incomingPayments;
  }

  @override
  void clearIncomingPayments(Object wallet) {
    (wallet as LightningWallet).incomingPayments = {};
  }

  @override
  String lightningTransactionPriorityWithLabel(TransactionPriority priority, int rate,
          {int? customRate}) =>
      (priority as LightningTransactionPriority).labelWithRate(rate, customRate);

  @override
  List<TransactionPriority> getTransactionPriorities() => LightningTransactionPriority.all;

  @override
  TransactionPriority getLightningTransactionPriorityCustom() =>
      LightningTransactionPriority.custom;

  @override
  int getFeeRate(Object wallet, TransactionPriority priority) {
    final lightningWallet = wallet as LightningWallet;
    return lightningWallet.feeRate(priority);
  }

  @override
  int getMaxCustomFeeRate(Object wallet) {
    final lightningWallet = wallet as LightningWallet;
    return (lightningWallet.feeRate(LightningTransactionPriority.fastest) * 10).round();
  }

  @override
  Future<void> fetchFees(Object wallet) async {
    await (wallet as LightningWallet).fetchFees();
  }

  @override
  Future<int> calculateEstimatedFeeAsync(
      Object wallet, TransactionPriority? priority, int? amount) async {
    return await (wallet as LightningWallet).calculateEstimatedFeeAsync(priority, amount);
  }

  @override
  Future<int> getEstimatedFeeWithFeeRate(Object wallet, int feeRate, int? amount) async {
    return await (wallet as LightningWallet).getEstimatedFeeWithFeeRate(feeRate, amount);
  }

  @override
  TransactionPriority getDefaultTransactionPriority() => LightningTransactionPriority.economy;

  @override
  TransactionPriority deserializeLightningTransactionPriority({required int raw}) =>
      LightningTransactionPriority.deserialize(raw: raw);

  @override
  String getBreezApiKey() => secrets.breezApiKey;

  @override
  int getOnchainBalance(Object wallet) {
    return (wallet as LightningWallet).balance[CryptoCurrency.btcln]?.frozen ?? 0;
  }
}
