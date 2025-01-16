import 'dart:convert';
import 'dart:developer';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/buy/buy_exception.dart';
import 'package:cake_wallet/buy/buy_provider.dart';
import 'package:cake_wallet/buy/buy_provider_description.dart';
import 'package:cake_wallet/buy/buy_quote.dart';
import 'package:cake_wallet/buy/order.dart';
import 'package:cake_wallet/buy/payment_method.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';

class MoonPayProvider extends BuyProvider {
  MoonPayProvider({
    required SettingsStore settingsStore,
    required WalletBase wallet,
    bool isTestEnvironment = false,
  })  : baseSellUrl = isTestEnvironment ? _baseSellTestUrl : _baseSellProductUrl,
        baseBuyUrl = isTestEnvironment ? _baseBuyTestUrl : _baseBuyProductUrl,
        this._settingsStore = settingsStore,
        super(wallet: wallet, isTestEnvironment: isTestEnvironment, ledgerVM: null);

  final SettingsStore _settingsStore;

  static const _baseSellTestUrl = 'sell-sandbox.moonpay.com';
  static const _baseSellProductUrl = 'sell.moonpay.com';
  static const _baseBuyTestUrl = 'buy-staging.moonpay.com';
  static const _baseBuyProductUrl = 'buy.moonpay.com';
  static const _cIdBaseUrl = 'exchange-helper.cakewallet.com';
  static const _apiUrl = 'https://api.moonpay.com';
  static const _baseUrl = 'api.moonpay.com';
  static const _currenciesPath = '/v3/currencies';
  static const _buyQuote = '/buy_quote';
  static const _sellQuote = '/sell_quote';

  static const _transactionsSuffix = '/v1/transactions';

  final String baseBuyUrl;
  final String baseSellUrl;

  @override
  String get providerDescription =>
      'MoonPay offers a fast and simple way to buy and sell cryptocurrencies';

  @override
  String get title => 'MoonPay';

  @override
  String get lightIcon => 'assets/images/moonpay_light.png';

  @override
  String get darkIcon => 'assets/images/moonpay_dark.png';

  @override
  bool get isAggregator => false;

  static String get _apiKey => secrets.moonPayApiKey;

  String get currencyCode => walletTypeToCryptoCurrency(wallet.type).title.toLowerCase();

  String get trackUrl => baseBuyUrl + '/transaction_receipt?transactionId=';

  static String get _exchangeHelperApiKey => secrets.exchangeHelperApiKey;

  static String themeToMoonPayTheme(ThemeBase theme) {
    switch (theme.type) {
      case ThemeType.bright:
      case ThemeType.light:
        return 'light';
      case ThemeType.dark:
        return 'dark';
    }
  }

