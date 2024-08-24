import 'dart:async';
import 'package:breez_sdk/breez_sdk.dart';
import 'package:breez_sdk/bridge_generated.dart' as BZG;
import 'package:breez_sdk/sdk.dart';
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/entities/calculate_fiat_amount_raw.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/lightning/lightning.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:collection/collection.dart';

part 'lightning_send_view_model.g.dart';

class LightningSendViewModel = LightningSendViewModelBase with _$LightningSendViewModel;

abstract class LightningSendViewModelBase with Store {
  LightningSendViewModelBase({
    required this.wallet,
    required this.settingsStore,
    required this.fiatConversionStore,
  }) {
    _sdk = BreezSDK();
  }

  final WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> wallet;
  final SettingsStore settingsStore;
  final FiatConversionStore fiatConversionStore;
  int satAmount = 0;

  late final BreezSDK _sdk;

  FiatCurrency get fiat => settingsStore.fiatCurrency;

  CryptoCurrency get currency => wallet.currency;

  @action
  Future<void> fetchLimits() async {
    BZG.OnchainPaymentLimitsResponse currentLimits = await _sdk.onchainPaymentLimits();
    print("Minimum amount, in sats: ${currentLimits.minSat}");
    print("Maximum amount, in sats: ${currentLimits.maxSat}");
    minSats = currentLimits.minSat;
    maxSats = currentLimits.maxSat;
  }

  @action
  Future<void> fetchFees() async {
    lightning!.fetchFees(wallet);
  }

  @observable
  bool loading = false;

  @observable
  int minSats = 0;

  @observable
  int maxSats = 0;

  @observable
  String btcAddress = "";

  @observable
  LNInvoice? invoice;

  @action
  void setLoading(bool value) {
    loading = value;
  }

  @computed
  int get customBitcoinFeeRate => settingsStore.customBitcoinFeeRate;

  void set customBitcoinFeeRate(int value) => settingsStore.customBitcoinFeeRate = value;

  @computed
  bool get isFiatDisabled => settingsStore.fiatApiMode == FiatApiMode.disabled;

  TransactionPriority get transactionPriority {
    final priority = settingsStore.priority[WalletType.lightning];

    if (priority == null) {
      throw Exception('Unexpected type ${WalletType.lightning}');
    }

    return priority;
  }

  int? getCustomPriorityIndex(List<TransactionPriority> priorities) {
    final customItem = priorities.firstWhereOrNull(
        (element) => element == lightning!.getLightningTransactionPriorityCustom());

    return customItem != null ? priorities.indexOf(customItem) : null;
  }

  Future<int?> get maxCustomFeeRate async {
    await lightning!.fetchFees(wallet);
    return lightning!.getMaxCustomFeeRate(wallet);
  }

  @action
  void setTransactionPriority(TransactionPriority priority) {
    settingsStore.priority[WalletType.lightning] = priority;
    estimateFeeSats();
  }

  String displayFeeRate(dynamic priority, int? customValue) {
    final _priority = priority as TransactionPriority;

    final rate = lightning!.getFeeRate(wallet, _priority);

    return lightning!
        .lightningTransactionPriorityWithLabel(_priority, rate, customRate: customValue);
  }

  @observable
  int estimatedFeeSats = 0;

  @observable
  String estimatedFeeFiatAmount = "";

  @action
  Future<void> estimateFeeSats() async {
    int formattedCryptoAmount = satAmount;
    int? fee = await lightning!.calculateEstimatedFeeAsync(
      wallet,
      settingsStore.priority[WalletType.lightning]!,
      formattedCryptoAmount,
    );

    if (settingsStore.priority[WalletType.lightning] ==
        lightning!.getLightningTransactionPriorityCustom()) {
      fee = await lightning!.getEstimatedFeeWithFeeRate(
        wallet,
        settingsStore.customBitcoinFeeRate,
        formattedCryptoAmount,
      );
    }

    estimatedFeeSats = (bitcoin!.formatterBitcoinAmountToDouble(amount: fee) * 100000000).round();
    estimatedFeeFiatAmount = formattedFiatAmount(estimatedFeeSats);
  }

  @action
  void setCryptoAmount(int sats) {
    satAmount = sats;
    estimateFeeSats();
  }

  String formattedFiatAmount(int sats) {
    String amount = calculateFiatAmountRaw(
      cryptoAmount: lightning!.formatterLightningAmountToDouble(amount: sats),
      price: fiatConversionStore.prices[CryptoCurrency.btcln],
    );
    return amount;
  }

