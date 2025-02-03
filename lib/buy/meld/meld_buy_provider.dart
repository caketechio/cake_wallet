import 'dart:convert';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/buy/buy_provider.dart';
import 'package:cake_wallet/buy/buy_quote.dart';
import 'package:cake_wallet/buy/payment_method.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MeldBuyProvider extends BuyProvider {
  MeldBuyProvider({required WalletBase wallet, bool isTestEnvironment = false})
      : super(wallet: wallet, isTestEnvironment: isTestEnvironment, ledgerVM: null);

  static const _isProduction = false;

  static const _baseUrl = _isProduction ? 'api.meld.io' : 'api-sb.meld.io';
  static const _providersProperties = '/service-providers/properties';
  static const _paymentMethodsPath = '/payment-methods';
  static const _quotePath = '/payments/crypto/quote';

  static const String sandboxUrl = 'sb.fluidmoney.xyz';
  static const String productionUrl = 'fluidmoney.xyz';

  static const String _baseWidgetUrl = _isProduction ? productionUrl : sandboxUrl;

  static String get _testApiKey => secrets.meldTestApiKey;

  static String get _testPublicKey => '' ; //secrets.meldTestPublicKey;

  @override
  String get title => 'Meld';

  @override
  String get providerDescription => 'Meld Buy Provider';

  @override
  String get lightIcon => 'assets/images/meld_logo.svg';

  @override
  String get darkIcon => 'assets/images/meld_logo.svg';

  @override
  bool get isAggregator => true;

  @override
  Future<List<PaymentMethod>> getAvailablePaymentTypes(
      String fiatCurrency, String cryptoCurrency, bool isBuyAction) async {
    final params = {'fiatCurrencies': fiatCurrency, 'statuses': 'LIVE,RECENTLY_ADDED,BUILDING'};

    final path = '$_providersProperties$_paymentMethodsPath';
    final url = Uri.https(_baseUrl, path, params);

    try {
      final response = await ProxyWrapper().get(
        clearnetUri: url,
        headers: {
          'Authorization': _isProduction ? '' : _testApiKey,
          'Meld-Version': '2023-12-19',
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      final responseString = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseString) as List<dynamic>;
        final paymentMethods =
            data.map((e) => PaymentMethod.fromMeldJson(e as Map<String, dynamic>)).toList();
        return paymentMethods;
      } else {
        printV('Meld: Failed to fetch payment types');
        return List<PaymentMethod>.empty();
      }
    } catch (e) {
      printV('Meld: Failed to fetch payment types: $e');
      return List<PaymentMethod>.empty();
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
      if (paymentMethod == null) paymentMethod = paymentType.name;
    }

    log('Meld: Fetching buy quote: ${isBuyAction ? cryptoCurrency : fiatCurrency} -> ${isBuyAction ? fiatCurrency : cryptoCurrency}, amount: $amount');

    final url = Uri.https(_baseUrl, _quotePath);
    final headers = {
      'Authorization': _testApiKey,
      'Meld-Version': '2023-12-19',
      'accept': 'application/json',
      'content-type': 'application/json',
    };
    final body = jsonEncode({
      'countryCode': countryCode,
      'destinationCurrencyCode': isBuyAction ? fiatCurrency.name : cryptoCurrency.title,
      'sourceAmount': amount,
      'sourceCurrencyCode': isBuyAction ? cryptoCurrency.title : fiatCurrency.name,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final paymentType = _getPaymentTypeByString(data['paymentMethodType'] as String?);
        final quote = Quote.fromMeldJson(data, isBuyAction, paymentType);

        quote.setFiatCurrency = fiatCurrency;
        quote.setCryptoCurrency = cryptoCurrency;

        return [quote];
      } else {
        return null;
      }
    } catch (e) {
      printV('Error fetching buy quote: $e');
      return null;
    }
  }

  Future<void>? launchProvider(
      {required BuildContext context,
      required Quote quote,
      required double amount,
      required bool isBuyAction,
      required String cryptoCurrencyAddress,
      String? countryCode}) async {
    final actionType = isBuyAction ? 'BUY' : 'SELL';

    final params = {
      'publicKey': _isProduction ? '' : _testPublicKey,
      'countryCode': countryCode,
      //'paymentMethodType': normalizePaymentMethod(paymentMethod.paymentMethodType),
      'sourceAmount': amount.toString(),
      'sourceCurrencyCode': quote.fiatCurrency,
      'destinationCurrencyCode': quote.cryptoCurrency,
      'walletAddress': cryptoCurrencyAddress,
      'transactionType': actionType
    };

    final uri = Uri.https(_baseWidgetUrl, '', params);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      await showPopUp<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertWithOneAction(
                alertTitle: "Meld",
                alertContent: S.of(context).buy_provider_unavailable + ': $e',
                buttonText: S.of(context).ok,
                buttonAction: () => Navigator.of(context).pop());
          });
    }
  }

  String? normalizePaymentMethod(PaymentType paymentType) {
    switch (paymentType) {
      case PaymentType.creditCard:
        return 'CREDIT_DEBIT_CARD';
      case PaymentType.applePay:
        return 'APPLE_PAY';
      case PaymentType.googlePay:
        return 'GOOGLE_PAY';
      case PaymentType.neteller:
        return 'NETELLER';
      case PaymentType.skrill:
        return 'SKRILL';
      case PaymentType.sepa:
        return 'SEPA';
      case PaymentType.sepaInstant:
        return 'SEPA_INSTANT';
      case PaymentType.ach:
        return 'ACH';
      case PaymentType.achInstant:
        return 'INSTANT_ACH';
      case PaymentType.Khipu:
        return 'KHIPU';
      case PaymentType.ovo:
        return 'OVO';
      case PaymentType.zaloPay:
        return 'ZALOPAY';
      case PaymentType.zaloBankTransfer:
        return 'ZA_BANK_TRANSFER';
      case PaymentType.gcash:
        return 'GCASH';
      case PaymentType.imps:
        return 'IMPS';
      case PaymentType.dana:
        return 'DANA';
      case PaymentType.ideal:
        return 'IDEAL';
      default:
        return null;
    }
  }

  PaymentType _getPaymentTypeByString(String? paymentMethod) {
    switch (paymentMethod?.toUpperCase()) {
      case 'CREDIT_DEBIT_CARD':
        return PaymentType.creditCard;
      case 'APPLE_PAY':
        return PaymentType.applePay;
      case 'GOOGLE_PAY':
        return PaymentType.googlePay;
      case 'NETELLER':
        return PaymentType.neteller;
      case 'SKRILL':
        return PaymentType.skrill;
      case 'SEPA':
        return PaymentType.sepa;
      case 'SEPA_INSTANT':
        return PaymentType.sepaInstant;
      case 'ACH':
        return PaymentType.ach;
      case 'INSTANT_ACH':
        return PaymentType.achInstant;
      case 'KHIPU':
        return PaymentType.Khipu;
      case 'OVO':
        return PaymentType.ovo;
      case 'ZALOPAY':
        return PaymentType.zaloPay;
      case 'ZA_BANK_TRANSFER':
        return PaymentType.zaloBankTransfer;
      case 'GCASH':
        return PaymentType.gcash;
      case 'IMPS':
        return PaymentType.imps;
      case 'DANA':
        return PaymentType.dana;
      case 'IDEAL':
        return PaymentType.ideal;
      default:
        return PaymentType.all;
    }
  }
}
