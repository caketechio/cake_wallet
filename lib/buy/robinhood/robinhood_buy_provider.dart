import 'dart:convert';
import 'dart:developer';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/buy/buy_provider.dart';
import 'package:cake_wallet/buy/buy_quote.dart';
import 'package:cake_wallet/buy/payment_method.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/connect_device/connect_device_page.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/hardware_wallet/ledger_view_model.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class RobinhoodBuyProvider extends BuyProvider {
  RobinhoodBuyProvider(
      {required WalletBase wallet, bool isTestEnvironment = false, LedgerViewModel? ledgerVM})
      : super(wallet: wallet, isTestEnvironment: isTestEnvironment, ledgerVM: ledgerVM);

  static const _baseUrl = 'applink.robinhood.com';
  static const _cIdBaseUrl = 'exchange-helper.cakewallet.com';

  @override
  String get title => 'Robinhood Connect';

  @override
  String get providerDescription => S.current.robinhood_option_description;

  @override
  String get lightIcon => 'assets/images/robinhood_light.png';

  @override
  String get darkIcon => 'assets/images/robinhood_dark.png';

  @override
  bool get isAggregator => false;

  String get _applicationId => secrets.robinhoodApplicationId;

  String get _apiSecret => secrets.exchangeHelperApiKey;

  Future<String> getSignature(String message) async {
    switch (wallet.type) {
      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.solana:
      case WalletType.tron:
        return await wallet.signMessage(message);
      case WalletType.litecoin:
      case WalletType.bitcoin:
      case WalletType.bitcoinCash:
        return await wallet.signMessage(message, address: wallet.walletAddresses.address);
      default:
        throw Exception("WalletType is not available for Robinhood ${wallet.type}");
    }
  }

  Future<String> getConnectId() async {
    final walletAddress = wallet.walletAddresses.address;
    final valid_until = (DateTime.now().millisecondsSinceEpoch / 1000).round() + 10;
    final message = "$_apiSecret:${valid_until}";

    final signature = await getSignature(message);

    final uri = Uri.https(_cIdBaseUrl, "/api/robinhood");

    var response = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: json
            .encode({'valid_until': valid_until, 'wallet': walletAddress, 'signature': signature}));

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as Map<String, dynamic>)['connectId'] as String;
    } else {
      throw Exception('Provider currently unavailable. Status: ${response.statusCode}');
    }
  }

  Future<Uri> requestProviderUrl() async {
    final connectId = await getConnectId();
    final networkName = wallet.currency.fullName?.toUpperCase().replaceAll(" ", "_");

    return Uri.https(_baseUrl, '/u/connect', <String, dynamic>{
      'applicationId': _applicationId,
      'connectId': connectId,
      'walletAddress': wallet.walletAddresses.address,
      'userIdentifier': wallet.walletAddresses.address,
      'supportedNetworks': networkName
    });
  }

  Future<void>? launchProvider(
      {required BuildContext context,
      required Quote quote,
      required double amount,
      required bool isBuyAction,
      required String cryptoCurrencyAddress,
      String? countryCode}) async {
    if (wallet.isLedger) {
      if (!ledgerVM!.isConnected) {
        await Navigator.of(context).pushNamed(Routes.connectDevices,
            arguments: ConnectDevicePageParams(
                walletType: wallet.walletInfo.type,
                onConnectDevice: (BuildContext context, LedgerViewModel ledgerVM) {
                  ledgerVM.setLedger(wallet);
                  Navigator.of(context).pop();
                }));
      } else {
        ledgerVM!.setLedger(wallet);
      }
    }

    try {
      final uri = await requestProviderUrl();
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      await showPopUp<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertWithOneAction(
                alertTitle: "Robinhood Connect",
                alertContent: e.toString(),
                buttonText: S.of(context).ok,
                buttonAction: () => Navigator.of(context).pop());
          });
    }
  }

  @override
  Future<List<Quote>?> fetchQuote(
      {required CryptoCurrency cryptoCurrency,
      required FiatCurrency fiatCurrency,
      required double amount,
      required bool isBuyAction,
      required String walletAddress,
      PaymentType? paymentType,
      String? countryCode}) async {
    String? paymentMethod;

    if (paymentType != null && paymentType != PaymentType.all) {
      paymentMethod = normalizePaymentMethod(paymentType);
      if (paymentMethod == null) return null;
    }

    final action = isBuyAction ? 'buy' : 'sell';
    log('Robinhood: Fetching $action quote: ${isBuyAction ? cryptoCurrency.title : fiatCurrency.name.toUpperCase()} -> ${isBuyAction ? fiatCurrency.name.toUpperCase() : cryptoCurrency.title}, amount: $amount paymentMethod: $paymentMethod');

    final queryParams = {
      'applicationId': _applicationId,
      'fiatCode': fiatCurrency.name,
      'assetCode': cryptoCurrency.title,
      'fiatAmount': amount.toString(),
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    };

    final uri =
        Uri.https('api.robinhood.com', '/catpay/v1/${cryptoCurrency.title}/quote/', queryParams);

    try {
      final response = await http.get(uri, headers: {'accept': 'application/json'});
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final paymentType = _getPaymentTypeByString(responseData['paymentMethod'] as String?);
        final quote = Quote.fromRobinhoodJson(responseData, isBuyAction, paymentType);
        quote.setFiatCurrency = fiatCurrency;
        quote.setCryptoCurrency = cryptoCurrency;
        return [quote];
      } else {
        if (responseData.containsKey('message')) {
          log('Robinhood Error: ${responseData['message']}');
        } else {
          printV('Robinhood Failed to fetch $action quote: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      log('Robinhood: Failed to fetch $action quote: $e');
      return null;
    }

    // Supported payment methods:
    // ● buying_power
    // ● crypto_balance
    // ● debit_card
    // ● bank_transfer
  }

  String? normalizePaymentMethod(PaymentType paymentMethod) {
    switch (paymentMethod) {
      case PaymentType.creditCard:
        return 'debit_card';
      case PaymentType.debitCard:
        return 'debit_card';
      case PaymentType.bankTransfer:
        return 'bank_transfer';
      default:
        return null;
    }
  }

  PaymentType _getPaymentTypeByString(String? paymentMethod) {
    switch (paymentMethod) {
      case 'debit_card':
        return PaymentType.debitCard;
      case 'bank_transfer':
        return PaymentType.bankTransfer;
      default:
        return PaymentType.all;
    }
  }
}