  @action
  Future<void> sendInvoice(BZG.LNInvoice invoice, int satAmount) async {
    try {
      setLoading(true);
      late BZG.SendPaymentRequest req;

      if (invoice.amountMsat == null) {
        req = BZG.SendPaymentRequest(
          bolt11: invoice.bolt11,
          amountMsat: satAmount * 1000,
        );
      } else {
        req = BZG.SendPaymentRequest(bolt11: invoice.bolt11);
      }

      final response = await _sdk.sendPayment(req: req);
      if (response.payment.error != null) {
        throw Exception(response.payment.error);
      }

      if (response.payment.status == BZG.PaymentStatus.Failed) {
        throw Exception("Payment failed");
      }

      setLoading(false);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  @action
  Future<void> sendBtc(String address, int satAmount) async {
    try {
      setLoading(true);

      if (satAmount < minSats || (satAmount > maxSats && maxSats != 0)) {
        throw Exception("Amount is outside of liquidity limits!");
      }

      BZG.PrepareOnchainPaymentResponse prepareRes = await _sdk.prepareOnchainPayment(
        req: BZG.PrepareOnchainPaymentRequest(
          amountSat: satAmount,
          amountType: BZG.SwapAmountType.Send,
          claimTxFeerate: feeRate,
        ),
      );

      print("Sender amount: ${prepareRes.senderAmountSat} sats");
      print("Recipient amount: ${prepareRes.recipientAmountSat} sats");
      print("Total fees: ${prepareRes.totalFees} sats");

      BZG.PayOnchainRequest req = BZG.PayOnchainRequest(
        recipientAddress: address,
        prepareRes: prepareRes,
      );
      BZG.PayOnchainResponse res = await _sdk.payOnchain(req: req);

      if (res.reverseSwapInfo.status == BZG.ReverseSwapStatus.Cancelled) {
        throw Exception("Payment cancelled / error");
      }

      setLoading(false);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  int get feeRate {
    late int feeRate;
    if (settingsStore.priority[WalletType.lightning] ==
        lightning!.getLightningTransactionPriorityCustom()) {
      feeRate = settingsStore.customBitcoinFeeRate;
    } else {
      feeRate = lightning!.getFeeRate(wallet, settingsStore.priority[WalletType.lightning]!);
    }
    return feeRate;
  }

  @action
  Future<void> prepareRefundBtc(String address) async {
    BZG.PrepareRedeemOnchainFundsRequest req = BZG.PrepareRedeemOnchainFundsRequest(
      toAddress: address,
      satPerVbyte: feeRate,
    );
    final res = await _sdk.prepareRedeemOnchainFunds(req: req);
    estimatedFeeSats = res.txFeeSat;
  }

  @action
  Future<void> refundBtc(String address) async {
    try {
      setLoading(true);
      BZG.RedeemOnchainFundsRequest req = BZG.RedeemOnchainFundsRequest(
        toAddress: address,
        satPerVbyte: feeRate,
      );
      final res = await _sdk.redeemOnchainFunds(req: req);
      print(res.txid);
      setLoading(false);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  @action
  Future<void> processInput(String input, {BuildContext? context}) async {
    if (context != null) {
      FocusScope.of(context).unfocus();
    }

    late BZG.InputType inputType;

    try {
      inputType = await _sdk.parseInput(input: input);
    } catch (_) {
      throw Exception("Unknown input type");
    }

    if (inputType is BZG.InputType_Bolt11) {
      final bolt11 = await _sdk.parseInvoice(input);
      invoice = bolt11;
      if (invoice?.amountMsat != null) {
        setCryptoAmount(invoice!.amountMsat! ~/ 1000);
      }
      btcAddress = '';
    } else if (inputType is BZG.InputType_BitcoinAddress) {
      final address = inputType.address.address;
      btcAddress = address;
      invoice = null;
    } else if (inputType is BZG.InputType_LnUrlPay) {
      throw Exception("Unsupported input type");
    } else {
      throw Exception("Unknown input type");
    }
  }

  @action
  Future<void> processSilently(String input) async {
    try {
      await processInput(input);
    } catch (_) {
      btcAddress = '';
      invoice = null;
      setCryptoAmount(0);
    }
  }

  Future<bool> checkIfInputIsAddress(String input) async {
    try {
      final inputType = await _sdk.parseInput(input: input);
      if (inputType is BZG.InputType_BitcoinAddress) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
