import 'dart:convert';
import 'dart:developer';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/buy/buy_provider.dart';
import 'package:cake_wallet/buy/buy_quote.dart';
import 'package:cake_wallet/buy/payment_method.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OnRamperBuyProvider extends BuyProvider {
  OnRamperBuyProvider(this._settingsStore,
      {required WalletBase wallet, bool isTestEnvironment = false})
      : super(wallet: wallet, isTestEnvironment: isTestEnvironment, ledgerVM: null);

  static const _baseUrl = 'buy.onramper.com';
  static const _baseApiUrl = 'api.onramper.com';
  static const quotes = '/quotes';
  static const paymentTypes = '/payment-types';
  static const supported = '/supported';

  final SettingsStore _settingsStore;

  String get _apiKey => secrets.onramperApiKey;

  @override
  String get title => 'Onramper';

  @override
  String get providerDescription => S.current.onramper_option_description;

  @override
  String get lightIcon => 'assets/images/onramper_light.png';

  @override
  String get darkIcon => 'assets/images/onramper_dark.png';

  @override
  bool get isAggregator => true;

  Future<List<PaymentMethod>> getAvailablePaymentTypes(
      String fiatCurrency, String cryptoCurrency, bool isBuyAction) async {
    final params = {
      'fiatCurrency': fiatCurrency,
      'type': isBuyAction ? 'buy' : 'sell',
      'isRecurringPayment': 'false'
    };

    final url = Uri.https(_baseApiUrl, '$supported$paymentTypes/$fiatCurrency', params);

    try {
      final response =
          await http.get(url, headers: {'Authorization': _apiKey, 'accept': 'application/json'});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> message = data['message'] as List<dynamic>;
        return message
            .map((item) => PaymentMethod.fromOnramperJson(item as Map<String, dynamic>))
            .toList();
      } else {
        printV('Failed to fetch available payment types');
        return [];
      }
    } catch (e) {
      printV('Failed to fetch available payment types: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getOnrampMetadata() async {
    final url = Uri.https(_baseApiUrl, '$supported/onramps/all');

    try {
      final response =
          await http.get(url, headers: {'Authorization': _apiKey, 'accept': 'application/json'});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

        final List<dynamic> onramps = data['message'] as List<dynamic>;

        final Map<String, dynamic> result = {
          for (var onramp in onramps)
            (onramp['id'] as String): {
              'displayName': onramp['displayName'] as String,
              'svg': onramp['icons']['svg'] as String
            }
        };

        return result;
      } else {
        printV('Failed to fetch onramp metadata');
        return {};
      }
    } catch (e) {
      printV('Error occurred: $e');
      return {};
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

    final actionType = isBuyAction ? 'buy' : 'sell';

    final normalizedCryptoCurrency = _getNormalizeCryptoCurrency(cryptoCurrency);

    final params = {
      'amount': amount.toString(),
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      'clientName': 'CakeWallet',
      'type': actionType,
      'walletAddress': walletAddress,
      'isRecurringPayment': 'false',
      'input': 'source',
    };

    log('Onramper: Fetching $actionType quote: ${isBuyAction ? normalizedCryptoCurrency : fiatCurrency.name} -> ${isBuyAction ? fiatCurrency.name : normalizedCryptoCurrency}, amount: $amount, paymentMethod: $paymentMethod');

    final sourceCurrency = isBuyAction ? fiatCurrency.name : normalizedCryptoCurrency;
    final destinationCurrency = isBuyAction ? normalizedCryptoCurrency : fiatCurrency.name;

    final url = Uri.https(_baseApiUrl, '$quotes/${sourceCurrency}/${destinationCurrency}', params);
    final headers = {'Authorization': _apiKey, 'accept': 'application/json'};

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isEmpty) return null;

        List<Quote> validQuotes = [];

        final onrampMetadata = await getOnrampMetadata();

        for (var item in data) {

          if (item['errors'] != null) continue;

          final paymentMethod = (item as Map<String, dynamic>)['paymentMethod'] as String;

          final rampId = item['ramp'] as String?;
          final rampMetaData = onrampMetadata[rampId] as Map<String, dynamic>?;

          if (rampMetaData == null) continue;

          final quote = Quote.fromOnramperJson(
              item, isBuyAction, onrampMetadata, _getPaymentTypeByString(paymentMethod));
          quote.setFiatCurrency = fiatCurrency;
          quote.setCryptoCurrency = cryptoCurrency;
          validQuotes.add(quote);
        }

        if (validQuotes.isEmpty) return null;

        return validQuotes;
      } else {
        printV('Onramper: Failed to fetch rate');
        return null;
      }
    } catch (e) {
      printV('Onramper: Failed to fetch rate $e');
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
    final actionType = isBuyAction ? 'buy' : 'sell';

    final primaryColor = getColorStr(Theme.of(context).primaryColor);
    final secondaryColor = getColorStr(Theme.of(context).colorScheme.background);
    final primaryTextColor = getColorStr(Theme.of(context).extension<CakeTextTheme>()!.titleColor);
    final secondaryTextColor =
        getColorStr(Theme.of(context).extension<CakeTextTheme>()!.secondaryTextColor);
    final containerColor = getColorStr(Theme.of(context).colorScheme.background);
    var cardColor = getColorStr(Theme.of(context).cardColor);

    if (_settingsStore.currentTheme.title == S.current.high_contrast_theme) {
      cardColor = getColorStr(Colors.white);
    }

    final defaultCrypto = _getNormalizeCryptoCurrency(quote.cryptoCurrency);

    final paymentMethod = normalizePaymentMethod(quote.paymentType);

    final uri = Uri.https(_baseUrl, '', {
      'apiKey': _apiKey,
      'txnType': actionType,
      'txnFiat': quote.fiatCurrency.name,
      'txnCrypto': defaultCrypto,
      'txnAmount': amount.toString(),
      'skipTransactionScreen': "true",
      if (paymentMethod != null) 'txnPaymentMethod': paymentMethod,
      'txnOnramp': quote.rampId,
      'networkWallets': '$defaultCrypto:$cryptoCurrencyAddress',
      'supportSwap': "false",
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'containerColor': containerColor,
      'primaryTextColor': primaryTextColor,
      'secondaryTextColor': secondaryTextColor,
      'cardColor': cardColor,
    });

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch URL');
    }
  }

  List<CryptoCurrency> mainCurrency = [
    CryptoCurrency.btc,
    CryptoCurrency.eth,
    CryptoCurrency.sol,
  ];

  String _tagToNetwork(String tag) {
    switch (tag) {
      case 'OMNI':
      case 'BSC':
        return tag;
      case 'POL':
        return 'POLYGON';
      case 'ZEC':
        return 'ZCASH';
    default:
        try {
          return CryptoCurrency.fromString(tag).fullName!;
        } catch (_) {
          return tag;
        }
    }
  }

  String _getNormalizeCryptoCurrency(Currency currency) {
    if (currency is CryptoCurrency) {
      if (!mainCurrency.contains(currency)) {
        final network = currency.tag == null ? currency.fullName : _tagToNetwork(currency.tag!);
        return '${currency.title}_${network?.replaceAll(' ', '')}'.toUpperCase();
      }
      return currency.title.toUpperCase();
    }
    return currency.name.toUpperCase();
  }

  String? normalizePaymentMethod(PaymentType paymentType) {
    switch (paymentType) {
      case PaymentType.bankTransfer:
        return 'banktransfer';
      case PaymentType.creditCard:
        return 'creditcard';
      case PaymentType.debitCard:
        return 'debitcard';
      case PaymentType.applePay:
        return 'applepay';
      case PaymentType.googlePay:
        return 'googlepay';
      case PaymentType.revolutPay:
        return 'revolutpay';
      case PaymentType.neteller:
        return 'neteller';
      case PaymentType.skrill:
        return 'skrill';
      case PaymentType.sepa:
        return 'sepabanktransfer';
      case PaymentType.sepaInstant:
        return 'sepainstant';
      case PaymentType.ach:
        return 'ach';
      case PaymentType.achInstant:
        return 'iach';
      case PaymentType.Khipu:
        return 'khipu';
      case PaymentType.palomaBanktTansfer:
        return 'palomabanktransfer';
      case PaymentType.ovo:
        return 'ovo';
      case PaymentType.zaloPay:
        return 'zalopay';
      case PaymentType.zaloBankTransfer:
        return 'zalobanktransfer';
      case PaymentType.gcash:
        return 'gcash';
      case PaymentType.imps:
        return 'imps';
      case PaymentType.dana:
        return 'dana';
      case PaymentType.ideal:
        return 'ideal';
      default:
        return null;
    }
  }

  PaymentType _getPaymentTypeByString(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'banktransfer':
        return PaymentType.bankTransfer;
      case 'creditcard':
        return PaymentType.creditCard;
      case 'debitcard':
        return PaymentType.debitCard;
      case 'applepay':
        return PaymentType.applePay;
      case 'googlepay':
        return PaymentType.googlePay;
      case 'revolutpay':
        return PaymentType.revolutPay;
      case 'neteller':
        return PaymentType.neteller;
      case 'skrill':
        return PaymentType.skrill;
      case 'sepabanktransfer':
        return PaymentType.sepa;
      case 'sepainstant':
        return PaymentType.sepaInstant;
      case 'ach':
        return PaymentType.ach;
      case 'iach':
        return PaymentType.achInstant;
      case 'khipu':
        return PaymentType.Khipu;
      case 'palomabanktransfer':
        return PaymentType.palomaBanktTansfer;
      case 'ovo':
        return PaymentType.ovo;
      case 'zalopay':
        return PaymentType.zaloPay;
      case 'zalobanktransfer':
        return PaymentType.zaloBankTransfer;
      case 'gcash':
        return PaymentType.gcash;
      case 'imps':
        return PaymentType.imps;
      case 'dana':
        return PaymentType.dana;
      case 'ideal':
        return PaymentType.ideal;
      default:
        return PaymentType.all;
    }
  }

  String getColorStr(Color color) => color.value.toRadixString(16).replaceAll(RegExp(r'^ff'), "");
}