  Future<String> getMoonpaySignature(String query) async {
    final uri = Uri.https(_cIdBaseUrl, "/api/moonpay");

    final response = await post(uri,
        headers: {'Content-Type': 'application/json', 'x-api-key': _exchangeHelperApiKey},
        body: json.encode({'query': query}));

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as Map<String, dynamic>)['signature'] as String;
    } else {
      throw Exception(
          'Provider currently unavailable. Status: ${response.statusCode} ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchFiatCredentials(
      String fiatCurrency, String cryptocurrency, String? paymentMethod) async {
    final params = {'baseCurrencyCode': fiatCurrency.toLowerCase(), 'apiKey': _apiKey};

    if (paymentMethod != null) params['paymentMethod'] = paymentMethod;

    final path = '$_currenciesPath/${cryptocurrency.toLowerCase()}/limits';
    final url = Uri.https(_baseUrl, path, params);

    try {
      final response = await ProxyWrapper().get(clearnetUri: url, headers: {'accept': 'application/json'});
      final responseString = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        return jsonDecode(responseString) as Map<String, dynamic>;
      } else {
        printV('MoonPay does not support fiat: $fiatCurrency');
        return {};
      }
    } catch (e) {
      printV('MoonPay Error fetching fiat currencies: $e');
      return {};
    }
  }

  Future<List<PaymentMethod>> getAvailablePaymentTypes(
      String fiatCurrency, String cryptoCurrency, bool isBuyAction) async {
    final List<PaymentMethod> paymentMethods = [];

    if (isBuyAction) {
      final fiatBuyCredentials = await fetchFiatCredentials(fiatCurrency, cryptoCurrency, null);
      if (fiatBuyCredentials.isNotEmpty) {
        final paymentMethod = fiatBuyCredentials['paymentMethod'] as String?;
        paymentMethods.add(PaymentMethod.fromMoonPayJson(
            fiatBuyCredentials, _getPaymentTypeByString(paymentMethod)));
        return paymentMethods;
      }
    }

    return paymentMethods;
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
    } else {
      paymentMethod = 'credit_debit_card';
    }

    final action = isBuyAction ? 'buy' : 'sell';

    final formattedCryptoCurrency = _normalizeCurrency(cryptoCurrency);
    final baseCurrencyCode =
        isBuyAction ? fiatCurrency.name.toLowerCase() : cryptoCurrency.title.toLowerCase();

    final params = {
      'baseCurrencyCode': baseCurrencyCode,
      'baseCurrencyAmount': amount.toString(),
      'amount': amount.toString(),
      'paymentMethod': paymentMethod,
      'areFeesIncluded': 'false',
      'apiKey': _apiKey
    };

    log('MoonPay: Fetching $action quote: ${isBuyAction ? formattedCryptoCurrency : fiatCurrency.name.toLowerCase()} -> ${isBuyAction ? baseCurrencyCode : formattedCryptoCurrency}, amount: $amount, paymentMethod: $paymentMethod');

    final quotePath = isBuyAction ? _buyQuote : _sellQuote;

    final path = '$_currenciesPath/$formattedCryptoCurrency$quotePath';
    final url = Uri.https(_baseUrl, path, params);
    try {
      final response = await ProxyWrapper().get(clearnetUri: url);
      final responseString = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final data = jsonDecode(responseString) as Map<String, dynamic>;

        // Check if the response is for the correct fiat currency
        if (isBuyAction) {
          final fiatCurrencyCode = data['baseCurrencyCode'] as String?;
          if (fiatCurrencyCode == null || fiatCurrencyCode != fiatCurrency.name.toLowerCase())
            return null;
        } else {
          final quoteCurrency = data['quoteCurrency'] as Map<String, dynamic>?;
          if (quoteCurrency == null || quoteCurrency['code'] != fiatCurrency.name.toLowerCase())
            return null;
        }

        final paymentMethods = data['paymentMethod'] as String?;
        final quote =
            Quote.fromMoonPayJson(data, isBuyAction, _getPaymentTypeByString(paymentMethods));

        quote.setFiatCurrency = fiatCurrency;
        quote.setCryptoCurrency = cryptoCurrency;

        return [quote];
      } else {
        printV('Moon Pay: Error fetching buy quote: ');
        return null;
      }
    } catch (e) {
      printV('Moon Pay: Error fetching buy quote: $e');
      return null;
    }
  }

  @override
  Future<void>? launchProvider(
      {required BuildContext context,
      required Quote quote,
      required double amount,
      required bool isBuyAction,
      required String cryptoCurrencyAddress,
      String? countryCode}) async {

    final Map<String, String> params = {
      'theme': themeToMoonPayTheme(_settingsStore.currentTheme),
      'language': _settingsStore.languageCode,
      'colorCode': _settingsStore.currentTheme.type == ThemeType.dark
          ? '#${Palette.blueCraiola.value.toRadixString(16).substring(2, 8)}'
          : '#${Palette.moderateSlateBlue.value.toRadixString(16).substring(2, 8)}',
      'baseCurrencyCode': isBuyAction ? quote.fiatCurrency.name : quote.cryptoCurrency.name,
      'baseCurrencyAmount': amount.toString(),
      'walletAddress': cryptoCurrencyAddress,
      'lockAmount': 'false',
      'showAllCurrencies': 'false',
      'showWalletAddressForm': 'false',
      if (isBuyAction)
        'enabledPaymentMethods': normalizePaymentMethod(quote.paymentType) ??
            'credit_debit_card,apple_pay,google_pay,samsung_pay,sepa_bank_transfer,gbp_bank_transfer,gbp_open_banking_payment',
      if (!isBuyAction) 'refundWalletAddress': cryptoCurrencyAddress
    };

    if (isBuyAction) params['currencyCode'] = quote.cryptoCurrency.name;
    if (!isBuyAction) params['quoteCurrencyCode'] = quote.cryptoCurrency.name;

    try {
      {
        final uri = await requestMoonPayUrl(
            walletAddress: cryptoCurrencyAddress,
            settingsStore: _settingsStore,
            isBuyAction: isBuyAction,
            amount: amount.toString(),
            params: params);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch URL');
        }
      }
    } catch (e) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertWithOneAction(
              alertTitle: 'MoonPay',
              alertContent: 'The MoonPay service is currently unavailable: $e',
              buttonText: S.of(context).ok,
              buttonAction: () => Navigator.of(context).pop(),
            );
          },
        );
      }
    }
  }

  Future<Uri> requestMoonPayUrl({
    required String walletAddress,
    required SettingsStore settingsStore,
    required bool isBuyAction,
    required Map<String, String> params,
    String? amount,
  }) async {
    if (_apiKey.isNotEmpty) params['apiKey'] = _apiKey;

    final baseUrl = isBuyAction ? baseBuyUrl : baseSellUrl;
    final originalUri = Uri.https(baseUrl, '', params);

    if (isTestEnvironment) return originalUri;

    final signature = await getMoonpaySignature('?${originalUri.query}');
    final query = Map<String, dynamic>.from(originalUri.queryParameters);
    query['signature'] = signature;
    final signedUri = originalUri.replace(queryParameters: query);
    return signedUri;
  }

  Future<Order> findOrderById(String id) async {
    final url = _apiUrl + _transactionsSuffix + '/$id' + '?apiKey=' + _apiKey;
    final uri = Uri.parse(url);
    final response = await ProxyWrapper().get(clearnetUri: uri);
    final responseString = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw BuyException(title: providerDescription, content: 'Transaction $id is not found!');
    }

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final status = responseJSON['status'] as String;
    final state = TradeState.deserialize(raw: status);
    final createdAtRaw = responseJSON['createdAt'] as String;
    final createdAt = DateTime.parse(createdAtRaw).toLocal();
    final amount = responseJSON['quoteCurrencyAmount'] as double;

    return Order(
        id: id,
        provider: BuyProviderDescription.moonPay,
        transferId: id,
        state: state,
        createdAt: createdAt,
        amount: amount.toString(),
        receiveAddress: wallet.walletAddresses.address,
        walletId: wallet.id);
  }

  String _normalizeCurrency(CryptoCurrency currency) {
    if (currency.tag == 'POLY') {
      return '${currency.title.toLowerCase()}_polygon';
    }

    if (currency.tag == 'TRX') {
      return '${currency.title.toLowerCase()}_trx';
    }

    return currency.toString().toLowerCase();
  }

  String? normalizePaymentMethod(PaymentType paymentMethod) {
    switch (paymentMethod) {
      case PaymentType.creditCard:
        return 'credit_debit_card';
      case PaymentType.debitCard:
        return 'credit_debit_card';
      case PaymentType.ach:
        return 'ach_bank_transfer';
      case PaymentType.applePay:
        return 'apple_pay';
      case PaymentType.googlePay:
        return 'google_pay';
      case PaymentType.sepa:
        return 'sepa_bank_transfer';
      case PaymentType.paypal:
        return 'paypal';
      case PaymentType.sepaOpenBankingPayment:
        return 'sepa_open_banking_payment';
      case PaymentType.gbpOpenBankingPayment:
        return 'gbp_open_banking_payment';
      case PaymentType.lowCostAch:
        return 'low_cost_ach';
      case PaymentType.mobileWallet:
        return 'mobile_wallet';
      case PaymentType.pixInstantPayment:
        return 'pix_instant_payment';
      case PaymentType.yellowCardBankTransfer:
        return 'yellow_card_bank_transfer';
      case PaymentType.fiatBalance:
        return 'fiat_balance';
      default:
        return null;
    }
  }

  PaymentType _getPaymentTypeByString(String? paymentMethod) {
    switch (paymentMethod) {
      case 'ach_bank_transfer':
        return PaymentType.ach;
      case 'apple_pay':
        return PaymentType.applePay;
      case 'credit_debit_card':
        return PaymentType.creditCard;
      case 'fiat_balance':
        return PaymentType.fiatBalance;
      case 'gbp_open_banking_payment':
        return PaymentType.gbpOpenBankingPayment;
      case 'google_pay':
        return PaymentType.googlePay;
      case 'low_cost_ach':
        return PaymentType.lowCostAch;
      case 'mobile_wallet':
        return PaymentType.mobileWallet;
      case 'paypal':
        return PaymentType.paypal;
      case 'pix_instant_payment':
        return PaymentType.pixInstantPayment;
      case 'sepa_bank_transfer':
        return PaymentType.sepa;
      case 'sepa_open_banking_payment':
        return PaymentType.sepaOpenBankingPayment;
      case 'yellow_card_bank_transfer':
        return PaymentType.yellowCardBankTransfer;
      default:
        return PaymentType.all;
    }
  }
}
