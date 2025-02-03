import 'dart:convert';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_not_created_exception.dart';
import 'package:cake_wallet/exchange/trade_not_found_exception.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/exchange/utils/currency_pairs_utils.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:http/http.dart';

class SimpleSwapExchangeProvider extends ExchangeProvider {
  SimpleSwapExchangeProvider() : super(pairList: supportedPairs(_notSupported));

  static const List<CryptoCurrency> _notSupported = [
    CryptoCurrency.zaddr,
    CryptoCurrency.xhv,
  ];

  static final apiKey =
      DeviceInfo.instance.isMobile ? secrets.simpleSwapApiKey : secrets.simpleSwapApiKeyDesktop;
  static const apiAuthority = 'api.simpleswap.io';
  static const getEstimatePath = '/v1/get_estimated';
  static const rangePath = '/v1/get_ranges';
  static const getExchangePath = '/v1/get_exchange';
  static const createExchangePath = '/v1/create_exchange';

  @override
  String get title => 'SimpleSwap';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => false;

  @override
  ExchangeProviderDescription get description => ExchangeProviderDescription.simpleSwap;

  @override
  Future<bool> checkIsAvailable() async {
    final uri = Uri.https(apiAuthority, getEstimatePath, <String, String>{'api_key': apiKey});
    final response = await ProxyWrapper().get(clearnetUri: uri);

    return !(response.statusCode == 403);
  }

  @override
  Future<Limits> fetchLimits(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required bool isFixedRateMode}) async {
    final params = <String, dynamic>{
      'api_key': apiKey,
      'fixed': isFixedRateMode.toString(),
      'currency_from': _normalizeCurrency(from),
      'currency_to': _normalizeCurrency(to),
    };
    final uri = Uri.https(apiAuthority, rangePath, params);

    final response = await ProxyWrapper().get(clearnetUri: uri);
    final responseString = await response.transform(utf8.decoder).join();

    if (response.statusCode == 500) {
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;
      final error = responseJSON['message'] as String;

      throw Exception('$error');
    }

    if (response.statusCode != 200) {
      throw Exception('Unexpected http status: ${response.statusCode}');
    }

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final min = double.tryParse(responseJSON['min'] as String? ?? '');
    final max = double.tryParse(responseJSON['max'] as String? ?? '');

    return Limits(min: min, max: max);
  }

  @override
  Future<double> fetchRate(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required double amount,
      required bool isFixedRateMode,
      required bool isReceiveAmount}) async {
    try {
      if (amount == 0) return 0.0;

      final params = {
        'api_key': apiKey,
        'currency_from': _normalizeCurrency(from),
        'currency_to': _normalizeCurrency(to),
        'amount': amount.toString(),
        'fixed': isFixedRateMode.toString()
      };
      final uri = Uri.https(apiAuthority, getEstimatePath, params);
      final response = await ProxyWrapper().get(clearnetUri: uri);
      final responseString = await response.transform(utf8.decoder).join();

      if (responseString == "null") return 0.00;

      final data = json.decode(responseString) as String;

      return double.parse(data) / amount;
    } catch (_) {
      return 0.00;
    }
  }

  @override
  Future<Trade> createTrade({
    required TradeRequest request,
    required bool isFixedRateMode,
    required bool isSendAll,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    final params = {'api_key': apiKey};
    final body = <String, dynamic>{
      "currency_from": _normalizeCurrency(request.fromCurrency),
      "currency_to": _normalizeCurrency(request.toCurrency),
      "amount": request.fromAmount,
      "fixed": isFixedRateMode,
      "user_refund_address": _normalizeAddress(request.refundAddress),
      "address_to": _normalizeAddress(request.toAddress)
    };
    final uri = Uri.https(apiAuthority, createExchangePath, params);

    final response = await post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode != 200 && response.statusCode != 201) {
      if (response.statusCode == 400) {
        final responseJSON = json.decode(response.body) as Map<String, dynamic>;
        final error = responseJSON['message'] as String;

        throw TradeNotCreatedException(description, description: error);
      }

      throw TradeNotCreatedException(description);
    }

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;
    final id = responseJSON['id'] as String;
    final inputAddress = responseJSON['address_from'] as String;
    final payoutAddress = responseJSON['address_to'] as String;
    final settleAddress = responseJSON['user_refund_address'] as String;
    final extraId = responseJSON['extra_id_from'] as String?;
    final receiveAmount = responseJSON['amount_to'] as String?;

    return Trade(
      id: id,
      provider: description,
      from: request.fromCurrency,
      to: request.toCurrency,
      inputAddress: inputAddress,
      refundAddress: settleAddress,
      extraId: extraId,
      state: TradeState.created,
      amount: request.fromAmount,
      receiveAmount: receiveAmount ?? request.toAmount,
      payoutAddress: payoutAddress,
      createdAt: DateTime.now(),
      isSendAll: isSendAll,
    );
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    final params = {'api_key': apiKey, 'id': id};
    final uri = Uri.https(apiAuthority, getExchangePath, params);
    final response = await ProxyWrapper().get(clearnetUri: uri);
    final responseString = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 404) {
      throw TradeNotFoundException(id, provider: description);
    }

    if (response.statusCode == 400) {
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;
      final error = responseJSON['message'] as String;

      throw TradeNotFoundException(id, provider: description, description: error);
    }

    if (response.statusCode != 200) {
      throw Exception('Unexpected http status: ${response.statusCode}');
    }

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final fromCurrency = responseJSON['currency_from'] as String;
    final toCurrency = responseJSON['currency_to'] as String;
    final inputAddress = responseJSON['address_from'] as String;
    final expectedSendAmount = responseJSON['expected_amount'].toString();
    final extraId = responseJSON['extra_id_from'] as String?;
    final status = responseJSON['status'] as String;
    final payoutAddress = responseJSON['address_to'] as String;

    return Trade(
      id: id,
      from: CryptoCurrency.fromString(fromCurrency),
      to: CryptoCurrency.fromString(toCurrency),
      extraId: extraId,
      provider: description,
      inputAddress: inputAddress,
      amount: expectedSendAmount,
      state: TradeState.deserialize(raw: status),
      payoutAddress: payoutAddress,
    );
  }

  static String _normalizeCurrency(CryptoCurrency currency) {
    switch (currency) {
      case CryptoCurrency.zaddr:
        return 'zec';
      case CryptoCurrency.zec:
        return 'zec';
      case CryptoCurrency.bnb:
        return currency.tag!.toLowerCase();
      case CryptoCurrency.usdterc20:
        return 'usdterc20';
      case CryptoCurrency.usdttrc20:
        return 'usdttrc20';
      case CryptoCurrency.usdcpoly:
        return 'usdcpoly';
      case CryptoCurrency.usdtPoly:
        return 'usdtpoly';
      case CryptoCurrency.usdcEPoly:
        return 'usdcepoly';
      case CryptoCurrency.usdcsol:
        return 'usdcspl';
      case CryptoCurrency.matic:
        return 'pol';
      case CryptoCurrency.maticpoly:
        return 'matic';
      default:
        return currency.title.toLowerCase();
    }
  }

  String _normalizeAddress(String address) =>
      address.startsWith('bitcoincash:') ? address.replaceFirst('bitcoincash:', '') : address;
}
